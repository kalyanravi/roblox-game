--!strict
--[[
	Map Builder — Urban Combat Zone
	Constructs a gritty abandoned city block at dusk.
	Features multi-story buildings, alleyways, cover objects, street lamps, and dramatic lighting.
]]

local Lighting = game:GetService("Lighting")

----------------------------------------------------------------------
-- Configuration
----------------------------------------------------------------------

local MAP_LENGTH = 240 -- Z axis (street runs along Z)
local MAP_WIDTH = 160 -- X axis
local ROAD_WIDTH = 24
local SIDEWALK_WIDTH = 6
local BUILDING_SETBACK = 2 -- gap between sidewalk and building face

----------------------------------------------------------------------
-- Color Palette
----------------------------------------------------------------------

local COLORS = {
	Road = Color3.fromRGB(45, 45, 50),
	Sidewalk = Color3.fromRGB(130, 125, 115),
	CurbLine = Color3.fromRGB(200, 195, 60),
	Concrete = Color3.fromRGB(85, 80, 75),
	Brick = Color3.fromRGB(120, 65, 45),
	BrickDark = Color3.fromRGB(80, 45, 30),
	RustyMetal = Color3.fromRGB(140, 75, 35),
	Glass = Color3.fromRGB(50, 60, 80),
	Rubble = Color3.fromRGB(95, 90, 80),
	CarRed = Color3.fromRGB(140, 25, 25),
	CarBlue = Color3.fromRGB(30, 50, 110),
	CarBlack = Color3.fromRGB(25, 25, 30),
	Dumpster = Color3.fromRGB(40, 80, 40),
	Barrier = Color3.fromRGB(170, 165, 155),
	LampPost = Color3.fromRGB(50, 50, 55),
	Roof = Color3.fromRGB(55, 50, 48),
}

----------------------------------------------------------------------
-- Spawn Positions (logical urban positions)
----------------------------------------------------------------------

local SPAWN_POSITIONS: { Vector3 } = {
	Vector3.new(-45, 1.5, -80),  -- behind west building, south
	Vector3.new(45, 1.5, -80),   -- behind east building, south
	Vector3.new(-45, 1.5, 80),   -- behind west building, north
	Vector3.new(45, 1.5, 80),    -- behind east building, north
	Vector3.new(-20, 1.5, 0),    -- west alley, center
	Vector3.new(20, 1.5, 0),     -- east alley, center
	Vector3.new(0, 1.5, -100),   -- south end of road
	Vector3.new(0, 1.5, 100),    -- north end of road
}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local mapFolder = Instance.new("Folder")
mapFolder.Name = "UrbanCombatMap"
mapFolder.Parent = workspace

local function makePart(props: {
	Name: string?,
	Size: Vector3,
	Position: Vector3,
	Color: Color3?,
	Material: Enum.Material?,
	Transparency: number?,
	Anchored: boolean?,
	CanCollide: boolean?,
	Parent: Instance?,
}): Part
	local part = Instance.new("Part")
	part.Name = props.Name or "Part"
	part.Size = props.Size
	part.Position = props.Position
	part.Color = props.Color or COLORS.Concrete
	part.Material = props.Material or Enum.Material.Concrete
	part.Transparency = props.Transparency or 0
	part.Anchored = if props.Anchored ~= nil then props.Anchored else true
	part.CanCollide = if props.CanCollide ~= nil then props.CanCollide else true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.Parent or mapFolder
	return part
end

local function makeFolder(name: string, parent: Instance?): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent or mapFolder
	return folder
end

----------------------------------------------------------------------
-- Ground: Road + Sidewalks
----------------------------------------------------------------------

local groundFolder = makeFolder("Ground")

-- Main road surface
makePart({
	Name = "Road",
	Size = Vector3.new(ROAD_WIDTH, 1, MAP_LENGTH),
	Position = Vector3.new(0, 0, 0),
	Color = COLORS.Road,
	Material = Enum.Material.Asphalt,
	Parent = groundFolder,
})

-- Center line markings
for z = -MAP_LENGTH / 2 + 10, MAP_LENGTH / 2 - 10, 20 do
	makePart({
		Name = "CenterLine",
		Size = Vector3.new(0.4, 1.02, 8),
		Position = Vector3.new(0, 0.01, z),
		Color = COLORS.CurbLine,
		Material = Enum.Material.SmoothPlastic,
		Parent = groundFolder,
	})
end

-- West sidewalk
makePart({
	Name = "SidewalkWest",
	Size = Vector3.new(SIDEWALK_WIDTH, 1.3, MAP_LENGTH),
	Position = Vector3.new(-(ROAD_WIDTH / 2 + SIDEWALK_WIDTH / 2), 0.15, 0),
	Color = COLORS.Sidewalk,
	Material = Enum.Material.Concrete,
	Parent = groundFolder,
})

-- East sidewalk
makePart({
	Name = "SidewalkEast",
	Size = Vector3.new(SIDEWALK_WIDTH, 1.3, MAP_LENGTH),
	Position = Vector3.new(ROAD_WIDTH / 2 + SIDEWALK_WIDTH / 2, 0.15, 0),
	Color = COLORS.Sidewalk,
	Material = Enum.Material.Concrete,
	Parent = groundFolder,
})

-- Ground fill (dirt/rubble) on each side behind sidewalks
makePart({
	Name = "GroundWest",
	Size = Vector3.new(MAP_WIDTH / 2 - ROAD_WIDTH / 2 - SIDEWALK_WIDTH, 1, MAP_LENGTH),
	Position = Vector3.new(-(ROAD_WIDTH / 2 + SIDEWALK_WIDTH + (MAP_WIDTH / 2 - ROAD_WIDTH / 2 - SIDEWALK_WIDTH) / 2), -0.01, 0),
	Color = COLORS.Rubble,
	Material = Enum.Material.Ground,
	Parent = groundFolder,
})

makePart({
	Name = "GroundEast",
	Size = Vector3.new(MAP_WIDTH / 2 - ROAD_WIDTH / 2 - SIDEWALK_WIDTH, 1, MAP_LENGTH),
	Position = Vector3.new(ROAD_WIDTH / 2 + SIDEWALK_WIDTH + (MAP_WIDTH / 2 - ROAD_WIDTH / 2 - SIDEWALK_WIDTH) / 2, -0.01, 0),
	Color = COLORS.Rubble,
	Material = Enum.Material.Ground,
	Parent = groundFolder,
})

----------------------------------------------------------------------
-- Buildings
----------------------------------------------------------------------

local buildingsFolder = makeFolder("Buildings")

type BuildingDef = {
	Position: Vector3, -- base center of building
	Size: Vector3, -- footprint width (X), height (Y), depth (Z)
	Color: Color3,
	Material: Enum.Material,
	Ruined: boolean?,
}

local westBuildingX = -(ROAD_WIDTH / 2 + SIDEWALK_WIDTH + BUILDING_SETBACK + 12)
local eastBuildingX = ROAD_WIDTH / 2 + SIDEWALK_WIDTH + BUILDING_SETBACK + 12

local buildings: { BuildingDef } = {
	-- West side (5 buildings)
	{ Position = Vector3.new(westBuildingX, 0, -90), Size = Vector3.new(24, 20, 22), Color = COLORS.Brick, Material = Enum.Material.Brick, Ruined = false },
	{ Position = Vector3.new(westBuildingX, 0, -50), Size = Vector3.new(24, 28, 26), Color = COLORS.Concrete, Material = Enum.Material.Concrete, Ruined = false },
	{ Position = Vector3.new(westBuildingX, 0, -10), Size = Vector3.new(24, 16, 20), Color = COLORS.BrickDark, Material = Enum.Material.Brick, Ruined = true },
	{ Position = Vector3.new(westBuildingX, 0, 30), Size = Vector3.new(24, 24, 24), Color = COLORS.Brick, Material = Enum.Material.Brick, Ruined = false },
	{ Position = Vector3.new(westBuildingX, 0, 80), Size = Vector3.new(24, 18, 28), Color = COLORS.Concrete, Material = Enum.Material.Concrete, Ruined = true },

	-- East side (5 buildings)
	{ Position = Vector3.new(eastBuildingX, 0, -85), Size = Vector3.new(24, 24, 24), Color = COLORS.Concrete, Material = Enum.Material.Concrete, Ruined = false },
	{ Position = Vector3.new(eastBuildingX, 0, -40), Size = Vector3.new(24, 20, 20), Color = COLORS.BrickDark, Material = Enum.Material.Brick, Ruined = false },
	{ Position = Vector3.new(eastBuildingX, 0, 5), Size = Vector3.new(24, 30, 26), Color = COLORS.Brick, Material = Enum.Material.Brick, Ruined = false },
	{ Position = Vector3.new(eastBuildingX, 0, 50), Size = Vector3.new(24, 16, 22), Color = COLORS.Concrete, Material = Enum.Material.Concrete, Ruined = true },
	{ Position = Vector3.new(eastBuildingX, 0, 95), Size = Vector3.new(24, 22, 20), Color = COLORS.BrickDark, Material = Enum.Material.Brick, Ruined = false },
}

local function buildBuilding(def: BuildingDef, index: number)
	local bFolder = makeFolder("Building_" .. tostring(index), buildingsFolder)
	local height = def.Size.Y
	local ruinedHeight = if def.Ruined then height * 0.6 else height
	local baseY = def.Position.Y + ruinedHeight / 2 + 0.5

	-- Main body
	makePart({
		Name = "Body",
		Size = Vector3.new(def.Size.X, ruinedHeight, def.Size.Z),
		Position = Vector3.new(def.Position.X, baseY, def.Position.Z),
		Color = def.Color,
		Material = def.Material,
		Parent = bFolder,
	})

	-- Roof slab
	if not def.Ruined then
		makePart({
			Name = "Roof",
			Size = Vector3.new(def.Size.X + 1, 1, def.Size.Z + 1),
			Position = Vector3.new(def.Position.X, def.Position.Y + ruinedHeight + 1, def.Position.Z),
			Color = COLORS.Roof,
			Material = Enum.Material.Concrete,
			Parent = bFolder,
		})
	end

	-- Windows (dark insets on front face — toward road)
	local windowRows = math.floor(ruinedHeight / 6)
	local windowCols = math.floor(def.Size.X / 7)
	local facingZ = if def.Position.X < 0 then def.Position.Z + def.Size.Z / 2 + 0.05 else def.Position.Z - def.Size.Z / 2 - 0.05
	-- Determine which face points toward the road
	local faceDir = if def.Position.X < 0 then 1 else -1

	for row = 1, windowRows do
		for col = 1, windowCols do
			local wx = def.Position.X - (def.Size.X / 2) + col * (def.Size.X / (windowCols + 1))
			local wy = def.Position.Y + 0.5 + row * (ruinedHeight / (windowRows + 1))
			local wz = def.Position.Z + faceDir * (def.Size.Z / 2 + 0.05)

			makePart({
				Name = "Window",
				Size = Vector3.new(3, 4, 0.5),
				Position = Vector3.new(wx, wy, wz),
				Color = COLORS.Glass,
				Material = Enum.Material.SmoothPlastic,
				Transparency = 0.4,
				CanCollide = false,
				Parent = bFolder,
			})
		end
	end

	-- Rubble for ruined buildings
	if def.Ruined then
		local rubbleCount = math.random(6, 12)
		for r = 1, rubbleCount do
			local rSize = Vector3.new(math.random(1, 4), math.random(1, 3), math.random(1, 4))
			local rPos = Vector3.new(
				def.Position.X + math.random(-10, 10),
				rSize.Y / 2 + 0.5,
				def.Position.Z + math.random(-12, 12)
			)
			makePart({
				Name = "Rubble_" .. tostring(r),
				Size = rSize,
				Position = rPos,
				Color = COLORS.Rubble,
				Material = Enum.Material.Slate,
				Parent = bFolder,
			})
		end
	end
end

for i, def in buildings do
	buildBuilding(def, i)
end

----------------------------------------------------------------------
-- Rooftop Access Ramp (stacked parts forming stairs on one building)
----------------------------------------------------------------------

local stairsFolder = makeFolder("RooftopStairs")
local stairBuilding = buildings[2] -- tall west building
local stairBaseX = stairBuilding.Position.X + stairBuilding.Size.X / 2 + 2
local stairBaseZ = stairBuilding.Position.Z - stairBuilding.Size.Z / 2
local stairSteps = 10
local stepHeight = stairBuilding.Size.Y / stairSteps

for s = 1, stairSteps do
	makePart({
		Name = "Step_" .. tostring(s),
		Size = Vector3.new(4, stepHeight, 3),
		Position = Vector3.new(stairBaseX, 0.5 + (s - 0.5) * stepHeight, stairBaseZ + (s - 1) * 3),
		Color = COLORS.Concrete,
		Material = Enum.Material.Concrete,
		Parent = stairsFolder,
	})
end

----------------------------------------------------------------------
-- Cover Objects
----------------------------------------------------------------------

local coverFolder = makeFolder("Cover")

-- Cars
local carDefs: { { Position: Vector3, Color: Color3 } } = {
	{ Position = Vector3.new(-8, 2.5, -60), Color = COLORS.CarRed },
	{ Position = Vector3.new(7, 2.5, -20), Color = COLORS.CarBlue },
	{ Position = Vector3.new(-6, 2.5, 40), Color = COLORS.CarBlack },
	{ Position = Vector3.new(9, 2.5, 75), Color = COLORS.CarRed },
}

for i, car in carDefs do
	local cFolder = makeFolder("Car_" .. tostring(i), coverFolder)
	-- Car body
	makePart({
		Name = "Body",
		Size = Vector3.new(6, 3, 12),
		Position = car.Position,
		Color = car.Color,
		Material = Enum.Material.SmoothPlastic,
		Parent = cFolder,
	})
	-- Roof/cabin
	makePart({
		Name = "Cabin",
		Size = Vector3.new(5, 2, 6),
		Position = car.Position + Vector3.new(0, 2.5, 0),
		Color = car.Color,
		Material = Enum.Material.SmoothPlastic,
		Parent = cFolder,
	})
	-- Windshield
	makePart({
		Name = "Windshield",
		Size = Vector3.new(4.5, 1.8, 0.3),
		Position = car.Position + Vector3.new(0, 2.5, 3),
		Color = COLORS.Glass,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.5,
		Parent = cFolder,
	})
end

-- Dumpsters
local dumpsterPositions: { Vector3 } = {
	Vector3.new(-20, 2, -30),
	Vector3.new(22, 2, 60),
	Vector3.new(-22, 2, 50),
}

for i, pos in dumpsterPositions do
	makePart({
		Name = "Dumpster_" .. tostring(i),
		Size = Vector3.new(5, 4, 6),
		Position = pos,
		Color = COLORS.Dumpster,
		Material = Enum.Material.DiamondPlate,
		Parent = coverFolder,
	})
end

-- Jersey barriers
local barrierPositions: { Vector3 } = {
	Vector3.new(3, 1.5, -40),
	Vector3.new(-4, 1.5, 20),
	Vector3.new(0, 1.5, 50),
	Vector3.new(6, 1.5, -80),
	Vector3.new(-3, 1.5, 90),
}

for i, pos in barrierPositions do
	makePart({
		Name = "Barrier_" .. tostring(i),
		Size = Vector3.new(8, 3, 2),
		Position = pos,
		Color = COLORS.Barrier,
		Material = Enum.Material.Concrete,
		Parent = coverFolder,
	})
end

-- Sandbag walls
makePart({
	Name = "Sandbags_1",
	Size = Vector3.new(10, 2.5, 2),
	Position = Vector3.new(-10, 1.75, -70),
	Color = Color3.fromRGB(130, 115, 80),
	Material = Enum.Material.Fabric,
	Parent = coverFolder,
})

makePart({
	Name = "Sandbags_2",
	Size = Vector3.new(2, 2.5, 10),
	Position = Vector3.new(15, 1.75, 30),
	Color = Color3.fromRGB(130, 115, 80),
	Material = Enum.Material.Fabric,
	Parent = coverFolder,
})

----------------------------------------------------------------------
-- Street Lamps
----------------------------------------------------------------------

local lampsFolder = makeFolder("StreetLamps")
local lampPositions: { Vector3 } = {
	Vector3.new(-(ROAD_WIDTH / 2 + 1), 0, -90),
	Vector3.new(-(ROAD_WIDTH / 2 + 1), 0, -40),
	Vector3.new(-(ROAD_WIDTH / 2 + 1), 0, 10),
	Vector3.new(-(ROAD_WIDTH / 2 + 1), 0, 60),
	Vector3.new(ROAD_WIDTH / 2 + 1, 0, -65),
	Vector3.new(ROAD_WIDTH / 2 + 1, 0, -15),
	Vector3.new(ROAD_WIDTH / 2 + 1, 0, 35),
	Vector3.new(ROAD_WIDTH / 2 + 1, 0, 85),
}

for i, basePos in lampPositions do
	local lFolder = makeFolder("Lamp_" .. tostring(i), lampsFolder)
	local poleHeight = 14

	-- Pole
	makePart({
		Name = "Pole",
		Size = Vector3.new(0.5, poleHeight, 0.5),
		Position = basePos + Vector3.new(0, poleHeight / 2 + 0.5, 0),
		Color = COLORS.LampPost,
		Material = Enum.Material.Metal,
		Parent = lFolder,
	})

	-- Lamp head
	local lampHead = makePart({
		Name = "LampHead",
		Size = Vector3.new(2, 1, 2),
		Position = basePos + Vector3.new(0, poleHeight + 1, 0),
		Color = Color3.fromRGB(255, 220, 130),
		Material = Enum.Material.Neon,
		Parent = lFolder,
	})

	-- PointLight
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 100)
	light.Brightness = 1.5
	light.Range = 30
	light.Shadows = true
	light.Parent = lampHead
end

----------------------------------------------------------------------
-- Spawn Locations
----------------------------------------------------------------------

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

----------------------------------------------------------------------
-- Boundary Walls (invisible)
----------------------------------------------------------------------

local halfX = MAP_WIDTH / 2
local halfZ = MAP_LENGTH / 2
local boundaryHeight = 30
local bThick = 2

local boundaryDefs = {
	{ Name = "BoundaryNorth", Size = Vector3.new(MAP_WIDTH, boundaryHeight, bThick), Position = Vector3.new(0, boundaryHeight / 2, halfZ) },
	{ Name = "BoundarySouth", Size = Vector3.new(MAP_WIDTH, boundaryHeight, bThick), Position = Vector3.new(0, boundaryHeight / 2, -halfZ) },
	{ Name = "BoundaryEast", Size = Vector3.new(bThick, boundaryHeight, MAP_LENGTH), Position = Vector3.new(halfX, boundaryHeight / 2, 0) },
	{ Name = "BoundaryWest", Size = Vector3.new(bThick, boundaryHeight, MAP_LENGTH), Position = Vector3.new(-halfX, boundaryHeight / 2, 0) },
}

for _, bDef in boundaryDefs do
	makePart({
		Name = bDef.Name,
		Size = bDef.Size,
		Position = bDef.Position,
		Color = Color3.fromRGB(30, 30, 35),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.85,
		Parent = mapFolder,
	})
end

----------------------------------------------------------------------
-- Lighting Setup — Dusk / Evening Warfare
----------------------------------------------------------------------

Lighting.Ambient = Color3.fromRGB(40, 35, 50)
Lighting.OutdoorAmbient = Color3.fromRGB(60, 50, 70)
Lighting.Brightness = 1.5
Lighting.ClockTime = 18 -- Dusk
Lighting.GeographicLatitude = 40
Lighting.FogColor = Color3.fromRGB(80, 60, 70)
Lighting.FogEnd = 400
Lighting.FogStart = 50

-- Atmosphere: heavy, cinematic
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.4
atmosphere.Offset = 0.2
atmosphere.Color = Color3.fromRGB(180, 130, 90) -- warm orange sky
atmosphere.Decay = Color3.fromRGB(50, 30, 50) -- purple/dark decay
atmosphere.Glare = 0.3
atmosphere.Haze = 2
atmosphere.Parent = Lighting

-- Color correction for gritty feel
local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Brightness = -0.02
colorCorrection.Contrast = 0.15
colorCorrection.Saturation = -0.1
colorCorrection.TintColor = Color3.fromRGB(255, 240, 220)
colorCorrection.Parent = Lighting

-- Bloom for neon/lamp glow
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.5
bloom.Size = 30
bloom.Threshold = 0.8
bloom.Parent = Lighting

-- Sun rays
local sunRays = Instance.new("SunRaysEffect")
sunRays.Intensity = 0.15
sunRays.Spread = 0.8
sunRays.Parent = Lighting

-- Sky with orange/purple dusk colors
local sky = Instance.new("Sky")
sky.SunAngularSize = 15
sky.MoonAngularSize = 8
sky.StarCount = 1500
sky.SkyboxBk = ""
sky.SkyboxDn = ""
sky.SkyboxFt = ""
sky.SkyboxLf = ""
sky.SkyboxRt = ""
sky.SkyboxUp = ""
sky.CelestialBodiesShown = true
sky.Parent = Lighting

print("[Shardstrike Map] Urban combat zone built successfully.")
