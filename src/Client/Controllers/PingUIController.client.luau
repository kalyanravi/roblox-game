--!strict
--[[
	PingUIController (Client)
	Handles visual display of team pings and callouts.
	- Listens to PingBroadcast RemoteEvent: renders a 3D ping marker (BillboardGui)
	  above the world position for the specified duration (5s).
	- Listens to CalloutBroadcast RemoteEvent: displays callout as a brief
	  notification in the HUD (top-left chat area, fades after 3s).
	Requirements: 17.1, 17.2, 17.3
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

----------------------------------------------------------------------
-- Remote Events
----------------------------------------------------------------------

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

local PingBroadcastRemote: RemoteEvent? = if Remotes
	then Remotes:FindFirstChild("PingBroadcast") :: RemoteEvent?
	else ReplicatedStorage:FindFirstChild("PingBroadcast") :: RemoteEvent?

local CalloutBroadcastRemote: RemoteEvent? = if Remotes
	then Remotes:FindFirstChild("CalloutBroadcast") :: RemoteEvent?
	else ReplicatedStorage:FindFirstChild("CalloutBroadcast") :: RemoteEvent?

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local PING_MARKER_COLOR = Color3.fromRGB(50, 200, 255)
local PING_MARKER_SIZE = UDim2.new(0, 50, 0, 60)
local CALLOUT_FADE_DURATION = 3 -- seconds
local MAX_CALLOUT_NOTIFICATIONS = 5

----------------------------------------------------------------------
-- Callout Notification GUI (persistent, top-left area)
----------------------------------------------------------------------

local calloutGui = Instance.new("ScreenGui")
calloutGui.Name = "PingCalloutGui"
calloutGui.ResetOnSpawn = false
calloutGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
calloutGui.IgnoreGuiInset = true
calloutGui.Parent = PlayerGui

local calloutContainer = Instance.new("Frame")
calloutContainer.Name = "CalloutContainer"
calloutContainer.Size = UDim2.new(0, 280, 0, 200)
calloutContainer.Position = UDim2.new(0, 15, 0, 220)
calloutContainer.BackgroundTransparency = 1
calloutContainer.Parent = calloutGui

local calloutLayout = Instance.new("UIListLayout")
calloutLayout.FillDirection = Enum.FillDirection.Vertical
calloutLayout.SortOrder = Enum.SortOrder.LayoutOrder
calloutLayout.Padding = UDim.new(0, 4)
calloutLayout.Parent = calloutContainer

----------------------------------------------------------------------
-- Ping Marker (3D BillboardGui)
----------------------------------------------------------------------

local function createPingMarker(worldPosition: Vector3, playerName: string, duration: number)
	-- Create an anchored part at the world position to host the BillboardGui
	local anchorPart = Instance.new("Part")
	anchorPart.Name = "PingAnchor_" .. playerName
	anchorPart.Size = Vector3.new(0.5, 0.5, 0.5)
	anchorPart.Position = worldPosition + Vector3.new(0, 3, 0) -- slightly above the pinged position
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.CanTouch = false
	anchorPart.CanQuery = false
	anchorPart.Transparency = 1
	anchorPart.Parent = workspace

	-- BillboardGui attached to the anchor part
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PingMarkerGui"
	billboard.Size = PING_MARKER_SIZE
	billboard.StudsOffset = Vector3.new(0, 1, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 200
	billboard.Adornee = anchorPart
	billboard.Parent = anchorPart

	-- Ping icon frame
	local markerFrame = Instance.new("Frame")
	markerFrame.Name = "MarkerFrame"
	markerFrame.Size = UDim2.new(1, 0, 0.7, 0)
	markerFrame.Position = UDim2.new(0, 0, 0, 0)
	markerFrame.BackgroundColor3 = PING_MARKER_COLOR
	markerFrame.BackgroundTransparency = 0.3
	markerFrame.BorderSizePixel = 0
	markerFrame.Parent = billboard

	local markerCorner = Instance.new("UICorner")
	markerCorner.CornerRadius = UDim.new(0.5, 0)
	markerCorner.Parent = markerFrame

	-- Ping symbol
	local pingIcon = Instance.new("TextLabel")
	pingIcon.Name = "PingIcon"
	pingIcon.Size = UDim2.new(1, 0, 1, 0)
	pingIcon.BackgroundTransparency = 1
	pingIcon.Text = "📍"
	pingIcon.TextScaled = true
	pingIcon.Font = Enum.Font.GothamBold
	pingIcon.Parent = markerFrame

	-- Player name label below the marker
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PingerName"
	nameLabel.Size = UDim2.new(1, 0, 0.25, 0)
	nameLabel.Position = UDim2.new(0, 0, 0.75, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = playerName
	nameLabel.TextColor3 = PING_MARKER_COLOR
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = billboard

	-- Glow effect around marker
	local glowStroke = Instance.new("UIStroke")
	glowStroke.Color = PING_MARKER_COLOR
	glowStroke.Thickness = 2
	glowStroke.Transparency = 0.4
	glowStroke.Parent = markerFrame

	-- Pulsing animation
	local pulseInfo = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local pulseTween = TweenService:Create(glowStroke, pulseInfo, { Thickness = 4, Transparency = 0.1 })
	pulseTween:Play()

	-- Remove after duration
	task.delay(duration, function()
		pulseTween:Cancel()
		-- Fade out before destroying
		local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local fadeTween = TweenService:Create(markerFrame, fadeInfo, { BackgroundTransparency = 1 })
		fadeTween:Play()
		fadeTween.Completed:Connect(function()
			if anchorPart and anchorPart.Parent then
				anchorPart:Destroy()
			end
		end)
	end)
end

----------------------------------------------------------------------
-- Callout Notification (2D HUD)
----------------------------------------------------------------------

local function showCalloutNotification(playerName: string, displayMessage: string)
	local notification = Instance.new("TextLabel")
	notification.Name = "CalloutNotif"
	notification.Size = UDim2.new(1, 0, 0, 24)
	notification.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	notification.BackgroundTransparency = 0.4
	notification.BorderSizePixel = 0
	notification.Text = "[" .. playerName .. "] " .. displayMessage
	notification.TextColor3 = PING_MARKER_COLOR
	notification.TextScaled = true
	notification.Font = Enum.Font.Gotham
	notification.TextXAlignment = Enum.TextXAlignment.Left
	notification.Parent = calloutContainer

	local notifCorner = Instance.new("UICorner")
	notifCorner.CornerRadius = UDim.new(0, 4)
	notifCorner.Parent = notification

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.Parent = notification

	-- Fade out after CALLOUT_FADE_DURATION
	task.delay(CALLOUT_FADE_DURATION, function()
		if notification and notification.Parent then
			local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local fadeTween = TweenService:Create(notification, fadeInfo, { TextTransparency = 1, BackgroundTransparency = 1 })
			fadeTween:Play()
			fadeTween.Completed:Connect(function()
				if notification and notification.Parent then
					notification:Destroy()
				end
			end)
		end
	end)

	-- Limit visible notifications
	local children = calloutContainer:GetChildren()
	local notifCount = 0
	for _, child in children do
		if child:IsA("TextLabel") then
			notifCount += 1
		end
	end
	if notifCount > MAX_CALLOUT_NOTIFICATIONS then
		for _, child in children do
			if child:IsA("TextLabel") then
				child:Destroy()
				break
			end
		end
	end
end

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

-- Ping broadcast listener
local function getPingRemote(): RemoteEvent?
	if PingBroadcastRemote then
		return PingBroadcastRemote
	end
	local remote = ReplicatedStorage:FindFirstChild("PingBroadcast")
	if remote and remote:IsA("RemoteEvent") then
		return remote :: RemoteEvent
	end
	return nil
end

local pingRemote = getPingRemote()
if pingRemote then
	pingRemote.OnClientEvent:Connect(function(playerName: any, worldPosition: any, duration: any)
		if typeof(playerName) ~= "string" then return end
		if typeof(worldPosition) ~= "Vector3" then return end
		if typeof(duration) ~= "number" then return end

		createPingMarker(worldPosition, playerName, duration)
	end)
end

-- Callout broadcast listener
local function getCalloutRemote(): RemoteEvent?
	if CalloutBroadcastRemote then
		return CalloutBroadcastRemote
	end
	local remote = ReplicatedStorage:FindFirstChild("CalloutBroadcast")
	if remote and remote:IsA("RemoteEvent") then
		return remote :: RemoteEvent
	end
	return nil
end

local calloutRemote = getCalloutRemote()
if calloutRemote then
	calloutRemote.OnClientEvent:Connect(function(playerName: any, _calloutId: any, displayMessage: any)
		if typeof(playerName) ~= "string" then return end
		if typeof(displayMessage) ~= "string" then return end

		showCalloutNotification(playerName, displayMessage)
	end)
end

----------------------------------------------------------------------

return nil
