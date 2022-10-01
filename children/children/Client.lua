--!strict

-- Settings
local MsgFont = Enum.Font.Code
local TextSize = 14
--

type CmdResult = {
	Text : string,
	Color : Color3
}

local ClientMessageRemote : RemoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("Watchdog_CmdsEvent")
local StarterGui = game:GetService("StarterGui")

StarterGui:SetCore("ChatWindowSize", UDim2.fromScale(0.35, 0.4))

ClientMessageRemote.OnClientEvent:Connect(function(result : CmdResult)
	task.wait() -- to make sure message doesn't show before player's cmd
	
	StarterGui:SetCore("ChatMakeSystemMessage", {
		Text = result.Text,
		Color = result.Color,
		Font = MsgFont,
		TextSize = TextSize
	})
end)
