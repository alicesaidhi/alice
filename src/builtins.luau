type Value = any
type Callback = (options: {[string]: Value}, ...Value) -> Value?

export type Option = {
    long: string,
    short: string?,
    arg: boolean?
}
type Command = {
	opts: {Option}?,
	callback: Callback
}

local option = require("./option")

local function find<T>(l: {T}, predicate: (T) -> boolean): T?
	for k, v in l do
		if predicate(v) then return v end
	end
	return nil
end

local function command(command: Command)

	local opts = command.opts

	return function(...)
		local arguments = {}
		local options = {}
		local processing_opt

		for i = 1, select("#", ...) do
			local arg = select(i, ...)
			
			if type(arg) == "table" and option.is_option(arg) then
				if processing_opt then error(`option "{processing_opt}" has no argument`, 0) end
				local opt: option.Option = arg

				if not opts then error("command does not expect options", 0) end
				local corresponding = find(opts, function(v)
					return if opt.type == "long" then v.long == opt.name else v.short == opt.name
				end)

				if not corresponding then error(`unknown option "{opt.name}"`, 0) end
				if corresponding.arg then
					processing_opt = corresponding
					options[processing_opt.long] = true
				else
					options[processing_opt.long] = true
				end
			end

			if processing_opt then
				options[processing_opt.long] = arg
				processing_opt = nil
			else
				table.insert(arguments, arg)
			end

		end

		return command.callback(options, unpack(arguments))
	end
end

return {

	echo = command {
		callback = function(_, ...)
			print(...)
		end
	},

	-- table manip

	set = command {
		callback = function(_, t, key, value)
			t[key] = value
		end
	},

	read = command {
		callback = function(_, t, key)
			return t[key]
		end
	},

	insert = command {
		callback = function(_, t, k, v)
			table.insert(t, k, v)
		end
	},

	remove = command {
		callback = function(_, t, k)
			table.remove(t, k)
		end
	},

	find = command {
		callback = function(_, t, predicate)
			if type(predicate) ~= "function" then
				error("no predicate given")
			end
			
			for k, v in t do
				if predicate(v, k) then
					return k
				end
			end
			return nil
		end
	},

	-- loop

	["if"] = command {
		callback = function(_, condition, callback, orelse)
			if not callback or typeof(callback) ~= "function" then
				error("callback is not a function", 0)
			end

			if orelse and typeof(orelse) ~= "function" then
				error("else is not a function", 0)
			end

			if condition then
				return callback()
			else
				return orelse()
			end
		end
	},

	["while"] = command {
		callback = function(_, condition, callback)
			if not condition or typeof(condition) ~= "function" then
				error("condition is not a function", 0)
			end

			if not callback or typeof(callback) ~= "function" then
				error("callback is not a function", 0)
			end

			while condition() do
				callback()
			end
		end
	},

	["for"] = command {
		opts = {
			{
				long = "step",
				short = "s",
				arg = true
			}
		},
		callback = function(opts, start, stop, callback)
			if typeof(start) ~= "number" then
				error("start must be a number", 0)
			end

			if typeof(stop) ~= "number" then
				error("start must be a number", 0)
			end

			local step = if opts.step ~= nil then opts.step else 1

			if step and typeof(step) ~= "number" then
				error("step must be a number", 0)
			end

			if not callback or typeof(callback) ~= "function" then
				error("callback is not a function", 0)
				end

			for i = start, stop, step do
				callback(i)
			end
		end
	},

	["foreach"] = command {
		callback = function(_, t, callback)
			if type(t) ~= "table" and type(t) ~= "userdata" then
				error("t is not iterable", 0)
			end

			for k, v in t do
				callback(v, k)
			end
		end
	},

	-- math

	add = command {
		callback = function(_, a, b)
			return a + b
		end
	},

	sub = command {
		callback = function(_, a, b)
			return a - b
		end
	},
	
	mul = command {
		callback = function(_, a, b)
			return a * b
		end
	},

	div = command {
		callback = function(_, a, b)
			return a / b
		end
	},

	idiv = command {
		callback = function(_, a, b)
			return a // b
		end
	},

	mod = command {
		callback = function(_, a, b)
			return a % b
		end
	},

	-- time

	time = command {
		opts = {
			{
				long = "unix",
				short = "u"
			},
			{
				long = "clock",
				short = "s"
			}
		},
		callback = function(opts)
			if opts.unix then
				return os.time()
			elseif opts.clock then
				return os.clock()
			else
				return os.clock()
			end
		end
	},

} :: {[string]: (...any) -> any}