local alice = require("../src/init")
local testkit = require("./testkit")

local vm = alice.create_vm()

vm.commands["set"] = {
	opts = {},
	callback = function(opts, dict, key, value)
		dict[key] = value
		return dict
	end
}

vm.commands["get"] = {
	opts = {},
	callback = function(opts, dict, key)
		return dict[key]
	end
}

vm.commands["insert"] = {
	opts = {},
	callback = function(opts, list, key, value)
		if value == nil then
			table.insert(list, key)
		else
			table.insert(list, key, value)
		end
		return list
	end
}

vm.commands["remove"] = {
	opts = {},
	callback = function(opts, list, key)
		table.remove(list, key)
	end
}

vm.commands["find"] = {
	opts = {},
	callback = function(opts, haystack, needle)
		return table.find(haystack, needle)
	end
}

vm.commands["add"] = {
	opts = {},
	callback = function(opts, a, b)
		return a + b
	end
}

vm.commands["sub"] = {
	opts = {},
	callback = function(opts, a, b)
		return a - b
	end
}

vm.commands["mul"] = {
	opts = {},
	callback = function(opts, a, b)
		return a * b
	end
}

vm.commands["div"] = {
	opts = {},
	callback = function(opts, a, b)
		return a / b
	end
}

vm.commands["idiv"] = {
	opts = {},
	callback = function(opts, a, b)
		return a // b
	end
}

vm.commands["for"] = {
	opts = {
		{
			short = "s",
			long = "step",
			arg = true
		},
		{
			short = "i",
			long = "in",
			arg = true
		}
	},
	callback = function(opts, from, to, callback)
		print(opts)
		local iterate_over = opts["in"]

		if iterate_over ~= nil then
			assert(typeof(iterate_over) == "table", `cannot iterate over {typeof(iterate_over)}`)
			for k, v in iterate_over do
				from(k, v)
			end
			return
		end

		assert(typeof(from) == "number", "from must be a number")
		assert(typeof(to) == "number", "to must be a number")
		local step: number = opts.step or 1
		assert(typeof(step) == "number", "step must be a number")
		assert(typeof(callback) == "function", "callback must be a function")

		for i = from, to, step do
			callback(i)
		end
	end
}

vm.commands["while"] = {
	opts = {},
	callback = function(opts, condition, callback)
		assert(typeof(condition) == "function", "condition must be a function")
		
		while condition() do
			callback()
		end
	end
}

vm.commands["print"] = {
	opts = {},
	callback = function(opts, ...)
		for i = 1, select("#", ...) do
			testkit.print2(select(i, ...))
		end
		
	end
}


-- testkit.print2(alice.compile("echo {start: sort [2, 1], until: 3}"))
-- alice.run(vm, alice.compile("a = 7"))
-- alice.run(vm, alice.compile("b = 3"))
-- alice.run(vm, alice.compile("echo [(add $a $b)]"))
-- alice.run(vm, alice.compile("test = ((echo $1))"))
-- testkit.print2(alice.compile("test = ((echo hello))"))
-- testkit.print2(alice.compile([[
-- into_list = ((b=[$1]; $b))
-- echo ($into_list 3)
-- ]]))

testkit.print2(alice.compile([[
l = [1, 2, 3, 4]
print $l
print ok
for --in $l ((
	print $1
	print $2
	a = [$1, $2]
	print $a
))
print done
]]))
-- alice.run(vm, alice.compile([[
-- l = [1, 2, 3, 4]
-- print $l
-- print ok
-- for --in $l ((
-- 	print $1
-- 	print $2
-- 	a = [$1, $2]
-- 	print $a
-- ))
-- print done
-- ]]))

local start = os.clock()
-- testkit.print2(alice.compile("sort [1, 2] --ascending [4, 3, 2] -xf"))
-- print((os.clock() - start) * 1e6)