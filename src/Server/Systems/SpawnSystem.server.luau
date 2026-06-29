--!strict
--[[
	Spawn System
	Manages respawn timers, spawn point selection (maximizing distance from enemies),
	and spawn protection (invincibility).
	Requirements: 3.5, 3.6
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local MapDefinitions = require(Shared:WaitForChild("Definitions"):WaitForChild("MapDefinitions"))
local MathUtils = require(Shared:WaitForChild("Utils"):WaitForChild("MathUtils"))

local RESPAWN_TIMER = Constants.RESPAWN_TIMER
local SPAWN_PROTECTION_DURATION = Constants.SPAWN_PROTECTION_DURATION

local SpawnSystem = {}

-- Track which players currently have spawn protection
local spawnProtectedPlayers: { [Player]: boolean } = {}

--[[
	Selects a spawn point that MAXIMIZES the minimum distance to any enemy player.
	For each available spawn point, computes the minimum distance to all enemy positions,
	then picks the spawn point with the largest such minimum distance.
]]
function SpawnSystem.getSpawnPoint(player: Player, mapId: string, enemyPositions: { Vector3 }): CFrame
	local mapDef = MapDefinitions[mapId]
	if not mapDef then
		-- Fallback: return origin if map not found
		return CFrame.new(0, 5, 0)
	end

	local spawnPoints: { CFrame } = mapDef.spawnPoints
	if #spawnPoints == 0 then
		return CFrame.new(0, 5, 0)
	end

	-- If no enemies, return a random spawn point
	if #enemyPositions == 0 then
		local randomIndex = math.random(1, #spawnPoints)
		return spawnPoints[randomIndex]
	end

	local bestSpawn: CFrame = spawnPoints[1]
	local bestMinDistance: number = -1

	for _, spawnCFrame in spawnPoints do
		local spawnPos = spawnCFrame.Position
		local minDistToEnemy = math.huge

		for _, enemyPos in enemyPositions do
			local dist = MathUtils.distance(spawnPos, enemyPos)
			if dist < minDistToEnemy then
				minDistToEnemy = dist
			end
		end

		if minDistToEnemy > bestMinDistance then
			bestMinDistance = minDistToEnemy
			bestSpawn = spawnCFrame
		end
	end

	return bestSpawn
end

--[[
	Starts a respawn timer for the player. After RESPAWN_TIMER seconds,
	calls the provided callback function.
]]
function SpawnSystem.startRespawnTimer(player: Player, callback: () -> ()): ()
	task.delay(RESPAWN_TIMER, function()
		-- Only call callback if player is still in game
		if player and player.Parent then
			callback()
		end
	end)
end

--[[
	Marks the player as invincible (spawn protected) for SPAWN_PROTECTION_DURATION seconds.
	Uses task.delay() for timed removal.
]]
function SpawnSystem.applySpawnProtection(player: Player): ()
	spawnProtectedPlayers[player] = true

	task.delay(SPAWN_PROTECTION_DURATION, function()
		-- Auto-remove spawn protection after duration
		if spawnProtectedPlayers[player] then
			spawnProtectedPlayers[player] = nil
		end
	end)
end

--[[
	Removes spawn protection from the player immediately.
]]
function SpawnSystem.removeSpawnProtection(player: Player): ()
	spawnProtectedPlayers[player] = nil
end

--[[
	Returns whether the player currently has spawn protection (invincibility).
]]
function SpawnSystem.isSpawnProtected(player: Player): boolean
	return spawnProtectedPlayers[player] == true
end

return SpawnSystem
