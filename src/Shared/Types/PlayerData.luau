--!strict
--[[
	PlayerData Type Definitions
	Defines the persistent player save data schema used by DataPersistenceService.
	Requirements: 24.1
]]

export type PlayerSettings = {
	sensitivity: number, -- 0.1 to 5.0
	crosshair: {
		shape: "dot" | "cross" | "circle",
		color: Color3,
		size: number,
		opacity: number,
	},
	audio: {
		master: number, -- 0 to 1
		sfx: number, -- 0 to 1
		music: number, -- 0 to 1
		voice: number, -- 0 to 1
	},
	keybinds: { [string]: Enum.KeyCode },
	mobileOnlyMatchmaking: boolean,
}

export type LoadoutData = {
	primaryWeapon: string,
	secondaryWeapon: string,
	meleeWeapon: string,
	abilities: { string }, -- max 2
	finisher: string,
	emotes: { string }, -- max 8
}

export type PlayerSaveData = {
	coins: number,
	gems: number,
	ownedWeapons: { string },
	ownedAbilities: { string },
	ownedEmotes: { string },
	ownedFinishers: { string },
	ownedCamos: { string },
	ownedSkins: { string },
	equippedLoadout: LoadoutData,
	level: number, -- 1 to 100
	xp: number,
	prestige: number, -- 0 to 5
	masteryKills: { [string]: number }, -- weaponId -> kill count
	settings: PlayerSettings,
	playtimeMinutes: number,
	chestPlaytime: number, -- active playtime toward next chest
	loginStreak: number,
	lastLoginDate: string,
	dailyCycleDay: number, -- 1 to 4
	totalKills: number,
	totalDeaths: number,
	totalWins: number,
	totalMatches: number,
}

local Types = {}
return Types
