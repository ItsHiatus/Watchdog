-- Credits to @AljoSven for ParseArgs function

local Settings = require(script.Parent.Parent.Settings)
local MSG_BRACKETS = Settings.MSG_BRACKETS

return function(message : string) : {string|number}
	if not MSG_BRACKETS then warn("Message brackets have not been loaded!") return end
	if type(message) ~= "string" then warn("Must pass a string to be parsed") return end

	local args = {}
	local chunk = ""
	local bracket = nil

	for char in string.gmatch(message, ".") do
		if string.len(chunk) <= 0 and string.match(char, "%s") then continue end

		if not bracket and string.match(char, "%s") then
			table.insert(args, chunk)
			chunk = ""
		else
			if not bracket and MSG_BRACKETS[char] then
				bracket = char
			elseif bracket and char == MSG_BRACKETS[bracket] then
				bracket = nil
			else
				chunk = chunk .. char
			end
		end
	end

	if string.len(chunk) > 0 then table.insert(args, chunk) end
	return args
end
