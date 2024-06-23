

export type Option = {
    long: string,
    short: string?,
    arg: boolean?
}
type Command = {
	opts: {Option}?,
	callback: (opts: {[string]: any}, ...any) -> any
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

return command