--!strict
--[[
	Map System
	Manages map rotation, map definitions, spawn points, and fall zone detection.
	Requirements: 10.1, 10.2, 10.3, 10.4, 10.5
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapDefinitions = require(Shared:WaitForChild("Definitions"):WaitForChild("MapDefinitions"))

type MapDefinition = {
	id: string,
	name: string,
	description: string,
	spawnPoints: { CFrame },
	hasFallZones: boolean,
}

local MapSystem = {}

-- Internal state tracking
local currentMapId: string = ""
local mapHistory: { string } = {}

-- Fall zone threshold: if player Y position drops below this, they have fallen off
local FALL_ZONE_THRESHOLD: number = -50

--[[
	Returns the current active map ID.
]]
function MapSystem.getCurrentMap(): string
	return currentMapId
end

--[[
	Rotates to a new map, avoiding immediate repetition of the last map.
	Selects from all available maps excluding the current one.
]]
function MapSystem.rotateMap(): ()
	local availableMaps: { string } = {}

	for mapId, _ in MapDefinitions do
		-- Avoid repeating the last map
		if mapId ~= currentMapId then
			table.insert(availableMaps, mapId)
		end
	end

	-- If somehow all maps are filtered (only 1 map exists), allow repeat
	if #availableMaps == 0 then
		for mapId, _ in MapDefinitions do
			table.insert(availableMaps, mapId)
		end
	end

	-- Select a random map from available options
	local selectedIndex = math.random(1, #availableMaps)
	local newMapId = availableMaps[selectedIndex]

	-- Track history
	if currentMapId ~= "" then
		table.insert(mapHistory, currentMapId)
	end

	currentMapId = newMapId
end

--[[
	Returns the MapDefinition for a given map ID.
]]
function MapSystem.getMapDefinition(mapId: string): MapDefinition?
	return MapDefinitions[mapId]
end

--[[
	Returns the spawn points (as CFrame array) for the given map ID.
]]
function MapSystem.getSpawnPoints(mapId: string): { CFrame }
	local mapDef = MapDefinitions[mapId]
	if not mapDef then
		return {}
	end
	return mapDef.spawnPoints
end

--[[
	Checks if a player has fallen below the fall zone threshold on the current map.
	If the map has fall zones and the player's Y position drops below the threshold,
	registers a self-inflicted death and triggers respawn.

	Returns true if the player fell and a death was registered.
]]
function MapSystem.checkFallZone(player: Player): boolean
	local mapDef = MapDefinitions[currentMapId]
	if not mapDef then
		return false
	end

	-- Only check maps that have fall zones
	if not mapDef.hasFallZones then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		return false
	end

	local playerY = humanoidRootPart.Position.Y

	if playerY < FALL_ZONE_THRESHOLD then
		-- Register self-inflicted death
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
		return true
	end

	return false
end

--[[
	Returns the map history (list of previously played map IDs).
]]
function MapSystem.getMapHistory(): { string }
	return mapHistory
end

-- Initialize with a random map on module load
MapSystem.rotateMap()

return MapSystem
