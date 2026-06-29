--!strict
--[[
	Map Definitions
	Defines all playable maps with spawn points and metadata.
	Requirements: 5.2, 14.1
]]

export type MapDefinition = {
	id: string,
	name: string,
	description: string,
	spawnPoints: { CFrame },
	hasFallZones: boolean,
}

local MapDefinitions: { [string]: MapDefinition } = {
	desert_outpost = {
		id = "desert_outpost",
		name = "Desert Outpost",
		description = "Open sightlines with elevated vantage points, favoring long-range engagements.",
		spawnPoints = {
			CFrame.new(50, 5, 20),
			CFrame.new(-40, 5, 35),
			CFrame.new(10, 5, -60),
			CFrame.new(-55, 5, -25),
			CFrame.new(70, 5, -40),
			CFrame.new(-20, 5, 70),
			CFrame.new(30, 5, -80),
			CFrame.new(-70, 5, 50),
		},
		hasFallZones = false,
	},

	futuristic_city = {
		id = "futuristic_city",
		name = "Futuristic City",
		description = "Vertical gameplay with rooftops and alleys providing multi-level combat paths.",
		spawnPoints = {
			CFrame.new(25, 30, 10),
			CFrame.new(-30, 5, 40),
			CFrame.new(60, 20, -20),
			CFrame.new(-15, 40, -50),
			CFrame.new(45, 10, 55),
			CFrame.new(-50, 25, 15),
			CFrame.new(10, 35, -70),
			CFrame.new(-60, 15, -30),
		},
		hasFallZones = true,
	},

	military_base = {
		id = "military_base",
		name = "Military Base",
		description = "Balanced layout with vehicles and structures providing ample cover.",
		spawnPoints = {
			CFrame.new(40, 5, 30),
			CFrame.new(-35, 5, 45),
			CFrame.new(15, 5, -55),
			CFrame.new(-50, 5, -20),
			CFrame.new(65, 5, -35),
			CFrame.new(-25, 5, 65),
			CFrame.new(55, 5, 50),
			CFrame.new(-65, 5, -55),
		},
		hasFallZones = false,
	},

	abandoned_factory = {
		id = "abandoned_factory",
		name = "Abandoned Factory",
		description = "Tight corridors and enclosed spaces favoring close-range combat.",
		spawnPoints = {
			CFrame.new(15, 5, 10),
			CFrame.new(-20, 5, 25),
			CFrame.new(30, 5, -15),
			CFrame.new(-10, 5, -30),
			CFrame.new(25, 5, 35),
			CFrame.new(-35, 5, -10),
			CFrame.new(5, 5, -40),
			CFrame.new(-25, 5, 40),
		},
		hasFallZones = false,
	},

	sky_fortress = {
		id = "sky_fortress",
		name = "Sky Fortress",
		description = "Floating platforms high above the ground with fall-off danger zones.",
		spawnPoints = {
			CFrame.new(20, 200, 15),
			CFrame.new(-25, 200, 30),
			CFrame.new(40, 200, -20),
			CFrame.new(-15, 200, -40),
			CFrame.new(55, 200, 10),
			CFrame.new(-45, 200, -15),
			CFrame.new(10, 200, 50),
			CFrame.new(-35, 200, 45),
		},
		hasFallZones = true,
	},
}

return table.freeze(MapDefinitions)
