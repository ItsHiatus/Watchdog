--!strict
-- Settings
local PREFIX = ";"

local LOGGING_CMDS = { -- add function names here that require the moderator (e.g. for logging purposes)
	note = true, -- put function name in lower case
	kick = true,
	ban = true,
	unban = true
}

local TARGETING_CMDS = { -- add function names that require a target
	verify = true,
	addmod = true,
	removemod = true,
	getlogs = true,
	note = true,
	kick = true,
	ban = true,
	unban = true
}

local MSG_BRACKETS = {
	-- supported brackets in chat cmd arg parser e.g.
	--  msg: ;kick Roblox 'idk why'  => args: "Roblox", "idk why"
	--  msg: ;kick Roblox idk why    => args: "Roblox", "idk", "why"
	["'"] = "'",
	['"'] = '"',
	["<"] = ">",
	["{"] = "}",
	["["] = "]",
	["("] = ")",
}

-- CLIENT ERROR MESSAGES
local INVALID_CMD = "Could not find command %s"
local INVALID_SINGLE_TARGET = "More than one target found with name %s!"
local INVALID_TARGET = "Please provide a valid target (UserId or Name of a player in the server)!"
local INVALID_LOG_CATEGORY = "Please provide a valid log category! (notes/kicks/bans)"
local INVALID_LOG_NUMBER = "Please provide a valid log number!"
local INVALID_NOTE = "Please provide a valid note!"
local INVALID_REASON = "Please provide a valid reason!"
local INVALID_DURATION = "Please provide a valid ban duration (-1 for indefinite bans)"

--

local Moderation = require(script.Parent.Moderation)
local GenerateMessage = require(script.GenerateMessage)
local ParseArgs = require(script.ParseArgs)

local Parser = ParseArgs.Parse
ParseArgs.LoadMsgBrackets(MSG_BRACKETS)

local ClientCmdScript = script.Moderation_Client
local Players = game:GetService("Players")

local Commands = {}
local Prefix_Anchored = string.format("^%s", PREFIX)

for name, func in pairs(Moderation) do
	if type(name) == "string" and type(func) == "function" then
		Commands[string.lower(name)] = name
	end
end

local function GivePlayerCmdScript(player : Player)
	local player_gui = player:WaitForChild("PlayerGui") :: PlayerGui
	if player_gui:FindFirstChild(ClientCmdScript.Name) then return end
	ClientCmdScript:Clone().Parent = player_gui
end

local function FindPlayer(name : string) : (Player|{Player})?
	local target = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if name == string.lower(player.Name) or name == string.lower(player.DisplayName) then
			table.insert(target, player)
		end
	end
	
	return (#target == 1) and target[1] or (#target > 0) and target or nil
end

local function VerifyCmdArgs(player : Player, cmd : string, args : {any}) : boolean?
	if LOGGING_CMDS[cmd] then
		table.insert(args, 2, player.UserId)
	end
	
	if cmd == "getlogs" then -- must specify category and log number with chat cmd, otherwise floods chat
		if not args[2] or not (args[2] == "notes" or args[2] == "kicks" or args[3] == "bans") then
			GenerateMessage.fromResult(player, INVALID_LOG_CATEGORY, "error")
			return warn(INVALID_LOG_CATEGORY)
		elseif not args[3] or type(args[3]) ~= "number" then
			GenerateMessage.fromResult(player, INVALID_LOG_NUMBER, "error")
			return warn(INVALID_LOG_NUMBER)
		end
	elseif cmd == "note" then -- must provide a valid note
		if not args[3] then
			GenerateMessage.fromResult(player, INVALID_NOTE, "error")
			return warn(INVALID_NOTE)
		end
	elseif cmd == "kick" then -- must provide reason and format
		if not args[3] then
			GenerateMessage.fromResult(player, INVALID_REASON, "error")
			return warn(INVALID_REASON)
		elseif not args[4] then
			table.insert(args, "none")
		end
	elseif cmd == "ban" then -- must provide duration and reason
		if not args[3] or type(args[3]) ~= "number" then
			GenerateMessage.fromResult(player, INVALID_DURATION, "error")
			return warn(INVALID_DURATION)
		elseif not args[4] then
			GenerateMessage.fromResult(player, INVALID_REASON, "error")
			return warn(INVALID_REASON)
		end
	elseif cmd == "unban" then
		if not args[3] then
			GenerateMessage.fromResult(player, INVALID_REASON, "error")
			return warn(INVALID_REASON)
		end
	end
	
	table.insert(args, player) -- ChatMod at end of args
	return true
end

local function OnPlayerChatted(player : Player, message : string) 
	if not Moderation.GetMods()[player.UserId] then return end
	if type(message) ~= "string" then warn("message is not a valid string", message) return end
	if not string.match(message, Prefix_Anchored) then return end
	
	local cmd, rest_of_msg = string.match(string.lower(message), "(%a+)%s*(.*)", #PREFIX + 1)
	
	if not Commands[cmd] then
		local error_message = string.format(INVALID_CMD, tostring(cmd))
		GenerateMessage.fromResult(player, error_message, "error")
		return warn(error_message)
	end
	
	local args : {any} = Parser(rest_of_msg or "")
	for i, arg in ipairs(args) do
		args[i] = tonumber(arg) or arg
	end
	
	local target = args[1]
	
	if not target and TARGETING_CMDS[cmd] then
		GenerateMessage.fromResult(player, INVALID_TARGET, "error")
		return warn(INVALID_TARGET)
		
	elseif target and type(target) == "string" then
		local target_player = (target == "me") and player or FindPlayer(target)

		if typeof(target_player) == "Instance" and target_player:IsA("Player") then
			args[1] = target_player.UserId

		elseif typeof(target_player) == "table" then
			local error_message = string.format(INVALID_SINGLE_TARGET, target)
			GenerateMessage.fromResult(player, error_message, "error")
			return warn(error_message)
		else
			GenerateMessage.fromResult(player, INVALID_TARGET, "error")
			return warn(INVALID_TARGET)
		end
	end
	
	if not VerifyCmdArgs(player, cmd, args) then return end
	
	local result = Moderation[Commands[cmd]](unpack(args))
	print(result)
	GenerateMessage.new(player, cmd, result)
end

local ChatCmds = {}

function ChatCmds.EnableChatCmds(player : Player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		warn("Must provide a valid player to grant them access to chat cmds! Sent:", player) return
	elseif not Moderation.GetMods()[player.UserId] then
		warn(string.format("This player cannot receive chat cmds. They are not a moderator. (Sent %s)", player.Name)) return
	end
	
	player.CharacterAdded:Connect(function()
		GivePlayerCmdScript(player)
	end)
	GivePlayerCmdScript(player)
	
	player.Chatted:Connect(function(message)
		OnPlayerChatted(player, message)
	end)
end

return ChatCmds
