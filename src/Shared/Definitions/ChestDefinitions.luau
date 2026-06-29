--!strict
--[[
	Chest Definitions
	Defines playtime chest tiers, unlock thresholds, and reward tables.
	Requirements: 9.1, 9.2, 9.3, 9.6
]]

export type ChestRewards = {
	itemCount: number,
	itemRarities: { string },
	coins: number,
	gems: number,
}

export type ChestDefinition = {
	id: string,
	name: string,
	tier: string,
	minutes: number, -- playtime minutes required
	rewards: ChestRewards,
}

local ChestDefinitions: { ChestDefinition } = {
	{
		id = "chest_bronze",
		name = "Bronze Chest",
		tier = "Bronze",
		minutes = 30,
		rewards = {
			itemCount = 1,
			itemRarities = { "Common", "Rare" },
			coins = 50,
			gems = 0,
		},
	},
	{
		id = "chest_silver",
		name = "Silver Chest",
		tier = "Silver",
		minutes = 60,
		rewards = {
			itemCount = 1,
			itemRarities = { "Rare", "Epic" },
			coins = 100,
			gems = 5,
		},
	},
	{
		id = "chest_gold",
		name = "Gold Chest",
		tier = "Gold",
		minutes = 120,
		rewards = {
			itemCount = 1,
			itemRarities = { "Epic", "Legendary" },
			coins = 200,
			gems = 15,
		},
	},
}

return table.freeze(ChestDefinitions)
