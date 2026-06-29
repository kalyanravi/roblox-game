--!strict
--[[
	GameLoop
	Manages the FFA match lifecycle: auto-start, death/respawn handling,
	kill feed, and match restart.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Services = Server:WaitForChild("Services")
local Systems = Server:WaitForChild("Systems")

local MatchService = require(Services:WaitForChild("MatchService"))
local CombatService = require(Services:WaitForChild("CombatService"))
local SpawnSystem = require(Systems:WaitForChild("SpawnSystem"))
local MapSystem = require(Systems:WaitForChild("MapSystem"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

----------------------------------------------------------------------
-- Remotes
----------------------------------------------------------------------

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local KillFeedRemote = Remotes:WaitForChild("KillFeed") :: RemoteEvent

----------------------------------------------------------------------
-- BindableEvents
----------------------------------------------------------------------

local KillRegisteredEvent = ReplicatedStorage:WaitForChild("KillRegistered") :: BindableEvent

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local currentMatchId: string? = nil
local matchActive: boolean = false
local MATCH_DURATION = Constants.MATCH_DURATION -- 300 seconds (5 minutes)
local RESTART_DELAY = 10

----------------------------------------------------------------------
-- Module
----------------------------------------------------------------------

local GameLoop = {}

--[[
	Gets enemy positions for spawn point selection (all alive players except the respawning one).
]]
local function getEnemyPositions(excludePlayer: Player): { Vector3 }
	local positions: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		if player ~= excludePlayer and player.Character then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				table.insert(positions, hrp.Position)
			end
		end
	end
	return positions
end

--[[
	Respawns a player at a smart spawn point after the respawn timer.
]]
local function respawnPlayer(player: Player)
	SpawnSystem.startRespawnTimer(player, function()
		if not player or not player.Parent then
			return
		end

		-- Get best spawn point away from enemies
		local mapId = MapSystem.getCurrentMap()
		local enemyPositions = getEnemyPositions(player)
		local spawnCFrame = SpawnSystem.getSpawnPoint(player, mapId, enemyPositions)

		-- Load character at the spawn point
		player:LoadCharacter()

		-- Wait for character to load
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		if humanoidRootPart then
			humanoidRootPart.CFrame = spawnCFrame
		end

		-- Apply spawn protection
		SpawnSystem.applySpawnProtection(player)

		-- Restore combat state
		CombatService.respawnPlayer(player)
	end)
end

--[[
	Hooks up death detection for a player's character.
]]
local function hookCharacterDeath(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end

	humanoid.Died:Connect(function()
		if not currentMatchId or not matchActive then
			-- Still respawn even outside a match
			respawnPlayer(player)
			return
		end

		-- Record death in match
		MatchService.addDeath(currentMatchId :: string, player)

		-- Respawn after timer
		respawnPlayer(player)
	end)
end

--[[
	Broadcasts a kill feed notification to all players.
]]
local function broadcastKillFeed(attacker: Player, victim: Player, weaponId: string, isHeadshot: boolean)
	local payload = {
		attackerName = attacker.DisplayName,
		victimName = victim.DisplayName,
		weaponId = weaponId,
		isHeadshot = isHeadshot,
	}

	for _, player in Players:GetPlayers() do
		KillFeedRemote:FireClient(player, payload)
	end
end

--[[
	Starts a new FFA match.
]]
function GameLoop.startMatch()
	-- Create FFA match config
	local matchId = MatchService.createMatch({
		mode = "FFA",
		teamSize = 1,
		maxPlayers = 10,
		timeLimit = MATCH_DURATION,
		mapId = MapSystem.getCurrentMap(),
		weaponRestrictions = nil,
	})

	currentMatchId = matchId

	-- Add all current players to the match
	for _, player in Players:GetPlayers() do
		MatchService.addPlayer(matchId, player)
	end

	-- Start countdown then activate
	MatchService.startCountdown(matchId)
	matchActive = true

	print("[GameLoop] Match started: " .. matchId)

	-- Monitor match end (time-based ending is handled by MatchService timer)
	-- We poll for state change to "Results" to trigger restart
	task.spawn(function()
		while matchActive do
			task.wait(1)
			if not currentMatchId then
				break
			end

			local state = MatchService.getMatchState(currentMatchId :: string)
			if state == "Results" or state == "Ending" then
				matchActive = false
				break
			end
		end

		-- Match ended — show results briefly then restart
		task.wait(RESTART_DELAY)

		-- Cleanup old match
		if currentMatchId then
			MatchService.cleanupMatch(currentMatchId :: string)
			currentMatchId = nil
		end

		-- Rotate map and start new match
		MapSystem.rotateMap()
		GameLoop.startMatch()
	end)
end

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

-- Handle kills: update match stats and broadcast kill feed
KillRegisteredEvent.Event:Connect(function(attacker: Player, victim: Player, weaponId: string, isHeadshot: boolean)
	if currentMatchId and matchActive then
		MatchService.addKill(currentMatchId :: string, attacker)
	end

	-- Broadcast kill feed to all players
	broadcastKillFeed(attacker, victim, weaponId, isHeadshot)
end)

-- Handle player added: hook death, add to match if active
Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		hookCharacterDeath(player, character)
	end)

	-- If a match is active, add the joining player
	if currentMatchId and matchActive then
		MatchService.addPlayer(currentMatchId :: string, player)
	end

	-- Auto-start match if this is the first player and no match running
	if not matchActive and #Players:GetPlayers() >= 1 then
		task.wait(2) -- Brief delay to let everything initialize
		if not matchActive then
			GameLoop.startMatch()
		end
	end
end)

-- Handle player removing: clean up from match
Players.PlayerRemoving:Connect(function(player: Player)
	if currentMatchId then
		MatchService.removePlayer(currentMatchId :: string, player)
	end
end)

----------------------------------------------------------------------
-- Initialize: hook existing players (for late script loading)
----------------------------------------------------------------------

for _, player in Players:GetPlayers() do
	if player.Character then
		hookCharacterDeath(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character: Model)
		hookCharacterDeath(player, character)
	end)
end

-- If players are already in game, auto-start
if #Players:GetPlayers() >= 1 and not matchActive then
	task.spawn(function()
		task.wait(3)
		if not matchActive and #Players:GetPlayers() >= 1 then
			GameLoop.startMatch()
		end
	end)
end

return GameLoop
