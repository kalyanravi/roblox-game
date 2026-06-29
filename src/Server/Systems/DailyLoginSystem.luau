--!strict
--[[
	DailyLoginSystem
	Tracks per-player daily login streaks and awards scaled coin/gem rewards
	on a 4-day cycle. Resets streak if a calendar day is missed.
	Requirements: 11.1, 11.2, 11.3, 11.4
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------

export type LoginResult = {
	coins: number,
	gems: number,
	newCycleDay: number,
	newStreak: number,
}

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local DAILY_LOGIN_CYCLE: { number } = Constants.DAILY_LOGIN_CYCLE
local DAILY_GEM_BONUS: number = Constants.DAILY_GEM_BONUS

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

-- In-memory state per player (loaded from DataStore externally)
local playerLoginData: { [Player]: { lastLoginDate: string, dailyCycleDay: number, loginStreak: number } } = {}

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

local DailyRewardRemote = getOrCreateRemoteEvent("DailyReward")

----------------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------------

local function getCurrentDateString(): string
	return os.date("%Y-%m-%d") :: string
end

local function isConsecutiveDay(lastDate: string, currentDate: string): boolean
	-- Parse last login date
	local ly, lm, ld = lastDate:match("^(%d+)-(%d+)-(%d+)$")
	if not ly then
		return false
	end

	local lastTime = os.time({
		year = tonumber(ly) :: number,
		month = tonumber(lm) :: number,
		day = tonumber(ld) :: number,
		hour = 0,
		min = 0,
		sec = 0,
	})

	-- Parse current date
	local cy, cm, cd = currentDate:match("^(%d+)-(%d+)-(%d+)$")
	if not cy then
		return false
	end

	local currentTime = os.time({
		year = tonumber(cy) :: number,
		month = tonumber(cm) :: number,
		day = tonumber(cd) :: number,
		hour = 0,
		min = 0,
		sec = 0,
	})

	-- Consecutive if exactly 1 day apart (86400 seconds)
	local diff = currentTime - lastTime
	return diff >= 86400 and diff < 172800
end

----------------------------------------------------------------------
-- Core Logic
----------------------------------------------------------------------

--[[
	Processes a player login and determines daily rewards.
	@param player - The player who logged in
	@param lastLoginDate - The date string of the player's last login (YYYY-MM-DD)
	@param dailyCycleDay - The current position in the 4-day reward cycle (1-4)
	@param loginStreak - The player's current consecutive login streak
	@return LoginResult with coins, gems, new cycle day, and new streak
]]
local function processLogin(
	player: Player,
	lastLoginDate: string,
	dailyCycleDay: number,
	loginStreak: number
): LoginResult
	local currentDate = getCurrentDateString()

	-- Same day: no reward (already claimed)
	if lastLoginDate == currentDate then
		return {
			coins = 0,
			gems = 0,
			newCycleDay = dailyCycleDay,
			newStreak = loginStreak,
		}
	end

	local coins: number
	local gems: number = DAILY_GEM_BONUS
	local newCycleDay: number
	local newStreak: number

	if isConsecutiveDay(lastLoginDate, currentDate) then
		-- Consecutive day: increment streak and advance cycle
		newStreak = loginStreak + 1
		newCycleDay = dailyCycleDay + 1
		if newCycleDay > #DAILY_LOGIN_CYCLE then
			newCycleDay = 1
		end
		coins = DAILY_LOGIN_CYCLE[newCycleDay]
	else
		-- Missed a day: reset streak and cycle
		newStreak = 1
		newCycleDay = 1
		coins = DAILY_LOGIN_CYCLE[1]
	end

	-- Update in-memory state
	playerLoginData[player] = {
		lastLoginDate = currentDate,
		dailyCycleDay = newCycleDay,
		loginStreak = newStreak,
	}

	-- Fire client notification with reward info
	DailyRewardRemote:FireClient(player, {
		coins = coins,
		gems = gems,
		cycleDay = newCycleDay,
		streak = newStreak,
	})

	return {
		coins = coins,
		gems = gems,
		newCycleDay = newCycleDay,
		newStreak = newStreak,
	}
end

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player: Player)
	-- Initialize with default data; external DataService will call processLogin
	-- with actual persisted values once loaded
	playerLoginData[player] = {
		lastLoginDate = "",
		dailyCycleDay = 0,
		loginStreak = 0,
	}
end)

Players.PlayerRemoving:Connect(function(player: Player)
	playerLoginData[player] = nil
end)

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local DailyLoginSystem = {}

DailyLoginSystem.processLogin = processLogin

function DailyLoginSystem.getPlayerLoginData(player: Player): { lastLoginDate: string, dailyCycleDay: number, loginStreak: number }?
	return playerLoginData[player]
end

return DailyLoginSystem
