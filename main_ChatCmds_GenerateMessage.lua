--!strict
-- Generates a message for client

-- Settings
local ChatName = "Server"

local FailedResultMessage = string.format("[%s]: Proper result not found", ChatName)

local Colors = {
	normal = Color3.fromRGB(222, 221, 209),
	error = Color3.fromRGB(255, 218, 67)
}
type MsgType = "normal" | "error"

--

type Table = {[any] : any}
type NestedDict = {[string] : Table}

local ClientCmdEvent  = script.Moderation_CmdsEvent
ClientCmdEvent.Parent = game:GetService("ReplicatedStorage")

local function GetPaddedStringFromDict(dict : Table|NestedDict)
	local padded = {}
	local max = 0
	local padded_string = "\n"
	
	for key, value in pairs(dict) do
		max = math.max(#tostring(key), max)
		if type(value) == "table" then
			padded[tostring(key)] = GetPaddedStringFromDict(value)
		else
			padded[tostring(key)] = tostring(value)
		end
	end
	
	for key, value in padded do
		padded_string = padded_string .. string.format("%s : %s\n", string.rep(" ", max - #key) .. key, value)
	end
	return padded_string
end

local function GetStringFromArray(array : {any}) : string
	local str = "\n"
	for _, value in ipairs(array) do
		if type(value) ~= "string" and type(value) ~= "number" then continue end
		str = str .. string.format("%s\n", tostring(value))
	end
	return str
end

local CommandResults = {
	cmds = function(result : {string})
		if typeof(result) ~= "table" then return FailedResultMessage end
		local padded_string = GetStringFromArray(result)
		return string.format("[%s]: %s", ChatName, padded_string)
	end,
	
	verify = function(result : boolean?) : string
		if result and typeof(result) ~= "boolean" then return FailedResultMessage end
		if result == nil then return string.format("[%s]: Please send a valid id!", ChatName) end
		return string.format("[%s]: User is %s.", ChatName, (result == true) and "clean" or "banned")
	end,
	
	updatemods = function(result : boolean) : string
		if typeof(result) ~= "boolean" then warn(result) return FailedResultMessage end
		return string.format("[%s]: Mods have %s", ChatName, (result) and "been updated successfully." or "failed to update!")
	end,
	
	getmods = function(result : {[number]: string}) : string
		if typeof(result) ~= "table" then warn(result) return FailedResultMessage end
		local padded_string = GetPaddedStringFromDict(result)
		return string.format("[%s]: %s", ChatName, padded_string)
	end,
	
	addmod = function(result : boolean?) : string
		if result and typeof(result) ~= "boolean" then return FailedResultMessage end
		return string.format("[%s]: %s", ChatName, (result) and "Successfully added moderator." or "Failed to add moderator.")
	end,
	
	removemod = function(result : boolean?) : string
		if result and typeof(result) ~= "boolean" then return FailedResultMessage end
		return string.format("[%s]: %s", ChatName, (result) and "Successfully removed moderator." or "Failed to remove moderator.")
	end,
	
	getlogs = function(result : Table | NestedDict) : string
		if not result or typeof(result) ~= "table" then return FailedResultMessage end
		local padded_string = GetPaddedStringFromDict(result)
		return string.format("[%s]: %s", ChatName, padded_string)
	end,
	
	note = function(result : boolean?) : string
		if result and typeof(result) ~= "boolean" then return FailedResultMessage end
		return string.format("[%s]: %s", ChatName, (result) and "Successfully noted player." or "Failed to note player.")
	end,
	
	kick = function(result : boolean?) : string
		if result and typeof(result) ~= "boolean" then return FailedResultMessage end
		return string.format("[%s]: %s", ChatName, (result) and "Successfully kicked player." or "Failed to kick player.")
	end,
	
	ban = function(result : boolean?) : string
		if result and typeof(result) ~= "boolean" then return FailedResultMessage end
		return string.format("[%s]: %s", ChatName, (result) and "Successfully banned player." or "Failed to kick player.")
	end,
	
	unban = function(result : boolean?) : string
		if result and typeof(result) ~= "boolean" then return FailedResultMessage end
		return string.format("[%s]: %s", ChatName, (result) and "Successfully unbanned player." or "Failed to unban player.")
	end,
}

--

local ChatService = game:GetService("Chat")

local function FilterMessage(msg : string, player : Player)
	if type(msg) ~= "string" then return FailedResultMessage end

	local success, filtered_message = pcall(function()
		return ChatService:FilterStringAsync(msg, player, player)
	end)

	return (success) and filtered_message or FailedResultMessage
end

return {
	new = function(player : Player, cmd : string, result : any)
		ClientCmdEvent:FireClient(player, {
			Text = FilterMessage(CommandResults[cmd](result), player),
			Color = Colors.normal
		}) 
	end,
	
	fromResult = function(player : Player, result : string, msg_type : MsgType?)
		local message = string.format("[%s]: %s", ChatName, result)
		ClientCmdEvent:FireClient(player, {
			Text = FilterMessage(message, player),
			Color = Colors[msg_type or "normal"]
		})
	end,
}
