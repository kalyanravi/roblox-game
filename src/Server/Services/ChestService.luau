--!strict
--[[
	ChestService
	Server-authoritative playtime chest system. Tracks active match playtime per player,
	awards tiered chests (Bronze/Silver/Gold) at thresholds, generates randomized rewards,
	and handles duplicate item conversion.
	Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChestDefinitions = require(Shared.Definitions.ChestDefinitions)
local WeaponDefinitions = require(Shared.Definitions.WeaponDefinitions)
local Constants = require(Shared.Constants)

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------

type ChestTier = "Bronze" | "Silver" | "Gold"

type ChestReward = {
	items: { string },
	coins: number,
	gems: number,
}

type PlaytimeState = {
	currentMinutes: number, -- accumulated playtime in current cycle
	paused: boolean, -- true when AFK system has paused tracking
}

type PlaytimeProgress = {
	current: number,
	nextChestMinutes: number,
	nextChestTier: string,
}

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local BRONZE_MINUTES = Constants.CHEST_BRONZE_MINUTES -- 30
local SILVER_MINUTES = Constants.CHEST_SILVER_MINUTES -- 60
local GOLD_MINUTES = Constants.CHEST_GOLD_MINUTES -- 120

-- Ordered chest thresholds for determining next chest tier
local CHEST_THRESHOLDS: { { tier: ChestTier, minutes: number } } = {
	{ tier = "Bronze", minutes = BRONZE_MINUTES },
	{ tier = "Silver", minutes = SILVER_MINUTES },
	{ tier = "Gold", minutes = GOLD_MINUTES },
}

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

-- Per-player playtime tracking (server-side only, requirement 9.4)
local playtimeStates: { [Player]: PlaytimeState } = {}

-- Per-player inventory for duplicate detection (set by external systems)
local playerInventories: { [Player]: { string } } = {}

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

local ChestAwardedRemote = getOrCreateRemoteEvent("ChestAwarded")

----------------------------------------------------------------------
-- Internal Helpers
----------------------------------------------------------------------

--- Gets the chest definition for a given tier.
local function getChestDefinition(tier: ChestTier): typeof(ChestDefinitions[1])?
	for _, def in ChestDefinitions do
		if def.tier == tier then
			return def
		end
	end
	return nil
end

--- Determines which chest tier (if any) was just reached given playtime.
--- Returns the tier if a threshold was crossed, nil otherwise.
local function checkThreshold(previousMinutes: number, currentMinutes: number): ChestTier?
	for _, threshold in CHEST_THRESHOLDS do
		if previousMinutes < threshold.minutes and currentMinutes >= threshold.minutes then
			return threshold.tier
		end
	end
	return nil
end

--- Gets weapons from the appropriate rarity pool for reward selection.
local function getWeaponsForRarities(rarities: { string }): { string }
	local weaponIds: { string } = {}
	for _, rarity in rarities do
		local weapons = WeaponDefinitions.getWeaponsByRarity(rarity :: any)
		for _, weapon in weapons do
			table.insert(weaponIds, weapon.id)
		end
	end
	return weaponIds
end

--- Checks if a player already owns a given item.
local function playerOwnsItem(player: Player, itemId: string): boolean
	local inventory = playerInventories[player]
	if not inventory then
		return false
	end
	for _, id in inventory do
		if id == itemId then
			return true
		end
	end
	return false
end

--- Gets the coin cost of a weapon (for duplicate conversion).
local function getWeaponCoinValue(weaponId: string): number
	local weapon = WeaponDefinitions.getWeapon(weaponId)
	if not weapon or not weapon.cost then
		-- Free weapons have no cost, give a default value
		return 50
	end
	-- If the weapon costs gems, convert based on gem value
	if weapon.cost.currency == "gems" then
		-- Gem weapons: use gem amount × a coin conversion (use amount directly as coins)
		return weapon.cost.amount
	end
	return weapon.cost.amount
end

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local ChestService = {}

--- Initializes playtime state for a player when they join.
function ChestService.initPlayer(player: Player): ()
	playtimeStates[player] = {
		currentMinutes = 0,
		paused = false,
	}
	playerInventories[player] = {}
end

--- Cleans up playtime state when a player leaves.
function ChestService.removePlayer(player: Player): ()
	playtimeStates[player] = nil
	playerInventories[player] = nil
end

--- Sets the player's owned items inventory (called by DataPersistenceService on load).
function ChestService.setPlayerInventory(player: Player, ownedWeapons: { string }): ()
	playerInventories[player] = ownedWeapons
end

--- Increments playtime for a player. Returns the chest tier if a threshold was hit.
--- After awarding a chest, resets the playtime counter for the next cycle.
--- @param player — the player whose playtime to update
--- @param deltaMinutes — number of minutes to add
--- @return ChestTier? — "Bronze", "Silver", or "Gold" if a chest was earned, nil otherwise
function ChestService.updatePlaytime(player: Player, deltaMinutes: number): string?
	local state = playtimeStates[player]
	if not state then
		return nil
	end

	-- Don't accumulate if paused (AFK)
	if state.paused then
		return nil
	end

	local previousMinutes = state.currentMinutes
	state.currentMinutes = state.currentMinutes + deltaMinutes

	-- Check if any threshold was crossed
	local tier = checkThreshold(previousMinutes, state.currentMinutes)
	if tier then
		-- Award the chest
		local rewards = ChestService.generateRewards(player, tier)

		-- Reset playtime counter for the next cycle after the awarded tier
		-- After Gold (120 min), reset completely. Otherwise reset after current tier threshold.
		local chestDef = getChestDefinition(tier)
		if chestDef then
			state.currentMinutes = state.currentMinutes - chestDef.minutes
		end

		-- Fire remote to client for opening animation (requirement 9.7)
		ChestAwardedRemote:FireClient(player, tier, rewards)

		return tier
	end

	return nil
end

--- Generates rewards for a given chest tier. Selects items from appropriate
--- rarity pools and handles duplicate conversion.
--- @param player — the player receiving the chest
--- @param tier — "Bronze", "Silver", or "Gold"
--- @return ChestReward — table with items, coins, and gems
function ChestService.generateRewards(player: Player, tier: string): ChestReward
	local chestDef = getChestDefinition(tier :: ChestTier)
	if not chestDef then
		-- Fallback if tier is invalid
		return { items = {}, coins = 0, gems = 0 }
	end

	local rewards: ChestReward = {
		items = {},
		coins = chestDef.rewards.coins,
		gems = chestDef.rewards.gems,
	}

	-- Select random items from the appropriate rarity pool
	local availableWeapons = getWeaponsForRarities(chestDef.rewards.itemRarities)

	for _ = 1, chestDef.rewards.itemCount do
		if #availableWeapons > 0 then
			local randomIndex = math.random(1, #availableWeapons)
			local selectedWeaponId = availableWeapons[randomIndex]

			-- Check for duplicate (requirement 9.5)
			if playerOwnsItem(player, selectedWeaponId) then
				local coinValue = ChestService.handleDuplicate(player, selectedWeaponId)
				rewards.coins = rewards.coins + coinValue
			else
				table.insert(rewards.items, selectedWeaponId)
			end
		end
	end

	return rewards
end

--- Handles a duplicate item by returning the coin equivalent (weapon's purchase price).
--- @param player — the player who received the duplicate
--- @param itemId — the weapon ID that is already owned
--- @return number — coin value equivalent to the weapon's cost
function ChestService.handleDuplicate(_player: Player, itemId: string): number
	return getWeaponCoinValue(itemId)
end

--- Returns the player's current playtime progress toward the next chest.
--- @param player — the player to query
--- @return PlaytimeProgress — current minutes, next threshold, and next tier
function ChestService.getPlaytimeProgress(player: Player): PlaytimeProgress
	local state = playtimeStates[player]
	if not state then
		return {
			current = 0,
			nextChestMinutes = BRONZE_MINUTES,
			nextChestTier = "Bronze",
		}
	end

	-- Find the next chest the player hasn't reached yet in this cycle
	for _, threshold in CHEST_THRESHOLDS do
		if state.currentMinutes < threshold.minutes then
			return {
				current = state.currentMinutes,
				nextChestMinutes = threshold.minutes,
				nextChestTier = threshold.tier,
			}
		end
	end

	-- If past all thresholds (shouldn't happen due to reset), default to Bronze cycle
	return {
		current = state.currentMinutes,
		nextChestMinutes = BRONZE_MINUTES,
		nextChestTier = "Bronze",
	}
end

--- Pauses playtime tracking for a player (called by AFK system).
function ChestService.pausePlaytime(player: Player): ()
	local state = playtimeStates[player]
	if state then
		state.paused = true
	end
end

--- Resumes playtime tracking for a player (called when AFK ends).
function ChestService.resumePlaytime(player: Player): ()
	local state = playtimeStates[player]
	if state then
		state.paused = false
	end
end

--- Returns whether playtime is currently paused for a player.
function ChestService.isPaused(player: Player): boolean
	local state = playtimeStates[player]
	if state then
		return state.paused
	end
	return false
end

--- Returns the raw playtime state (for data persistence).
function ChestService.getPlaytimeMinutes(player: Player): number
	local state = playtimeStates[player]
	if state then
		return state.currentMinutes
	end
	return 0
end

--- Sets the playtime from loaded data (called by DataPersistenceService on load).
function ChestService.setPlaytimeMinutes(player: Player, minutes: number): ()
	local state = playtimeStates[player]
	if state then
		state.currentMinutes = minutes
	end
end

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player: Player)
	ChestService.initPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	ChestService.removePlayer(player)
end)

-- Initialize any players already in the game (for late script loading)
for _, player in Players:GetPlayers() do
	if not playtimeStates[player] then
		ChestService.initPlayer(player)
	end
end

----------------------------------------------------------------------

return ChestService
