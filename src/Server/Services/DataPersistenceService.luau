--!strict
--[[
	DataPersistenceService
	Handles all DataStore operations for player save data with retry logic,
	auto-save, and player lifecycle management (load on join, save on leave).
	Requirements: 24.1, 24.2, 24.3, 24.4, 24.5, 24.6
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

----------------------------------------------------------------------
-- Service References (loaded lazily to avoid circular require issues)
----------------------------------------------------------------------

local CombatService: any = nil
local EconomyService: any = nil
local ChestService: any = nil
local MasteryService: any = nil
local ProgressionService: any = nil
local AbilityServer: any = nil

local function getServices()
	if CombatService then return end
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local Services = Server:WaitForChild("Services")
	local Systems = Server:WaitForChild("Systems")

	CombatService = require(Services:WaitForChild("CombatService"))
	EconomyService = require(Services:WaitForChild("EconomyService"))
	ChestService = require(Services:WaitForChild("ChestService"))
	MasteryService = require(Services:WaitForChild("MasteryService"))
	ProgressionService = require(Services:WaitForChild("ProgressionService"))
	AbilityServer = require(Systems:WaitForChild("AbilityServer"))
end

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------

type LoadoutData = {
	primaryWeapon: string,
	secondaryWeapon: string,
	meleeWeapon: string,
	abilities: { string },
	finisher: string,
	emotes: { string },
}

type PlayerSettings = {
	sensitivity: number,
	crosshair: {
		shape: string,
		color: { number },
		size: number,
		opacity: number,
	},
	audio: {
		master: number,
		sfx: number,
		music: number,
		voice: number,
	},
	keybinds: { [string]: string },
	mobileOnlyMatchmaking: boolean,
}

type PlayerSaveData = {
	coins: number,
	gems: number,
	ownedWeapons: { string },
	ownedAbilities: { string },
	ownedEmotes: { string },
	ownedFinishers: { string },
	ownedCamos: { string },
	ownedSkins: { string },
	equippedLoadout: LoadoutData,
	level: number,
	xp: number,
	prestige: number,
	masteryKills: { [string]: number },
	settings: PlayerSettings,
	playtimeMinutes: number,
	chestPlaytime: number,
	loginStreak: number,
	lastLoginDate: string,
	dailyCycleDay: number,
	totalKills: number,
	totalDeaths: number,
	totalWins: number,
	totalMatches: number,
}

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local AUTO_SAVE_INTERVAL = Constants.AUTO_SAVE_INTERVAL -- 300 seconds
local MAX_DATASTORE_RETRIES = Constants.MAX_DATASTORE_RETRIES -- 3

local DATASTORE_NAME = "ShardstrikePlayerData"
local KEY_PREFIX = "Player_"

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local playerDataStore = DataStoreService:GetDataStore(DATASTORE_NAME)

-- Cached player data in memory (loaded on join, updated in real-time by other services)
local playerDataCache: { [Player]: PlayerSaveData } = {}

-- Per-player connections that need to be disconnected on leave
local playerConnections: { [Player]: { RBXScriptConnection } } = {}

----------------------------------------------------------------------
-- Default Data
----------------------------------------------------------------------

--- Returns a fresh default PlayerSaveData for new players.
local function getDefaultData(): PlayerSaveData
	return {
		coins = 0,
		gems = 0,
		ownedWeapons = {
			"ar_standard",
			"sg_pump",
			"sniper_bolt",
			"rev_sixshooter",
			"dp_twin",
			"rl_basic",
			"cb_hunter",
			"lmg_standard",
			"melee_knife",
			"melee_fists",
			"melee_scythe",
		},
		ownedAbilities = { "dash" },
		ownedEmotes = {},
		ownedFinishers = {},
		ownedCamos = {},
		ownedSkins = {},
		equippedLoadout = {
			primaryWeapon = "ar_standard",
			secondaryWeapon = "rev_sixshooter",
			meleeWeapon = "melee_knife",
			abilities = { "dash" },
			finisher = "",
			emotes = {},
		},
		level = 1,
		xp = 0,
		prestige = 0,
		masteryKills = {},
		settings = {
			sensitivity = 1.0,
			crosshair = {
				shape = "cross",
				color = { 1, 1, 1 },
				size = 1,
				opacity = 1,
			},
			audio = {
				master = 1,
				sfx = 1,
				music = 1,
				voice = 1,
			},
			keybinds = {},
			mobileOnlyMatchmaking = false,
		},
		playtimeMinutes = 0,
		chestPlaytime = 0,
		loginStreak = 0,
		lastLoginDate = "",
		dailyCycleDay = 1,
		totalKills = 0,
		totalDeaths = 0,
		totalWins = 0,
		totalMatches = 0,
	}
end

----------------------------------------------------------------------
-- Internal Helpers
----------------------------------------------------------------------

--- Generates the DataStore key for a player.
local function getPlayerKey(player: Player): string
	return KEY_PREFIX .. tostring(player.UserId)
end

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local DataPersistenceService = {}

--- Retries a DataStore SetAsync operation with exponential backoff.
--- Returns true if save succeeded within MAX_DATASTORE_RETRIES attempts.
function DataPersistenceService.retryWithBackoff(key: string, data: PlayerSaveData, attempt: number): boolean
	if attempt > MAX_DATASTORE_RETRIES then
		return false
	end

	local success, err = pcall(function()
		playerDataStore:SetAsync(key, data)
	end)

	if success then
		return true
	end

	warn("[DataPersistenceService] Save failed for key '" .. key .. "' (attempt " .. tostring(attempt) .. "): " .. tostring(err))

	-- Exponential backoff: 2^attempt seconds
	local delay = math.pow(2, attempt)
	task.wait(delay)

	return DataPersistenceService.retryWithBackoff(key, data, attempt + 1)
end

--- Loads player data from DataStore with retry on failure (up to 3 retries).
--- Returns nil only if all retries fail (caller should use default data).
function DataPersistenceService.loadPlayerData(player: Player): PlayerSaveData?
	local key = getPlayerKey(player)
	local data: PlayerSaveData? = nil

	for attempt = 1, MAX_DATASTORE_RETRIES do
		local success, result = pcall(function()
			return playerDataStore:GetAsync(key)
		end)

		if success then
			if result ~= nil then
				data = result :: PlayerSaveData
			end
			-- nil result means new player (no data stored yet)
			return data
		end

		warn("[DataPersistenceService] Load failed for key '" .. key .. "' (attempt " .. tostring(attempt) .. "): " .. tostring(result))

		if attempt < MAX_DATASTORE_RETRIES then
			local delay = math.pow(2, attempt)
			task.wait(delay)
		end
	end

	-- All retries exhausted
	return nil
end

--- Saves the current player state to DataStore.
--- Collects state from all services and persists as a single blob.
--- Returns true on success, false on failure.
function DataPersistenceService.savePlayerData(player: Player): boolean
	getServices()
	local cachedData = playerDataCache[player]
	if not cachedData then
		return false
	end

	-- Collect current state from all services
	local coins, gems = EconomyService.getBalance(player)
	cachedData.coins = coins
	cachedData.gems = gems

	local inventory = EconomyService.getInventory(player)
	if inventory then
		cachedData.ownedWeapons = inventory.weapons
		cachedData.ownedAbilities = inventory.abilities
		cachedData.ownedEmotes = inventory.emotes
		cachedData.ownedFinishers = inventory.finishers
	end

	cachedData.masteryKills = MasteryService.getMasteryProgress(player)
	cachedData.playtimeMinutes = ChestService.getPlaytimeMinutes(player)

	cachedData.level = ProgressionService.getLevel(player)
	cachedData.xp = ProgressionService.getXP(player)
	cachedData.prestige = ProgressionService.getPrestige(player)

	-- Save to DataStore with retry
	local key = getPlayerKey(player)
	local success = DataPersistenceService.retryWithBackoff(key, cachedData, 1)

	if not success then
		warn("[DataPersistenceService] Failed to save data for " .. player.Name .. " after " .. tostring(MAX_DATASTORE_RETRIES) .. " retries.")
	end

	return success
end

--- Distributes loaded data to all dependent services.
local function distributeDataToServices(player: Player, data: PlayerSaveData): ()
	getServices()
	-- Economy: set balance and inventory
	EconomyService.setBalance(player, data.coins, data.gems)
	EconomyService.setInventory(player, {
		weapons = data.ownedWeapons,
		abilities = data.ownedAbilities,
		emotes = data.ownedEmotes,
		finishers = data.ownedFinishers,
	})

	-- Combat: set owned weapons
	CombatService.setOwnedWeapons(player, data.ownedWeapons)

	-- Abilities: set owned and equipped
	AbilityServer.setOwnedAbilities(player, data.ownedAbilities)
	AbilityServer.setEquippedAbilities(player, data.equippedLoadout.abilities)

	-- Progression: set level, XP, prestige
	ProgressionService.setProgression(player, data.level, data.xp, data.prestige)

	-- Mastery: set kill counts
	MasteryService.setMasteryData(player, data.masteryKills)

	-- Chest: set playtime
	ChestService.setPlaytimeMinutes(player, data.chestPlaytime)
end

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

--- Handles player joining: loads data, distributes to services.
local function onPlayerAdded(player: Player): ()
	-- Disconnect any lingering connections from a previous session (Req 24.5)
	local existingConnections = playerConnections[player]
	if existingConnections then
		for _, connection in existingConnections do
			connection:Disconnect()
		end
		playerConnections[player] = nil
	end

	-- Initialize connections table for this player
	playerConnections[player] = {}

	-- Load player data from DataStore
	local loadedData = DataPersistenceService.loadPlayerData(player)

	-- Check if player left while we were loading
	if not player:IsDescendantOf(Players) then
		playerConnections[player] = nil
		return
	end

	local data: PlayerSaveData
	if loadedData then
		data = loadedData
	else
		-- Load failed after retries or new player: use default data
		data = getDefaultData()
		warn("[DataPersistenceService] Using default data for " .. player.Name .. " (load failed or new player)")
	end

	-- Cache the data
	playerDataCache[player] = data

	-- Distribute to all services
	distributeDataToServices(player, data)
end

--- Handles player leaving: collects state, saves, disconnects listeners.
local function onPlayerRemoving(player: Player): ()
	-- Save player data
	local saveSuccess = DataPersistenceService.savePlayerData(player)

	if not saveSuccess then
		warn("[DataPersistenceService] Data may not have been saved for " .. player.Name)
	end

	-- Disconnect all event listeners for this player (Req 24.5, 24.6)
	local connections = playerConnections[player]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
	end

	-- Clean up cached data
	playerDataCache[player] = nil
	playerConnections[player] = nil
end

----------------------------------------------------------------------
-- Auto-Save
----------------------------------------------------------------------

--- Periodic auto-save for all connected players (every AUTO_SAVE_INTERVAL seconds).
local function autoSaveLoop(): ()
	while true do
		task.wait(AUTO_SAVE_INTERVAL)

		for _, player in Players:GetPlayers() do
			-- Only save if we have cached data for this player
			if playerDataCache[player] then
				task.spawn(function()
					local success = DataPersistenceService.savePlayerData(player)
					if not success then
						warn("[DataPersistenceService] Auto-save failed for " .. player.Name)
					end
				end)
			end
		end
	end
end

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player: Player)
	onPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	onPlayerRemoving(player)
end)

-- Handle server shutdown: save all players before close
game:BindToClose(function()
	local threads: { thread } = {}

	for _, player in Players:GetPlayers() do
		if playerDataCache[player] then
			local thread = task.spawn(function()
				DataPersistenceService.savePlayerData(player)
			end)
			table.insert(threads, thread)
		end
	end

	-- Wait briefly for saves to complete (BindToClose has ~30s on Roblox)
	task.wait(5)
end)

-- Initialize auto-save loop in a separate thread
task.spawn(autoSaveLoop)

-- Handle any players already in the game (for late script loading)
for _, player in Players:GetPlayers() do
	if not playerDataCache[player] then
		task.spawn(function()
			onPlayerAdded(player)
		end)
	end
end

----------------------------------------------------------------------

return DataPersistenceService
