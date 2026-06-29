--!strict
--[[
	PingSystem
	Handles team communication via world pings and quick callouts.
	Pings broadcast a world position to teammates for 5 seconds.
	Callouts display pre-set messages in the chat feed.
	Rate limited to 1 ping per 3 seconds per player.
	Requirements: 17.1, 17.2, 17.3, 17.4, 17.5
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local PING_COOLDOWN = Constants.PING_COOLDOWN -- 3 seconds
local PING_DURATION = 5 -- seconds a ping remains visible

local VALID_CALLOUTS: { [string]: string } = {
	enemy_spotted = "Enemy Spotted",
	need_backup = "Need Backup",
	push_now = "Push Now",
	fall_back = "Fall Back",
	healing = "Healing",
	nice_shot = "Nice Shot",
}

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

-- Last ping time per player (for rate limiting)
local lastPingTime: { [Player]: number } = {}

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

-- Client fires this to request a world ping
local SendPingRemote = getOrCreateRemoteEvent("SendPing")

-- Client fires this to request a callout
local SendCalloutRemote = getOrCreateRemoteEvent("SendCallout")

-- Server fires this to display a ping on teammates' screens
local PingBroadcastRemote = getOrCreateRemoteEvent("PingBroadcast")

-- Server fires this to display a callout to teammates
local CalloutBroadcastRemote = getOrCreateRemoteEvent("CalloutBroadcast")

----------------------------------------------------------------------
-- Internal Helpers
----------------------------------------------------------------------

--- Returns the team of a player, or nil if not on a team.
local function getPlayerTeam(player: Player): Team?
	return player.Team
end

--- Returns all teammates of a player (excluding the player themselves).
local function getTeammates(player: Player): { Player }
	local team = getPlayerTeam(player)
	if not team then
		return {}
	end

	local teammates: { Player } = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Team == team then
			table.insert(teammates, other)
		end
	end
	return teammates
end

--- Checks if a player is within the rate limit cooldown.
local function isOnCooldown(player: Player): boolean
	local lastTime = lastPingTime[player]
	if not lastTime then
		return false
	end
	return (os.clock() - lastTime) < PING_COOLDOWN
end

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local PingSystem = {}

--- Broadcasts a world-position ping to all teammates for 5 seconds.
--- Rate limited to 1 ping per 3 seconds.
function PingSystem.sendPing(player: Player, worldPosition: Vector3): boolean
	-- Reject if on cooldown
	if isOnCooldown(player) then
		return false
	end

	-- Must be on a team to ping
	local team = getPlayerTeam(player)
	if not team then
		return false
	end

	-- Update last ping time
	lastPingTime[player] = os.clock()

	-- Broadcast to all teammates
	local teammates = getTeammates(player)
	for _, teammate in teammates do
		PingBroadcastRemote:FireClient(teammate, player.Name, worldPosition, PING_DURATION)
	end

	return true
end

--- Broadcasts a pre-set callout message to all teammates in the chat feed.
--- Rate limited using the same cooldown as pings.
function PingSystem.sendCallout(player: Player, calloutId: string): boolean
	-- Validate callout ID
	local displayMessage = VALID_CALLOUTS[calloutId]
	if not displayMessage then
		return false
	end

	-- Reject if on cooldown
	if isOnCooldown(player) then
		return false
	end

	-- Must be on a team to callout
	local team = getPlayerTeam(player)
	if not team then
		return false
	end

	-- Update last ping time (shares cooldown with pings)
	lastPingTime[player] = os.clock()

	-- Broadcast callout to all teammates
	local teammates = getTeammates(player)
	for _, teammate in teammates do
		CalloutBroadcastRemote:FireClient(teammate, player.Name, calloutId, displayMessage)
	end

	return true
end

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

SendPingRemote.OnServerEvent:Connect(function(player: Player, worldPosition: unknown)
	-- Validate input
	if typeof(worldPosition) ~= "Vector3" then
		return
	end
	PingSystem.sendPing(player, worldPosition :: Vector3)
end)

SendCalloutRemote.OnServerEvent:Connect(function(player: Player, calloutId: unknown)
	-- Validate input
	if typeof(calloutId) ~= "string" then
		return
	end
	PingSystem.sendCallout(player, calloutId :: string)
end)

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player: Player)
	lastPingTime[player] = nil
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastPingTime[player] = nil
end)

----------------------------------------------------------------------

return PingSystem
