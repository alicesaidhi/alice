
local lex = require("../src/lex")
local parse = require("../src/parse")
local compile = require("../src/compile")
local vm = require("../src/vm")

return {

	create_vm = vm.create_vm,
	run = function(vm_state: vm.VMState, instructions: {vm.Instruction})
		vm.run(vm_state, instructions)
	end,

	parse = function(input: string)
		return parse(lex(input))
	end,

	compile = function(input: string)
		return compile(parse(lex(input)))
	end

}