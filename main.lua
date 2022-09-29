local Moderation = require(script.Moderation)
local ChatCmds = require(script.ChatCmds)

local Players = game:GetService("Players")

local function OnPlayerAdded(player : Player)
	if not Moderation.Verify(player) then return end
	
	if Moderation.GetMods()[player.UserId] then
		ChatCmds.EnableChatCmds(player)
	end
end

Players.PlayerAdded:Connect(OnPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	OnPlayerAdded(player)
end
