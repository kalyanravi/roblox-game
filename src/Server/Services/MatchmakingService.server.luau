--!strict
--[[
	MatchmakingService
	Groups players into appropriate match lobbies based on mode and team size.
	Auto-starts matches when enough players are queued or after 30 seconds
	with available players.
	Requirements: 3.7
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------

export type QueueMode = "TDM" | "FFA"

type QueueEntry = {
	players: { Player },
	startTime: number,
}

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

-- Maximum wait time before starting a match with available players
local QUEUE_TIMEOUT = 30

-- Default team sizes for TDM mode
local DEFAULT_TDM_TEAM_SIZE = 5

-- Default max players for FFA mode
local DEFAULT_FFA_MAX_PLAYERS = 10

-- How often the queue check loop runs (seconds)
local QUEUE_CHECK_INTERVAL = 1

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

-- Per-mode queues: { mode_teamSize: { players: {Player}, startTime: number } }
local queues: { [string]: QueueEntry } = {}

-- Tracks which queue a player is currently in: { [Player]: queueKey }
local playerQueueMap: { [Player]: string } = {}

----------------------------------------------------------------------
-- RemoteEvent Setup
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

local JoinQueueRemote = getOrCreateRemoteEvent("JoinQueue")

----------------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------------

--- Generates a unique queue key based on mode and team size.
local function getQueueKey(mode: QueueMode, teamSize: number?): string
	if mode == "TDM" then
		local size = teamSize or DEFAULT_TDM_TEAM_SIZE
		return mode .. "_" .. tostring(size)
	end
	return mode .. "_0"
end

--- Returns the required player count for a queue to be considered full.
local function getRequiredPlayers(mode: QueueMode, teamSize: number?): number
	if mode == "TDM" then
		local size = teamSize or DEFAULT_TDM_TEAM_SIZE
		return size * 2 -- Two teams
	end
	return DEFAULT_FFA_MAX_PLAYERS
end

--- Returns the minimum player count to start a match after timeout.
local function getMinimumPlayers(mode: QueueMode): number
	if mode == "TDM" then
		return 2 -- At least 1v1
	end
	return 2 -- At least 2 players for FFA
end

--- Removes a player from the queue's player list.
local function removePlayerFromQueueList(queueEntry: QueueEntry, player: Player): ()
	for i, p in queueEntry.players do
		if p == player then
			table.remove(queueEntry.players, i)
			break
		end
	end
end

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local MatchmakingService = {}

--- Adds a player to the matchmaking queue for the specified mode.
function MatchmakingService.joinQueue(player: Player, mode: QueueMode, teamSize: number?): ()
	-- If already in a queue, remove first
	if playerQueueMap[player] then
		MatchmakingService.leaveQueue(player)
	end

	local key = getQueueKey(mode, teamSize)

	-- Create the queue if it doesn't exist
	if not queues[key] then
		queues[key] = {
			players = {},
			startTime = os.clock(),
		}
	end

	local queue = queues[key]
	table.insert(queue.players, player)
	playerQueueMap[player] = key

	-- Check if the queue is now full (enough players to start immediately)
	local requiredPlayers = getRequiredPlayers(mode, teamSize)
	if #queue.players >= requiredPlayers then
		MatchmakingService.startMatch(key, mode, teamSize)
	end
end

--- Removes a player from their current queue.
function MatchmakingService.leaveQueue(player: Player): ()
	local key = playerQueueMap[player]
	if not key then
		return
	end

	local queue = queues[key]
	if queue then
		removePlayerFromQueueList(queue, player)

		-- Clean up empty queues
		if #queue.players == 0 then
			queues[key] = nil
		end
	end

	playerQueueMap[player] = nil
end

--- Starts a match with players currently in the specified queue.
--- Called either when the queue is full or the timeout expires with enough players.
function MatchmakingService.startMatch(queueKey: string, mode: QueueMode, teamSize: number?): ()
	local queue = queues[queueKey]
	if not queue or #queue.players == 0 then
		return
	end

	local requiredPlayers = getRequiredPlayers(mode, teamSize)
	local matchPlayers: { Player } = {}

	-- Take up to the required number of players from the queue
	local count = math.min(#queue.players, requiredPlayers)
	for i = 1, count do
		local player = queue.players[1]
		table.remove(queue.players, 1)
		playerQueueMap[player] = nil
		table.insert(matchPlayers, player)
	end

	-- Clean up the queue if empty
	if #queue.players == 0 then
		queues[queueKey] = nil
	else
		-- Reset start time for remaining players
		queue.startTime = os.clock()
	end

	-- TODO: Wire to MatchService.createMatch() and add players
	-- For now, log the match start (integration wiring in task 12.1)
	print(
		string.format(
			"[MatchmakingService] Starting %s match with %d players (teamSize: %s)",
			mode,
			#matchPlayers,
			tostring(teamSize or "N/A")
		)
	)
end

--- Returns the current queue state for a given mode/teamSize.
function MatchmakingService.getQueueInfo(mode: QueueMode, teamSize: number?): { players: { Player }, startTime: number }?
	local key = getQueueKey(mode, teamSize)
	return queues[key]
end

--- Returns whether a player is currently in a queue.
function MatchmakingService.isInQueue(player: Player): boolean
	return playerQueueMap[player] ~= nil
end

--- Returns all active queues (for debugging/admin).
function MatchmakingService.getActiveQueues(): { [string]: QueueEntry }
	return queues
end

----------------------------------------------------------------------
-- Queue Timeout Loop
----------------------------------------------------------------------

-- Periodically checks queues that have been waiting longer than QUEUE_TIMEOUT
-- and starts matches with available players if minimum requirements are met.
task.spawn(function()
	while true do
		task.wait(QUEUE_CHECK_INTERVAL)

		local currentTime = os.clock()

		for key, queue in queues do
			local elapsed = currentTime - queue.startTime

			if elapsed >= QUEUE_TIMEOUT and #queue.players > 0 then
				-- Parse mode from the queue key (format: "MODE_teamSize")
				local mode: QueueMode = "FFA"
				local teamSize: number? = nil

				local underscorePos = string.find(key, "_")
				if underscorePos then
					local modeStr = string.sub(key, 1, underscorePos - 1)
					local sizeStr = string.sub(key, underscorePos + 1)

					if modeStr == "TDM" then
						mode = "TDM"
						teamSize = tonumber(sizeStr)
					else
						mode = "FFA"
					end
				end

				-- Check if we have at least the minimum players
				local minPlayers = getMinimumPlayers(mode)
				if #queue.players >= minPlayers then
					MatchmakingService.startMatch(key, mode, teamSize)
				end
			end
		end
	end
end)

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

-- Wire JoinQueue RemoteEvent
-- Clients send: { mode: "TDM" | "FFA", teamSize: number? }
JoinQueueRemote.OnServerEvent:Connect(function(player: Player, mode: any, teamSize: any)
	-- Validate mode
	if mode ~= "TDM" and mode ~= "FFA" then
		return
	end

	-- Validate teamSize (optional, must be a number 1-5 if provided)
	local validTeamSize: number? = nil
	if teamSize ~= nil then
		if typeof(teamSize) ~= "number" then
			return
		end
		local size = math.floor(teamSize :: number)
		if size < 1 or size > 5 then
			return
		end
		validTeamSize = size
	end

	MatchmakingService.joinQueue(player, mode :: QueueMode, validTeamSize)
end)

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player: Player)
	MatchmakingService.leaveQueue(player)
end)

----------------------------------------------------------------------

return MatchmakingService
