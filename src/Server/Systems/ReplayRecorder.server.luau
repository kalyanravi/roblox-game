--!strict
--[[
	ReplayRecorder
	Records the last 10 seconds of match kill data on the server using a
	circular buffer. On match end, sends the final kill replay payload to
	all clients via the ReplayData RemoteEvent.
	
	Listens to KillRegistered BindableEvent from CombatService.
	Requirements: 15.1, 15.2, 15.4
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------

export type KillEventRecord = {
	killerName: string,
	victimName: string,
	weaponId: string,
	killerPosition: Vector3,
	victimPosition: Vector3,
	streakCount: number,
	timestamp: number,
}

export type ReplayPayload = {
	killerName: string,
	victimName: string,
	weaponId: string,
	killerPosition: Vector3,
	streakCount: number,
	timestamp: number,
}

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

-- Only keep events from the last 10 seconds
local REPLAY_WINDOW_SECONDS = 10

-- Maximum number of kill events to store in the circular buffer
-- (generous limit to handle rapid kills within 10-second window)
local BUFFER_MAX_SIZE = 64

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

-- Circular buffer of kill events
local killBuffer: { KillEventRecord } = {}
local bufferWriteIndex: number = 0
local bufferCount: number = 0

-- Per-player streak tracking for replay data
local playerStreaks: { [Player]: number } = {}

----------------------------------------------------------------------
-- RemoteEvent / BindableEvent Setup
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

local ReplayDataRemote = getOrCreateRemoteEvent("ReplayData")

-- Listen to KillRegistered BindableEvent from CombatService
local KillRegisteredEvent = ReplicatedStorage:WaitForChild("KillRegistered") :: BindableEvent

----------------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------------

--- Gets the position of a player's HumanoidRootPart, or Vector3.zero if unavailable.
local function getPlayerPosition(player: Player): Vector3
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			return rootPart.Position
		end
	end
	return Vector3.zero
end

-- Note: Old events are naturally filtered by timestamp in getReplayData().
-- The circular buffer overwrites stale entries, keeping memory minimal with O(1) writes.

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local ReplayRecorder = {}

--- Records a kill event into the circular buffer.
function ReplayRecorder.recordKillEvent(
	attacker: Player,
	victim: Player,
	weaponId: string,
	attackerPosition: Vector3,
	victimPosition: Vector3,
	timestamp: number
): ()
	-- Update streak tracking
	playerStreaks[attacker] = (playerStreaks[attacker] or 0) + 1
	playerStreaks[victim] = 0

	local record: KillEventRecord = {
		killerName = attacker.Name,
		victimName = victim.Name,
		weaponId = weaponId,
		killerPosition = attackerPosition,
		victimPosition = victimPosition,
		streakCount = playerStreaks[attacker] or 0,
		timestamp = timestamp,
	}

	-- Write to circular buffer
	bufferWriteIndex = (bufferWriteIndex % BUFFER_MAX_SIZE) + 1
	killBuffer[bufferWriteIndex] = record

	if bufferCount < BUFFER_MAX_SIZE then
		bufferCount += 1
	end
end

--- Returns the most recent kill event data within the last 10 seconds (the final kill payload).
function ReplayRecorder.getReplayData(): ReplayPayload?
	if bufferCount == 0 then
		return nil
	end

	local currentTime = os.clock()
	local cutoff = currentTime - REPLAY_WINDOW_SECONDS

	-- Search from the most recent entry backwards to find the latest valid event
	local index = bufferWriteIndex
	for _ = 1, bufferCount do
		local record = killBuffer[index]
		if record and record.timestamp >= cutoff then
			return {
				killerName = record.killerName,
				victimName = record.victimName,
				weaponId = record.weaponId,
				killerPosition = record.killerPosition,
				streakCount = record.streakCount,
				timestamp = record.timestamp,
			}
		end

		-- Move backwards in circular buffer
		index -= 1
		if index < 1 then
			index = BUFFER_MAX_SIZE
		end
	end

	-- No valid events within the replay window; return the most recent anyway (for match end)
	local lastRecord = killBuffer[bufferWriteIndex]
	if lastRecord then
		return {
			killerName = lastRecord.killerName,
			victimName = lastRecord.victimName,
			weaponId = lastRecord.weaponId,
			killerPosition = lastRecord.killerPosition,
			streakCount = lastRecord.streakCount,
			timestamp = lastRecord.timestamp,
		}
	end

	return nil
end

--- Sends the replay payload to all connected clients. Called on match end.
function ReplayRecorder.broadcastReplay(): ()
	local payload = ReplayRecorder.getReplayData()
	if not payload then
		return
	end

	ReplayDataRemote:FireAllClients(payload)
end

--- Resets the replay buffer. Call at match start to clear previous match data.
function ReplayRecorder.reset(): ()
	killBuffer = {}
	bufferWriteIndex = 0
	bufferCount = 0

	-- Reset streaks
	for player in playerStreaks do
		playerStreaks[player] = 0
	end
end

--- Returns the current streak count for a player (used internally).
function ReplayRecorder.getStreakCount(player: Player): number
	return playerStreaks[player] or 0
end

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

-- Listen to KillRegistered from CombatService
-- CombatService fires: KillRegisteredEvent:Fire(attacker, victim, weaponId, isHeadshot)
KillRegisteredEvent.Event:Connect(function(attacker: Player, victim: Player, weaponId: string, _isHeadshot: boolean)
	local attackerPosition = getPlayerPosition(attacker)
	local victimPosition = getPlayerPosition(victim)
	local timestamp = os.clock()

	ReplayRecorder.recordKillEvent(attacker, victim, weaponId, attackerPosition, victimPosition, timestamp)
end)

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player: Player)
	playerStreaks[player] = 0
end)

Players.PlayerRemoving:Connect(function(player: Player)
	playerStreaks[player] = nil
end)

-- Initialize any players already in the game (for late script loading)
for _, player in Players:GetPlayers() do
	if playerStreaks[player] == nil then
		playerStreaks[player] = 0
	end
end

----------------------------------------------------------------------

return ReplayRecorder
