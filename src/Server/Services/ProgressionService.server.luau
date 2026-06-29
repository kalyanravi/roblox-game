--!strict
--[[
	ProgressionService
	Server-authoritative player progression managing XP, levels, prestige,
	and level milestone rewards. Tracks per-player state in server memory.
	Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local MAX_LEVEL = Constants.MAX_LEVEL -- 100
local MAX_PRESTIGE = Constants.MAX_PRESTIGE -- 5
local XP_BASE_MATCH = Constants.XP_BASE_MATCH -- 50
local XP_PER_KILL = Constants.XP_PER_KILL -- 10
local XP_WIN_BONUS = Constants.XP_WIN_BONUS -- 25
local LEVEL_MILESTONE_INTERVAL = Constants.LEVEL_MILESTONE_INTERVAL -- 5

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------

type PlayerProgression = {
	level: number,
	xp: number,
	prestige: number,
}

type MatchStats = {
	kills: number,
	isWinner: boolean,
}

type LevelReward = {
	type: string,
	amount: number,
}

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

-- Per-player progression data stored in server memory
local playerProgression: { [Player]: PlayerProgression } = {}

----------------------------------------------------------------------
-- Internal Helpers
----------------------------------------------------------------------

--- Calculates the XP required to advance from a given level to the next.
--- Formula: level × 100 XP per level.
local function xpRequiredForLevel(level: number): number
	return level * 100
end

--- Determines the level reward for a given level.
--- Awards at every LEVEL_MILESTONE_INTERVAL (5) levels.
--- Alternating cycle: 200 coins → 10 gems → cosmetic unlock.
local function calculateLevelReward(level: number): LevelReward?
	if level % LEVEL_MILESTONE_INTERVAL ~= 0 then
		return nil
	end

	-- Determine which milestone this is (5=1st, 10=2nd, 15=3rd, 20=4th, etc.)
	local milestoneIndex = level / LEVEL_MILESTONE_INTERVAL

	-- Cycle through 3 reward types: coins, gems, cosmetic
	local rewardCycle = ((milestoneIndex - 1) % 3) + 1

	if rewardCycle == 1 then
		return { type = "coins", amount = 200 }
	elseif rewardCycle == 2 then
		return { type = "gems", amount = 10 }
	else
		return { type = "cosmetic", amount = 1 }
	end
end

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local ProgressionService = {}

--- Initializes progression state for a player when they join.
function ProgressionService.initPlayer(player: Player): ()
	playerProgression[player] = {
		level = 1,
		xp = 0,
		prestige = 0,
	}
end

--- Cleans up progression state when a player leaves.
function ProgressionService.removePlayer(player: Player): ()
	playerProgression[player] = nil
end

--- Sets progression data (called by DataPersistenceService on load).
function ProgressionService.setProgression(player: Player, level: number, xp: number, prestige: number): ()
	local progression = playerProgression[player]
	if progression then
		progression.level = math.clamp(level, 1, MAX_LEVEL)
		progression.xp = math.max(0, xp)
		progression.prestige = math.clamp(prestige, 0, MAX_PRESTIGE)
	end
end

--- Returns the player's current level (1-100).
function ProgressionService.getLevel(player: Player): number
	local progression = playerProgression[player]
	if not progression then
		return 1
	end
	return progression.level
end

--- Returns the player's current prestige (0-5).
function ProgressionService.getPrestige(player: Player): number
	local progression = playerProgression[player]
	if not progression then
		return 0
	end
	return progression.prestige
end

--- Returns the player's current XP within their level.
function ProgressionService.getXP(player: Player): number
	local progression = playerProgression[player]
	if not progression then
		return 0
	end
	return progression.xp
end

--- Adds XP to a player. Handles level-up if XP threshold is exceeded.
--- Returns (newTotalXP, didLevelUp).
function ProgressionService.addXP(player: Player, amount: number, source: string): (number, boolean)
	local progression = playerProgression[player]
	if not progression then
		return 0, false
	end

	-- Cannot gain XP at max level
	if progression.level >= MAX_LEVEL then
		return progression.xp, false
	end

	if amount <= 0 then
		return progression.xp, false
	end

	progression.xp += amount
	local didLevelUp = false

	-- Check for level up(s) — a large XP grant may cause multiple level-ups
	while progression.level < MAX_LEVEL do
		local required = xpRequiredForLevel(progression.level)
		if progression.xp >= required then
			progression.xp -= required
			progression.level += 1
			didLevelUp = true
		else
			break
		end
	end

	-- Cap XP at 0 if we reached max level (no overflow)
	if progression.level >= MAX_LEVEL then
		progression.xp = 0
	end

	return progression.xp, didLevelUp
end

--- Calculates the XP awarded for a completed match.
--- Formula: 50 + (10 × kills) + (25 × win where win=1 if true else 0)
function ProgressionService.calculateMatchXP(stats: MatchStats): number
	local kills = math.max(0, stats.kills)
	local winBonus = if stats.isWinner then 1 else 0
	return XP_BASE_MATCH + (XP_PER_KILL * kills) + (XP_WIN_BONUS * winBonus)
end

--- Gets the reward for a specific level, if it is a milestone level.
--- Returns nil if the level is not a milestone (not a multiple of 5).
function ProgressionService.getLevelReward(level: number): LevelReward?
	return calculateLevelReward(level)
end

--- Activates prestige for a player.
--- Only available at level 100 and below max prestige (5).
--- Resets level to 1, grants prestige badge + 500 gems.
--- Returns true if prestige was activated successfully.
function ProgressionService.activatePrestige(player: Player): boolean
	local progression = playerProgression[player]
	if not progression then
		return false
	end

	-- Must be at max level
	if progression.level < MAX_LEVEL then
		return false
	end

	-- Must be below max prestige
	if progression.prestige >= MAX_PRESTIGE then
		return false
	end

	-- Reset level to 1, clear XP, increment prestige
	progression.level = 1
	progression.xp = 0
	progression.prestige += 1

	-- Grant 500 gems reward (integration with EconomyService handled by caller)
	-- The caller should invoke EconomyService.addGems(player, 500, "prestige")

	return true
end

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player: Player)
	ProgressionService.initPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	ProgressionService.removePlayer(player)
end)

-- Initialize any players already in the game (for late script loading)
for _, player in Players:GetPlayers() do
	if not playerProgression[player] then
		ProgressionService.initPlayer(player)
	end
end

----------------------------------------------------------------------

return ProgressionService
