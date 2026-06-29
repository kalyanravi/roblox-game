--!strict
--[[
	CombatService
	Server-authoritative combat system handling weapon firing, hit detection,
	damage calculation, ammo management, and kill attribution.
	Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 23.1, 23.3
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponDefinitions = require(Shared.Definitions.WeaponDefinitions)
local Constants = require(Shared.Constants)

local Server = ServerScriptService:WaitForChild("Server")
local Systems = Server:WaitForChild("Systems")
local AimAssist = require(Systems:WaitForChild("AimAssist"))

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------

type PlayerCombatState = {
	health: number,
	maxHealth: number,
	equippedWeaponId: string?,
	ammo: number,
	isReloading: boolean,
	ownedWeapons: { string },
}

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local DEFAULT_HEALTH = 100
local HEADSHOT_MULTIPLIER = Constants.HEADSHOT_MULTIPLIER -- 1.5

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

-- Per-player combat state tracked in server memory
local playerStates: { [Player]: PlayerCombatState } = {}

----------------------------------------------------------------------
-- RemoteEvents
----------------------------------------------------------------------

-- Get RemoteEvents from the Remotes folder (created by init.server.luau)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FireWeaponRemote = Remotes:WaitForChild("FireWeapon") :: RemoteEvent
local ReloadWeaponRemote = Remotes:WaitForChild("ReloadWeapon") :: RemoteEvent
local DamageIndicatorRemote = Remotes:WaitForChild("DamageIndicator") :: RemoteEvent

----------------------------------------------------------------------
-- BindableEvent for kill registration (other systems listen to this)
----------------------------------------------------------------------

local KillRegisteredEvent = ReplicatedStorage:WaitForChild("KillRegistered") :: BindableEvent

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local CombatService = {}

--- Initializes combat state for a player when they join.
function CombatService.initPlayer(player: Player): ()
	playerStates[player] = {
		health = DEFAULT_HEALTH,
		maxHealth = DEFAULT_HEALTH,
		equippedWeaponId = nil,
		ammo = 0,
		isReloading = false,
		ownedWeapons = {},
	}
end

--- Cleans up combat state when a player leaves.
function CombatService.removePlayer(player: Player): ()
	playerStates[player] = nil
end

--- Returns the current combat state for a player (or nil if not tracked).
function CombatService.getPlayerState(player: Player): PlayerCombatState?
	return playerStates[player]
end

--- Sets the list of weapons owned by a player (called by DataPersistenceService on load).
function CombatService.setOwnedWeapons(player: Player, weapons: { string }): ()
	local state = playerStates[player]
	if state then
		state.ownedWeapons = weapons
	end
end

--- Equips a weapon for the player, resetting ammo to full magazine.
function CombatService.equipWeapon(player: Player, weaponId: string): boolean
	local state = playerStates[player]
	if not state then
		return false
	end

	-- Verify player owns this weapon
	local owns = false
	for _, id in state.ownedWeapons do
		if id == weaponId then
			owns = true
			break
		end
	end
	if not owns then
		return false
	end

	local weaponDef = WeaponDefinitions.getWeapon(weaponId)
	if not weaponDef then
		return false
	end

	state.equippedWeaponId = weaponId
	state.ammo = weaponDef.magazineSize
	state.isReloading = false
	return true
end

--- Calculates final damage with rarity bonus and headshot multiplier.
--- Formula: baseDamage × (1 + rarityBonus) × headshotMultiplier
function CombatService.calculateDamage(baseDamage: number, rarityTier: string, isHeadshot: boolean): number
	local rarityBonus = WeaponDefinitions.getRarityBonus(rarityTier :: any)
	local headshotMult = if isHeadshot then HEADSHOT_MULTIPLIER else 1.0
	return baseDamage * (1 + rarityBonus) * headshotMult
end

--- Applies damage to target player, handles kill attribution if health reaches 0.
function CombatService.applyDamage(attacker: Player, target: Player, damage: number, weaponId: string): ()
	local targetState = playerStates[target]
	if not targetState then
		return
	end

	-- Don't damage players that are already dead
	if targetState.health <= 0 then
		return
	end

	targetState.health = math.max(0, targetState.health - damage)

	-- Fire DamageIndicator remote to victim for directional damage UI
	local attackerChar = attacker.Character
	if attackerChar then
		local rootPart = attackerChar:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			DamageIndicatorRemote:FireClient(target, rootPart.Position)
		end
	end

	-- Check for kill
	if targetState.health <= 0 then
		-- Determine if it was a headshot for kill registration
		local weaponDef = WeaponDefinitions.getWeapon(weaponId)
		local isHeadshot = false
		if weaponDef then
			-- The headshot flag is passed through the call chain; we check if damage
			-- includes the headshot multiplier by comparing expected values
			local baseWithRarity = weaponDef.damage * (1 + WeaponDefinitions.getRarityBonus(weaponDef.rarity))
			local headshotDamage = baseWithRarity * HEADSHOT_MULTIPLIER
			-- Use tolerance for floating point comparison
			isHeadshot = math.abs(damage - headshotDamage) < 0.01
		end

		CombatService.registerKill(attacker, target, weaponId, isHeadshot)
	end
end

--- Registers a kill event and fires BindableEvent for other systems to listen.
--- Listeners: KillStreakManager, EconomyService, MasterySystem, ProgressionEngine
function CombatService.registerKill(attacker: Player, victim: Player, weaponId: string, isHeadshot: boolean): ()
	-- Fire the BindableEvent so dependent systems can react
	KillRegisteredEvent:Fire(attacker, victim, weaponId, isHeadshot)

	-- Reset victim health (SpawnSystem will handle respawn)
	local victimState = playerStates[victim]
	if victimState then
		victimState.health = 0
	end
end

--- Respawns a player, restoring full health.
function CombatService.respawnPlayer(player: Player): ()
	local state = playerStates[player]
	if state then
		state.health = state.maxHealth
		-- Restore ammo to full magazine
		if state.equippedWeaponId then
			local weaponDef = WeaponDefinitions.getWeapon(state.equippedWeaponId)
			if weaponDef then
				state.ammo = weaponDef.magazineSize
			end
		end
		state.isReloading = false
	end
end

--- Handles a fire request from the client. Performs server-side raycasting.
function CombatService.handleFireRequest(player: Player, aimOrigin: Vector3, aimDirection: Vector3): ()
	local state = playerStates[player]
	if not state then
		print("[CombatService] No state for player, auto-initializing")
		CombatService.initPlayer(player)
		state = playerStates[player]
	end

	-- Validate: must have a weapon equipped (auto-equip ar_standard if nothing equipped)
	local weaponId = state.equippedWeaponId
	if not weaponId then
		-- Auto-equip starter weapon
		state.equippedWeaponId = "ar_standard"
		state.ammo = 30
		state.ownedWeapons = {"ar_standard"}
		weaponId = "ar_standard"
	end

	-- Validate: must not be reloading
	if state.isReloading then
		return
	end

	-- Validate: must have ammo (melee weapons have magazineSize 0, always fire)
	local weaponDef = WeaponDefinitions.getWeapon(weaponId)
	if not weaponDef then
		return
	end

	-- Melee weapons (magazineSize == 0) don't use ammo
	local isMelee = weaponDef.magazineSize == 0
	if not isMelee then
		if state.ammo <= 0 then
			return
		end
		-- Decrement ammo
		state.ammo -= 1
	end

	-- Verify weapon is owned (skip check for starter weapons to avoid race conditions)
	local ownsWeapon = false
	if weaponId == "ar_standard" then
		ownsWeapon = true -- Always allow the starter weapon
	else
		for _, id in state.ownedWeapons do
			if id == weaponId then
				ownsWeapon = true
				break
			end
		end
	end
	if not ownsWeapon then
		print("[CombatService] Player doesn't own weapon:", weaponId)
		return
	end

	-- Apply aim assist for eligible Mobile players (Level 20+)
	local adjustedAimDirection = AimAssist.applyAimAssist(player, aimOrigin, aimDirection)

	-- Perform server-side raycast
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Exclude attacker's character from raycast
	local ignoreList: { Instance } = {}
	if player.Character then
		table.insert(ignoreList, player.Character)
	end
	raycastParams.FilterDescendantsInstances = ignoreList

	local direction = adjustedAimDirection.Unit * weaponDef.range
	local rayResult = workspace:Raycast(aimOrigin, direction, raycastParams)

	-- Create visible bullet tracer (yellow beam) regardless of hit
	local endPos = if rayResult then rayResult.Position else (aimOrigin + direction)
	task.spawn(function()
		local tracer = Instance.new("Part")
		tracer.Name = "BulletTracer"
		tracer.Anchored = true
		tracer.CanCollide = false
		tracer.Material = Enum.Material.Neon
		tracer.BrickColor = BrickColor.new("Bright yellow")
		local dist = (endPos - aimOrigin).Magnitude
		tracer.Size = Vector3.new(0.3, 0.3, dist)
		tracer.CFrame = CFrame.lookAt(aimOrigin, endPos) * CFrame.new(0, 0, -dist / 2)
		tracer.Transparency = 0
		tracer.Parent = workspace
		task.wait(0.3)
		if tracer and tracer.Parent then
			tracer:Destroy()
		end
	end)

	-- Create hit spark effect at impact point
	if rayResult then
		task.spawn(function()
			local spark = Instance.new("Part")
			spark.Name = "HitSpark"
			spark.Anchored = true
			spark.CanCollide = false
			spark.Material = Enum.Material.Neon
			spark.BrickColor = BrickColor.new("Really red")
			spark.Size = Vector3.new(1, 1, 1)
			spark.Shape = Enum.PartType.Ball
			spark.CFrame = CFrame.new(rayResult.Position)
			spark.Transparency = 0
			spark.Parent = workspace
			task.wait(0.4)
			if spark and spark.Parent then
				spark:Destroy()
			end
		end)
	end

	if not rayResult then
		return -- Missed, no hit
	end

	-- Determine if we hit a player character
	local hitPart = rayResult.Instance
	local hitCharacter = hitPart:FindFirstAncestorOfClass("Model")
	if not hitCharacter then
		return
	end

	local hitHumanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
	if not hitHumanoid then
		return
	end

	-- Find the player who owns this character
	local targetPlayer: Player? = Players:GetPlayerFromCharacter(hitCharacter)
	
	-- If it's not a player character, it might be a training dummy — damage it directly
	if not targetPlayer then
		-- Damage non-player humanoids (training dummies, NPCs)
		local damage = CombatService.calculateDamage(weaponDef.damage, weaponDef.rarity, hitPart.Name == "Head")
		hitHumanoid:TakeDamage(damage)
		print("[CombatService] Hit dummy! Damage:", damage, "HP remaining:", hitHumanoid.Health)
		return
	end
	
	if targetPlayer == player then
		return -- Can't damage yourself
	end

	-- Determine if headshot (hit the Head part)
	local isHeadshot = hitPart.Name == "Head"

	-- Calculate damage
	local damage = CombatService.calculateDamage(weaponDef.damage, weaponDef.rarity, isHeadshot)

	-- Apply damage to target
	CombatService.applyDamage(player, targetPlayer, damage, weaponId)
end

--- Handles a reload request from the client.
function CombatService.handleReloadRequest(player: Player): ()
	local state = playerStates[player]
	if not state then
		return
	end

	-- Can't reload if already reloading
	if state.isReloading then
		return
	end

	local weaponId = state.equippedWeaponId
	if not weaponId then
		return
	end

	local weaponDef = WeaponDefinitions.getWeapon(weaponId)
	if not weaponDef then
		return
	end

	-- Melee weapons don't reload
	if weaponDef.magazineSize == 0 then
		return
	end

	-- Don't reload if already at full ammo
	if state.ammo >= weaponDef.magazineSize then
		return
	end

	-- Start reload
	state.isReloading = true

	-- Use task.delay for the reload timer
	task.delay(weaponDef.reloadTime, function()
		-- Verify player still exists and is still reloading this weapon
		local currentState = playerStates[player]
		if currentState and currentState.isReloading and currentState.equippedWeaponId == weaponId then
			currentState.ammo = weaponDef.magazineSize
			currentState.isReloading = false
		end
	end)
end

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

-- Wire FireWeapon remote
FireWeaponRemote.OnServerEvent:Connect(function(player: Player, aimOrigin: any, aimDirection: any)
	-- Type validation
	if typeof(aimOrigin) ~= "Vector3" or typeof(aimDirection) ~= "Vector3" then
		warn("[CombatService] Invalid fire args from", player.Name)
		return
	end
	print("[CombatService] Fire received from", player.Name)
	CombatService.handleFireRequest(player, aimOrigin, aimDirection)
end)

-- Wire ReloadWeapon remote
ReloadWeaponRemote.OnServerEvent:Connect(function(player: Player)
	CombatService.handleReloadRequest(player)
end)

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player: Player)
	CombatService.initPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	CombatService.removePlayer(player)
end)

-- Initialize any players already in the game (for late script loading)
for _, player in Players:GetPlayers() do
	if not playerStates[player] then
		CombatService.initPlayer(player)
	end
end

----------------------------------------------------------------------

return CombatService
