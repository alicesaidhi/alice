local function stream(input: string)

	local pos = 0
	local line = 1
	local col = 1

	local function peek(): string
		return string.sub(input, pos+1, pos+1)
	end

	local function next(): string
		local char = peek()
		pos += 1

		if char == "\n" then line += 1; col = 1
		else col += 1 end

		return char
	end

	local function eof(): boolean
		return peek() == ""
	end

	local function position()
		return {
			pos = pos,
			line = line,
			col = col
		}
	end

	local function croak(msg)
		error(`{msg} ({line}:{col})`, 0)
	end

	return {
		peek = peek,
		next = next,
		eof = eof,
		croak = croak,
		pos = position
	}

end

return stream