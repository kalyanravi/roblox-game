--!strict

local Constants = {
	-- Match / Respawn
	RESPAWN_TIMER = 3,
	SPAWN_PROTECTION_DURATION = 3,
	MATCH_DURATION = 300,

	-- AFK Detection
	AFK_WARNING_THRESHOLD = 45,
	AFK_KICK_THRESHOLD = 60,

	-- Networking
	REMOTE_RATE_LIMIT = 60,

	-- Progression
	MAX_LEVEL = 100,
	MAX_PRESTIGE = 5,

	-- Combat
	HEADSHOT_MULTIPLIER = 1.5,

	-- Loadout Limits
	MAX_ABILITIES_EQUIPPED = 2,
	MAX_EMOTES_EQUIPPED = 8,

	-- Communication
	PING_COOLDOWN = 3,

	-- Data Persistence
	AUTO_SAVE_INTERVAL = 300,
	MAX_DATASTORE_RETRIES = 3,

	-- Settings
	SENSITIVITY_MIN = 0.1,
	SENSITIVITY_MAX = 5.0,

	-- Chest Playtime Thresholds (minutes)
	CHEST_BRONZE_MINUTES = 30,
	CHEST_SILVER_MINUTES = 60,
	CHEST_GOLD_MINUTES = 120,

	-- Daily Login Rewards
	DAILY_LOGIN_CYCLE = { 25, 50, 75, 100 },
	DAILY_GEM_BONUS = 5,

	-- XP Awards
	XP_BASE_MATCH = 50,
	XP_PER_KILL = 10,
	XP_WIN_BONUS = 25,

	-- Level Milestone
	LEVEL_MILESTONE_INTERVAL = 5,

	-- Economy — Coins
	COINS_PER_KILL = 25,
	COINS_PER_ASSIST = 10,
	COINS_PER_WIN = 45,
	COINS_STREAK_BONUS = 50,
	COINS_MVP_BONUS = 100,

	-- Economy — Gems
	CONSECUTIVE_WINS_FOR_GEMS = 3,
	GEMS_CONSECUTIVE_WIN_REWARD = 10,

	-- Weapon Mastery Thresholds
	MASTERY_BRONZE = 50,
	MASTERY_SILVER = 100,
	MASTERY_GOLD = 250,
	MASTERY_DIAMOND = 500,
}

return table.freeze(Constants)
