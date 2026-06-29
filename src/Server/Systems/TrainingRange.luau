--!strict
--[[
	TrainingRange
	Solo practice environment accessible from the main lobby with no time limit.
	Players can test owned weapons and abilities against stationary and moving target dummies.
	All XP, coin, and gem awards are disabled while in the training range.
	Requirements: 16.1, 16.2, 16.3, 16.4, 16.5
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------

type TrainingStats = {
	shotsFired: number,
	hits: number,
	damageDealt: number,
}

type DummyState = {
	model: Model,
	humanoid: Humanoid,
	maxHealth: number,
	healTask: thread?,
}

type PlayerTrainingSession = {
	stats: TrainingStats,
	active: boolean,
}

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local DUMMY_HEALTH = 100
local DUMMY_AUTO_HEAL_DELAY = 3
-- Training range dummies disabled for multiplayer mode
-- (Training Range is accessed separately via command, not auto-spawned)

local STATIONARY_DUMMY_COUNT = 0
local MOVING_DUMMY_COUNT = 0

-- Training range area positioning (inside the arena so players can see dummies)
local TRAINING_RANGE_ORIGIN = Vector3.new(0, 1, -30)
local LOBBY_SPAWN_POSITION = Vector3.new(0, 5, 0)

-- Moving dummy rail parameters
local RAIL_LENGTH = 40
local RAIL_TWEEN_DURATION = 3

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

-- Players currently in the training range
local playersInRange: { [Player]: PlayerTrainingSession } = {}

-- Training range flag: other systems check this to skip awards
-- Exported as a module-level set for EconomyService, ProgressionEngine, ChestService
local trainingRangeFlags: { [Player]: boolean } = {}

-- Stationary dummies
local stationaryDummies: { DummyState } = {}

-- Moving dummies
local movingDummies: { DummyState } = {}

-- Active tweens for moving dummies
local activeTweens: { [Model]: Tween } = {}

----------------------------------------------------------------------
-- RemoteEvents
----------------------------------------------------------------------

local function getRemoteEvent(name: string): RemoteEvent
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local remote = remotes:FindFirstChild(name)
		if remote and remote:IsA("RemoteEvent") then
			return remote :: RemoteEvent
		end
	end
	-- Fallback: create if not found
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

-- Create TrainingStats and TrainingRange remotes
local TrainingStatsRemote = getRemoteEvent("TrainingStats")
local EnterTrainingRemote = getRemoteEvent("EnterTrainingRange")
local ExitTrainingRemote = getRemoteEvent("ExitTrainingRange")

----------------------------------------------------------------------
-- Dummy Creation Helpers
----------------------------------------------------------------------

--- Creates a BillboardGui for displaying damage numbers above a dummy.
local function showDamageNumber(dummy: Model, damage: number): ()
	local head = dummy:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		-- Use the primary part if no head
		head = dummy.PrimaryPart
	end
	if not head then
		return
	end

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size = UDim2.new(0, 100, 0, 40)
	billboardGui.StudsOffset = Vector3.new(0, 3, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.Parent = head

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = tostring(math.floor(damage))
	textLabel.TextColor3 = Color3.new(1, 0.2, 0.2)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = billboardGui

	-- Fade out and remove after 1 second
	task.spawn(function()
		task.wait(1)
		if billboardGui and billboardGui.Parent then
			billboardGui:Destroy()
		end
	end)
end

--- Creates a stationary target dummy at the specified position.
local function createStationaryDummy(position: Vector3): DummyState
	local model = Instance.new("Model")
	model.Name = "TrainingDummy_Stationary"

	-- Create torso (primary part)
	local torso = Instance.new("Part")
	torso.Name = "HumanoidRootPart"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Position = position
	torso.Anchored = true
	torso.CanCollide = true
	torso.BrickColor = BrickColor.new("Bright red")
	torso.Parent = model

	-- Create head for headshot detection
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.Shape = Enum.PartType.Ball
	head.Position = position + Vector3.new(0, 2, 0)
	head.Anchored = true
	head.CanCollide = true
	head.BrickColor = BrickColor.new("Bright yellow")
	head.Parent = model

	-- Create humanoid for damage registration
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = DUMMY_HEALTH
	humanoid.Health = DUMMY_HEALTH
	humanoid.Parent = model

	model.PrimaryPart = torso
	model.Parent = workspace

	local dummyState: DummyState = {
		model = model,
		humanoid = humanoid,
		maxHealth = DUMMY_HEALTH,
		healTask = nil,
	}

	return dummyState
end

--- Creates a moving target dummy at the specified position with rail movement.
local function createMovingDummy(position: Vector3, railDirection: Vector3): DummyState
	local model = Instance.new("Model")
	model.Name = "TrainingDummy_Moving"

	-- Create torso (primary part)
	local torso = Instance.new("Part")
	torso.Name = "HumanoidRootPart"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Position = position
	torso.Anchored = true
	torso.CanCollide = true
	torso.BrickColor = BrickColor.new("Bright blue")
	torso.Parent = model

	-- Create head for headshot detection
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.Shape = Enum.PartType.Ball
	head.Position = position + Vector3.new(0, 2, 0)
	head.Anchored = true
	head.CanCollide = true
	head.BrickColor = BrickColor.new("Bright orange")
	head.Parent = model

	-- Create humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = DUMMY_HEALTH
	humanoid.Health = DUMMY_HEALTH
	humanoid.Parent = model

	model.PrimaryPart = torso
	model.Parent = workspace

	local dummyState: DummyState = {
		model = model,
		humanoid = humanoid,
		maxHealth = DUMMY_HEALTH,
		healTask = nil,
	}

	-- Start rail movement using TweenService
	local startPos = position
	local endPos = position + (railDirection.Unit * RAIL_LENGTH)

	local tweenToEnd
	local tweenToStart

	tweenToEnd = function()
		if not model or not model.Parent then
			return
		end
		local tweenInfo = TweenInfo.new(RAIL_TWEEN_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
		local tween = TweenService:Create(torso, tweenInfo, { Position = endPos })
		activeTweens[model] = tween

		tween.Completed:Connect(function()
			head.Position = endPos + Vector3.new(0, 2, 0)
			tweenToStart()
		end)

		tween:Play()

		task.spawn(function()
			while tween.PlaybackState == Enum.PlaybackState.Playing do
				head.Position = torso.Position + Vector3.new(0, 2, 0)
				task.wait(0.03)
			end
		end)
	end

	tweenToStart = function()
		if not model or not model.Parent then
			return
		end
		local tweenInfo = TweenInfo.new(RAIL_TWEEN_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
		local tween = TweenService:Create(torso, tweenInfo, { Position = startPos })
		activeTweens[model] = tween

		tween.Completed:Connect(function()
			head.Position = startPos + Vector3.new(0, 2, 0)
			tweenToEnd()
		end)

		tween:Play()

		task.spawn(function()
			while tween.PlaybackState == Enum.PlaybackState.Playing do
				head.Position = torso.Position + Vector3.new(0, 2, 0)
				task.wait(0.03)
			end
		end)
	end

	-- Start movement
	task.spawn(tweenToEnd)

	return dummyState
end

--- Schedules auto-heal for a dummy after the configured delay.
local function scheduleAutoHeal(dummyState: DummyState): ()
	-- Cancel existing heal task if any
	if dummyState.healTask then
		task.cancel(dummyState.healTask)
		dummyState.healTask = nil
	end

	dummyState.healTask = task.delay(DUMMY_AUTO_HEAL_DELAY, function()
		if dummyState.humanoid and dummyState.humanoid.Parent then
			dummyState.humanoid.Health = dummyState.maxHealth
		end
		dummyState.healTask = nil
	end)
end

----------------------------------------------------------------------
-- Training Range Setup
----------------------------------------------------------------------

--- Spawns all stationary dummies in the training range area.
local function setupStationaryDummies(): ()
	for i = 1, STATIONARY_DUMMY_COUNT do
		local offset = Vector3.new((i - 1) * 6, 0, 0)
		local position = TRAINING_RANGE_ORIGIN + offset
		local dummy = createStationaryDummy(position)
		table.insert(stationaryDummies, dummy)
	end
end

--- Spawns all moving dummies in the training range area.
local function setupMovingDummies(): ()
	for i = 1, MOVING_DUMMY_COUNT do
		local offset = Vector3.new((i - 1) * 15, 0, 20)
		local position = TRAINING_RANGE_ORIGIN + offset
		local railDirection = Vector3.new(1, 0, 0)
		local dummy = createMovingDummy(position, railDirection)
		table.insert(movingDummies, dummy)
	end
end

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local TrainingRange = {}

--- Checks if a player is currently in the training range.
function TrainingRange.isInTrainingRange(player: Player): boolean
	return trainingRangeFlags[player] == true
end

--- Returns the training range flags table for other systems to check.
--- EconomyService, ProgressionEngine, and ChestService use this to skip awards.
function TrainingRange.getTrainingFlags(): { [Player]: boolean }
	return trainingRangeFlags
end

--- Enters the training range: teleports player, disables XP/coin/gem awards.
function TrainingRange.enterTrainingRange(player: Player): ()
	-- Already in training range
	if trainingRangeFlags[player] then
		return
	end

	-- Set flag so other services skip awards
	trainingRangeFlags[player] = true

	-- Initialize training session stats
	playersInRange[player] = {
		stats = {
			shotsFired = 0,
			hits = 0,
			damageDealt = 0,
		},
		active = true,
	}

	-- Teleport player to training range area
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			-- Offset slightly so players don't overlap dummies
			rootPart.CFrame = CFrame.new(TRAINING_RANGE_ORIGIN + Vector3.new(-10, 0, 10))
		end
	end
end

--- Exits the training range: returns player to lobby, ensures no rewards were given.
function TrainingRange.exitTrainingRange(player: Player): ()
	-- Not in training range
	if not trainingRangeFlags[player] then
		return
	end

	-- Remove training flag
	trainingRangeFlags[player] = nil

	-- Clean up session
	playersInRange[player] = nil

	-- Teleport player back to main lobby
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			rootPart.CFrame = CFrame.new(LOBBY_SPAWN_POSITION)
		end
	end
end

--- Registers a shot fired by a player in the training range.
function TrainingRange.registerShot(player: Player): ()
	local session = playersInRange[player]
	if not session or not session.active then
		return
	end

	session.stats.shotsFired += 1
	TrainingRange.sendStatsUpdate(player)
end

--- Registers a hit on a dummy by a player in the training range.
function TrainingRange.registerHit(player: Player, damage: number, dummyModel: Model): ()
	local session = playersInRange[player]
	if not session or not session.active then
		return
	end

	session.stats.hits += 1
	session.stats.damageDealt += damage

	-- Display damage number on the dummy
	showDamageNumber(dummyModel, damage)

	-- Find and schedule auto-heal for the hit dummy
	for _, dummy in stationaryDummies do
		if dummy.model == dummyModel then
			scheduleAutoHeal(dummy)
			break
		end
	end
	for _, dummy in movingDummies do
		if dummy.model == dummyModel then
			scheduleAutoHeal(dummy)
			break
		end
	end

	TrainingRange.sendStatsUpdate(player)
end

--- Sends real-time training stats to the client via TrainingStats RemoteEvent.
function TrainingRange.sendStatsUpdate(player: Player): ()
	local session = playersInRange[player]
	if not session then
		return
	end

	local stats = session.stats
	local accuracy = 0
	if stats.shotsFired > 0 then
		accuracy = (stats.hits / stats.shotsFired) * 100
	end

	TrainingStatsRemote:FireClient(player, {
		accuracy = accuracy,
		hits = stats.hits,
		damageDealt = stats.damageDealt,
		shotsFired = stats.shotsFired,
	})
end

--- Returns current training stats for a player (for external queries).
function TrainingRange.getStats(player: Player): TrainingStats?
	local session = playersInRange[player]
	if not session then
		return nil
	end
	return session.stats
end

----------------------------------------------------------------------
-- Dummy Damage Handling
----------------------------------------------------------------------

--- Processes a hit on any training dummy from a training range player.
--- Called by CombatService or directly when a raycast hits a dummy.
local function onDummyDamaged(player: Player, dummy: DummyState, damage: number): ()
	if not TrainingRange.isInTrainingRange(player) then
		return
	end

	-- Apply damage to dummy humanoid
	dummy.humanoid.Health = math.max(0, dummy.humanoid.Health - damage)

	-- If dummy health reaches 0, reset immediately for continuous practice
	if dummy.humanoid.Health <= 0 then
		dummy.humanoid.Health = dummy.maxHealth
	end

	-- Register the hit for accuracy tracking
	TrainingRange.registerHit(player, damage, dummy.model)
end

-- Expose the damage handler for integration with CombatService
TrainingRange.onDummyDamaged = onDummyDamaged

--- Finds a dummy by its model instance. Returns the DummyState or nil.
function TrainingRange.findDummyByModel(model: Model): DummyState?
	for _, dummy in stationaryDummies do
		if dummy.model == model then
			return dummy
		end
	end
	for _, dummy in movingDummies do
		if dummy.model == model then
			return dummy
		end
	end
	return nil
end

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

-- Client requests to enter training range
EnterTrainingRemote.OnServerEvent:Connect(function(player: Player)
	TrainingRange.enterTrainingRange(player)
end)

-- Client requests to exit training range
ExitTrainingRemote.OnServerEvent:Connect(function(player: Player)
	TrainingRange.exitTrainingRange(player)
end)

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player: Player)
	-- Clean up training range state on player leave
	if trainingRangeFlags[player] then
		trainingRangeFlags[player] = nil
	end
	if playersInRange[player] then
		playersInRange[player] = nil
	end
end)

----------------------------------------------------------------------
-- Initialize Training Range Dummies
----------------------------------------------------------------------

task.spawn(function()
	setupStationaryDummies()
	setupMovingDummies()
	print("[TrainingRange] Initialized with", STATIONARY_DUMMY_COUNT, "stationary and", MOVING_DUMMY_COUNT, "moving dummies.")
end)

----------------------------------------------------------------------

return TrainingRange
