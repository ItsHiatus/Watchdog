--!strict
-- Generates a message for client

-- Settings
local Settings = require(script.Parent.Parent.Settings)

local ChatName = Settings.ChatName
local ChatReplyColors = Settings.ChatReplyColors

local FailedResultMessage = string.format("[%s]: It seems like there was an issue with this request.", ChatName)
local Reply = string.format("[%s]: %%s", ChatName)

local TableResultTypes = Settings.TableResultTypes -- add function names that return a table
local BooleanResultTypes = Settings.BooleanResultTypes -- add function names that return a boolean

type MsgType = Settings.MessageType
type Table = Settings.Data
type DataDict = Settings.DataDict

local ClientCmdEvent  = script.Watchdog_CmdsEvent
ClientCmdEvent.Parent = game:GetService("ReplicatedStorage")

local function GetPaddedStringFromDict(dict : Table|DataDict)
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

local function VerifyResult(cmd : string, result : any) : boolean
	if TableResultTypes[cmd] then
		if type(result) == "table" then return true end
	elseif BooleanResultTypes[cmd] then
		if type(result) == "boolean" then return true end
	end
	return false
end

local CommandResults = {
	cmds = function(result : {{string}})
		local cmds = {}
		local args = {}
		local max = 0
		
		for index, cmd in result do
			local arg_list = ""
			for i, arg in cmd do
				if i == 1 then continue end
				arg_list = string.format("%s%s ", arg_list, arg)
			end
			cmds[index] = cmd[1]
			args[index] = arg_list
			max = math.max(#cmd[1], max)
		end
		
		local padded_string = "\n"
		for index, cmd in cmds do
			padded_string = padded_string .. string.format("%s : %s\n", string.rep(" ", max - #cmd) .. cmd, args[index])
		end
		
		return string.format(Reply, padded_string)
	end,
	
	verify = function(result : boolean) : string
		return string.format(Reply, (result == true) and "Player isn't banned" or "Player is banned")
	end,
	
	updatemods = function(result : boolean) : string
		return string.format(Reply, (result) and "Updated mods successfully." or "Failed to update mods!")
	end,
	
	getmods = function(result : {[number]: string}) : string
		return string.format(Reply, GetPaddedStringFromDict(result))
	end,
	
	addmod = function(result : boolean) : string
		return string.format(Reply, (result) and "Successfully added moderator." or "Failed to add moderator.")
	end,
	
	removemod = function(result : boolean) : string
		return string.format(Reply, (result) and "Successfully removed moderator." or "Failed to remove moderator.")
	end,
	
	getlogs = function(result : Table | DataDict) : string
		return string.format(Reply, GetPaddedStringFromDict(result))
	end,
	
	getlocalnotes = function(result : Table) : string
		return string.format(Reply, GetPaddedStringFromDict(result))
	end,
	
	note = function(result : boolean) : string
		return string.format(Reply, (result) and "Successfully noted player." or "Failed to note player.")
	end,
	
	removenote = function(result : boolean) : string
		return string.format(Reply, (result) and "Successfully removed note."or "Failed to remove note.")
	end,
	
	localnote = function(result : boolean) : string
		return string.format(Reply, (result) and "Successfully noted player." or "Failed to not player.")
	end,
	
	kick = function(result : boolean) : string
		return string.format(Reply, (result) and "Successfully kicked player." or "Failed to kick player.")
	end,
	
	ban = function(result : boolean) : string
		return string.format(Reply, (result) and "Successfully banned player." or "Failed to kick player.")
	end,
	
	unban = function(result : boolean) : string
		return string.format(Reply, (result) and "Successfully unbanned player." or "Failed to unban player.")
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
		local msg : string
		local msg_type : string
		
		if not VerifyResult(cmd, result) then
			msg = "Could not verify result for this cmd! Please make sure to specify what type of result this cmd returns in Watchdog Settings."
			msg_type = "error"
		elseif not CommandResults[cmd] then
			msg = "Could not format this result into a message! Please make sure to add a result formatting method in Watchdog GenerateMessage."
			msg_type = "error"
		else
			msg = CommandResults[cmd](result) or FailedResultMessage
			msg_type = (msg == FailedResultMessage) and "error" or "normal"
		end
		
		ClientCmdEvent:FireClient(player, {
			Text = FilterMessage(msg, player),
			Color = ChatReplyColors[msg_type] :: Color3
		}) 
	end,
	
	fromResult = function(player : Player, result : string, msg_type : MsgType?)
		ClientCmdEvent:FireClient(player, {
			Text = FilterMessage(string.format(Reply, result), player),
			Color = ChatReplyColors[msg_type or "normal"] :: Color3
		})
	end,
}
