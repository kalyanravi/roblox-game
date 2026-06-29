--!strict
--[[
	Map Builder
	Constructs a playable arena on server startup using Part instances.
	Builds the desert_outpost layout with floor, cover, spawns, and boundaries.
]]

local Lighting = game:GetService("Lighting")

----------------------------------------------------------------------
-- Configuration
----------------------------------------------------------------------

local FLOOR_SIZE = Vector3.new(200, 1, 200)
local FLOOR_POSITION = Vector3.new(0, 0, 0)
local BOUNDARY_HEIGHT = 20
local BOUNDARY_THICKNESS = 2

local SPAWN_POSITIONS: { Vector3 } = {
	Vector3.new(50, 5, 20),
	Vector3.new(-40, 5, 35),
	Vector3.new(10, 5, -60),
	Vector3.new(-55, 5, -25),
	Vector3.new(70, 5, -40),
	Vector3.new(-20, 5, 70),
	Vector3.new(30, 5, -80),
	Vector3.new(-70, 5, 50),
}

----------------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------------

local function createPart(name: string, size: Vector3, position: Vector3, color: BrickColor, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.BrickColor = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

----------------------------------------------------------------------
-- Build Map
----------------------------------------------------------------------

local mapFolder = Instance.new("Folder")
mapFolder.Name = "ArenaMap"
mapFolder.Parent = workspace

-- Floor
createPart("Floor", FLOOR_SIZE, FLOOR_POSITION, BrickColor.new("Medium stone grey"), mapFolder)

-- Cover objects: boxes, walls, ramps
local coverData: { { name: string, size: Vector3, position: Vector3, color: BrickColor } } = {
	-- Tall walls
	{ name = "WallA", size = Vector3.new(12, 10, 2), position = Vector3.new(20, 5.5, 0), color = BrickColor.new("Dark stone grey") },
	{ name = "WallB", size = Vector3.new(2, 10, 14), position = Vector3.new(-30, 5.5, -20), color = BrickColor.new("Dark stone grey") },
	{ name = "WallC", size = Vector3.new(16, 8, 2), position = Vector3.new(0, 4.5, 40), color = BrickColor.new("Dark stone grey") },
	-- Boxes / crates
	{ name = "CrateA", size = Vector3.new(6, 6, 6), position = Vector3.new(40, 3.5, -30), color = BrickColor.new("Brown") },
	{ name = "CrateB", size = Vector3.new(5, 5, 5), position = Vector3.new(-50, 3, 10), color = BrickColor.new("Brown") },
	{ name = "CrateC", size = Vector3.new(4, 4, 4), position = Vector3.new(60, 2.5, 50), color = BrickColor.new("Reddish brown") },
	-- Low cover
	{ name = "LowWallA", size = Vector3.new(10, 4, 2), position = Vector3.new(-10, 2.5, -40), color = BrickColor.new("Sand blue") },
	{ name = "LowWallB", size = Vector3.new(2, 4, 10), position = Vector3.new(50, 2.5, 60), color = BrickColor.new("Sand blue") },
	-- Ramps
	{ name = "RampA", size = Vector3.new(8, 1, 12), position = Vector3.new(-60, 2, -50), color = BrickColor.new("Olive") },
	{ name = "RampB", size = Vector3.new(10, 1, 8), position = Vector3.new(30, 2, 30), color = BrickColor.new("Olive") },
}

for _, data in coverData do
	createPart(data.name, data.size, data.position, data.color, mapFolder)
end

-- Spawn Locations
for i, pos in SPAWN_POSITIONS do
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn_" .. tostring(i)
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = pos
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = mapFolder
end

-- Boundary Walls (4 edges)
local halfFloor = FLOOR_SIZE.X / 2
local wallY = BOUNDARY_HEIGHT / 2 + 0.5

-- North wall (+Z)
createPart("BoundaryNorth", Vector3.new(FLOOR_SIZE.X, BOUNDARY_HEIGHT, BOUNDARY_THICKNESS), Vector3.new(0, wallY, halfFloor), BrickColor.new("Institutional white"), mapFolder)
-- South wall (-Z)
createPart("BoundarySouth", Vector3.new(FLOOR_SIZE.X, BOUNDARY_HEIGHT, BOUNDARY_THICKNESS), Vector3.new(0, wallY, -halfFloor), BrickColor.new("Institutional white"), mapFolder)
-- East wall (+X)
createPart("BoundaryEast", Vector3.new(BOUNDARY_THICKNESS, BOUNDARY_HEIGHT, FLOOR_SIZE.Z), Vector3.new(halfFloor, wallY, 0), BrickColor.new("Institutional white"), mapFolder)
-- West wall (-X)
createPart("BoundaryWest", Vector3.new(BOUNDARY_THICKNESS, BOUNDARY_HEIGHT, FLOOR_SIZE.Z), Vector3.new(-halfFloor, wallY, 0), BrickColor.new("Institutional white"), mapFolder)

-- Make boundary walls semi-transparent so players can see edges
for _, child in mapFolder:GetChildren() do
	if child.Name:find("Boundary") then
		(child :: BasePart).Transparency = 0.6
	end
end

----------------------------------------------------------------------
-- Lighting Setup
----------------------------------------------------------------------

Lighting.Ambient = Color3.fromRGB(120, 110, 90)
Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 120)
Lighting.Brightness = 2
Lighting.ClockTime = 14 -- Afternoon sun
Lighting.GeographicLatitude = 30

-- Add sun rays atmosphere
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Offset = 0.25
atmosphere.Color = Color3.fromRGB(199, 170, 107)
atmosphere.Decay = Color3.fromRGB(92, 60, 13)
atmosphere.Glare = 0.5
atmosphere.Haze = 1.5
atmosphere.Parent = Lighting

-- Add bloom effect
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.4
bloom.Size = 24
bloom.Threshold = 0.9
bloom.Parent = Lighting

print("[Shardstrike Map] Arena built successfully.")
