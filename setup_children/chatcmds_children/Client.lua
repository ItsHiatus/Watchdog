--!strict

-- TextChatService Settings (new)
local MsgFontFace = Font.new("rbxasset://fonts/families/Inconsolata.json")
-- LegacyChatService Settings
local MsgFont = Enum.Font.Code
local TextSize = 14
--

type CmdResult = {
	Text : string,
	Color : Color3
}

local TextChatService = game:GetService("TextChatService")
local Channel

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	local TextChannels = TextChatService:WaitForChild("TextChannels")
	Channel = TextChannels:WaitForChild("RBXGeneral") :: TextChannel
	
	local Configuration = TextChatService:WaitForChild("ChatWindowConfiguration")
	Configuration.FontFace = MsgFontFace
end

local ClientMessageRemote : RemoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("WatchdogCmdsEvent")
local StarterGui = game:GetService("StarterGui")

ClientMessageRemote.OnClientEvent:Connect(function(result : CmdResult)
	task.wait() -- to make sure message doesn't show before player's cmd
	
	if Channel then
		Channel:DisplaySystemMessage(result.Text)
	else
		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text = result.Text,
			Color = result.Color,
			Font = MsgFont,
			TextSize = TextSize
		})
	end
end)
