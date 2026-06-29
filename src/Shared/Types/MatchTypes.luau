--!strict
--[[
	Match Type Definitions
	Defines match lifecycle states, configuration, and per-player match statistics.
	Requirements: 3.1
]]

export type MatchState = "Waiting" | "Countdown" | "Active" | "Ending" | "Results"

export type MatchMode = "TDM" | "FFA"

export type MatchConfig = {
	mode: MatchMode,
	teamSize: number, -- 1 to 5 for TDM, ignored for FFA
	maxPlayers: number,
	timeLimit: number, -- seconds (default 300)
	mapId: string,
	weaponRestrictions: { string }?, -- optional restricted weapon list
}

export type PlayerMatchStats = {
	kills: number,
	deaths: number,
	assists: number,
	damageDealt: number,
	highestStreak: number,
	headshotKills: number,
}

local Types = {}
return Types
