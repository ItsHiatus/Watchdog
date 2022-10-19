--!strict
-- Settings
local Settings = require(script.Parent.Settings)

local PREFIX = Settings.Prefix

local TARGETING_CMDS = Settings.TargetingCmds -- add function names that require a target as 1st arg
local LOGGING_CMDS = Settings.LoggingCmds -- add function names here that require the moderator as 2nd arg (e.g. for logging purposes)

local CHATCMD_ACCESS_MSG = string.format("You have access to Watchdog's ChatCmds! Type %scmds for the list of commands that you can use.", PREFIX)
local CLIENT_ERROR_MSGS = Settings.ClientErrorMessages
--

local Watchdog = require(script.Parent.Parent.Watchdog)
local GenerateMessage = require(script.GenerateMessage)
local ParseArgs = require(script.ParseArgs)
local VerifyArgs = require(script.VerifyArgs)

local ClientCmdScript = script.Watchdog_Client
local Players = game:GetService("Players")

local Commands = {}
local Prefix_Anchored = string.format("^%s", PREFIX)

for name, func in pairs(Watchdog) do
	if type(name) == "string" and type(func) == "function" then
		Commands[string.lower(name)] = name
	end
end

local function GivePlayerCmdScript(player : Player)
	local player_gui = player:WaitForChild("PlayerGui") :: PlayerGui
	if player_gui:FindFirstChild(ClientCmdScript.Name) then return end
	ClientCmdScript:Clone().Parent = player_gui
end

local function FindPlayer(name : string, chatmod : Player) : (Player|{})?
	local target : Player
	
	for _, player in ipairs(Players:GetPlayers()) do -- look for direct match
		if name == string.lower(player.Name) or name == string.lower(player.DisplayName) then
			if target then-- target already found
				GenerateMessage.fromResult(chatmod, string.format(CLIENT_ERROR_MSGS.INVALID_SINGLE_TARGET, target), "error") return
			end
			
			target = player
		end
	end
	
	if not target then
		for _, player in ipairs(Players:GetPlayers()) do -- look for sub match
			if name == string.match(string.lower(player.Name), name) or name == string.match(string.lower(player.DisplayName), name) then
				if target then-- target already found
					GenerateMessage.fromResult(chatmod, string.format(CLIENT_ERROR_MSGS.INVALID_SINGLE_TARGET, target), "error") return
				end
				
				target = player
			end
		end
	end
	
	if not target then
		GenerateMessage.fromResult(chatmod, CLIENT_ERROR_MSGS.INVALID_TARGET, "error")
	end
	return target
end

local function VerifyCmdArgs(player : Player, cmd : string, args : {any}) : boolean?
	if LOGGING_CMDS[cmd] then
		table.insert(args, 2, player.UserId)
	end
	
	if VerifyArgs[cmd] then -- add commands to this table to assert the correct args are being sent
		if not VerifyArgs[cmd](player, args) then return end
	end
	
	table.insert(args, player) -- ChatMod at end of args
	return true
end

local function OnPlayerChatted(player : Player, message : string) 
	if not Watchdog.GetMods()[player.UserId] then return end
	if type(message) ~= "string" then warn("message is not a valid string", message) return end
	if not string.match(message, Prefix_Anchored) then return end
	
	local cmd, rest_of_msg = string.match(string.lower(message), "(%a+)%s*(.*)", #PREFIX + 1)
	
	if not Commands[cmd] then
		GenerateMessage.fromResult(player, string.format(CLIENT_ERROR_MSGS.INVALID_CMD, tostring(cmd)), "error") return
	end
	
	local args : {any} = ParseArgs(rest_of_msg or "")
	for i, arg in ipairs(args) do
		args[i] = tonumber(arg) or arg
	end
	
	local target = args[1]
	
	if not target and TARGETING_CMDS[cmd] then
		GenerateMessage.fromResult(player, CLIENT_ERROR_MSGS.INVALID_TARGET, "error") return
		
	elseif target and type(target) == "string" then
		local target_player = (target == "me") and player or FindPlayer(target, player)
		if not target_player then return end
		
		if typeof(target_player) == "Instance" and target_player:IsA("Player") then
			args[1] = target_player.UserId
		end
	end
	
	if not VerifyCmdArgs(player, cmd, args) then return end
	
	local result = Watchdog[Commands[cmd]](unpack(args))
	GenerateMessage.new(player, cmd, result)
end

local ChatCmds = {}

function ChatCmds.EnableChatCmds(player : Player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		warn("Must provide a valid player to grant them access to chat cmds! Sent:", player) return
	elseif not Watchdog.GetMods()[player.UserId] then
		warn(string.format("This player cannot receive chat cmds. They are not a moderator. (Sent %s)", player.Name)) return
	end
	
	player.CharacterAppearanceLoaded:Connect(function()
		GivePlayerCmdScript(player)
	end)
	GivePlayerCmdScript(player)
	
	GenerateMessage.fromResult(player, CHATCMD_ACCESS_MSG, "normal")
	
	player.Chatted:Connect(function(message)
		OnPlayerChatted(player, message)
	end)
end

return ChatCmds
