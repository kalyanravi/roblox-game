--!strict
--[[
	Server entry point for Shardstrike.
	Initializes all server-side services and systems in correct order.
	Creates RemoteEvents in ReplicatedStorage for client-server communication.
	Requirements: 23.1, 24.5, 24.6
]]

print("[Shardstrike Server] Initializing...")

----------------------------------------------------------------------
-- Services
----------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------------------------------------------------------------
-- Create Remotes folder with all RemoteEvents
----------------------------------------------------------------------

local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage

local remoteEventNames: { string } = {
	-- Combat
	"FireWeapon",
	"ReloadWeapon",
	"WeaponEquipped",
	"WeaponFired",
	"WeaponReloaded",
	"DamageIndicator",

	-- Abilities
	"ActivateAbility",
	"AbilityCooldown",

	-- Communication
	"SendPing",
	"SendCallout",
	"PingBroadcast",
	"CalloutBroadcast",

	-- Social
	"PlayEmote",
	"PlayFinisher",

	-- Economy
	"PurchaseItem",
	"EconomyUpdate",
	"ChestAwarded",
	"DailyReward",

	-- Loadout
	"EquipLoadout",
	"UpdateSettings",

	-- Match
	"JoinQueue",
	"MatchState",
	"KillFeed",
	"StreakNotification",
	"MythicKillEffect",

	-- Systems
	"ReplayData",
	"AFKWarning",
	"RadarPing",
	"Airstrike",

	-- Training Range
	"TrainingStats",
	"EnterTrainingRange",
	"ExitTrainingRange",
}

for _, name in remoteEventNames do
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = Remotes
end

----------------------------------------------------------------------
-- Create BindableEvents (used for internal server-to-server communication)
----------------------------------------------------------------------

local KillRegistered = Instance.new("BindableEvent")
KillRegistered.Name = "KillRegistered"
KillRegistered.Parent = ReplicatedStorage

----------------------------------------------------------------------
-- Require all server services (order matters for dependencies)
----------------------------------------------------------------------

local Services = script:WaitForChild("Services")

require(Services:WaitForChild("DataPersistenceService"))
require(Services:WaitForChild("EconomyService"))
require(Services:WaitForChild("ProgressionService"))
require(Services:WaitForChild("MasteryService"))
require(Services:WaitForChild("CombatService"))
require(Services:WaitForChild("MatchService"))
require(Services:WaitForChild("ChestService"))
require(Services:WaitForChild("MatchmakingService"))

----------------------------------------------------------------------
-- Require all server systems
----------------------------------------------------------------------

local Systems = script:WaitForChild("Systems")

require(Systems:WaitForChild("KillStreakManager"))
require(Systems:WaitForChild("SpawnSystem"))
require(Systems:WaitForChild("MapSystem"))
require(Systems:WaitForChild("AFKDetector"))
require(Systems:WaitForChild("AntiExploitValidator"))
require(Systems:WaitForChild("PingSystem"))
require(Systems:WaitForChild("FinisherSystem"))
require(Systems:WaitForChild("ReplayRecorder"))
require(Systems:WaitForChild("AbilityServer"))
require(Systems:WaitForChild("DailyLoginSystem"))
require(Systems:WaitForChild("TrainingRange"))

----------------------------------------------------------------------
-- Require gameplay modules (weapon setup + game loop)
----------------------------------------------------------------------

local Gameplay = script:WaitForChild("Gameplay")

require(Gameplay:WaitForChild("WeaponSetup"))
require(Gameplay:WaitForChild("GameLoop"))

----------------------------------------------------------------------
-- Initialization complete
----------------------------------------------------------------------

print("[Shardstrike Server] All services initialized.")
