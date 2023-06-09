--!strict

-- TextChatService Settings (new)
local MsgFontFace = Font.new("rbxasset://fonts/families/Inconsolata.json")
local TCSChatColor = Color3.fromRGB(255, 218, 67):ToHex()
-- LegacyChatService Settings
local MsgFont = Enum.Font.Code
local TextSize = 14
--

type CmdResult = {
	Text : string,
	Color : Color3
}

local TextChatService = game:GetService("TextChatService")
local Channel : TextChannel

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	local TextChannels = TextChatService:WaitForChild("TextChannels")
	Channel = TextChannels:WaitForChild("RBXGeneral")
	
	TextChatService.OnIncomingMessage = function(message : TextChatMessage)
		-- only change SystemMessage
		if not string.match(message.MessageId, "^0%-") or not string.match(message.Text, "[Server]") then return end
		
		local msg_properties = Instance.new("TextChatMessageProperties")
		msg_properties.Text = `<font face='Code' color='#{TCSChatColor}'>{message.Text}</font>`
		
		return msg_properties
	end
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
