--!strict
--[[
	Ability Definitions
	Defines all purchasable combat abilities with costs, cooldowns, and effect parameters.
	Requirements: 4.1
]]

export type AbilityParams = {
	speedMultiplier: number?,
	duration: number?,
	healPercent: number?,
	maxRange: number?,
	speed: number?,
	damageAbsorb: number?,
}

export type AbilityDefinition = {
	id: string,
	name: string,
	cost: number,
	cooldown: number,
	effect: string,
	params: AbilityParams,
}

local AbilityDefinitions: { [string]: AbilityDefinition } = {
	Dash = {
		id = "dash",
		name = "Dash",
		cost = 0,
		cooldown = 5,
		effect = "dash",
		params = { speedMultiplier = 3, duration = 0.3 },
	},
	Heal = {
		id = "heal",
		name = "Heal",
		cost = 500,
		cooldown = 20,
		effect = "heal",
		params = { healPercent = 0.3, duration = 3 },
	},
	Grapple = {
		id = "grapple",
		name = "Grapple",
		cost = 750,
		cooldown = 8,
		effect = "grapple",
		params = { maxRange = 100, speed = 80 },
	},
	Shield = {
		id = "shield",
		name = "Shield",
		cost = 1000,
		cooldown = 25,
		effect = "shield",
		params = { damageAbsorb = 50, duration = 5 },
	},
	SpeedBoost = {
		id = "speedboost",
		name = "Speed Boost",
		cost = 600,
		cooldown = 15,
		effect = "speedboost",
		params = { speedMultiplier = 1.5, duration = 3 },
	},
}

return table.freeze(AbilityDefinitions)
