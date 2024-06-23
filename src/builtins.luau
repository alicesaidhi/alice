type Value = any
type Callback = (options: {[string]: Value}, ...Value) -> Value?

export type Option = {
    long: string,
    short: string?,
    arg: boolean?
}
type Command = {
	opts: {Option},
	callback: Callback
}

return {

	echo = {
		opts = {},
		callback = function(_, value)
			print(value)
		end
	},

	-- table manip

	set = {
		opts = {},
		callback = function(_, t, key, value)
			t[key] = value
		end
	},

	read = {
		opts = {},
		callback = function(_, t, key)
			return t[key]
		end
	},

	insert = {
		opts = {},
		callback = function(_, t, k, v)
			table.insert(t, k, v)
		end
	},

	remove = {
		opts = {},
		callback = function(_, t, k)
			table.remove(t, k)
		end
	},

	find = {
		opts = {},
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

	["if"] = {
		opts = {},
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

	["while"] = {
		opts = {},
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

	["for"] = {
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

	["foreach"] = {
		opts = {},
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

	add = {
		opts = {},
		callback = function(_, a, b)
			return a + b
		end
	},

	sub = {
		opts = {},
		callback = function(_, a, b)
			return a - b
		end
	},
	
	mul = {
		opts = {},
		callback = function(_, a, b)
			return a * b
		end
	},

	div = {
		opts = {},
		callback = function(_, a, b)
			return a / b
		end
	},

	idiv = {
		opts = {},
		callback = function(_, a, b)
			return a // b
		end
	},

	mod = {
		opts = {},
		callback = function(_, a, b)
			return a % b
		end
	},

	-- time

	time = {
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

} :: {[string]: Command}