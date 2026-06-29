--!strict
--[[
	Weapon Definitions Module
	Defines all weapons with stats, categories, and rarity tiers.
	Provides lookup functions for weapon retrieval and stat calculation.
	Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6
]]

local WeaponTypes = require(script.Parent.Parent.Types.WeaponTypes)

type WeaponStats = WeaponTypes.WeaponStats
type WeaponCategory = WeaponTypes.WeaponCategory
type WeaponRarity = WeaponTypes.WeaponRarity
type WeaponCost = WeaponTypes.WeaponCost

-- Rarity stat bonus multipliers
local RARITY_BONUSES: { [WeaponRarity]: number } = {
	Common = 0.00,
	Rare = 0.05,
	Epic = 0.10,
	Legendary = 0.15,
	Mythic = 0.20,
}

-- All weapon definitions
local Weapons: { WeaponStats } = {
	-----------------------------------------------------------------------
	-- COMMON WEAPONS (Free starting weapons - one per category)
	-----------------------------------------------------------------------

	-- Assault Rifle
	{
		id = "ar_standard",
		name = "Standard Rifle",
		category = "AssaultRifle",
		rarity = "Common",
		damage = 20,
		fireRate = 8,
		range = 100,
		reloadTime = 2.0,
		magazineSize = 30,
		movementSpeedModifier = 1.0,
		headshotMultiplier = 1.5,
		cost = nil,
	},

	-- Shotgun
	{
		id = "sg_pump",
		name = "Pump Shotgun",
		category = "Shotgun",
		rarity = "Common",
		damage = 55,
		fireRate = 1.2,
		range = 20,
		reloadTime = 2.5,
		magazineSize = 6,
		movementSpeedModifier = 0.95,
		headshotMultiplier = 1.5,
		cost = nil,
	},

	-- Sniper
	{
		id = "sniper_bolt",
		name = "Bolt Action",
		category = "Sniper",
		rarity = "Common",
		damage = 75,
		fireRate = 0.8,
		range = 250,
		reloadTime = 3.5,
		magazineSize = 5,
		movementSpeedModifier = 0.9,
		headshotMultiplier = 1.5,
		cost = nil,
	},

	-- Revolver
	{
		id = "rev_sixshooter",
		name = "Six Shooter",
		category = "Revolver",
		rarity = "Common",
		damage = 35,
		fireRate = 3.5,
		range = 60,
		reloadTime = 2.2,
		magazineSize = 6,
		movementSpeedModifier = 1.0,
		headshotMultiplier = 1.5,
		cost = nil,
	},

	-- Dual Pistols
	{
		id = "dp_twin",
		name = "Twin Pistols",
		category = "DualPistols",
		rarity = "Common",
		damage = 14,
		fireRate = 10,
		range = 50,
		reloadTime = 2.0,
		magazineSize = 24,
		movementSpeedModifier = 1.0,
		headshotMultiplier = 1.5,
		cost = nil,
	},

	-- Rocket Launcher
	{
		id = "rl_basic",
		name = "RPG-7",
		category = "RocketLauncher",
		rarity = "Common",
		damage = 90,
		fireRate = 0.5,
		range = 150,
		reloadTime = 4.0,
		magazineSize = 1,
		movementSpeedModifier = 0.85,
		headshotMultiplier = 1.0,
		cost = nil,
	},

	-- Crossbow
	{
		id = "cb_hunter",
		name = "Hunter Crossbow",
		category = "Crossbow",
		rarity = "Common",
		damage = 65,
		fireRate = 0.7,
		range = 120,
		reloadTime = 3.0,
		magazineSize = 1,
		movementSpeedModifier = 0.95,
		headshotMultiplier = 1.5,
		cost = nil,
	},

	-- LMG
	{
		id = "lmg_standard",
		name = "Heavy MG",
		category = "LMG",
		rarity = "Common",
		damage = 18,
		fireRate = 12,
		range = 80,
		reloadTime = 4.5,
		magazineSize = 100,
		movementSpeedModifier = 0.80,
		headshotMultiplier = 1.5,
		cost = nil,
	},

	-- Knife (melee)
	{
		id = "melee_knife",
		name = "Combat Knife",
		category = "Knife",
		rarity = "Common",
		damage = 40,
		fireRate = 4,
		range = 5,
		reloadTime = 0,
		magazineSize = 0,
		movementSpeedModifier = 1.1,
		headshotMultiplier = 1.0,
		cost = nil,
	},

	-- Fists (melee)
	{
		id = "melee_fists",
		name = "Bare Fists",
		category = "Fists",
		rarity = "Common",
		damage = 25,
		fireRate = 6,
		range = 4,
		reloadTime = 0,
		magazineSize = 0,
		movementSpeedModifier = 1.15,
		headshotMultiplier = 1.0,
		cost = nil,
	},

	-- Scythe (melee)
	{
		id = "melee_scythe",
		name = "Reaper Scythe",
		category = "Scythe",
		rarity = "Common",
		damage = 60,
		fireRate = 1.5,
		range = 7,
		reloadTime = 0,
		magazineSize = 0,
		movementSpeedModifier = 0.9,
		headshotMultiplier = 1.0,
		cost = nil,
	},

	-----------------------------------------------------------------------
	-- RARE WEAPONS (+5% stat bonus, 500-1500 coins)
	-----------------------------------------------------------------------

	{
		id = "ar_tactical",
		name = "Tactical Carbine",
		category = "AssaultRifle",
		rarity = "Rare",
		damage = 22,
		fireRate = 9,
		range = 110,
		reloadTime = 1.8,
		magazineSize = 25,
		movementSpeedModifier = 1.0,
		headshotMultiplier = 1.5,
		cost = { currency = "coins", amount = 800 },
	},

	{
		id = "sg_auto",
		name = "Auto Shotgun",
		category = "Shotgun",
		rarity = "Rare",
		damage = 40,
		fireRate = 2.5,
		range = 18,
		reloadTime = 3.0,
		magazineSize = 8,
		movementSpeedModifier = 0.95,
		headshotMultiplier = 1.5,
		cost = { currency = "coins", amount = 1000 },
	},

	{
		id = "sniper_semi",
		name = "Marksman Rifle",
		category = "Sniper",
		rarity = "Rare",
		damage = 55,
		fireRate = 1.5,
		range = 200,
		reloadTime = 2.8,
		magazineSize = 10,
		movementSpeedModifier = 0.9,
		headshotMultiplier = 1.5,
		cost = { currency = "coins", amount = 1200 },
	},

	{
		id = "rev_magnum",
		name = "Magnum",
		category = "Revolver",
		rarity = "Rare",
		damage = 45,
		fireRate = 2.5,
		range = 70,
		reloadTime = 2.5,
		magazineSize = 6,
		movementSpeedModifier = 1.0,
		headshotMultiplier = 1.5,
		cost = { currency = "coins", amount = 900 },
	},

	{
		id = "dp_rapid",
		name = "Rapid Duals",
		category = "DualPistols",
		rarity = "Rare",
		damage = 12,
		fireRate = 13,
		range = 45,
		reloadTime = 1.8,
		magazineSize = 30,
		movementSpeedModifier = 1.0,
		headshotMultiplier = 1.5,
		cost = { currency = "coins", amount = 750 },
	},

	-----------------------------------------------------------------------
	-- EPIC WEAPONS (+10% stat bonus, 2000-4000 coins, unique reload anim)
	-----------------------------------------------------------------------

	{
		id = "ar_phantom",
		name = "Phantom AR",
		category = "AssaultRifle",
		rarity = "Epic",
		damage = 24,
		fireRate = 9,
		range = 120,
		reloadTime = 1.6,
		magazineSize = 35,
		movementSpeedModifier = 1.0,
		headshotMultiplier = 1.5,
		cost = { currency = "coins", amount = 3000 },
	},

	{
		id = "sg_dragon",
		name = "Dragon's Breath",
		category = "Shotgun",
		rarity = "Epic",
		damage = 60,
		fireRate = 1.0,
		range = 22,
		reloadTime = 2.8,
		magazineSize = 4,
		movementSpeedModifier = 0.95,
		headshotMultiplier = 1.5,
		cost = { currency = "coins", amount = 3500 },
	},

	{
		id = "lmg_chaingun",
		name = "Chaingun",
		category = "LMG",
		rarity = "Epic",
		damage = 16,
		fireRate = 15,
		range = 75,
		reloadTime = 5.0,
		magazineSize = 150,
		movementSpeedModifier = 0.75,
		headshotMultiplier = 1.5,
		cost = { currency = "coins", amount = 3800 },
	},

	{
		id = "cb_explosive",
		name = "Explosive Crossbow",
		category = "Crossbow",
		rarity = "Epic",
		damage = 80,
		fireRate = 0.6,
		range = 100,
		reloadTime = 3.5,
		magazineSize = 1,
		movementSpeedModifier = 0.95,
		headshotMultiplier = 1.5,
		cost = { currency = "coins", amount = 2500 },
	},

	{
		id = "rl_guided",
		name = "Guided Missile",
		category = "RocketLauncher",
		rarity = "Epic",
		damage = 100,
		fireRate = 0.4,
		range = 180,
		reloadTime = 4.5,
		magazineSize = 1,
		movementSpeedModifier = 0.85,
		headshotMultiplier = 1.0,
		cost = { currency = "coins", amount = 4000 },
	},

	-----------------------------------------------------------------------
	-- LEGENDARY WEAPONS (+15% stat bonus, 500 gems, unique fire sound + particle trail)
	-----------------------------------------------------------------------

	{
		id = "ar_golden",
		name = "Golden AK",
		category = "AssaultRifle",
		rarity = "Legendary",
		damage = 26,
		fireRate = 10,
		range = 130,
		reloadTime = 1.5,
		magazineSize = 35,
		movementSpeedModifier = 1.0,
		headshotMultiplier = 1.5,
		cost = { currency = "gems", amount = 500 },
	},

	{
		id = "sniper_railgun",
		name = "Railgun",
		category = "Sniper",
		rarity = "Legendary",
		damage = 95,
		fireRate = 0.5,
		range = 300,
		reloadTime = 4.0,
		magazineSize = 3,
		movementSpeedModifier = 0.85,
		headshotMultiplier = 1.5,
		cost = { currency = "gems", amount = 500 },
	},

	{
		id = "rev_deagle",
		name = "Desert Eagle",
		category = "Revolver",
		rarity = "Legendary",
		damage = 55,
		fireRate = 2.0,
		range = 80,
		reloadTime = 2.0,
		magazineSize = 7,
		movementSpeedModifier = 1.0,
		headshotMultiplier = 1.5,
		cost = { currency = "gems", amount = 500 },
	},

	{
		id = "melee_katana",
		name = "Shadow Katana",
		category = "Knife",
		rarity = "Legendary",
		damage = 55,
		fireRate = 3,
		range = 6,
		reloadTime = 0,
		magazineSize = 0,
		movementSpeedModifier = 1.1,
		headshotMultiplier = 1.0,
		cost = { currency = "gems", amount = 500 },
	},

	-----------------------------------------------------------------------
	-- MYTHIC WEAPONS (+20% stat bonus, 1000 gems, unique kill effect + glowing model)
	-----------------------------------------------------------------------

	{
		id = "ar_void",
		name = "Void Eater",
		category = "AssaultRifle",
		rarity = "Mythic",
		damage = 28,
		fireRate = 10,
		range = 140,
		reloadTime = 1.4,
		magazineSize = 40,
		movementSpeedModifier = 1.0,
		headshotMultiplier = 1.5,
		cost = { currency = "gems", amount = 1000 },
	},

	{
		id = "sg_inferno",
		name = "Inferno",
		category = "Shotgun",
		rarity = "Mythic",
		damage = 70,
		fireRate = 1.0,
		range = 25,
		reloadTime = 2.5,
		magazineSize = 5,
		movementSpeedModifier = 0.95,
		headshotMultiplier = 1.5,
		cost = { currency = "gems", amount = 1000 },
	},

	{
		id = "sniper_antimatter",
		name = "Antimatter",
		category = "Sniper",
		rarity = "Mythic",
		damage = 100,
		fireRate = 0.4,
		range = 350,
		reloadTime = 4.5,
		magazineSize = 3,
		movementSpeedModifier = 0.85,
		headshotMultiplier = 1.5,
		cost = { currency = "gems", amount = 1000 },
	},

	{
		id = "melee_scythe_doom",
		name = "Doom Scythe",
		category = "Scythe",
		rarity = "Mythic",
		damage = 80,
		fireRate = 1.5,
		range = 8,
		reloadTime = 0,
		magazineSize = 0,
		movementSpeedModifier = 0.9,
		headshotMultiplier = 1.0,
		cost = { currency = "gems", amount = 1000 },
	},
}

-----------------------------------------------------------------------
-- Lookup caches (built at module load time)
-----------------------------------------------------------------------

local weaponById: { [string]: WeaponStats } = {}
local weaponsByCategory: { [WeaponCategory]: { WeaponStats } } = {}
local weaponsByRarity: { [WeaponRarity]: { WeaponStats } } = {}

for _, weapon in Weapons do
	weaponById[weapon.id] = weapon

	if not weaponsByCategory[weapon.category] then
		weaponsByCategory[weapon.category] = {}
	end
	table.insert(weaponsByCategory[weapon.category], weapon)

	if not weaponsByRarity[weapon.rarity] then
		weaponsByRarity[weapon.rarity] = {}
	end
	table.insert(weaponsByRarity[weapon.rarity], weapon)
end

-----------------------------------------------------------------------
-- Public API
-----------------------------------------------------------------------

local WeaponDefinitions = {}

--- Returns the rarity stat bonus multiplier for the given rarity.
function WeaponDefinitions.getRarityBonus(rarity: WeaponRarity): number
	return RARITY_BONUSES[rarity] or 0
end

--- Retrieves a weapon by its unique id.
function WeaponDefinitions.getWeapon(weaponId: string): WeaponStats?
	return weaponById[weaponId]
end

--- Returns all weapons in the given category.
function WeaponDefinitions.getWeaponsByCategory(category: WeaponCategory): { WeaponStats }
	return weaponsByCategory[category] or {}
end

--- Returns all weapons of the given rarity.
function WeaponDefinitions.getWeaponsByRarity(rarity: WeaponRarity): { WeaponStats }
	return weaponsByRarity[rarity] or {}
end

--- Calculates effective weapon stats with rarity bonus applied to numeric combat stats.
--- Applies bonus to: damage, fireRate, range, magazineSize.
--- Does NOT apply bonus to: reloadTime (lower is better, handled separately),
--- movementSpeedModifier, or headshotMultiplier (fixed multipliers).
function WeaponDefinitions.calculateEffectiveStats(weapon: WeaponStats): WeaponStats
	local bonus = RARITY_BONUSES[weapon.rarity] or 0

	return {
		id = weapon.id,
		name = weapon.name,
		category = weapon.category,
		rarity = weapon.rarity,
		damage = weapon.damage * (1 + bonus),
		fireRate = weapon.fireRate * (1 + bonus),
		range = weapon.range * (1 + bonus),
		reloadTime = weapon.reloadTime,
		magazineSize = math.floor(weapon.magazineSize * (1 + bonus)),
		movementSpeedModifier = weapon.movementSpeedModifier,
		headshotMultiplier = weapon.headshotMultiplier,
		cost = weapon.cost,
	}
end

--- The full weapon list.
WeaponDefinitions.weapons = Weapons

return table.freeze(WeaponDefinitions)
