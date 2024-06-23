
local lex = require("../src/lex")
local parse = require("../src/parse")
local compile = require("../src/compile")
local vm = require("../src/vm")
local testkit = require("./testkit")

local l = lex("a=true")

local start = os.clock()
-- testkit.print2(parse(lex("a=(($foo {true}))")))
-- testkit.print2(parse(lex("a=((foo -t {true}))")))
-- testkit.print2(parse(lex("a=((foo -t {true} --))")))
local finish = os.clock()


local vm_state = vm.create_vm()

vm_state.commands["get-players"] = function()
	return {
		newproxy(),
		newproxy(),
		newproxy()
	}
end

vm_state.commands["get-player-position"] = function()
	return {1, 4, 3}
end

vm_state.commands["tp"] = function(_, target, to)
	print("teleported", target, "to", to)
end


print("parsing")
local parsed = parse(lex([[
foreach &get-players ((
    tp {t = true} &get-player-position
))

]]))

-- local currying = parse(lex([[

-- curry = ((
-- 	a=$1
-- 	((echo $a))
-- ))

-- foreach &get-players ((
--     tp {t = true} &get-player-position
-- ))

-- ]]))

local bytecode = compile(parsed)
print("compiled")
testkit.print2(bytecode)


print("running vm")
vm.run(vm_state, bytecode)


testkit.print2((finish - start) * 1e6)