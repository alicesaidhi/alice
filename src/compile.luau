--[[
Compiles the AST into bytecode
]]

local parse = require("./parse")
local vm = require("./vm")
local testkit = require("../test/testkit")

type Instruction = vm.Instruction

local function compile(root: {parse.Expression | parse.Call | parse.Statement})
	print "start compile"

	local instructions: {Instruction} = {}

	local generate_expression: (node: parse.Expression) -> ()
	local generate_command: (node: parse.Call) -> ()
	print("aa")

	local function generate_dictionary(node: parse.Expression)
		assert(node.type == "dictionary")

		local n = 0

		for _, value in node.values do
			if value.type == "assign" then
				generate_expression(value.left)
				generate_expression(value.right)
			else
				n += 1
				table.insert(instructions, {
					type = "PUSH_NUM",
					n = n
				})
				generate_expression(value)
			end
		end

		table.insert(instructions, {
			type = "PUSH_DICT",
			size = #node.values
		})
	end

	local function generate_function(node: parse.AST)
		assert(node.type == "function", `received {node.type}`)
		
		table.insert(instructions, {
			type = "PUSH_FUNC",
			value = compile(node.value)
		})
	end

	function generate_expression(node: parse.Expression | parse.Call)

		if node.type == "boolean" then
			table.insert(instructions, {
				type = "PUSH_BOOL",
				value = node.value
			})
		elseif node.type == "number" then
			table.insert(instructions, {
				type = "PUSH_NUM",
				value = node.value
			})
		elseif node.type == "string" then
			table.insert(instructions, {
				type = "PUSH_STR",
				value = node.value
			})
		elseif node.type == "variable" then
			table.insert(instructions, {
				type = "PUSH_VAR",
				value = node.value
			})
		elseif node.type == "dictionary" then
			generate_dictionary(node)
		elseif node.type == "function" then
			generate_function(node)
		elseif node.type == "ccall" then
			generate_command(node)
		elseif node.type == "fcall" then
			generate_command(node)
		else
			error(`received {node.type}`, 0)
		end

	end

	local function generate_option(node: parse.Option)

		if node.type == "loption" then
			table.insert(instructions, {
				type = "OPTION_LONG",
				value = node.value
			})
		elseif node.type == "soption" then
			table.insert(instructions, {
				type = "OPTION_SHORT",
				value = node.value
			})
		end

	end
	
	function generate_command(node: parse.Call)
		print(node.type, node.name)
		if node.type == "ccall" then

			for i = #node.arguments, 1, -1 do
				local arg = node.arguments[i]

				if arg.type == "loption" then
					generate_option(arg)
				elseif arg.type == "soption" then
					generate_option(arg)
				else
					generate_expression(arg)
				end
			end

			table.insert(instructions, {
				type = "RUN",
				command = node.name,
				arguments = #node.arguments
			} :: Instruction)
		elseif node.type == "fcall" then

			for i = #node.arguments, 1, -1 do
				local arg = node.arguments[i]
				generate_expression(arg)				
			end

			table.insert(instructions, {
				type = "RUN_VAR",
				value = node.name,
				arguments = #node.arguments
			})

		end

	end


	for _, node in root do
		if node.type == "assign" then
			generate_expression(node.right)

			if node.left.type ~= "string" then
				error(`variable must be identifier, but got {node.left.type}`, 0)
			end

			table.insert(instructions, {
				type = "SET",
				value = node.left.value
			})
		elseif node.type == "ccall" then
			generate_command(node)
		elseif node.type == "fcall" then
			generate_command(node)
		else
			testkit.print2(node)
			generate_expression(node)
		end
	end

	
	testkit.print2(instructions)

	return instructions

end

return compile