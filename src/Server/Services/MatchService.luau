--!strict
--[[
	MatchService
	Controls match lifecycle from creation through results.
	Supports Team Deathmatch (1v1–5v5) and Free-for-All (2–10 players).
	Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.7, 3.8
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Types = require(Shared:WaitForChild("Types"):WaitForChild("MatchTypes"))

--[[ Types ]]

export type MatchState = "Waiting" | "Countdown" | "Active" | "Ending" | "Results"
export type MatchMode = "TDM" | "FFA"

export type MatchConfig = {
	mode: MatchMode,
	teamSize: number,
	maxPlayers: number,
	timeLimit: number,
	mapId: string,
	weaponRestrictions: { string }?,
}

export type PlayerMatchStats = {
	kills: number,
	deaths: number,
	assists: number,
	damageDealt: number,
	highestStreak: number,
	headshotKills: number,
}

export type MatchSession = {
	matchId: string,
	config: MatchConfig,
	state: MatchState,
	startTime: number,
	endTime: number?,
	timeRemaining: number,
	teams: { [string]: { Player } }?,
	players: { Player },
	scores: { [string]: number },
	playerStats: { [string]: PlayerMatchStats },
	streaks: { [string]: number },
	lastKillData: {
		attacker: Player?,
		victim: Player?,
		weaponId: string?,
		timestamp: number?,
	}?,
}

--[[ State ]]

local activeMatches: { [string]: MatchSession } = {}
local matchTimerThreads: { [string]: thread } = {}

--[[ Remote Setup ]]

local function getOrCreateRemoteEvent(name: string): RemoteEvent
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end

	return remote :: RemoteEvent
end

local MatchStateRemote = getOrCreateRemoteEvent("MatchState")

--[[ Helper Functions ]]

local function generateMatchId(): string
	return HttpService:GenerateGUID(false)
end

local function createDefaultStats(): PlayerMatchStats
	return {
		kills = 0,
		deaths = 0,
		assists = 0,
		damageDealt = 0,
		highestStreak = 0,
		headshotKills = 0,
	}
end

local function getPlayerKey(player: Player): string
	return tostring(player.UserId)
end

local function broadcastMatchState(match: MatchSession)
	local payload = {
		matchId = match.matchId,
		state = match.state,
		timeRemaining = match.timeRemaining,
		scores = match.scores,
		mode = match.config.mode,
	}

	for _, player in match.players do
		if player and player.Parent then
			MatchStateRemote:FireClient(player, payload)
		end
	end
end

--[[ Match Timer ]]

-- Forward declare MatchService so the timer can call endMatch
local MatchService = {}

local function startMatchTimer(matchId: string)
	local timerThread = task.spawn(function()
		local match = activeMatches[matchId]
		if not match then
			return
		end

		while match.state == "Active" and match.timeRemaining > 0 do
			task.wait(1)
			match = activeMatches[matchId]
			if not match or match.state ~= "Active" then
				break
			end

			match.timeRemaining -= 1
			broadcastMatchState(match)

			if match.timeRemaining <= 0 then
				MatchService.endMatch(matchId)
				break
			end
		end
	end)

	matchTimerThreads[matchId] = timerThread
end

--[[ MatchService Module ]]

--[[
	Creates a new match session with the given configuration.
	Returns a unique matchId string.
]]
function MatchService.createMatch(config: MatchConfig): string
	local matchId = generateMatchId()

	local timeLimit = config.timeLimit
	if timeLimit <= 0 then
		timeLimit = Constants.MATCH_DURATION
	end

	local match: MatchSession = {
		matchId = matchId,
		config = {
			mode = config.mode,
			teamSize = config.teamSize,
			maxPlayers = config.maxPlayers,
			timeLimit = timeLimit,
			mapId = config.mapId,
			weaponRestrictions = config.weaponRestrictions,
		},
		state = "Waiting" :: MatchState,
		startTime = 0,
		endTime = nil,
		timeRemaining = timeLimit,
		teams = if config.mode == "TDM" then {} else nil,
		players = {},
		scores = {},
		playerStats = {},
		streaks = {},
		lastKillData = nil,
	}

	activeMatches[matchId] = match
	return matchId
end

--[[
	Adds a player to a match. For TDM, optionally assigns to a team.
]]
function MatchService.addPlayer(matchId: string, player: Player, teamName: string?)
	local match = activeMatches[matchId]
	if not match then
		warn("[MatchService] Match not found: " .. matchId)
		return
	end

	if match.state ~= "Waiting" and match.state ~= "Countdown" then
		warn("[MatchService] Cannot add player during state: " .. match.state)
		return
	end

	table.insert(match.players, player)
	local key = getPlayerKey(player)
	match.playerStats[key] = createDefaultStats()
	match.scores[key] = 0
	match.streaks[key] = 0

	-- Assign to team if TDM
	if match.config.mode == "TDM" and match.teams then
		local team = teamName or "TeamA"
		if not match.teams[team] then
			match.teams[team] = {}
		end
		table.insert(match.teams[team], player)
	end
end

--[[
	Starts the 5-second countdown before the match becomes Active.
]]
function MatchService.startCountdown(matchId: string)
	local match = activeMatches[matchId]
	if not match then
		warn("[MatchService] Match not found: " .. matchId)
		return
	end

	if match.state ~= "Waiting" then
		warn("[MatchService] Cannot start countdown from state: " .. match.state)
		return
	end

	match.state = "Countdown"
	broadcastMatchState(match)

	task.spawn(function()
		-- 5-second countdown
		for i = 5, 1, -1 do
			local currentMatch = activeMatches[matchId]
			if not currentMatch or currentMatch.state ~= "Countdown" then
				return
			end
			task.wait(1)
		end

		local currentMatch = activeMatches[matchId]
		if not currentMatch or currentMatch.state ~= "Countdown" then
			return
		end

		-- Transition to Active
		currentMatch.state = "Active"
		currentMatch.startTime = os.clock()
		broadcastMatchState(currentMatch)
		startMatchTimer(matchId)
	end)
end

--[[
	Ends the match — triggered when timer expires or manually.
	Transitions to "Ending" then "Results".
]]
function MatchService.endMatch(matchId: string)
	local match = activeMatches[matchId]
	if not match then
		warn("[MatchService] Match not found: " .. matchId)
		return
	end

	if match.state == "Ending" or match.state == "Results" then
		return
	end

	match.state = "Ending"
	match.endTime = os.clock()
	broadcastMatchState(match)

	-- Cancel timer thread if it exists
	local timerThread = matchTimerThreads[matchId]
	if timerThread then
		task.cancel(timerThread)
		matchTimerThreads[matchId] = nil
	end

	-- Brief delay before showing results
	task.spawn(function()
		task.wait(2)
		local currentMatch = activeMatches[matchId]
		if not currentMatch then
			return
		end
		currentMatch.state = "Results"
		broadcastMatchState(currentMatch)
	end)
end

--[[
	Increments kill score for a player (and team in TDM).
]]
function MatchService.addKill(matchId: string, player: Player, team: string?)
	local match = activeMatches[matchId]
	if not match then
		warn("[MatchService] Match not found: " .. matchId)
		return
	end

	if match.state ~= "Active" then
		return
	end

	local key = getPlayerKey(player)
	local stats = match.playerStats[key]
	if not stats then
		return
	end

	stats.kills += 1
	match.scores[key] = stats.kills

	-- Update streak
	local currentStreak = (match.streaks[key] or 0) + 1
	match.streaks[key] = currentStreak
	if currentStreak > stats.highestStreak then
		stats.highestStreak = currentStreak
	end

	-- Update team score if TDM
	if match.config.mode == "TDM" and team then
		local teamKey = "team_" .. team
		match.scores[teamKey] = (match.scores[teamKey] or 0) + 1
	end

	broadcastMatchState(match)
end

--[[
	Increments death counter for a player and resets their streak.
]]
function MatchService.addDeath(matchId: string, player: Player)
	local match = activeMatches[matchId]
	if not match then
		warn("[MatchService] Match not found: " .. matchId)
		return
	end

	if match.state ~= "Active" then
		return
	end

	local key = getPlayerKey(player)
	local stats = match.playerStats[key]
	if not stats then
		return
	end

	stats.deaths += 1
	match.streaks[key] = 0
end

--[[
	Adds an assist for a player.
]]
function MatchService.addAssist(matchId: string, player: Player)
	local match = activeMatches[matchId]
	if not match then
		return
	end

	if match.state ~= "Active" then
		return
	end

	local key = getPlayerKey(player)
	local stats = match.playerStats[key]
	if not stats then
		return
	end

	stats.assists += 1
end

--[[
	Adds damage dealt by a player.
]]
function MatchService.addDamage(matchId: string, player: Player, damage: number)
	local match = activeMatches[matchId]
	if not match then
		return
	end

	if match.state ~= "Active" then
		return
	end

	local key = getPlayerKey(player)
	local stats = match.playerStats[key]
	if not stats then
		return
	end

	stats.damageDealt += damage
end

--[[
	Adds a headshot kill for a player.
]]
function MatchService.addHeadshotKill(matchId: string, player: Player)
	local match = activeMatches[matchId]
	if not match then
		return
	end

	if match.state ~= "Active" then
		return
	end

	local key = getPlayerKey(player)
	local stats = match.playerStats[key]
	if not stats then
		return
	end

	stats.headshotKills += 1
end

--[[
	Returns the scoreboard with PlayerMatchStats for all players in the match.
]]
function MatchService.getScoreboard(matchId: string): { [string]: PlayerMatchStats }
	local match = activeMatches[matchId]
	if not match then
		return {}
	end

	return match.playerStats
end

--[[
	Determines the winner based on most kills.
	If tied on kills, fewest deaths breaks the tie.
	For TDM, returns team name. For FFA, returns the Player.
]]
function MatchService.determineWinner(matchId: string): Player | string | nil
	local match = activeMatches[matchId]
	if not match then
		return nil
	end

	if match.config.mode == "TDM" and match.teams then
		-- Aggregate team scores
		local teamScores: { [string]: { kills: number, deaths: number } } = {}

		for teamName, teamPlayers in match.teams do
			local totalKills = 0
			local totalDeaths = 0
			for _, player in teamPlayers do
				local key = getPlayerKey(player)
				local stats = match.playerStats[key]
				if stats then
					totalKills += stats.kills
					totalDeaths += stats.deaths
				end
			end
			teamScores[teamName] = { kills = totalKills, deaths = totalDeaths }
		end

		-- Find winning team
		local winnerTeam: string? = nil
		local bestKills = -1
		local bestDeaths = math.huge

		for teamName, teamData in teamScores do
			if teamData.kills > bestKills then
				bestKills = teamData.kills
				bestDeaths = teamData.deaths
				winnerTeam = teamName
			elseif teamData.kills == bestKills then
				-- Tiebreaker: fewest deaths
				if teamData.deaths < bestDeaths then
					bestDeaths = teamData.deaths
					winnerTeam = teamName
				end
			end
		end

		return winnerTeam
	else
		-- FFA mode: find player with most kills, then fewest deaths
		local winnerPlayer: Player? = nil
		local bestKills = -1
		local bestDeaths = math.huge

		for _, player in match.players do
			local key = getPlayerKey(player)
			local stats = match.playerStats[key]
			if stats then
				if stats.kills > bestKills then
					bestKills = stats.kills
					bestDeaths = stats.deaths
					winnerPlayer = player
				elseif stats.kills == bestKills then
					-- Tiebreaker: fewest deaths
					if stats.deaths < bestDeaths then
						bestDeaths = stats.deaths
						winnerPlayer = player
					end
				end
			end
		end

		return winnerPlayer
	end
end

--[[
	Removes a player from a match (disconnect handling).
]]
function MatchService.removePlayer(matchId: string, player: Player)
	local match = activeMatches[matchId]
	if not match then
		return
	end

	-- Remove from players list
	for i, p in match.players do
		if p == player then
			table.remove(match.players, i)
			break
		end
	end

	-- Remove from team if TDM
	if match.config.mode == "TDM" and match.teams then
		for _, teamPlayers in match.teams do
			for i, p in teamPlayers do
				if p == player then
					table.remove(teamPlayers, i)
					break
				end
			end
		end
	end

	-- End match if no players remain
	if #match.players == 0 and match.state == "Active" then
		MatchService.endMatch(matchId)
	end
end

--[[
	Gets a match session by ID (for other services to access).
]]
function MatchService.getMatch(matchId: string): MatchSession?
	return activeMatches[matchId]
end

--[[
	Gets the current match state.
]]
function MatchService.getMatchState(matchId: string): MatchState?
	local match = activeMatches[matchId]
	if not match then
		return nil
	end
	return match.state
end

--[[
	Cleans up a match from memory after results have been shown.
]]
function MatchService.cleanupMatch(matchId: string)
	local timerThread = matchTimerThreads[matchId]
	if timerThread then
		task.cancel(timerThread)
		matchTimerThreads[matchId] = nil
	end

	activeMatches[matchId] = nil
end

--[[
	Returns all currently active matches (for debugging/admin).
]]
function MatchService.getActiveMatches(): { [string]: MatchSession }
	return activeMatches
end

return MatchService
