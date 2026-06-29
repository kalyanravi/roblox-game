--!strict
--[[
	Rarity Configuration
	Defines stat bonuses and visual features for each weapon rarity tier.
	Requirements: 2.5
]]

local Types = require(script.Parent.Parent.Types.WeaponTypes)

export type RarityData = {
	statBonus: number,
	features: { string },
}

local RarityConfig: { [Types.WeaponRarity]: RarityData } = {
	Common = { statBonus = 0.00, features = {} },
	Rare = { statBonus = 0.05, features = {} },
	Epic = { statBonus = 0.10, features = { "uniqueReloadAnim" } },
	Legendary = { statBonus = 0.15, features = { "uniqueFireSound", "particleTrail" } },
	Mythic = { statBonus = 0.20, features = { "uniqueKillEffect", "glowingModel" } },
}

return table.freeze(RarityConfig)
