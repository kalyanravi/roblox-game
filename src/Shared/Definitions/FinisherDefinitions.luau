--!strict
--[[
	Finisher Definitions
	Defines purchasable finisher effects triggered on final/streak kills.
	Requirements: 10.1
]]

export type FinisherDefinition = {
	id: string,
	name: string,
	cost: number, -- coins
	effectType: string,
	duration: number, -- seconds
}

local FinisherDefinitions: { FinisherDefinition } = {
	{
		id = "finisher_dissolve",
		name = "Dissolve",
		cost = 1000,
		effectType = "dissolve",
		duration = 1.5,
	},
	{
		id = "finisher_explosion",
		name = "Explosion",
		cost = 1500,
		effectType = "explosion",
		duration = 1.0,
	},
	{
		id = "finisher_freeze_shatter",
		name = "Freeze Shatter",
		cost = 1500,
		effectType = "freeze_shatter",
		duration = 2.0,
	},
	{
		id = "finisher_lightning_strike",
		name = "Lightning Strike",
		cost = 2000,
		effectType = "lightning_strike",
		duration = 1.5,
	},
	{
		id = "finisher_vaporize",
		name = "Vaporize",
		cost = 2000,
		effectType = "vaporize",
		duration = 1.2,
	},
	{
		id = "finisher_ragdoll_launch",
		name = "Ragdoll Launch",
		cost = 2500,
		effectType = "ragdoll_launch",
		duration = 2.5,
	},
}

return table.freeze(FinisherDefinitions)
