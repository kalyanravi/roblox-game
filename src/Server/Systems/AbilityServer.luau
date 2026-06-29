--!strict
--[[
	AbilityServer
	Server-authoritative ability system handling ability activation, cooldown tracking,
	equipped ability management, and effect execution.
	Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbilityDefinitions = require(Shared.Definitions.AbilityDefinitions)
local Constants = require(Shared.Constants)

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------

type AbilityDefinition = {
	id: string,
	name: string,
	cost: number,
	cooldown: number,
	effect: string,
	params: {
		speedMultiplier: number?,
		duration: number?,
		healPercent: number?,
		maxRange: number?,
		speed: number?,
		damageAbsorb: number?,
	},
}

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local MAX_ABILITIES_EQUIPPED = Constants.MAX_ABILITIES_EQUIPPED -- 2

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

-- Per-player cooldown tracking: playerCooldowns[player][abilityId] = lastActivationTime
local playerCooldowns: { [Player]: { [string]: number } } = {}

-- Per-player equipped abilities: playerEquipped[player] = { slot1Id?, slot2Id? }
local playerEquipped: { [Player]: { string? } } = {}

-- Per-player owned abilities: playerOwned[player] = { abilityId, ... }
local playerOwned: { [Player]: { string } } = {}

----------------------------------------------------------------------
-- RemoteEvents
----------------------------------------------------------------------

local function getOrCreateRemoteEvent(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing :: RemoteEvent
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local ActivateAbilityRemote = getOrCreateRemoteEvent("ActivateAbility")
local AbilityCooldownRemote = getOrCreateRemoteEvent("AbilityCooldown")

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local AbilityServer = {}

--- Initializes ability state for a player when they join.
function AbilityServer.initPlayer(player: Player): ()
	playerCooldowns[player] = {}
	playerEquipped[player] = { nil, nil }
	playerOwned[player] = {}
end

--- Cleans up ability state when a player leaves.
function AbilityServer.removePlayer(player: Player): ()
	playerCooldowns[player] = nil
	playerEquipped[player] = nil
	playerOwned[player] = nil
end

--- Sets owned abilities for a player (called by DataPersistenceService on load).
function AbilityServer.setOwnedAbilities(player: Player, abilities: { string }): ()
	playerOwned[player] = abilities
end

--- Sets equipped abilities for a player (called by DataPersistenceService on load).
--- Expects an array of up to 2 ability IDs (or nil for empty slots).
function AbilityServer.setEquippedAbilities(player: Player, abilities: { string? }): ()
	local equipped: { string? } = { nil, nil }
	for i = 1, math.min(#abilities, MAX_ABILITIES_EQUIPPED) do
		equipped[i] = abilities[i]
	end
	playerEquipped[player] = equipped
end

--- Returns the equipped abilities for a player (max 2 slots).
function AbilityServer.getEquippedAbilities(player: Player): { string? }
	return playerEquipped[player] or { nil, nil }
end

--- Checks if an ability is on cooldown for a player.
--- Returns (isOnCooldown, remainingTime?)
function AbilityServer.isOnCooldown(player: Player, abilityId: string): (boolean, number?)
	local cooldowns = playerCooldowns[player]
	if not cooldowns then
		return false, nil
	end

	local lastActivation = cooldowns[abilityId]
	if not lastActivation then
		return false, nil
	end

	-- Look up the ability definition to get its cooldown duration
	local abilityDef = AbilityServer._getDefinitionById(abilityId)
	if not abilityDef then
		return false, nil
	end

	local elapsed = os.clock() - lastActivation
	local remaining = abilityDef.cooldown - elapsed

	if remaining > 0 then
		return true, remaining
	end

	return false, nil
end

--- Activates an ability from the player's equipped slot.
--- Returns true if activation succeeded, false otherwise.
function AbilityServer.activateAbility(player: Player, slotIndex: number): boolean
	-- Validate slot index (must be 1 or 2)
	if slotIndex ~= 1 and slotIndex ~= 2 then
		return false
	end

	-- Get equipped abilities for this player
	local equipped = playerEquipped[player]
	if not equipped then
		return false
	end

	-- Must have an ability in that slot
	local abilityId = equipped[slotIndex]
	if not abilityId then
		return false
	end

	-- Validate the player owns this ability
	local owned = playerOwned[player]
	if not owned then
		return false
	end
	local ownsAbility = false
	for _, id in owned do
		if id == abilityId then
			ownsAbility = true
			break
		end
	end
	if not ownsAbility then
		return false
	end

	-- Check cooldown
	local onCooldown, remainingTime = AbilityServer.isOnCooldown(player, abilityId)
	if onCooldown then
		-- Notify client of remaining cooldown
		AbilityCooldownRemote:FireClient(player, slotIndex, remainingTime)
		return false
	end

	-- Look up the ability definition
	local abilityDef = AbilityServer._getDefinitionById(abilityId)
	if not abilityDef then
		return false
	end

	-- Start cooldown timer using os.clock()
	local cooldowns = playerCooldowns[player]
	if cooldowns then
		cooldowns[abilityId] = os.clock()
	end

	-- Execute the ability effect
	AbilityServer.applyEffect(player, abilityDef)

	-- Fire cooldown remote to client with the full cooldown duration
	AbilityCooldownRemote:FireClient(player, slotIndex, abilityDef.cooldown)

	return true
end

--- Executes the ability effect on the player.
function AbilityServer.applyEffect(player: Player, ability: AbilityDefinition): ()
	local effect = ability.effect
	local params = ability.params

	if effect == "dash" then
		AbilityServer._applyDash(player, params)
	elseif effect == "heal" then
		AbilityServer._applyHeal(player, params)
	elseif effect == "grapple" then
		AbilityServer._applyGrapple(player, params)
	elseif effect == "shield" then
		AbilityServer._applyShield(player, params)
	elseif effect == "speedboost" then
		AbilityServer._applySpeedBoost(player, params)
	end
end

----------------------------------------------------------------------
-- Effect Implementations
----------------------------------------------------------------------

--- Dash: Burst of speed in movement direction for 0.3s using BodyVelocity.
function AbilityServer._applyDash(player: Player, params: any): ()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local speedMultiplier = params.speedMultiplier or 3
	local duration = params.duration or 0.3

	-- Get the movement direction (use look vector if not moving)
	local moveDirection = humanoid.MoveDirection
	if moveDirection.Magnitude < 0.1 then
		moveDirection = rootPart.CFrame.LookVector
	end

	-- Create a BodyVelocity for the burst of speed
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, 0, math.huge)
	bodyVelocity.Velocity = moveDirection.Unit * humanoid.WalkSpeed * speedMultiplier
	bodyVelocity.Parent = rootPart

	-- Remove after duration
	task.delay(duration, function()
		if bodyVelocity and bodyVelocity.Parent then
			bodyVelocity:Destroy()
		end
	end)
end

--- Heal: Restores 30% health over 3 seconds using task.spawn loop.
function AbilityServer._applyHeal(player: Player, params: any): ()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local healPercent = params.healPercent or 0.3
	local duration = params.duration or 3

	local totalHeal = humanoid.MaxHealth * healPercent
	local tickInterval = 0.25 -- heal every 0.25 seconds
	local ticks = math.floor(duration / tickInterval)
	local healPerTick = totalHeal / ticks

	task.spawn(function()
		for _ = 1, ticks do
			-- Check if character/humanoid still exists
			if not character.Parent or not humanoid.Parent then
				break
			end
			if humanoid.Health <= 0 then
				break
			end

			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + healPerTick)
			task.wait(tickInterval)
		end
	end)
end

--- Grapple: BodyPosition toward aimed surface (up to 100 stud range).
function AbilityServer._applyGrapple(player: Player, params: any): ()
	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local maxRange = params.maxRange or 100
	local speed = params.speed or 80

	-- Raycast in look direction to find a surface
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local lookDirection = rootPart.CFrame.LookVector
	local rayResult = workspace:Raycast(rootPart.Position, lookDirection * maxRange, raycastParams)

	if not rayResult then
		return -- No surface in range
	end

	local targetPosition = rayResult.Position

	-- Create a BodyPosition to pull player toward the surface
	local bodyPosition = Instance.new("BodyPosition")
	bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyPosition.D = 500
	bodyPosition.P = speed * 100
	bodyPosition.Position = targetPosition
	bodyPosition.Parent = rootPart

	-- Calculate travel time based on distance and speed
	local distance = (targetPosition - rootPart.Position).Magnitude
	local travelTime = math.min(distance / speed, 2) -- cap at 2 seconds max

	-- Remove BodyPosition after travel time or when close enough
	task.spawn(function()
		local startTime = os.clock()
		while os.clock() - startTime < travelTime do
			if not rootPart.Parent then
				break
			end
			local currentDist = (targetPosition - rootPart.Position).Magnitude
			if currentDist < 5 then
				break
			end
			task.wait(0.05)
		end

		if bodyPosition and bodyPosition.Parent then
			bodyPosition:Destroy()
		end
	end)
end

--- Shield: Temporary ForceField or damage absorption (50 HP buffer) for 5 seconds.
function AbilityServer._applyShield(player: Player, params: any): ()
	local character = player.Character
	if not character then
		return
	end

	local damageAbsorb = params.damageAbsorb or 50
	local duration = params.duration or 5

	-- Use ForceField for visual feedback
	local forceField = Instance.new("ForceField")
	forceField.Name = "AbilityShield"
	forceField.Visible = true
	forceField.Parent = character

	-- Also grant temporary extra health as a damage buffer
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Add absorb HP on top of current health (capped at max + absorb)
		local originalMaxHealth = humanoid.MaxHealth
		humanoid.MaxHealth = originalMaxHealth + damageAbsorb
		humanoid.Health = humanoid.Health + damageAbsorb

		-- Remove shield after duration
		task.delay(duration, function()
			if forceField and forceField.Parent then
				forceField:Destroy()
			end

			-- Restore original max health; clamp current health
			if humanoid and humanoid.Parent then
				humanoid.MaxHealth = originalMaxHealth
				if humanoid.Health > originalMaxHealth then
					humanoid.Health = originalMaxHealth
				end
			end
		end)
	else
		-- No humanoid, just remove ForceField after duration
		task.delay(duration, function()
			if forceField and forceField.Parent then
				forceField:Destroy()
			end
		end)
	end
end

--- SpeedBoost: 50% move speed increase for 3 seconds.
function AbilityServer._applySpeedBoost(player: Player, params: any): ()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local speedMultiplier = params.speedMultiplier or 1.5
	local duration = params.duration or 3

	local originalSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = originalSpeed * speedMultiplier

	-- Restore after duration
	task.delay(duration, function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = originalSpeed
		end
	end)
end

----------------------------------------------------------------------
-- Internal Helpers
----------------------------------------------------------------------

--- Looks up an AbilityDefinition by its id field.
function AbilityServer._getDefinitionById(abilityId: string): AbilityDefinition?
	for _, def in AbilityDefinitions :: any do
		if def.id == abilityId then
			return def :: AbilityDefinition
		end
	end
	return nil
end

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

-- Wire ActivateAbility remote with server validation
ActivateAbilityRemote.OnServerEvent:Connect(function(player: Player, slotIndex: any)
	-- Type validation: slotIndex must be a number
	if type(slotIndex) ~= "number" then
		return
	end

	-- Validate slot index must be 1 or 2
	if slotIndex ~= 1 and slotIndex ~= 2 then
		return
	end

	AbilityServer.activateAbility(player, slotIndex)
end)

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player: Player)
	AbilityServer.initPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	AbilityServer.removePlayer(player)
end)

-- Initialize any players already in the game (for late script loading)
for _, player in Players:GetPlayers() do
	if not playerCooldowns[player] then
		AbilityServer.initPlayer(player)
	end
end

----------------------------------------------------------------------

return AbilityServer
