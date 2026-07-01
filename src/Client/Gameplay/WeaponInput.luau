--!strict
--[[
	WeaponInput
	Client-side weapon input handler.
	Sends aim origin and direction to the server on Tool activation.
	Handles reload input (R key).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

----------------------------------------------------------------------
-- Remotes
----------------------------------------------------------------------

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FireWeaponRemote = Remotes:WaitForChild("FireWeapon") :: RemoteEvent
local ReloadWeaponRemote = Remotes:WaitForChild("ReloadWeapon") :: RemoteEvent

----------------------------------------------------------------------
-- Module
----------------------------------------------------------------------

local WeaponInput = {}

--[[
	Creates a visible bullet tracer from camera to hit point (CLIENT-SIDE, instant feedback).
]]
local function createClientTracer(origin: Vector3, direction: Vector3)
	-- Do a client-side raycast to find where the bullet would hit
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local character = player.Character
	if character then
		rayParams.FilterDescendantsInstances = {character}
	end
	
	local result = workspace:Raycast(origin, direction * 200, rayParams)
	local endPos = if result then result.Position else (origin + direction * 200)
	
	-- Create bright yellow tracer beam
	local dist = (endPos - origin).Magnitude
	local tracer = Instance.new("Part")
	tracer.Name = "ClientTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanTouch = false
	tracer.CanQuery = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 255, 0)
	tracer.Size = Vector3.new(0.2, 0.2, dist)
	tracer.CFrame = CFrame.lookAt(origin, endPos) * CFrame.new(0, 0, -dist/2)
	tracer.Transparency = 0
	tracer.Parent = workspace
	
	-- Red hit spark at impact point
	if result then
		local spark = Instance.new("Part")
		spark.Name = "HitSpark"
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanTouch = false
		spark.Material = Enum.Material.Neon
		spark.Color = Color3.fromRGB(255, 50, 0)
		spark.Size = Vector3.new(1.5, 1.5, 1.5)
		spark.Shape = Enum.PartType.Ball
		spark.CFrame = CFrame.new(result.Position)
		spark.Parent = workspace
		
		task.delay(0.5, function()
			if spark.Parent then spark:Destroy() end
		end)
	end
	
	-- Remove tracer after 0.3 seconds
	task.delay(0.3, function()
		if tracer.Parent then tracer:Destroy() end
	end)
end

--[[
	Plays a gunshot sound from the character.
]]
local function playGunSound()
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://168143115" -- Generic gunshot sound
	sound.Volume = 0.8
	sound.PlaybackSpeed = 1.2
	sound.Parent = rootPart
	sound:Play()
	
	-- Cleanup after sound finishes
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

--[[
	Fires the weapon using camera position and look direction.
	Called when the player clicks/taps while holding the tool.
]]
local function fireWeapon()
	if not camera then
		return
	end

	local aimOrigin = camera.CFrame.Position
	local aimDirection = camera.CFrame.LookVector

	-- Instant client-side feedback: tracer + sound
	createClientTracer(aimOrigin, aimDirection)
	playGunSound()

	-- Send to server for actual damage calculation
	FireWeaponRemote:FireServer(aimOrigin, aimDirection)
end

--[[
	Sends a reload request to the server.
]]
local function requestReload()
	ReloadWeaponRemote:FireServer()
end

----------------------------------------------------------------------
-- Input Handling
----------------------------------------------------------------------

-- Listen for mouse click (fires weapon when tool is equipped)
local mouse = player:GetMouse()
local toolEquipped = false

local function onCharacterAdded(character: Model)
	-- Watch for tool equip/unequip
	character.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Tool") then
			toolEquipped = true
		end
	end)

	character.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Tool") then
			toolEquipped = false
		end
	end)

	-- Check if tool is already equipped
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			toolEquipped = true
		end
	end
end

-- Mouse button fire
mouse.Button1Down:Connect(function()
	if toolEquipped then
		fireWeapon()
	end
end)

-- Keyboard input for reload
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.R then
		requestReload()
	end
end)

-- Character setup
if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

function WeaponInput.init()
	-- Already initialized via connections above
end

WeaponInput.init()

return WeaponInput
