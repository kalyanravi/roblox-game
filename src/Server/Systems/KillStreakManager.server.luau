--!strict
--[[
	KillStreakManager
	Tracks consecutive kills without death for each player and grants
	streak rewards at defined milestones (3, 5, 7, 10 kills).
	Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StreakDefinitions = require(Shared.Definitions.StreakDefinitions)

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------

export type StreakReward = {
	streakCount: number,
	name: string,
	effect: string,
	params: {
		duration: number?,
		damageMultiplier: number?,
		delay: number?,
		healthMultiplier: number?,
		armorBonus: number?,
	},
}

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

-- Per-player kill streak count
local playerStreaks: { [Player]: number } = {}

-- Per-player active damage multiplier (for Damage Boost reward)
local damageMultipliers: { [Player]: number } = {}

----------------------------------------------------------------------
-- RemoteEvents / BindableEvents
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

-- Streak notification sent to all players for streaks of 5+
local StreakNotificationRemote = getOrCreateRemoteEvent("StreakNotification")

-- Radar Ping remote to reveal enemy positions
local RadarPingRemote = getOrCreateRemoteEvent("RadarPing")

-- Airstrike remote for zone marking
local AirstrikeRemote = getOrCreateRemoteEvent("Airstrike")

-- Listen to KillRegistered BindableEvent from CombatService
local KillRegisteredEvent = ReplicatedStorage:WaitForChild("KillRegistered") :: BindableEvent

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local KillStreakManager = {}

--- Finds the streak definition matching a given kill count, if any.
local function getStreakDefinition(streakCount: number): StreakReward?
	for _, def in StreakDefinitions do
		if def.streakCount == streakCount then
			return {
				streakCount = def.streakCount,
				name = def.name,
				effect = def.effect,
				params = def.params,
			}
		end
	end
	return nil
end

--- Registers a kill for the player, increments streak, returns StreakReward if milestone hit.
function KillStreakManager.registerKill(player: Player): StreakReward?
	if not playerStreaks[player] then
		playerStreaks[player] = 0
	end

	playerStreaks[player] += 1
	local currentStreak = playerStreaks[player]

	-- Check if this streak count matches a milestone
	local reward = getStreakDefinition(currentStreak)

	if reward then
		-- Apply the reward
		KillStreakManager.applyStreakReward(player, reward)
	end

	-- Announce streaks of 5 or higher to all players
	if currentStreak >= 5 then
		StreakNotificationRemote:FireAllClients(player.Name, currentStreak)
	end

	return reward
end

--- Registers a death for the player, resets streak to 0.
function KillStreakManager.registerDeath(player: Player): ()
	playerStreaks[player] = 0
end

--- Returns the current streak count for a player.
function KillStreakManager.getCurrentStreak(player: Player): number
	return playerStreaks[player] or 0
end

--- Returns the current damage multiplier for a player (1.0 if no boost active).
function KillStreakManager.getDamageMultiplier(player: Player): number
	return damageMultipliers[player] or 1.0
end

--- Applies the streak reward effects for the given player.
function KillStreakManager.applyStreakReward(player: Player, reward: StreakReward): ()
	local effect = reward.effect

	if effect == "reveal_enemies" then
		-- 3-kill "Radar Ping": fire remote revealing all enemy positions for 5 seconds
		local duration = reward.params.duration or 5
		RadarPingRemote:FireClient(player, duration)

	elseif effect == "damage_boost" then
		-- 5-kill "Damage Boost": set damage multiplier to 1.2x for 10 seconds
		local duration = reward.params.duration or 10
		local multiplier = reward.params.damageMultiplier or 1.20

		damageMultipliers[player] = multiplier

		-- Reset multiplier after duration
		task.delay(duration, function()
			-- Only reset if the player still has this multiplier active
			if damageMultipliers[player] == multiplier then
				damageMultipliers[player] = nil
			end
		end)

	elseif effect == "airstrike" then
		-- 7-kill "Airstrike": player marks a zone, area damage after 3-second delay
		local delay = reward.params.delay or 3
		AirstrikeRemote:FireClient(player, delay)

	elseif effect == "juggernaut" then
		-- 10-kill "Juggernaut Mode": double health + armor for 15 seconds
		local duration = reward.params.duration or 15
		local healthMultiplier = reward.params.healthMultiplier or 2.0
		local armorBonus = reward.params.armorBonus or 50

		-- Apply to the player's character
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local originalMaxHealth = humanoid.MaxHealth
				local originalHealth = humanoid.Health

				-- Double max health and restore to full new max
				humanoid.MaxHealth = originalMaxHealth * healthMultiplier
				humanoid.Health = humanoid.MaxHealth

				-- Revert after duration
				task.delay(duration, function()
					if humanoid and humanoid.Parent then
						humanoid.MaxHealth = originalMaxHealth
						humanoid.Health = math.min(humanoid.Health, originalMaxHealth)
					end
				end)
			end
		end
	end
end

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

-- Listen to KillRegistered from CombatService
-- CombatService fires: KillRegisteredEvent:Fire(attacker, victim, weaponId, isHeadshot)
KillRegisteredEvent.Event:Connect(function(attacker: Player, victim: Player, _weaponId: string, _isHeadshot: boolean)
	-- Register kill for attacker (increments streak)
	KillStreakManager.registerKill(attacker)

	-- Register death for victim (resets streak)
	KillStreakManager.registerDeath(victim)
end)

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player: Player)
	playerStreaks[player] = 0
end)

Players.PlayerRemoving:Connect(function(player: Player)
	playerStreaks[player] = nil
	damageMultipliers[player] = nil
end)

-- Initialize any players already in the game (for late script loading)
for _, player in Players:GetPlayers() do
	if not playerStreaks[player] then
		playerStreaks[player] = 0
	end
end

----------------------------------------------------------------------

return KillStreakManager
