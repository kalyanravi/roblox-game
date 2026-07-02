--!strict
--[[
	WeaponInput
	Client-side weapon input handler.
	Sends aim origin and direction to the server on Tool activation.
	Handles reload input (R key).
	Includes muzzle flash effect and screen shake (recoil).
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
-- Third Person Camera reference (for screen shake)
----------------------------------------------------------------------

local Gameplay = script.Parent
local ThirdPersonCamera: any = nil

-- Safely attempt to get ThirdPersonCamera module for recoil
task.defer(function()
	local success, mod = pcall(function()
		return require(Gameplay:WaitForChild("ThirdPersonCamera", 5))
	end)
	if success then
		ThirdPersonCamera = mod
	end
end)

----------------------------------------------------------------------
-- Module
----------------------------------------------------------------------

local WeaponInput = {}

----------------------------------------------------------------------
-- Muzzle Flash Effect
----------------------------------------------------------------------

local function createMuzzleFlash()
	local character = player.Character
	if not character then return end

	-- Find the weapon handle (Tool's Handle part)
	local tool: Tool? = nil
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			tool = child :: Tool
			break
		end
	end

	local attachPoint: BasePart = (if tool and tool:FindFirstChild("Handle")
		then tool.Handle :: BasePart
		else character:FindFirstChild("HumanoidRootPart") :: BasePart?) :: BasePart

	if not attachPoint then return end

	-- Muzzle flash Part (small bright neon sphere)
	local flash = Instance.new("Part")
	flash.Name = "MuzzleFlash"
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 180, 50)
	flash.Size = Vector3.new(1.2, 1.2, 1.2)
	flash.Shape = Enum.PartType.Ball
	flash.Transparency = 0.2
	flash.CFrame = attachPoint.CFrame * CFrame.new(0, 0, -2) -- slightly in front
	flash.Parent = workspace

	-- PointLight for illumination
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 80)
	light.Brightness = 4
	light.Range = 12
	light.Shadows = false
	light.Parent = flash

	-- Remove after brief flash (0.05 seconds)
	task.delay(0.05, function()
		if flash.Parent then flash:Destroy() end
	end)
end

----------------------------------------------------------------------
-- Screen Shake (Recoil)
----------------------------------------------------------------------

local function applyScreenShake()
	-- Random small offset to simulate recoil kick
	local shakeX = (math.random() - 0.5) * 0.3
	local shakeY = math.random() * 0.4 + 0.1 -- slight upward kick
	local shakeCFrame = CFrame.Angles(math.rad(shakeY), math.rad(shakeX), 0)

	if ThirdPersonCamera and ThirdPersonCamera.setRecoilOffset then
		ThirdPersonCamera.setRecoilOffset(shakeCFrame)

		-- Reset recoil after a brief moment
		task.delay(0.06, function()
			if ThirdPersonCamera and ThirdPersonCamera.setRecoilOffset then
				ThirdPersonCamera.setRecoilOffset(CFrame.new())
			end
		end)
	else
		-- Fallback: directly offset camera briefly
		if camera then
			local original = camera.CFrame
			camera.CFrame = original * shakeCFrame
			task.delay(0.06, function()
				-- Camera will self-correct on next frame via ThirdPersonCamera or default
			end)
		end
	end
end

----------------------------------------------------------------------
-- Bullet Tracer
----------------------------------------------------------------------

--[[
	Creates a visible bullet tracer from camera to hit point (CLIENT-SIDE, instant feedback).
]]
local function createClientTracer(origin: Vector3, direction: Vector3)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local character = player.Character
	if character then
		rayParams.FilterDescendantsInstances = { character }
	end

	local result = workspace:Raycast(origin, direction * 200, rayParams)
	local endPos = if result then result.Position else (origin + direction * 200)

	-- Bright yellow tracer beam
	local dist = (endPos - origin).Magnitude
	local tracer = Instance.new("Part")
	tracer.Name = "ClientTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanTouch = false
	tracer.CanQuery = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 255, 0)
	tracer.Size = Vector3.new(0.15, 0.15, dist)
	tracer.CFrame = CFrame.lookAt(origin, endPos) * CFrame.new(0, 0, -dist / 2)
	tracer.Transparency = 0
	tracer.Parent = workspace

	-- Red hit spark at impact
	if result then
		local spark = Instance.new("Part")
		spark.Name = "HitSpark"
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanTouch = false
		spark.Material = Enum.Material.Neon
		spark.Color = Color3.fromRGB(255, 50, 0)
		spark.Size = Vector3.new(1.2, 1.2, 1.2)
		spark.Shape = Enum.PartType.Ball
		spark.CFrame = CFrame.new(result.Position)
		spark.Parent = workspace

		task.delay(0.4, function()
			if spark.Parent then spark:Destroy() end
		end)
	end

	-- Remove tracer after brief duration
	task.delay(0.25, function()
		if tracer.Parent then tracer:Destroy() end
	end)
end

----------------------------------------------------------------------
-- Gun Sound
----------------------------------------------------------------------

--[[
	Plays a gunshot sound from the character.
]]
local function playGunSound()
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://168143115"
	sound.Volume = 0.8
	sound.PlaybackSpeed = 1.2
	sound.Parent = rootPart
	sound:Play()

	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

----------------------------------------------------------------------
-- Fire Weapon
----------------------------------------------------------------------

--[[
	Fires the weapon using camera position and look direction.
]]
local function fireWeapon()
	if not camera then
		return
	end

	local aimOrigin = camera.CFrame.Position
	local aimDirection = camera.CFrame.LookVector

	-- Visual feedback: muzzle flash + tracer + sound + recoil shake
	createMuzzleFlash()
	createClientTracer(aimOrigin, aimDirection)
	playGunSound()
	applyScreenShake()

	-- Send to server for damage calculation
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

local mouse = player:GetMouse()
local toolEquipped = false

local function onCharacterAdded(character: Model)
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

-- Mouse fire
mouse.Button1Down:Connect(function()
	if toolEquipped then
		fireWeapon()
	end
end)

-- Keyboard: reload
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end

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
	-- Initialized via connections above
end

WeaponInput.init()

return WeaponInput
