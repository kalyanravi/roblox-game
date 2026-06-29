--!strict
--[[
	Streak Definitions
	Defines kill streak milestones and their rewards.
	Requirements: 5.2, 5.3, 5.4, 5.5
]]

export type StreakDefinition = {
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

local StreakDefinitions: { StreakDefinition } = {
	{
		streakCount = 3,
		name = "Radar Ping",
		effect = "reveal_enemies",
		params = {
			duration = 5,
		},
	},
	{
		streakCount = 5,
		name = "Damage Boost",
		effect = "damage_boost",
		params = {
			duration = 10,
			damageMultiplier = 1.20,
		},
	},
	{
		streakCount = 7,
		name = "Airstrike",
		effect = "airstrike",
		params = {
			delay = 3,
			duration = 0,
		},
	},
	{
		streakCount = 10,
		name = "Juggernaut Mode",
		effect = "juggernaut",
		params = {
			duration = 15,
			healthMultiplier = 2.0,
			armorBonus = 50,
		},
	},
}

return table.freeze(StreakDefinitions)
