--!strict
--[[
	CrosshairUI
	Creates a simple crosshair overlay in the center of the screen.
]]

local Players = game:GetService("Players")

local CrosshairUI = {}

function CrosshairUI.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CrosshairGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Create crosshair "+" label
	local crosshair = Instance.new("TextLabel")
	crosshair.Name = "Crosshair"
	crosshair.Size = UDim2.fromOffset(20, 20)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.BackgroundTransparency = 1
	crosshair.Text = "+"
	crosshair.TextColor3 = Color3.new(1, 1, 1)
	crosshair.TextSize = 18
	crosshair.Font = Enum.Font.GothamBold
	crosshair.TextStrokeTransparency = 0.5
	crosshair.TextStrokeColor3 = Color3.new(0, 0, 0)
	crosshair.Parent = screenGui
end

-- Auto-initialize
CrosshairUI.init()

return CrosshairUI
