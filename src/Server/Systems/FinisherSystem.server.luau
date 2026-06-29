--!strict
--[[
	FinisherSystem
	Manages equipped kill effects that play on special kills (final kill of match,
	kill streak milestones at 3, 5, 7, 10). Regular kills use standard ragdoll on client.
	
	Listens to KillRegistered BindableEvent from CombatService.
	Fires PlayFinisher RemoteEvent to nearby clients for VFX rendering.
	
	Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FinisherDefinitions = require(Shared:WaitForChild("Definitions"):WaitForChild("FinisherDefinitions"))

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

-- Kill streak milestones that trigger a finisher
local STREAK_MILESTONES: { number } = { 3, 5, 7, 10 }

-- Maximum distance (studs) from victim for a client to receive the finisher event
local FINISHER_BROADCAST_RADIUS = 150

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

-- Tracks the equipped finisher per player: { [Player]: finisherId }
local equippedFinishers: { [Player]: string } = {}

-- Tracks current kill streak per player (incremented on kill, reset on death)
local killStreaks: { [Player]: number } = {}

-- Tracks the last kill data so match end can trigger finisher on the final kill
local lastKillData: {
	attacker: Player?,
	victim: Player?,
	weaponId: string?,
	streak: number?,
} = {
	attacker = nil,
	victim = nil,
	weaponId = nil,
	streak = nil,
}

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

local PlayFinisherRemote = getOrCreateRemoteEvent("PlayFinisher")

----------------------------------------------------------------------
-- Helper: Find finisher definition by ID
----------------------------------------------------------------------

local function getFinisherDef(finisherId: string): { effectType: string, duration: number }?
	for _, def in FinisherDefinitions do
		if def.id == finisherId then
			return { effectType = def.effectType, duration = def.duration }
		end
	end
	return nil
end

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local FinisherSystem = {}

--- Sets the equipped finisher for a player.
function FinisherSystem.setEquippedFinisher(player: Player, finisherId: string): ()
	equippedFinishers[player] = finisherId
end

--- Gets the equipped finisher for a player (or nil if none).
function FinisherSystem.getEquippedFinisher(player: Player): string?
	return equippedFinishers[player]
end

--- Determines whether a finisher should play for this kill.
--- Returns true if: player has a finisher equipped AND (isLastKill OR currentStreak is a milestone: 3, 5, 7, 10)
function FinisherSystem.shouldPlayFinisher(player: Player, isLastKill: boolean, currentStreak: number): boolean
	-- Must have a finisher equipped
	if not equippedFinishers[player] then
		return false
	end

	-- Play on final kill of match
	if isLastKill then
		return true
	end

	-- Play on streak milestone kills
	for _, milestone in STREAK_MILESTONES do
		if currentStreak == milestone then
			return true
		end
	end

	return false
end

--- Fires the PlayFinisher RemoteEvent to all clients near the victim.
--- Sends the finisher effectType and duration so the client can render VFX.
function FinisherSystem.triggerFinisher(attacker: Player, victim: Player): ()
	local finisherId = equippedFinishers[attacker]
	if not finisherId then
		return
	end

	local finisherDef = getFinisherDef(finisherId)
	if not finisherDef then
		return
	end

	-- Get victim position for proximity broadcast
	local victimPosition: Vector3? = nil
	local victimCharacter = victim.Character
	if victimCharacter then
		local rootPart = victimCharacter:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			victimPosition = rootPart.Position
		end
	end

	-- Build payload for clients
	local payload = {
		attacker = attacker.Name,
		victim = victim.Name,
		effectType = finisherDef.effectType,
		duration = finisherDef.duration,
	}

	-- Fire to all players near the victim (or all players if no position available)
	for _, player in Players:GetPlayers() do
		if victimPosition then
			local playerCharacter = player.Character
			if playerCharacter then
				local playerRoot = playerCharacter:FindFirstChild("HumanoidRootPart")
				if playerRoot and playerRoot:IsA("BasePart") then
					local distance = (playerRoot.Position - victimPosition).Magnitude
					if distance <= FINISHER_BROADCAST_RADIUS then
						PlayFinisherRemote:FireClient(player, payload)
					end
				else
					-- Player has no root part (e.g., dead/respawning), send anyway
					PlayFinisherRemote:FireClient(player, payload)
				end
			else
				-- No character, send anyway (spectating, etc.)
				PlayFinisherRemote:FireClient(player, payload)
			end
		else
			-- No victim position available, broadcast to all
			PlayFinisherRemote:FireClient(player, payload)
		end
	end
end

--- Handles a kill event from CombatService.
--- Updates streaks, stores last kill data, and triggers finisher if applicable.
local function onKillRegistered(attacker: Player, victim: Player, weaponId: string, _isHeadshot: boolean): ()
	-- Update attacker's kill streak
	local currentStreak = (killStreaks[attacker] or 0) + 1
	killStreaks[attacker] = currentStreak

	-- Reset victim's streak
	killStreaks[victim] = 0

	-- Store as last kill (for final-kill finisher on match end)
	lastKillData.attacker = attacker
	lastKillData.victim = victim
	lastKillData.weaponId = weaponId
	lastKillData.streak = currentStreak

	-- Determine if a finisher should play (not final kill here — that's triggered on match end)
	-- For regular gameplay, only streak milestones trigger a finisher
	local isLastKill = false -- Will be set to true only when match ends
	if FinisherSystem.shouldPlayFinisher(attacker, isLastKill, currentStreak) then
		FinisherSystem.triggerFinisher(attacker, victim)
	end
	-- If shouldPlayFinisher returns false, the client plays standard ragdoll (Req 14.5)
end

--- Called when a match ends to trigger the finisher on the final kill.
--- This should be invoked by the match system when the match transitions to "Ending".
function FinisherSystem.onMatchEnd(): ()
	local attacker = lastKillData.attacker
	local victim = lastKillData.victim

	if attacker and victim then
		local streak = lastKillData.streak or 0
		-- Check if a finisher should play on the final kill
		if FinisherSystem.shouldPlayFinisher(attacker, true, streak) then
			FinisherSystem.triggerFinisher(attacker, victim)
		end
	end
end

--- Resets last kill data (call at match start or between matches).
function FinisherSystem.resetMatchData(): ()
	lastKillData.attacker = nil
	lastKillData.victim = nil
	lastKillData.weaponId = nil
	lastKillData.streak = nil

	-- Reset all streaks
	for player in killStreaks do
		killStreaks[player] = 0
	end
end

--- Gets the current kill streak for a player.
function FinisherSystem.getCurrentStreak(player: Player): number
	return killStreaks[player] or 0
end

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

-- Listen to KillRegistered BindableEvent from CombatService
local KillRegisteredEvent = ReplicatedStorage:WaitForChild("KillRegistered") :: BindableEvent
KillRegisteredEvent.Event:Connect(onKillRegistered)

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player: Player)
	killStreaks[player] = 0
end)

Players.PlayerRemoving:Connect(function(player: Player)
	equippedFinishers[player] = nil
	killStreaks[player] = nil
end)

-- Initialize any players already in the game (for late script loading)
for _, player in Players:GetPlayers() do
	if killStreaks[player] == nil then
		killStreaks[player] = 0
	end
end

----------------------------------------------------------------------

return FinisherSystem
