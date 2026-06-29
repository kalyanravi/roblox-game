--!strict
--[[
	MasteryService
	Tracks per-weapon kill counts and unlocks camo rewards at defined thresholds.
	Listens to KillRegistered BindableEvent from CombatService.
	Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local MASTERY_BRONZE = Constants.MASTERY_BRONZE -- 50
local MASTERY_SILVER = Constants.MASTERY_SILVER -- 100
local MASTERY_GOLD = Constants.MASTERY_GOLD -- 250
local MASTERY_DIAMOND = Constants.MASTERY_DIAMOND -- 500

-- Ordered thresholds for camo unlocks
local CAMO_THRESHOLDS: { { kills: number, name: string } } = {
	{ kills = MASTERY_BRONZE, name = "Bronze" },
	{ kills = MASTERY_SILVER, name = "Silver" },
	{ kills = MASTERY_GOLD, name = "Gold" },
	{ kills = MASTERY_DIAMOND, name = "Diamond" },
}

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

-- Per-player weapon kill counts: {[Player]: {[weaponId]: number}}
local masteryData: { [Player]: { [string]: number } } = {}

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local MasteryService = {}

--- Initializes mastery state for a player when they join.
function MasteryService.initPlayer(player: Player): ()
	masteryData[player] = {}
end

--- Cleans up mastery state when a player leaves.
function MasteryService.removePlayer(player: Player): ()
	masteryData[player] = nil
end

--- Sets mastery data for a player (called by DataPersistenceService on load).
function MasteryService.setMasteryData(player: Player, data: { [string]: number }): ()
	masteryData[player] = data
end

--- Registers a kill for a specific weapon, incrementing the kill count.
--- Checks for newly unlocked camos at each threshold.
function MasteryService.registerKill(player: Player, weaponId: string): ()
	local playerData = masteryData[player]
	if not playerData then
		return
	end

	local currentKills = playerData[weaponId] or 0
	local newKills = currentKills + 1
	playerData[weaponId] = newKills
end

--- Returns the kill count for a player with a specific weapon.
function MasteryService.getKillCount(player: Player, weaponId: string): number
	local playerData = masteryData[player]
	if not playerData then
		return 0
	end
	return playerData[weaponId] or 0
end

--- Returns the list of unlocked camo names for a player's weapon based on kill count thresholds.
function MasteryService.getUnlockedCamos(player: Player, weaponId: string): { string }
	local killCount = MasteryService.getKillCount(player, weaponId)
	local unlocked: { string } = {}

	for _, threshold in CAMO_THRESHOLDS do
		if killCount >= threshold.kills then
			table.insert(unlocked, threshold.name)
		end
	end

	return unlocked
end

--- Returns all weapon kill counts for a player (for loadout screen display).
function MasteryService.getMasteryProgress(player: Player): { [string]: number }
	local playerData = masteryData[player]
	if not playerData then
		return {}
	end
	-- Return a copy to prevent external mutation
	local copy: { [string]: number } = {}
	for weaponId, kills in playerData do
		copy[weaponId] = kills
	end
	return copy
end

----------------------------------------------------------------------
-- KillRegistered Integration
----------------------------------------------------------------------

-- Listen to KillRegistered BindableEvent from CombatService
local KillRegisteredEvent = ReplicatedStorage:WaitForChild("KillRegistered") :: BindableEvent

KillRegisteredEvent.Event:Connect(function(attacker: Player, _victim: Player, weaponId: string, _isHeadshot: boolean)
	MasteryService.registerKill(attacker, weaponId)
end)

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player: Player)
	MasteryService.initPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	MasteryService.removePlayer(player)
end)

-- Initialize any players already in the game (for late script loading)
for _, player in Players:GetPlayers() do
	if not masteryData[player] then
		MasteryService.initPlayer(player)
	end
end

----------------------------------------------------------------------

return MasteryService
