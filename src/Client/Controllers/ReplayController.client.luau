--!strict
--[[
	ReplayController (Client)
	Listens to the ReplayData RemoteEvent from server on match end.
	Hides standard HUD, shows "FINAL KILL" banner, plays a 5-second
	slow-motion replay from the killer's perspective, displays kill info,
	then restores normal HUD and camera control.
	Requirements: 15.1, 15.2, 15.3
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

----------------------------------------------------------------------
-- Remote Events
----------------------------------------------------------------------

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local ReplayDataRemote: RemoteEvent? = if Remotes
	then Remotes:FindFirstChild("ReplayData") :: RemoteEvent?
	else ReplicatedStorage:FindFirstChild("ReplayData") :: RemoteEvent?

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local REPLAY_DURATION = 5 -- seconds
local SLOW_MOTION_FACTOR = 0.3 -- slowed time scale

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local isReplayActive = false
local originalCameraType: Enum.CameraType? = nil
local originalCameraCFrame: CFrame? = nil
local replayGui: ScreenGui? = nil

----------------------------------------------------------------------
-- UI Helpers
----------------------------------------------------------------------

local function createReplayGui(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "ReplayOverlay"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Parent = PlayerGui
	return gui
end

local function createBanner(parent: ScreenGui): Frame
	local bannerFrame = Instance.new("Frame")
	bannerFrame.Name = "FinalKillBanner"
	bannerFrame.Size = UDim2.new(1, 0, 0, 80)
	bannerFrame.Position = UDim2.new(0.5, 0, 0.1, 0)
	bannerFrame.AnchorPoint = Vector2.new(0.5, 0)
	bannerFrame.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
	bannerFrame.BackgroundTransparency = 0.2
	bannerFrame.BorderSizePixel = 0
	bannerFrame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bannerFrame

	local bannerLabel = Instance.new("TextLabel")
	bannerLabel.Name = "BannerText"
	bannerLabel.Size = UDim2.new(1, 0, 1, 0)
	bannerLabel.BackgroundTransparency = 1
	bannerLabel.Text = "⚔️ FINAL KILL ⚔️"
	bannerLabel.TextColor3 = Color3.new(1, 1, 1)
	bannerLabel.TextScaled = true
	bannerLabel.Font = Enum.Font.GothamBold
	bannerLabel.Parent = bannerFrame

	return bannerFrame
end

local function createKillInfoPanel(parent: ScreenGui, killerName: string, weaponId: string, streakCount: number): Frame
	local infoFrame = Instance.new("Frame")
	infoFrame.Name = "KillInfoPanel"
	infoFrame.Size = UDim2.new(0, 400, 0, 100)
	infoFrame.Position = UDim2.new(0.5, 0, 0.8, 0)
	infoFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	infoFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	infoFrame.BackgroundTransparency = 0.3
	infoFrame.BorderSizePixel = 0
	infoFrame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = infoFrame

	-- Killer name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "KillerName"
	nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = killerName
	nameLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = infoFrame

	-- Weapon used
	local weaponLabel = Instance.new("TextLabel")
	weaponLabel.Name = "WeaponUsed"
	weaponLabel.Size = UDim2.new(1, 0, 0.3, 0)
	weaponLabel.Position = UDim2.new(0, 0, 0.4, 0)
	weaponLabel.BackgroundTransparency = 1
	weaponLabel.Text = "Weapon: " .. weaponId
	weaponLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	weaponLabel.TextScaled = true
	weaponLabel.Font = Enum.Font.Gotham
	weaponLabel.Parent = infoFrame

	-- Streak count
	local streakLabel = Instance.new("TextLabel")
	streakLabel.Name = "StreakCount"
	streakLabel.Size = UDim2.new(1, 0, 0.3, 0)
	streakLabel.Position = UDim2.new(0, 0, 0.7, 0)
	streakLabel.BackgroundTransparency = 1
	streakLabel.Text = "🔥 Streak: " .. tostring(streakCount)
	streakLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
	streakLabel.TextScaled = true
	streakLabel.Font = Enum.Font.GothamBold
	streakLabel.Parent = infoFrame

	return infoFrame
end

----------------------------------------------------------------------
-- Replay Logic
----------------------------------------------------------------------

local function hideStandardHUD()
	local shardstrikeHUD = PlayerGui:FindFirstChild("ShardstrikeHUD")
	if shardstrikeHUD then
		(shardstrikeHUD :: ScreenGui).Enabled = false
	end
end

local function showStandardHUD()
	local shardstrikeHUD = PlayerGui:FindFirstChild("ShardstrikeHUD")
	if shardstrikeHUD then
		(shardstrikeHUD :: ScreenGui).Enabled = true
	end
end

local function endReplay()
	if not isReplayActive then
		return
	end
	isReplayActive = false

	-- Restore camera
	local cam = Camera or workspace.CurrentCamera
	if cam then
		if originalCameraType then
			cam.CameraType = originalCameraType
		else
			cam.CameraType = Enum.CameraType.Custom
		end
	end

	-- Remove replay overlay GUI
	if replayGui then
		replayGui:Destroy()
		replayGui = nil
	end

	-- Restore standard HUD
	showStandardHUD()

	-- Clear stored state
	originalCameraType = nil
	originalCameraCFrame = nil
end

local function startReplay(killerName: string, weaponId: string, killerPosition: Vector3, streakCount: number)
	if isReplayActive then
		return
	end
	isReplayActive = true

	-- Store original camera state
	local cam = Camera or workspace.CurrentCamera
	if cam then
		originalCameraType = cam.CameraType
		originalCameraCFrame = cam.CFrame
	end

	-- Hide standard HUD
	hideStandardHUD()

	-- Create replay overlay GUI
	local gui = createReplayGui()
	replayGui = gui

	-- Show FINAL KILL banner
	createBanner(gui)

	-- Show kill info (killer name, weapon, streak)
	createKillInfoPanel(gui, killerName, weaponId, streakCount)

	-- Position camera at killer's perspective
	if cam then
		cam.CameraType = Enum.CameraType.Scriptable
		-- Position camera slightly above and behind the killer position, looking forward
		local replayCFrame = CFrame.new(killerPosition + Vector3.new(0, 3, 5), killerPosition)
		cam.CFrame = replayCFrame
	end

	-- Slow orbiting camera around the kill position for cinematic effect
	local startTime = os.clock()
	local renderConnection: RBXScriptConnection? = nil

	renderConnection = RunService.RenderStepped:Connect(function(_dt: number)
		if not isReplayActive then
			if renderConnection then
				renderConnection:Disconnect()
				renderConnection = nil
			end
			return
		end

		local elapsed = os.clock() - startTime
		local progress = math.clamp(elapsed / REPLAY_DURATION, 0, 1)

		-- Slow orbiting camera around the killer position
		if cam then
			local angle = progress * math.pi * SLOW_MOTION_FACTOR * 2
			local radius = 8
			local height = 4
			local orbitPosition = killerPosition + Vector3.new(
				math.cos(angle) * radius,
				height,
				math.sin(angle) * radius
			)
			cam.CFrame = CFrame.new(orbitPosition, killerPosition)
		end
	end)

	-- End replay after REPLAY_DURATION seconds
	task.delay(REPLAY_DURATION, function()
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		endReplay()
	end)
end

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

-- Try to find ReplayData remote in multiple locations
local function getReplayRemote(): RemoteEvent?
	if ReplayDataRemote then
		return ReplayDataRemote
	end
	-- Fallback: check directly in ReplicatedStorage
	local remote = ReplicatedStorage:FindFirstChild("ReplayData")
	if remote and remote:IsA("RemoteEvent") then
		return remote :: RemoteEvent
	end
	return nil
end

local remote = getReplayRemote()
if remote then
	remote.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end

		local killerName = payload.killerName
		local weaponId = payload.weaponId
		local killerPosition = payload.killerPosition
		local streakCount = payload.streakCount

		if typeof(killerName) ~= "string" then return end
		if typeof(weaponId) ~= "string" then return end
		if typeof(killerPosition) ~= "Vector3" then return end
		if typeof(streakCount) ~= "number" then return end

		startReplay(killerName, weaponId, killerPosition, streakCount)
	end)
end

----------------------------------------------------------------------

return nil
