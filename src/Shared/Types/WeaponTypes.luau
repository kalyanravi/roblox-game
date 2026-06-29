--!strict
--[[
	Weapon Type Definitions
	Defines weapon stat schema and category types used by both Server and Client.
	Requirements: 2.6
]]

export type WeaponCategory =
	"AssaultRifle"
	| "Shotgun"
	| "Sniper"
	| "Revolver"
	| "DualPistols"
	| "RocketLauncher"
	| "Crossbow"
	| "LMG"
	| "Knife"
	| "Fists"
	| "Scythe"

export type WeaponRarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type WeaponCost = {
	currency: "coins" | "gems",
	amount: number,
}

export type WeaponStats = {
	id: string,
	name: string,
	category: WeaponCategory,
	rarity: WeaponRarity,
	damage: number,
	fireRate: number, -- rounds per second
	range: number, -- studs
	reloadTime: number, -- seconds
	magazineSize: number,
	movementSpeedModifier: number, -- multiplier (e.g., 0.85 for LMG, 1.0 default)
	headshotMultiplier: number, -- default 1.5
	cost: WeaponCost?, -- nil for free Common weapons
}

local Types = {}
return Types
