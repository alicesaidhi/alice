
local option_mt = {__type = "option"}

type LongOption = typeof(setmetatable(
	{} :: {
		type: "long",
		name: string
	}, option_mt)
)

type ShortOption = typeof(setmetatable(
	{} :: {
		type: "short",
		name: string
	}, option_mt)
)

local function new_long_option(name: string)
	return setmetatable({
		type = "long",
		name = name	
	}, option_mt)
end

local function new_short_option(name: string)
	return setmetatable({
		type = "short",
		name = name	
	}, option_mt)
end

local function is_option(option: any): boolean
	return getmetatable(option) == option_mt
end

export type Option = LongOption | ShortOption

return {
	long = new_long_option,
	short = new_short_option,
	is_option = is_option :: ((option: Option) -> true) & ((option: unknown) -> false)
}