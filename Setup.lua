--!strict
-- Setup for Watchdog. Enables ChatCmds.

local Watchdog = require(script.Parent.Watchdog)
local ChatCmds = require(script.ChatCmds)

local Players = game:GetService("Players")
local CheckedPlayers = {}

local function OnPlayerAdded(player : Player)
	if CheckedPlayers[player] then return end
	CheckedPlayers[player] = true
	
	if not Watchdog.Verify(player) then return end
	
	if Watchdog.GetMods()[player.UserId] then
		ChatCmds.EnableChatCmds(player)
	end
end

local function OnPlayerRemoving(player : Player)
	CheckedPlayers[player] = nil
end

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	OnPlayerAdded(player)
end
