
local lex = require("./lex")

type pos = lex.Position

type Number = {
	type: "number",
	value: number,
	from: pos,
	to: pos
}

type String = {
	type: "string",
	value: string,
	from: pos,
	to: pos
}

type Boolean = {
	type: "boolean",
	value: boolean,
	from: pos,
	to: pos
}

type Variable = {
	type: "variable",
	value: string,
	from: pos,
	to: pos
}

type Dictionary = {
	type: "dictionary",
	values: {Expression | Assign},
	from: pos,
	to: pos
}

type Function = {
	type: "function",
	value: {Expression | Assign},
	from: pos,
	to: pos
}

type Assign = {
	type: "assign",
	left: AST | lex.Identifier,
	right: AST,
	operator: "=",
	from: pos,
	to: pos
}

type SOption = {
	type: "soption",
	value: string,
	from: pos,
	to: pos
}

type LOption = {
	type: "loption",
	value: string,
	from: pos,
	to: pos
}

type CCall = {
	type: "ccall",
	name: string,
	arguments: {Expression | Option},
	from: pos,
	to: pos
}

type FCall = {
	type: "fcall",
	name: string,
	arguments: {Expression},
	from: pos,
	to: pos
}

export type Call = CCall | FCall
export type Expression = Number | String | Boolean | Variable | Dictionary | Function | Call
export type Option = SOption | LOption
export type Statement = Assign

export type AST = Expression | Call | Option

local function parse(stream: lex.Stream): {Expression | Statement}

	local function skip_separator()
		local node = stream.peek()
		while node.type == "symbol" and node.s == "\n" do
			stream.next()
			node = stream.peek()
		end
	end

	local function is_sym(s: string)
		local node = stream.peek()
		return node.type == "symbol" and node.s == s
	end

	local function is_op(s: string)
		local node = stream.peek()
		return node.type == "operator" and node.s == s
	end

	local function is_kw(s: string)
		local node = stream.peek()
		return node.type == "keyword" and node.s == s
	end

	local function is_line_separator(node: lex.Token)
		return node.type == "symbol" and (node.s == ";" or node.s == "\n")
	end

	local function skip_symbol(ch)
		if is_sym(ch) then
			local token = stream.next()
			return token.from, token.to
		else
			stream.croak(`expecting symbol: "{ch}"`)
			error("")
		end
	end

	local function skip_op(ch)
		if is_op(ch) then
			local token = stream.next()
			return token.from, token.to
		else
			stream.croak(`expecting op: "{ch}"`)
			error("")
		end
	end

	local function delimited(start, stop, separator, parser: () -> AST)
		local a = {}
		local first = true
		local from = stream.pos()
		skip_symbol(start)
		while not stream.eof() do
			if is_sym(stop) then break end
			if first then
				first = false
			elseif typeof(separator) == "string" then
				skip_symbol(separator)
			elseif typeof(separator) == "function" then
				separator()
			end
			if is_sym(stop) then break end
			table.insert(a, parser())
			-- print('next')
		end
		skip_symbol(stop)
		local to = stream.pos()
		return a, from, to
	end

	local parse_dictionary: () -> Dictionary
	local parse_expression_or_assignment: () -> Expression | Assign
	local parse_expression: () -> Expression
	local parse_assignment: () -> Assign
	local parse_command: () -> FCall | CCall
	local parse_option: () -> Option
	local parse_function: () -> Function
	local parse_nested: () -> Call | Function
	local parse_variable: () -> Variable
	local parse_not_nested_cmd: () -> CCall

	function parse_not_nested_cmd()
		skip_op("&")
		
		local token = stream.next()

		if token.type ~= "identifier" then
			stream.croak(`expected identifier, got {token.type}`)
			error("")
		end
		
		return {
			type = "ccall",
			name = token.s,
			arguments = {}
		}

	end

	function parse_dictionary(): Dictionary
		local values, from, to = delimited("{", "}", ",", function()

			if is_sym("[") then
				local key = delimited("[", "]", "", function()
					return parse_expression()
				end)[1]
				skip_symbol("=")
				local value = parse_expression()
				return {
					type = "assign",
					left = key,
					right = value,
					operator = "="
				} :: Assign
			else
				return parse_expression_or_assignment()
			end
		end)

		return {
			type = "dictionary",
			from = from,
			to = to,
			values = values
		}
	end

	function parse_expression_or_assignment()
		if stream.peek().type == "identifier" then
			return parse_assignment()
		else
			return parse_expression()
		end
	end

	function parse_option(): Option
		local n = stream.next()
		return {
			type = n.type,
			value = n.s,
			from = n.from,
			to = n.to
		}
	end

	function parse_command(): Call
		local var_cmd = false
		local from = stream.pos()
		if is_op("&") then stream.next() elseif is_op("$") then var_cmd = true; stream.next() end
		local ident = stream.next()

		if ident.type ~= "identifier" then
			stream.croak(`expected identifier, got {ident.type} {ident.s}`)
		end
		-- assert(ident.type == "identifier", "expected identifier")

		local arg: {Expression | Option} = {}

		while not stream.eof() do
			
			local peek = stream.peek()

			if peek.type == "loption" then
				if var_cmd then error(`cannot use option in var cmd`, 0) end
				table.insert(arg, parse_option())
			elseif peek.type == "soption" then
				if var_cmd then error(`cannot use option in var cmd`, 0) end
				table.insert(arg, parse_option())
			elseif is_sym("{") or is_sym("(") or peek.type ~= "symbol" then
				table.insert(arg, parse_expression())
			else
				-- print("stop due to", peek.type, peek.s)
				break
			end

		end

		return {
			type = if var_cmd then "fcall" else "ccall",
			name = ident.s,
			arguments = arg,
			from = from,
			to = stream.pos()
		}
	end

	function parse_assignment(): Assign
		local left = stream.next()

		if left.type ~= "identifier" then
			stream.croak(`expected identifier, got {left.type} {left.s}`)
			error("")
		end

		skip_op("=")
		local expression = parse_expression()

		return {
			type = "assign",
			left = {type = "string", value = left.s, from = left.from, to = left.to},
			right = expression,
			operator = "=",
			from = left.from,
			to = expression.to
		}
	end

	function parse_function(): Function

		local value, from, to = delimited("(", ")", skip_separator, function()
			skip_separator()
			-- print("peek", stream.peek().type)
			if is_op("&") or is_op("$") then
				-- print('parse cmd')
				return parse_command()
			elseif stream.peek(2).type == "operator" and stream.peek(2).s == "=" then
				-- print("parse assign")
				return parse_assignment()
			elseif stream.peek().type == "identifier" then
				return parse_command()
			else
				return parse_expression()
			end
		end)

		return {
			type = "function",
			value = value,
			from = from,
			to = to
		}
	end

	function parse_nested(fn: boolean?): Call
		local tokens, from, to = delimited("(", ")", nil, function()
			if is_op("&") or is_op("$") then
				-- parse as normal command
				-- print("parse cmd")
				return parse_command()
			elseif fn and is_sym("(") then
				-- parse as function
				-- print("parse fn")
				return parse_function()
			elseif stream.peek().type == "identifier" then
				return parse_command()
			else
				stream.croak("expected function call or function definition")
				error("")
			end
		end)

		tokens[1].from = from
		tokens[1].to = to

		return tokens[1]
	end

	function parse_variable(): Variable
		local token = stream.next()
		return {type = "variable", value = tostring(token.s), from = token.from, to = token.to}
	end

	function parse_expression(): Expression
		local token = stream.peek()

		if token.type == "identifier" then
			return {type = "string", value = stream.next().s, from = token.from, to = token.to}
		elseif token.type == "number" then
			return {type = "number", value = stream.next().s, from = token.from, to = token.to}
		elseif is_kw("true") then
			stream.next()
			return {type = "boolean", value = true, from = token.from, to = token.to}
		elseif is_kw("false") then
			stream.next()
			return {type = "boolean", value = false, from = token.from, to = token.to}
		elseif is_sym("{") then
			return parse_dictionary()
		elseif is_op("$") then
			stream.next()
			return parse_variable()
		elseif is_op("&") then
			-- print("parse not nested")
			return parse_not_nested_cmd()
		elseif is_sym("(") then
			return parse_nested(true)
		elseif is_sym("\n") then
			stream.next()
			return nil
		end

		stream.croak(`unable to parse {token.type} {token.s} in a expression`)
		error("")
	end

	local nodes: {Assign | Call | Expression} = {}

	while not stream.eof() do
		
		local token = stream.peek()
		-- print(#nodes, token.s, token.type)
		
		if token.type == "identifier" and stream.peek(2).type == "operator" and stream.peek(2).s == "=" then
			-- print("parse assignment")
			table.insert(nodes, parse_assignment())
		elseif token.type == "operator" or token.type == "identifier" then
			-- print("parse command")
			table.insert(nodes, parse_command())
		else
			-- print("parse expression")
			table.insert(nodes, parse_expression())
		end
	end

	return nodes

end

return parse