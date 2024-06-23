--[[

Alice Virtual Machine:

Instructions:

CLEAR
	Clears the stack
RUN [command] [number]
	Pops n arguments from the stack and passes all the values into the command.
	The resulting value is then pushed onto the stack.
RUN_VAR [command] [number]
	Pops n arguments from the stack and passes all the values into a variable that
	hopefully is a command. The resulting value is then pushed onto the stack.
SET [name]
	Pops the last value from the stack and sets it to [name]
PUSH_BOOL [0 | 1]
	Pushes either a true or false value into the stack
PUSH_NUM [number]
	Pushes the given number into the stack
PUSH_STR [string]
	Pushes the given string into the stack
PUSH_VAR [string]
	Pops a variable and pushes it's value to the stack
SHORT [string]
	Adds a string to the stack and a short option to the type
LONG [string]
	Adds a string to the stack and a long option to the type
PUSH_LIST [number]
	Pops n of stack and converts it into a list and pushes the list into the stack
PUSH_DICTIONARY [number]
	Pops n * 2 values from the stack and maps each key to a value in a dictionary, then
	pushes it back into the stack.

example:

test -xf -o {players: get-players, values: [1, 2, 3]}

would be converted into

SHORT X
SHORT F
PUSH_STR players
RUN test 0
PUSH_STR values
PUSH_NUM 1
PUSH_NUM 2
PUSH_NUM 3
PUSH_LIST 3
PUSH_DICT 2
SHORT o
RUN test 0

]]

local builtins = require("./builtins")
local option = require("./option")

type Value = any

export type Option = {
    long: string
} | {
	short: string
}

type Argument = Option | Value

type Command = (...Argument) -> (Value)

export type VMState = {
	variables: {[string]: any},
	commands: {[string]: Command},
	stack: {Value}
}

export type Clear = {
	type: "CLEAR"
}

export type Run = {
	type: "RUN",
	command: string,
	arguments: number
}

export type RunVariable = {
	type: "RUN_VAR",
	value: string,
	arguments: number
}

export type Set = {
	type: "SET",
	value: string
}

export type PushBool = {
	type: "PUSH_BOOL",
	value: boolean
}

export type PushNum = {
	type: "PUSH_NUM",
	value: number
}

export type PushStr = {
	type: "PUSH_STR",
	value: string
}

export type PushVar = {
	type: "PUSH_VAR",
	value: string
}

export type ShortOption = {
	type: "OPTION_SHORT",
	value: string
}

export type LongOption = {
	type: "OPTION_LONG",
	value: string
}

export type PushDictionary = {
	type: "PUSH_DICT",
	size: number
}

export type PushFunction = {
	type: "PUSH_FUNC",
	value: {Instruction}
}


export type Instruction = Clear | RunVariable | Run | Set | PushBool | PushNum | PushStr | PushVar | ShortOption | LongOption | PushDictionary | PushFunction

--- we use a separate nil value so that we can store it inside our stack.
local NIL = newproxy()

local function create_vm(): VMState
	return {
		variables = {},
		commands = setmetatable({}, {__index = builtins}) :: any,
		stack = {}
	}
end

local function inherited_vm(vm: VMState): VMState

	return {
		variables = setmetatable({}, {__index = vm.stack}) :: any,
		commands = setmetatable({}, {__index = vm.variables}) :: any,
		stack = {}
	}

end

local function run(vm: VMState, bytecode: {Instruction})

	-- we create our own versions of the stack and variables.
	-- this is done so that when the VM does error, we wont destroy the vm and
	-- we can recover from it.

	-- we clone the stack so that we can still pop values from it
	local stack = table.clone(vm.variables)
	-- we use a metatable to allow us to write to a new table, but read from our old table.
	local vars = setmetatable({}, {__index = vm.variables})
	local commands = vm.commands

	local function pop()
		local value = table.remove(stack)
		return if value == NIL then nil else value
	end

	local function push(value)
		table.insert(stack, if value == nil then NIL else value)
	end

	local function push_tuple(...)
		for i = 1, select("#", ...) do
			push(select(i, ...))
		end
	end

	local function Clear(i: Clear)
		table.clear(stack)
	end

	local function RunVar(i: RunVariable)
		local key = i.value
		local value = vars[key]

		if typeof(value) == "function" then
			-- pop the amount of values into a list of arguments
			local arguments = table.create(i.arguments)

			for i = 1, i.arguments do
				arguments[i] = pop()
			end

			push_tuple(value(arguments))
		else
			for i = 1, i.arguments do
				pop()
			end
			
			push(value)
		end
	end

	local function Run(i: Run)
		local key = i.command
		local command = commands[key]

		if command == nil then error(`"{key}" is not a valid command`, 0) end

		local arguments = {}
		for i = 1, i.arguments do
			push(arguments)
		end

	end

	local function Set(i: Set)
		
		local value = pop()

		vars[i.value] = value

	end

	local function PushV(i: PushBool)
		push(i.value)
	end

	local function PushShort(i: ShortOption)
		push(option.short(i.value))
	end

	local function PushLong(i: LongOption)
		push(option.long(i.value))
	end

	local function PushDict(i: PushDictionary)
		local size = i.size
		local dict = {}

		for i = 1, size do
			local key = pop()
			local value = pop()

			dict[key] = value
		end

		push(dict)
	end

	local function PushFunc(i: PushFunction)
		local inherited = inherited_vm(vm)

		local function closure(...)
			for i = 1, select("#", ...) do
				inherited.variables[i] = ...
			end
			inherited.variables["arguments"] = {...}

			run(inherited, i.value)
			table.clear(inherited.stack)
			return table.remove(inherited.stack)
		end

		push(closure)
	end

	local map = {
		CLEAR = Clear,
		RUN = Run,
		RUN_VAR = RunVar,
		SET = Set,
		PUSH_BOOL = PushV,
		PUSH_NUM = PushV,
		PUSH_STR = PushV,
		SHORT = PushShort,
		LONG = PushLong,
		PUSH_DICT = PushDict,
		PUSH_FUNC = PushFunc
	}

	for _, i in bytecode do
		map[i.type](i)
	end

	-- commit the changes to the vm
	for key, value in vars do
		vm.variables[key] = value
	end

	vm.stack = stack

end

return {

	create_vm = create_vm,
	inherited_vm = inherited_vm,
	run = run

}