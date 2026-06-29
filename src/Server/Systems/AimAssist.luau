--!strict
--[[
	AimAssist
	Provides slight aim magnetism for Mobile platform players at Level 20+.
	PC and Console players NEVER receive aim assist (hard restriction).
	Requirements: 19.3, 19.4
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local AIM_ASSIST_CONE_ANGLE = math.rad(10) -- 10-degree cone half-angle
local AIM_ASSIST_PULL_MIN = 0.05 -- 5% pull toward target
local AIM_ASSIST_PULL_MAX = 0.15 -- 15% pull toward target
local ELIGIBLE_LEVEL = 20
local ELIGIBLE_PLATFORM = "Mobile"

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

-- Tracks each player's platform (set via ReportPlatform RemoteEvent)
local playerPlatforms: { [Player]: string } = {}

----------------------------------------------------------------------
-- RemoteEvent for platform reporting
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

local ReportPlatformRemote = getOrCreateRemoteEvent("ReportPlatform")

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local AimAssist = {}

--- Checks if a player is eligible for aim assist.
--- Must be on Mobile platform AND level >= 20.
function AimAssist.isEligible(player: Player): boolean
	-- Check platform from stored value or player attribute
	local platform = playerPlatforms[player] or player:GetAttribute("Platform")
	if platform ~= ELIGIBLE_PLATFORM then
		return false
	end

	-- Check level (stored as player attribute by ProgressionEngine)
	local level = player:GetAttribute("Level")
	if typeof(level) ~= "number" or level < ELIGIBLE_LEVEL then
		return false
	end

	return true
end

--- Applies aim assist by slightly adjusting aim direction toward the nearest
--- enemy within a cone. Only works for eligible Mobile players.
--- Returns the adjusted direction (or original if no assist applied).
function AimAssist.applyAimAssist(player: Player, aimOrigin: Vector3, aimDirection: Vector3): Vector3
	-- Hard restriction: only eligible mobile players
	if not AimAssist.isEligible(player) then
		return aimDirection
	end

	local normalizedAim = aimDirection.Unit

	-- Find nearest enemy within the aim cone
	local bestTarget: Vector3? = nil
	local bestAngle = AIM_ASSIST_CONE_ANGLE -- Only consider targets within cone

	for _, otherPlayer in Players:GetPlayers() do
		-- Skip self
		if otherPlayer == player then
			continue
		end

		-- Skip teammates (if on same team)
		if player.Team and otherPlayer.Team and player.Team == otherPlayer.Team then
			continue
		end

		local otherChar = otherPlayer.Character
		if not otherChar then
			continue
		end

		-- Target the torso (UpperTorso or Torso depending on rig)
		local torso = otherChar:FindFirstChild("UpperTorso") or otherChar:FindFirstChild("Torso")
		if not torso or not torso:IsA("BasePart") then
			continue
		end

		-- Check if target humanoid is alive
		local humanoid = otherChar:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end

		local targetPosition = torso.Position
		local toTarget = (targetPosition - aimOrigin)
		local distanceToTarget = toTarget.Magnitude

		-- Skip if target is too close (avoid division issues)
		if distanceToTarget < 1 then
			continue
		end

		local directionToTarget = toTarget.Unit

		-- Calculate angle between aim direction and direction to target
		local dotProduct = math.clamp(normalizedAim:Dot(directionToTarget), -1, 1)
		local angle = math.acos(dotProduct)

		-- Check if within cone and closer than current best
		if angle < bestAngle then
			bestAngle = angle
			bestTarget = targetPosition
		end
	end

	-- If no target found in cone, return original direction
	if not bestTarget then
		return aimDirection
	end

	-- Calculate adjusted direction with magnetism pull
	-- Pull strength scales inversely with angle (closer to center = stronger pull)
	local pullStrength = AIM_ASSIST_PULL_MIN + (AIM_ASSIST_PULL_MAX - AIM_ASSIST_PULL_MIN) * (1 - bestAngle / AIM_ASSIST_CONE_ANGLE)

	local directionToTarget = (bestTarget - aimOrigin).Unit
	local adjustedDirection = (normalizedAim * (1 - pullStrength) + directionToTarget * pullStrength).Unit

	return adjustedDirection
end

--- Returns the platform string for a player (for testing/debugging).
function AimAssist.getPlayerPlatform(player: Player): string?
	return playerPlatforms[player] or player:GetAttribute("Platform") :: string?
end

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

-- Listen for clients reporting their platform on join
ReportPlatformRemote.OnServerEvent:Connect(function(player: Player, platform: any)
	-- Validate input
	if typeof(platform) ~= "string" then
		return
	end

	-- Only accept known platform values
	if platform ~= "Mobile" and platform ~= "PC" and platform ~= "Console" then
		return
	end

	playerPlatforms[player] = platform
	player:SetAttribute("Platform", platform)
end)

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player: Player)
	playerPlatforms[player] = nil
end)

----------------------------------------------------------------------

return AimAssist
