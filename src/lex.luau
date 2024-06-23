--!strict
local create_stream = require("./input_stream")

local escape_chars = {
	a = "\a",
	b = "\b",
	f = "\f",
	n = "\n",
	r = "\r",
	t = "\t",
	v = "\v",
	["\\"] = "\\",
	["\""] = "\"",
	["\'"] = "\'"
}

local keywords = {"true", "false"}

export type Position = {
	line: number,
	pos: number,
	col: number
}

export type String = {type: "string", s: string, from: Position, to: Position}
export type Number = {type: "number", s: number, from: Position, to: Position}
export type Identifier = {type: "identifier", s: string, from: Position, to: Position}
export type Keyword = {type: "keyword", s: "true" | "false", from: Position, to: Position}
export type Operator = {type: "operator", s: "=" | "$" | "&", from: Position, to: Position}
export type Symbol = {type: "symbol", s: "[" | "]" | "{" | "}" | "(" | ")" | ";" | "," | "\n", from: Position, to: Position}
export type SOption = {type: "soption", s: string, from: Position, to: Position}
export type LOption = {type: "loption", s: string, from: Position, to: Position}
export type EOF = {type: "eof", s: "eof", from: Position, to: Position}

export type Token =
	String
	| Number
	| Identifier
	| Keyword
	| Symbol
	| Operator
	| SOption
	| LOption
	| EOF


export type Stream = {
	next: () -> Token,
	peek: (n: number?) -> Token,
	eof: () -> boolean,
	croak: (msg: string) -> (),
	pos: () -> Position
}

local function lex(source: string): Stream
	
	local input = create_stream(source)

	local function is_whitespace(char: string)
		return not not string.match(char, "[\t ]")
	end

	local function is_digit(char: string)
		return not not (char == "." or string.match(char, "%d"))
	end
	
	local function is_start_identifier(char: string)
		return not not string.match(char, "[%a_]")
	end

	local function is_identifier(char: string)
		return not not string.match(char, "[%a_%-:]")
	end
	
	local function is_op_char(char: string)
		return not not string.match(char, "[=%$&]")
	end

	local function is_option(char: string)
		return not not string.find(char, "-", 1, true)
	end

	local function is_punc(char: string)
		return not not string.match(char, "[%(%);%[%]{},\n]")
	end

	local function read_while(predicate: (char: string) -> boolean)
		local str = ""
		while input.eof() == false and predicate(input.peek()) do
			str ..= input.next()
		end
		return str
	end

	local function skip_comment()
		read_while(function(char) return char ~= "\n" end)
	end

	local function skip_whitespace()
		read_while(is_whitespace)
	end

	local function read_string(): String
		local escaped = false
		local token = ""
		local eliminator = input.next()
		local from = input.pos()

		while input.eof() == false and (input.peek() ~= eliminator or escaped) do
			local char = input.next()
		
			if char == "\\" then
				escaped = true
			end

			if escaped then
				token ..= escape_chars[char] or input.croak(`cannot escape {char}`)
				escaped = false
			else
				token ..= char
			end
		end

		local to = input.pos()

		-- print("t", token, eliminator, input.peek())

		if input.peek() ~= eliminator then input.croak("unterminated string") end
		input.next()
		return {type = "string", s = token, from = from, to = to}
	end

	local function read_number(): Number
		local decimal_pointer = false
		local from = input.pos()
		local token = read_while(function(char)
			if decimal_pointer and char == "." then return false end
			if char == "." then decimal_pointer = true end
			return is_digit(char)
		end)
		local to = input.pos()

		local n = tonumber(token)

		if not n then
			input.croak(`could not read {token} as number`)
		end

		return {type = "number", s = assert(n), from = from, to = to}
	end

	local function read_identifier(): Identifier | Keyword
		local from = input.pos()
		local token = read_while(is_identifier)
		local to = input.pos()

		if table.find(keywords, token) then
			return {type = "keyword", s = token :: any, from = from, to = to}
		else
			return {type = "identifier", s = token, from = from, to = to}
		end
	end

	local function read_option(): SOption | LOption
		local from = input.pos()
		local char = input.next()

		if char == "-" and input.peek() == "-" then
			input.next()
			return {type = "loption", s = read_while(is_identifier), from = from, to = input.pos()}
		else
			return {type = "soption", s = read_while(is_identifier), from = from, to = input.pos()}
		end
	end
	
	local function read_next(): Token
		skip_whitespace()
		local from = input.pos()
		if input.eof() then return {type = "eof", s = "eof", from = from, to = input.pos()} end

		local char = input.peek()

		if char == "#" then
			-- skip comment
			skip_comment()
			return read_next()
		end

		if char == "\"" or char == "'" then return read_string() end
		if is_digit(char) then return read_number() end
		if is_start_identifier(char) then return read_identifier() end
		if is_option(char) then return read_option() end
		if is_op_char(char) then return {type = "operator", s = input.next(), from = from, to = input.pos()} end
		if is_punc(char) then return {type = "symbol", s = input.next(), from = from, to = input.pos()} end

		input.croak(`cannot lex {char}`)
		error("fail")
	end

	local current: {Token} = {}

	local function next()
		local token = table.remove(current, 1)
		return if token == nil then read_next() else token
	end

	local function peek(n: number?)
		local n = n or 1
		while #current < n do
			table.insert(current, read_next())
		end
		return current[n]
	end

	local function eof()
		return peek().type == "eof"
	end

	return {

		peek = peek,
		next = next,
		eof = eof,
		croak = input.croak,
		pos = input.pos

	}
end


return lex