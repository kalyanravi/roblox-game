--!strict
--[[
	AFKDetector
	Monitors player input during active matches and removes idle players.
	Warning at 45 seconds of inactivity, kick at 60 seconds total.
	Pauses ChestService playtime tracking during warning period.
	Only operates during active matches (not lobby/training range).
	Requirements: 22.1, 22.2, 22.3, 22.4, 22.5
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local AFK_WARNING_THRESHOLD = Constants.AFK_WARNING_THRESHOLD -- 45 seconds
local AFK_KICK_THRESHOLD = Constants.AFK_KICK_THRESHOLD -- 60 seconds
local CHECK_INTERVAL = 1 -- how often to check AFK status (seconds)

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------

type AFKState = {
	lastInputTime: number, -- os.clock() of last registered input
	warned: boolean, -- whether the player has been sent a warning
	matchActive: boolean, -- whether the player is in an active match
}

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

-- Per-player AFK tracking state
local afkStates: { [Player]: AFKState } = {}

----------------------------------------------------------------------
-- RemoteEvents
----------------------------------------------------------------------

local function getOrCreateRemoteEvent(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing :: RemoteEvent
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

-- Fired to the player when they receive an AFK warning
local AFKWarningRemote = getOrCreateRemoteEvent("AFKWarning")

----------------------------------------------------------------------
-- External Service References
----------------------------------------------------------------------

-- ChestService reference (loaded lazily to avoid circular dependencies)
local ChestService: any = nil

local function getChestService(): any
	if ChestService then
		return ChestService
	end
	local Services = script.Parent.Parent:FindFirstChild("Services")
	if Services then
		local chestModule = Services:FindFirstChild("ChestService")
		if chestModule then
			ChestService = require(chestModule)
		end
	end
	return ChestService
end

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local AFKDetector = {}

--- Registers input activity for a player. Called when any input is received
--- (fire, move, ability use, etc.). Resets the AFK timer and cancels warnings.
function AFKDetector.registerInput(player: Player): ()
	local state = afkStates[player]
	if not state then
		return
	end

	state.lastInputTime = os.clock()

	-- If the player was in warning state, cancel the warning and resume tracking
	if state.warned then
		state.warned = false

		-- Resume ChestService playtime tracking
		local chestSvc = getChestService()
		if chestSvc then
			chestSvc.resumePlaytime(player)
		end
	end
end

--- Enables or disables AFK detection for a player.
--- Should be called when a player enters/exits an active match.
function AFKDetector.setMatchActive(player: Player, active: boolean): ()
	local state = afkStates[player]
	if not state then
		return
	end

	state.matchActive = active

	if active then
		-- Reset timer when match starts
		state.lastInputTime = os.clock()
		state.warned = false
	else
		-- Clear warning state when leaving match
		if state.warned then
			state.warned = false
			local chestSvc = getChestService()
			if chestSvc then
				chestSvc.resumePlaytime(player)
			end
		end
	end
end

--- Returns whether a player is currently in the warning state.
function AFKDetector.isWarned(player: Player): boolean
	local state = afkStates[player]
	if state then
		return state.warned
	end
	return false
end

--- Returns the idle duration in seconds for a player.
function AFKDetector.getIdleDuration(player: Player): number
	local state = afkStates[player]
	if not state then
		return 0
	end
	return os.clock() - state.lastInputTime
end

--- Returns whether AFK detection is active for a player.
function AFKDetector.isMatchActive(player: Player): boolean
	local state = afkStates[player]
	if state then
		return state.matchActive
	end
	return false
end

----------------------------------------------------------------------
-- AFK Check Loop
----------------------------------------------------------------------

local timeSinceLastCheck = 0

RunService.Heartbeat:Connect(function(deltaTime: number)
	timeSinceLastCheck += deltaTime
	if timeSinceLastCheck < CHECK_INTERVAL then
		return
	end
	timeSinceLastCheck = 0

	local now = os.clock()

	for player, state in afkStates do
		-- Only check players in active matches
		if not state.matchActive then
			continue
		end

		local idleDuration = now - state.lastInputTime

		-- Check for kick threshold (60 seconds)
		if idleDuration >= AFK_KICK_THRESHOLD then
			-- Remove from match - kick back to lobby
			task.spawn(function()
				-- Resume playtime tracking before removing
				local chestSvc = getChestService()
				if chestSvc and state.warned then
					chestSvc.resumePlaytime(player)
				end

				-- Disable match state
				state.matchActive = false
				state.warned = false

				-- Kick the player from the server
				player:Kick("You were removed for being AFK.")
			end)

		-- Check for warning threshold (45 seconds)
		elseif idleDuration >= AFK_WARNING_THRESHOLD and not state.warned then
			state.warned = true

			-- Pause ChestService playtime tracking during warning period
			local chestSvc = getChestService()
			if chestSvc then
				chestSvc.pausePlaytime(player)
			end

			-- Fire warning to client
			AFKWarningRemote:FireClient(player, AFK_KICK_THRESHOLD - AFK_WARNING_THRESHOLD)
		end
	end
end)

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player: Player)
	afkStates[player] = {
		lastInputTime = os.clock(),
		warned = false,
		matchActive = false,
	}
end)

Players.PlayerRemoving:Connect(function(player: Player)
	afkStates[player] = nil
end)

-- Initialize any players already in the game (for late script loading)
for _, player in Players:GetPlayers() do
	if not afkStates[player] then
		afkStates[player] = {
			lastInputTime = os.clock(),
			warned = false,
			matchActive = false,
		}
	end
end

----------------------------------------------------------------------

return AFKDetector
