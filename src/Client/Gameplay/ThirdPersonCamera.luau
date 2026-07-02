--!strict
--[[
	ThirdPersonCamera
	Over-the-shoulder third-person camera (Rivals/Fortnite style).
	Offset to the right and slightly above the character.
	Right-click enters ADS (aim-down-sights) mode with tighter zoom.
	Mouse controls camera rotation with cursor locked.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

----------------------------------------------------------------------
-- Configuration
----------------------------------------------------------------------

local NORMAL_OFFSET = Vector3.new(2, 1, 6) -- right, up, back
local ADS_OFFSET = Vector3.new(1, 0.5, 3) -- tighter when aiming
local LERP_SPEED = 0.2
local SENSITIVITY = Vector2.new(0.3, 0.25) -- X and Y mouse sensitivity
local MIN_PITCH = -60 -- degrees (look down limit)
local MAX_PITCH = 70 -- degrees (look up limit)

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local yaw: number = 0
local pitch: number = 0
local isADS: boolean = false
local currentOffset: Vector3 = NORMAL_OFFSET
local enabled: boolean = true

----------------------------------------------------------------------
-- Module
----------------------------------------------------------------------

local ThirdPersonCamera = {}

--[[
	Returns the current camera recoil offset (set by WeaponInput for screen shake).
	This is read externally via a shared value.
]]
local recoilOffset = CFrame.new()

function ThirdPersonCamera.setRecoilOffset(cf: CFrame)
	recoilOffset = cf
end

function ThirdPersonCamera.getRecoilOffset(): CFrame
	return recoilOffset
end

----------------------------------------------------------------------
-- Input: Mouse Delta for rotation
----------------------------------------------------------------------

local function onInputChanged(input: InputObject, _gameProcessed: boolean)
	if not enabled then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Delta
		yaw = yaw - delta.X * SENSITIVITY.X
		pitch = math.clamp(pitch - delta.Y * SENSITIVITY.Y, MIN_PITCH, MAX_PITCH)
	end
end

----------------------------------------------------------------------
-- Input: Right-click for ADS
----------------------------------------------------------------------

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isADS = true
	end
end

local function onInputEnded(input: InputObject, _gameProcessed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isADS = false
	end
end

----------------------------------------------------------------------
-- Camera Update (every render frame)
----------------------------------------------------------------------

local function updateCamera(_deltaTime: number)
	if not enabled then return end

	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then return end

	-- Set camera to scriptable so we have full control
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	-- Lock mouse to center
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	-- Determine target offset (smooth transition between normal and ADS)
	local targetOffset = if isADS then ADS_OFFSET else NORMAL_OFFSET
	currentOffset = currentOffset:Lerp(targetOffset, LERP_SPEED)

	-- Build rotation CFrame from yaw/pitch
	local rootPos = humanoidRootPart.Position
	local rotation = CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(pitch), 0, 0)

	-- Calculate camera position: behind + right + up relative to character
	local offsetCFrame = rotation * CFrame.new(currentOffset.X, currentOffset.Y, currentOffset.Z)
	local cameraPosition = rootPos + offsetCFrame.Position

	-- Camera looks at a point slightly ahead of the character
	local lookTarget = rootPos + (rotation * CFrame.new(0, 1, -20)).Position

	-- Build final CFrame
	local targetCFrame = CFrame.lookAt(cameraPosition, lookTarget)

	-- Apply smooth lerp
	local currentCFrame = camera.CFrame
	camera.CFrame = currentCFrame:Lerp(targetCFrame, LERP_SPEED) * recoilOffset

	-- Rotate character to face camera direction (yaw only)
	humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position) * CFrame.Angles(0, math.rad(yaw), 0)
end

----------------------------------------------------------------------
-- Character Death / Respawn Handling
----------------------------------------------------------------------

local function onCharacterAdded(character: Model)
	-- Reset camera state on respawn
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	yaw = 0
	pitch = 0
	isADS = false
	currentOffset = NORMAL_OFFSET
	recoilOffset = CFrame.new()
	enabled = true

	humanoid.Died:Connect(function()
		enabled = false
		-- Return camera to default on death so respawn screen works
		camera.CameraType = Enum.CameraType.Custom
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end)
end

----------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------

function ThirdPersonCamera.init()
	-- Connect input
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)

	-- Connect render update
	RunService.RenderStepped:Connect(updateCamera)

	-- Character setup
	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

ThirdPersonCamera.init()

return ThirdPersonCamera
