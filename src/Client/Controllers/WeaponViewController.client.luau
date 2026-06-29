--!strict
--[[
	WeaponViewController (Client)
	Manages first-person weapon view model rendering, animations, and rarity visual effects.
	Attaches weapon model to the Camera for standard FPS view.
	Listens to server events for weapon state changes.
	Requirements: 2.5, 14.6
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local WeaponDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Definitions"):WaitForChild("WeaponDefinitions"))
local RarityConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Definitions"):WaitForChild("RarityConfig"))

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Types
type WeaponRarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"

type WeaponViewState = {
	equippedWeaponId: string?,
	isAnimating: boolean,
	currentModel: Model?,
	particleEmitter: ParticleEmitter?,
	surfaceLight: SurfaceLight?,
	renderConnection: RBXScriptConnection?,
}

-- Module state
local state: WeaponViewState = {
	equippedWeaponId = nil,
	isAnimating = false,
	currentModel = nil,
	particleEmitter = nil,
	surfaceLight = nil,
	renderConnection = nil,
}

-- Constants
local WEAPON_OFFSET = CFrame.new(0.5, -0.5, -1.5) -- Default weapon position relative to camera
local RECOIL_KICK_DISTANCE = 0.15
local RECOIL_KICK_DURATION = 0.08
local RECOIL_RECOVER_DURATION = 0.12
local RELOAD_DIP_DISTANCE = 0.4
local RELOAD_DIP_DURATION = 0.3
local RELOAD_RAISE_DURATION = 0.4
local SWAP_LOWER_DISTANCE = 0.8
local SWAP_DURATION = 0.25

---------------------------------------------------------------------------
-- Internal Helpers
---------------------------------------------------------------------------

local function getWeaponRarity(weaponId: string): WeaponRarity?
	local weaponData = WeaponDefinitions.getWeapon(weaponId)
	if weaponData then
		return weaponData.rarity
	end
	return nil
end

local function hasFeature(rarity: WeaponRarity, feature: string): boolean
	local rarityData = RarityConfig[rarity]
	if not rarityData then
		return false
	end
	for _, f in rarityData.features do
		if f == feature then
			return true
		end
	end
	return false
end

--- Creates a placeholder weapon model (box mesh) for the given weapon ID.
--- In production, this would load the actual weapon asset from ReplicatedStorage.
local function createWeaponModel(weaponId: string): Model
	local weaponData = WeaponDefinitions.getWeapon(weaponId)
	local model = Instance.new("Model")
	model.Name = "WeaponViewModel_" .. weaponId

	-- Create main weapon part (placeholder geometry)
	local mainPart = Instance.new("Part")
	mainPart.Name = "Handle"
	mainPart.Size = Vector3.new(0.3, 0.3, 1.5)
	mainPart.Anchored = true
	mainPart.CanCollide = false
	mainPart.CastShadow = false
	mainPart.Color = Color3.fromRGB(60, 60, 60)
	mainPart.Material = Enum.Material.Metal
	mainPart.Parent = model

	-- Create muzzle point
	local muzzle = Instance.new("Part")
	muzzle.Name = "Muzzle"
	muzzle.Size = Vector3.new(0.15, 0.15, 0.1)
	muzzle.Anchored = true
	muzzle.CanCollide = false
	muzzle.CastShadow = false
	muzzle.Transparency = 1
	muzzle.CFrame = mainPart.CFrame * CFrame.new(0, 0, -0.8)
	muzzle.Parent = model

	model.PrimaryPart = mainPart

	-- Apply rarity-specific visual features
	if weaponData then
		local rarity: WeaponRarity = weaponData.rarity

		-- Mythic: glowing weapon model (Neon material + SurfaceLight)
		if hasFeature(rarity, "glowingModel") then
			mainPart.Material = Enum.Material.Neon
			mainPart.Color = Color3.fromRGB(180, 120, 255) -- Purple glow for Mythic

			local light = Instance.new("SurfaceLight")
			light.Name = "MythicGlow"
			light.Brightness = 2
			light.Range = 6
			light.Color = Color3.fromRGB(180, 120, 255)
			light.Face = Enum.NormalId.Front
			light.Parent = mainPart
			state.surfaceLight = light
		end

		-- Legendary: particle trail effect
		if hasFeature(rarity, "particleTrail") then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "LegendaryTrail"
			emitter.Rate = 20
			emitter.Lifetime = NumberRange.new(0.3, 0.6)
			emitter.Speed = NumberRange.new(1, 2)
			emitter.SpreadAngle = Vector2.new(10, 10)
			emitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 50))
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 0),
			})
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.LightEmission = 1
			emitter.Parent = mainPart
			state.particleEmitter = emitter
		end
	end

	return model
end

--- Attaches the weapon model to the camera and starts the render step connection.
local function attachToCamera(model: Model): ()
	if state.renderConnection then
		state.renderConnection:Disconnect()
		state.renderConnection = nil
	end

	model.Parent = Camera

	state.renderConnection = RunService.RenderStepped:Connect(function()
		if model and model.PrimaryPart and Camera then
			model:PivotTo(Camera.CFrame * WEAPON_OFFSET)
		end
	end)
end

--- Removes the current weapon model from the camera.
local function detachCurrentModel(): ()
	if state.renderConnection then
		state.renderConnection:Disconnect()
		state.renderConnection = nil
	end
	if state.currentModel then
		state.currentModel:Destroy()
		state.currentModel = nil
	end
	state.particleEmitter = nil
	state.surfaceLight = nil
end

--- Animates a CFrame offset on the weapon model using TweenService.
local function animateOffset(offset: CFrame, duration: number, easingStyle: Enum.EasingStyle?, callback: (() -> ())?): ()
	if not state.currentModel or not state.currentModel.PrimaryPart then
		if callback then
			callback()
		end
		return
	end

	-- Temporarily override the render connection offset
	local originalOffset = WEAPON_OFFSET
	local targetOffset = originalOffset * offset

	-- Disconnect render to animate manually
	if state.renderConnection then
		state.renderConnection:Disconnect()
	end

	local elapsed = 0
	local style = easingStyle or Enum.EasingStyle.Quad

	state.renderConnection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		local alpha = math.min(elapsed / duration, 1)

		-- Ease the alpha
		local easedAlpha = TweenService:GetValue(alpha, style, Enum.EasingDirection.Out)

		if state.currentModel and state.currentModel.PrimaryPart and Camera then
			local interpolatedOffset = originalOffset:Lerp(targetOffset, easedAlpha)
			state.currentModel:PivotTo(Camera.CFrame * interpolatedOffset)
		end

		if alpha >= 1 then
			if state.renderConnection then
				state.renderConnection:Disconnect()
			end
			if callback then
				callback()
			end
		end
	end)
end

--- Restores the weapon to its default camera-attached position.
local function restoreDefaultPosition(): ()
	if state.currentModel then
		attachToCamera(state.currentModel)
	end
	state.isAnimating = false
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

local WeaponViewController = {}

--- Loads and shows the weapon view model for the given weapon ID.
--- If a weapon is already equipped, the old model is removed first.
function WeaponViewController.equipWeapon(weaponId: string): ()
	-- Remove existing weapon model
	detachCurrentModel()

	-- Create new weapon model
	local model = createWeaponModel(weaponId)
	state.currentModel = model
	state.equippedWeaponId = weaponId
	state.isAnimating = false

	-- Attach to camera
	attachToCamera(model)
end

--- Triggers the fire animation: recoil kick backward and muzzle flash placeholder.
function WeaponViewController.playFireAnimation(): ()
	if state.isAnimating or not state.currentModel then
		return
	end
	state.isAnimating = true

	local rarity = if state.equippedWeaponId then getWeaponRarity(state.equippedWeaponId) else nil

	-- Muzzle flash placeholder (PointLight flash)
	if state.currentModel then
		local muzzle = state.currentModel:FindFirstChild("Muzzle")
		if muzzle and muzzle:IsA("BasePart") then
			local flash = Instance.new("PointLight")
			flash.Brightness = 5
			flash.Range = 4
			flash.Color = Color3.fromRGB(255, 200, 50)
			flash.Parent = muzzle

			task.delay(0.05, function()
				flash:Destroy()
			end)
		end
	end

	-- Legendary: unique fire sound
	if rarity and hasFeature(rarity, "uniqueFireSound") then
		-- Placeholder: play a distinct sound for Legendary weapons
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://0" -- Placeholder asset ID
		sound.Volume = 0.6
		sound.PlaybackSpeed = 0.8 -- Deeper, more impactful sound
		sound.Parent = state.currentModel
		sound:Play()
		task.delay(1, function()
			sound:Destroy()
		end)
	end

	-- Recoil kick: move weapon backward briefly
	local recoilOffset = CFrame.new(0, 0.02, RECOIL_KICK_DISTANCE)
	animateOffset(recoilOffset, RECOIL_KICK_DURATION, Enum.EasingStyle.Back, function()
		-- Recover to original position
		animateOffset(CFrame.new(), RECOIL_RECOVER_DURATION, Enum.EasingStyle.Quad, function()
			restoreDefaultPosition()
		end)
	end)
end

--- Triggers the reload animation: weapon dips down, simulates magazine swap, then raises back.
--- Epic rarity gets a unique reload animation variant (spin + dip).
function WeaponViewController.playReloadAnimation(): ()
	if state.isAnimating or not state.currentModel then
		return
	end
	state.isAnimating = true

	local rarity = if state.equippedWeaponId then getWeaponRarity(state.equippedWeaponId) else nil
	local isEpicVariant = rarity ~= nil and hasFeature(rarity, "uniqueReloadAnim")

	if isEpicVariant then
		-- Epic: unique reload animation variant (angled dip with rotation)
		local epicDipOffset = CFrame.new(-0.2, -RELOAD_DIP_DISTANCE, 0.1) * CFrame.Angles(math.rad(-15), math.rad(30), 0)
		animateOffset(epicDipOffset, RELOAD_DIP_DURATION * 1.2, Enum.EasingStyle.Sine, function()
			-- Magazine swap pause
			task.delay(0.2, function()
				-- Raise back with a slight twist
				animateOffset(CFrame.new(), RELOAD_RAISE_DURATION, Enum.EasingStyle.Quad, function()
					restoreDefaultPosition()
				end)
			end)
		end)
	else
		-- Standard reload: dip weapon down, pause (mag swap), raise
		local dipOffset = CFrame.new(0, -RELOAD_DIP_DISTANCE, 0.1)
		animateOffset(dipOffset, RELOAD_DIP_DURATION, Enum.EasingStyle.Sine, function()
			-- Magazine swap pause
			task.delay(0.15, function()
				-- Raise back up
				animateOffset(CFrame.new(), RELOAD_RAISE_DURATION, Enum.EasingStyle.Quad, function()
					restoreDefaultPosition()
				end)
			end)
		end)
	end
end

--- Triggers the weapon swap animation: lowers current weapon, then raises new one.
--- Called before equipWeapon to provide smooth visual transition.
function WeaponViewController.playSwapAnimation(): ()
	if state.isAnimating or not state.currentModel then
		return
	end
	state.isAnimating = true

	-- Lower current weapon off-screen
	local lowerOffset = CFrame.new(0, -SWAP_LOWER_DISTANCE, 0)
	animateOffset(lowerOffset, SWAP_DURATION, Enum.EasingStyle.Quad, function()
		-- The equipWeapon call handles loading the new weapon
		-- After lowering, restore the animating state so equipWeapon can proceed
		state.isAnimating = false
	end)
end

--- Returns the currently equipped weapon ID.
function WeaponViewController.getEquippedWeaponId(): string?
	return state.equippedWeaponId
end

--- Returns whether the view controller is currently animating.
function WeaponViewController.isAnimating(): boolean
	return state.isAnimating
end

--- Cleans up the weapon view (called on player leave or controller teardown).
function WeaponViewController.cleanup(): ()
	detachCurrentModel()
	state.equippedWeaponId = nil
	state.isAnimating = false
end

---------------------------------------------------------------------------
-- Server Event Listeners
---------------------------------------------------------------------------

-- Listen for weapon equip events from the server
local function setupRemoteListeners(): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		-- Remotes folder may not exist yet during early initialization
		remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	end
	if not remotes then
		warn("[WeaponViewController] Remotes folder not found, skipping remote listeners")
		return
	end

	-- Listen for weapon equip events
	local weaponEquipped = remotes:FindFirstChild("WeaponEquipped")
	if weaponEquipped and weaponEquipped:IsA("RemoteEvent") then
		weaponEquipped.OnClientEvent:Connect(function(weaponId: string)
			if state.equippedWeaponId then
				-- Play swap animation before equipping new weapon
				WeaponViewController.playSwapAnimation()
				task.wait(SWAP_DURATION + 0.05)
			end
			WeaponViewController.equipWeapon(weaponId)
		end)
	end

	-- Listen for fire events (to sync animation with combat)
	local weaponFired = remotes:FindFirstChild("WeaponFired")
	if weaponFired and weaponFired:IsA("RemoteEvent") then
		weaponFired.OnClientEvent:Connect(function()
			WeaponViewController.playFireAnimation()
		end)
	end

	-- Listen for reload events
	local weaponReloaded = remotes:FindFirstChild("WeaponReloaded")
	if weaponReloaded and weaponReloaded:IsA("RemoteEvent") then
		weaponReloaded.OnClientEvent:Connect(function()
			WeaponViewController.playReloadAnimation()
		end)
	end

	-- Listen for Mythic kill effect trigger
	local mythicKillEffect = remotes:FindFirstChild("MythicKillEffect")
	if mythicKillEffect and mythicKillEffect:IsA("RemoteEvent") then
		mythicKillEffect.OnClientEvent:Connect(function(victimPosition: Vector3)
			-- Mythic unique kill effect: burst of particles at victim location
			local rarity = if state.equippedWeaponId then getWeaponRarity(state.equippedWeaponId) else nil
			if rarity == "Mythic" then
				local effectPart = Instance.new("Part")
				effectPart.Name = "MythicKillEffect"
				effectPart.Size = Vector3.new(1, 1, 1)
				effectPart.Position = victimPosition
				effectPart.Anchored = true
				effectPart.CanCollide = false
				effectPart.Transparency = 1
				effectPart.Parent = workspace

				local emitter = Instance.new("ParticleEmitter")
				emitter.Rate = 0 -- Burst mode
				emitter.Lifetime = NumberRange.new(0.5, 1.0)
				emitter.Speed = NumberRange.new(5, 10)
				emitter.SpreadAngle = Vector2.new(360, 360)
				emitter.Color = ColorSequence.new(Color3.fromRGB(180, 120, 255))
				emitter.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.5),
					NumberSequenceKeypoint.new(1, 0),
				})
				emitter.LightEmission = 1
				emitter.Parent = effectPart

				-- Emit burst
				emitter:Emit(30)

				-- Cleanup after effect completes
				task.delay(1.5, function()
					effectPart:Destroy()
				end)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------

setupRemoteListeners()

return WeaponViewController
