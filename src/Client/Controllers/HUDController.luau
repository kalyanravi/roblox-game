--!strict
--[[
	HUDController — Client-side HUD rendering for Shardstrike.
	Creates ScreenGui with all gameplay HUD elements using Roblox Instance API.
	Listens to server RemoteEvents: MatchState, DamageIndicator, KillFeed, EconomyUpdate, StreakNotification.
	Requirements: 21.1, 21.2, 21.3, 21.4, 21.5, 21.6, 19.2
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Remote Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

local MatchStateRemote: RemoteEvent? = if Remotes then Remotes:FindFirstChild("MatchState") :: RemoteEvent? else nil
local DamageIndicatorRemote: RemoteEvent? = if Remotes then Remotes:FindFirstChild("DamageIndicator") :: RemoteEvent? else nil
local KillFeedRemote: RemoteEvent? = if Remotes then Remotes:FindFirstChild("KillFeed") :: RemoteEvent? else nil
local EconomyUpdateRemote: RemoteEvent? = if Remotes then Remotes:FindFirstChild("EconomyUpdate") :: RemoteEvent? else nil
local StreakNotificationRemote: RemoteEvent? = if Remotes then Remotes:FindFirstChild("StreakNotification") :: RemoteEvent? else nil

-- Platform detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShardstrikeHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = PlayerGui

--------------------------------------------------------------------------------
-- UTILITY HELPERS
--------------------------------------------------------------------------------

local function healthColor(ratio: number): Color3
	if ratio > 0.6 then
		return Color3.fromRGB(76, 209, 55) -- green
	elseif ratio > 0.3 then
		return Color3.fromRGB(251, 197, 49) -- yellow
	else
		return Color3.fromRGB(232, 65, 24) -- red
	end
end

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", mins, secs)
end

local function createFrame(props: {
	Name: string,
	Parent: Instance,
	Position: UDim2?,
	Size: UDim2,
	AnchorPoint: Vector2?,
	BackgroundColor3: Color3?,
	BackgroundTransparency: number?,
}): Frame
	local frame = Instance.new("Frame")
	frame.Name = props.Name
	frame.Size = props.Size
	frame.Position = props.Position or UDim2.new(0, 0, 0, 0)
	frame.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	frame.BackgroundColor3 = props.BackgroundColor3 or Color3.new(0, 0, 0)
	frame.BackgroundTransparency = if props.BackgroundTransparency then props.BackgroundTransparency else 0.5
	frame.BorderSizePixel = 0
	frame.Parent = props.Parent
	return frame
end

local function createLabel(props: {
	Name: string,
	Parent: Instance,
	Position: UDim2?,
	Size: UDim2,
	AnchorPoint: Vector2?,
	Text: string?,
	TextColor3: Color3?,
	TextScaled: boolean?,
	Font: Enum.Font?,
	BackgroundTransparency: number?,
}): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = props.Name
	label.Size = props.Size
	label.Position = props.Position or UDim2.new(0, 0, 0, 0)
	label.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	label.Text = props.Text or ""
	label.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	label.TextScaled = if props.TextScaled ~= nil then props.TextScaled else true
	label.Font = props.Font or Enum.Font.GothamBold
	label.BackgroundTransparency = if props.BackgroundTransparency ~= nil then props.BackgroundTransparency else 1
	label.BorderSizePixel = 0
	label.Parent = props.Parent
	return label
end

--------------------------------------------------------------------------------
-- HEALTH BAR (bottom-left area)
--------------------------------------------------------------------------------

local healthBarContainer = createFrame({
	Name = "HealthBarContainer",
	Parent = screenGui,
	Position = UDim2.new(0, 20, 1, -60),
	Size = UDim2.new(0, 250, 0, 24),
	AnchorPoint = Vector2.new(0, 1),
	BackgroundColor3 = Color3.fromRGB(30, 30, 30),
	BackgroundTransparency = 0.3,
})

local healthBarCorner = Instance.new("UICorner")
healthBarCorner.CornerRadius = UDim.new(0, 6)
healthBarCorner.Parent = healthBarContainer

local healthBarFill = createFrame({
	Name = "HealthFill",
	Parent = healthBarContainer,
	Position = UDim2.new(0, 0, 0, 0),
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(76, 209, 55),
	BackgroundTransparency = 0,
})

local healthFillCorner = Instance.new("UICorner")
healthFillCorner.CornerRadius = UDim.new(0, 6)
healthFillCorner.Parent = healthBarFill

local healthLabel = createLabel({
	Name = "HealthLabel",
	Parent = healthBarContainer,
	Size = UDim2.new(1, 0, 1, 0),
	Text = "100 / 100",
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
})

--------------------------------------------------------------------------------
-- AMMO COUNTER (bottom-right area)
--------------------------------------------------------------------------------

local ammoContainer = createFrame({
	Name = "AmmoContainer",
	Parent = screenGui,
	Position = UDim2.new(1, -20, 1, -60),
	Size = UDim2.new(0, 140, 0, 40),
	AnchorPoint = Vector2.new(1, 1),
	BackgroundColor3 = Color3.fromRGB(30, 30, 30),
	BackgroundTransparency = 0.3,
})

local ammoCorner = Instance.new("UICorner")
ammoCorner.CornerRadius = UDim.new(0, 6)
ammoCorner.Parent = ammoContainer

local ammoLabel = createLabel({
	Name = "AmmoLabel",
	Parent = ammoContainer,
	Size = UDim2.new(1, 0, 1, 0),
	Text = "30 / 30",
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
})

--------------------------------------------------------------------------------
-- K/D/A DISPLAY (top-right)
--------------------------------------------------------------------------------
local kdaContainer = createFrame({
	Name = "KDAContainer",
	Parent = screenGui,
	Position = UDim2.new(1, -20, 0, 50),
	Size = UDim2.new(0, 160, 0, 30),
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = Color3.fromRGB(30, 30, 30),
	BackgroundTransparency = 0.4,
})

local kdaCorner = Instance.new("UICorner")
kdaCorner.CornerRadius = UDim.new(0, 6)
kdaCorner.Parent = kdaContainer

local kdaLabel = createLabel({
	Name = "KDALabel",
	Parent = kdaContainer,
	Size = UDim2.new(1, 0, 1, 0),
	Text = "K: 0  D: 0  A: 0",
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
})

--------------------------------------------------------------------------------
-- MATCH TIMER (top-center)
--------------------------------------------------------------------------------
local timerContainer = createFrame({
	Name = "TimerContainer",
	Parent = screenGui,
	Position = UDim2.new(0.5, 0, 0, 20),
	Size = UDim2.new(0, 120, 0, 40),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Color3.fromRGB(30, 30, 30),
	BackgroundTransparency = 0.3,
})

local timerCorner = Instance.new("UICorner")
timerCorner.CornerRadius = UDim.new(0, 8)
timerCorner.Parent = timerContainer

local timerLabel = createLabel({
	Name = "TimerLabel",
	Parent = timerContainer,
	Size = UDim2.new(1, 0, 1, 0),
	Text = "05:00",
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
})

--------------------------------------------------------------------------------
-- ABILITY COOLDOWN INDICATORS (bottom-center, 2 circular)
--------------------------------------------------------------------------------

local abilityCooldownContainer = createFrame({
	Name = "AbilityCooldownContainer",
	Parent = screenGui,
	Position = UDim2.new(0.5, 0, 1, -70),
	Size = UDim2.new(0, 120, 0, 50),
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundTransparency = 1,
})

local abilitySlots: { Frame } = {}
local abilityCooldownOverlays: { Frame } = {}
local abilityCooldownLabels: { TextLabel } = {}

for i = 1, 2 do
	local slot = createFrame({
		Name = "AbilitySlot" .. tostring(i),
		Parent = abilityCooldownContainer,
		Position = UDim2.new(0, (i - 1) * 60, 0, 0),
		Size = UDim2.new(0, 50, 0, 50),
		BackgroundColor3 = Color3.fromRGB(50, 50, 80),
		BackgroundTransparency = 0.2,
	})

	local slotCorner = Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(1, 0) -- circular
	slotCorner.Parent = slot

	-- Cooldown overlay (darkens during cooldown)
	local overlay = createFrame({
		Name = "CooldownOverlay",
		Parent = slot,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1, -- hidden by default
	})

	local overlayCorner = Instance.new("UICorner")
	overlayCorner.CornerRadius = UDim.new(1, 0)
	overlayCorner.Parent = overlay

	-- Cooldown timer text
	local cdLabel = createLabel({
		Name = "CooldownLabel",
		Parent = slot,
		Size = UDim2.new(1, 0, 1, 0),
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
	})

	table.insert(abilitySlots, slot)
	table.insert(abilityCooldownOverlays, overlay)
	table.insert(abilityCooldownLabels, cdLabel)
end

--------------------------------------------------------------------------------
-- KILL STREAK COUNTER (left of center, above abilities)
--------------------------------------------------------------------------------
local streakContainer = createFrame({
	Name = "StreakContainer",
	Parent = screenGui,
	Position = UDim2.new(0, 20, 1, -100),
	Size = UDim2.new(0, 80, 0, 30),
	AnchorPoint = Vector2.new(0, 1),
	BackgroundColor3 = Color3.fromRGB(50, 20, 20),
	BackgroundTransparency = 0.4,
})

local streakCorner = Instance.new("UICorner")
streakCorner.CornerRadius = UDim.new(0, 6)
streakCorner.Parent = streakContainer

local streakLabel = createLabel({
	Name = "StreakLabel",
	Parent = streakContainer,
	Size = UDim2.new(1, 0, 1, 0),
	Text = "🔥 0",
	TextColor3 = Color3.fromRGB(255, 165, 0),
	Font = Enum.Font.GothamBold,
})

-- Glow effect (UIStroke for milestones)
local streakGlow = Instance.new("UIStroke")
streakGlow.Name = "StreakGlow"
streakGlow.Color = Color3.fromRGB(255, 200, 50)
streakGlow.Thickness = 0
streakGlow.Transparency = 0.3
streakGlow.Parent = streakContainer

--------------------------------------------------------------------------------
-- MINIMAP (top-left, TDM only)
--------------------------------------------------------------------------------
local minimapFrame = createFrame({
	Name = "MinimapFrame",
	Parent = screenGui,
	Position = UDim2.new(0, 20, 0, 50),
	Size = UDim2.new(0, 150, 0, 150),
	AnchorPoint = Vector2.new(0, 0),
	BackgroundColor3 = Color3.fromRGB(20, 20, 30),
	BackgroundTransparency = 0.2,
})

local minimapCorner = Instance.new("UICorner")
minimapCorner.CornerRadius = UDim.new(0, 8)
minimapCorner.Parent = minimapFrame

local minimapBorder = Instance.new("UIStroke")
minimapBorder.Color = Color3.fromRGB(100, 100, 120)
minimapBorder.Thickness = 2
minimapBorder.Parent = minimapFrame

-- Store minimap dots for teammates
local minimapDots: { Frame } = {}
minimapFrame.Visible = false -- hidden by default, shown only in TDM

--------------------------------------------------------------------------------
-- KILL NOTIFICATION (top-center feed area)
--------------------------------------------------------------------------------
local killFeedContainer = createFrame({
	Name = "KillFeedContainer",
	Parent = screenGui,
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.new(0, 400, 0, 120),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
})

local killFeedLayout = Instance.new("UIListLayout")
killFeedLayout.FillDirection = Enum.FillDirection.Vertical
killFeedLayout.SortOrder = Enum.SortOrder.LayoutOrder
killFeedLayout.Padding = UDim.new(0, 4)
killFeedLayout.Parent = killFeedContainer

--------------------------------------------------------------------------------
-- DIRECTIONAL DAMAGE INDICATOR (center of screen, red arcs)
--------------------------------------------------------------------------------

local damageIndicatorContainer = createFrame({
	Name = "DamageIndicatorContainer",
	Parent = screenGui,
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 300, 0, 300),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
})

--------------------------------------------------------------------------------
-- MATCH RESULTS SCREEN (overlay)
--------------------------------------------------------------------------------
local matchResultsOverlay = createFrame({
	Name = "MatchResultsOverlay",
	Parent = screenGui,
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(1, 0, 1, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.4,
})
matchResultsOverlay.Visible = false

local resultsPanel = createFrame({
	Name = "ResultsPanel",
	Parent = matchResultsOverlay,
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 500, 0, 400),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(25, 25, 35),
	BackgroundTransparency = 0.1,
})

local resultsPanelCorner = Instance.new("UICorner")
resultsPanelCorner.CornerRadius = UDim.new(0, 12)
resultsPanelCorner.Parent = resultsPanel

local resultsTitleLabel = createLabel({
	Name = "ResultsTitle",
	Parent = resultsPanel,
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.new(0.8, 0, 0, 40),
	AnchorPoint = Vector2.new(0.5, 0),
	Text = "MATCH RESULTS",
	TextColor3 = Color3.fromRGB(255, 215, 0),
	Font = Enum.Font.GothamBold,
})

local resultsStandingsLabel = createLabel({
	Name = "StandingsLabel",
	Parent = resultsPanel,
	Position = UDim2.new(0.5, 0, 0, 60),
	Size = UDim2.new(0.9, 0, 0, 100),
	AnchorPoint = Vector2.new(0.5, 0),
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.Gotham,
})

local resultsPersonalLabel = createLabel({
	Name = "PersonalStatsLabel",
	Parent = resultsPanel,
	Position = UDim2.new(0.5, 0, 0, 170),
	Size = UDim2.new(0.9, 0, 0, 80),
	AnchorPoint = Vector2.new(0.5, 0),
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.Gotham,
})

local resultsRewardsLabel = createLabel({
	Name = "RewardsLabel",
	Parent = resultsPanel,
	Position = UDim2.new(0.5, 0, 0, 260),
	Size = UDim2.new(0.9, 0, 0, 60),
	AnchorPoint = Vector2.new(0.5, 0),
	Text = "",
	TextColor3 = Color3.fromRGB(100, 255, 100),
	Font = Enum.Font.GothamBold,
})

local resultsMVPLabel = createLabel({
	Name = "MVPLabel",
	Parent = resultsPanel,
	Position = UDim2.new(0.5, 0, 0, 330),
	Size = UDim2.new(0.9, 0, 0, 40),
	AnchorPoint = Vector2.new(0.5, 0),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 215, 0),
	Font = Enum.Font.GothamBold,
})

--------------------------------------------------------------------------------
-- SCOREBOARD (toggleable overlay, Tab hold)
--------------------------------------------------------------------------------
local scoreboardOverlay = createFrame({
	Name = "ScoreboardOverlay",
	Parent = screenGui,
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 600, 0, 400),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(20, 20, 30),
	BackgroundTransparency = 0.15,
})
scoreboardOverlay.Visible = false

local scoreboardCorner = Instance.new("UICorner")
scoreboardCorner.CornerRadius = UDim.new(0, 10)
scoreboardCorner.Parent = scoreboardOverlay

local scoreboardTitle = createLabel({
	Name = "ScoreboardTitle",
	Parent = scoreboardOverlay,
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(0.8, 0, 0, 30),
	AnchorPoint = Vector2.new(0.5, 0),
	Text = "SCOREBOARD",
	TextColor3 = Color3.fromRGB(200, 200, 255),
	Font = Enum.Font.GothamBold,
})

local scoreboardListFrame = createFrame({
	Name = "ScoreboardList",
	Parent = scoreboardOverlay,
	Position = UDim2.new(0.5, 0, 0, 45),
	Size = UDim2.new(0.95, 0, 1, -55),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
})

local scoreboardListLayout = Instance.new("UIListLayout")
scoreboardListLayout.FillDirection = Enum.FillDirection.Vertical
scoreboardListLayout.SortOrder = Enum.SortOrder.LayoutOrder
scoreboardListLayout.Padding = UDim.new(0, 2)
scoreboardListLayout.Parent = scoreboardListFrame

--------------------------------------------------------------------------------
-- MOBILE LAYOUT (virtual joystick, fire, ability, reload buttons)
--------------------------------------------------------------------------------
local mobileContainer = createFrame({
	Name = "MobileControls",
	Parent = screenGui,
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
})
mobileContainer.Visible = isMobile

-- Virtual Joystick (left side)
local joystickOuter = createFrame({
	Name = "JoystickOuter",
	Parent = mobileContainer,
	Position = UDim2.new(0, 40, 1, -60),
	Size = UDim2.new(0, 140, 0, 140),
	AnchorPoint = Vector2.new(0, 1),
	BackgroundColor3 = Color3.fromRGB(60, 60, 60),
	BackgroundTransparency = 0.5,
})

local joystickOuterCorner = Instance.new("UICorner")
joystickOuterCorner.CornerRadius = UDim.new(1, 0)
joystickOuterCorner.Parent = joystickOuter

local joystickInner = createFrame({
	Name = "JoystickInner",
	Parent = joystickOuter,
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 50, 0, 50),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(180, 180, 180),
	BackgroundTransparency = 0.3,
})

local joystickInnerCorner = Instance.new("UICorner")
joystickInnerCorner.CornerRadius = UDim.new(1, 0)
joystickInnerCorner.Parent = joystickInner

-- Fire Button (right side, large for touch)
local fireButton = Instance.new("TextButton")
fireButton.Name = "FireButton"
fireButton.Size = UDim2.new(0, 90, 0, 90)
fireButton.Position = UDim2.new(1, -50, 1, -100)
fireButton.AnchorPoint = Vector2.new(1, 1)
fireButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
fireButton.BackgroundTransparency = 0.3
fireButton.Text = "FIRE"
fireButton.TextColor3 = Color3.new(1, 1, 1)
fireButton.Font = Enum.Font.GothamBold
fireButton.TextScaled = true
fireButton.BorderSizePixel = 0
fireButton.Parent = mobileContainer

local fireButtonCorner = Instance.new("UICorner")
fireButtonCorner.CornerRadius = UDim.new(1, 0)
fireButtonCorner.Parent = fireButton

-- Reload Button (right side, above fire)
local reloadButton = Instance.new("TextButton")
reloadButton.Name = "ReloadButton"
reloadButton.Size = UDim2.new(0, 60, 0, 60)
reloadButton.Position = UDim2.new(1, -160, 1, -100)
reloadButton.AnchorPoint = Vector2.new(1, 1)
reloadButton.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
reloadButton.BackgroundTransparency = 0.3
reloadButton.Text = "R"
reloadButton.TextColor3 = Color3.new(1, 1, 1)
reloadButton.Font = Enum.Font.GothamBold
reloadButton.TextScaled = true
reloadButton.BorderSizePixel = 0
reloadButton.Parent = mobileContainer

local reloadButtonCorner = Instance.new("UICorner")
reloadButtonCorner.CornerRadius = UDim.new(1, 0)
reloadButtonCorner.Parent = reloadButton

-- Ability Buttons (right side, above reload)
for i = 1, 2 do
	local abilityBtn = Instance.new("TextButton")
	abilityBtn.Name = "MobileAbility" .. tostring(i)
	abilityBtn.Size = UDim2.new(0, 55, 0, 55)
	abilityBtn.Position = UDim2.new(1, -160 - (i - 1) * 65, 1, -180)
	abilityBtn.AnchorPoint = Vector2.new(1, 1)
	abilityBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 150)
	abilityBtn.BackgroundTransparency = 0.3
	abilityBtn.Text = "A" .. tostring(i)
	abilityBtn.TextColor3 = Color3.new(1, 1, 1)
	abilityBtn.Font = Enum.Font.GothamBold
	abilityBtn.TextScaled = true
	abilityBtn.BorderSizePixel = 0
	abilityBtn.Parent = mobileContainer

	local abilityBtnCorner = Instance.new("UICorner")
	abilityBtnCorner.CornerRadius = UDim.new(1, 0)
	abilityBtnCorner.Parent = abilityBtn
end


--------------------------------------------------------------------------------
-- UPDATE FUNCTIONS
--------------------------------------------------------------------------------

local function updateHealth(current: number, max: number)
	local ratio = math.clamp(current / math.max(max, 1), 0, 1)
	healthBarFill.Size = UDim2.new(ratio, 0, 1, 0)
	healthBarFill.BackgroundColor3 = healthColor(ratio)
	healthLabel.Text = tostring(math.floor(current)) .. " / " .. tostring(math.floor(max))
end

local function updateAmmo(current: number, magazineSize: number)
	ammoLabel.Text = tostring(current) .. " / " .. tostring(magazineSize)
	if current == 0 then
		ammoLabel.TextColor3 = Color3.fromRGB(232, 65, 24)
	elseif current <= math.floor(magazineSize * 0.25) then
		ammoLabel.TextColor3 = Color3.fromRGB(251, 197, 49)
	else
		ammoLabel.TextColor3 = Color3.new(1, 1, 1)
	end
end

local function updateKDA(kills: number, deaths: number, assists: number)
	kdaLabel.Text = "K: " .. tostring(kills) .. "  D: " .. tostring(deaths) .. "  A: " .. tostring(assists)
end

local function updateTimer(secondsRemaining: number)
	timerLabel.Text = formatTime(math.max(0, math.floor(secondsRemaining)))
	if secondsRemaining <= 30 then
		timerLabel.TextColor3 = Color3.fromRGB(232, 65, 24)
	else
		timerLabel.TextColor3 = Color3.new(1, 1, 1)
	end
end

local function updateAbilityCooldowns(slot1Remaining: number?, slot2Remaining: number?)
	local cooldowns = { slot1Remaining, slot2Remaining }
	for i = 1, 2 do
		local remaining = cooldowns[i]
		if remaining and remaining > 0 then
			abilityCooldownOverlays[i].BackgroundTransparency = 0.5
			abilityCooldownLabels[i].Text = string.format("%.1f", remaining)
		else
			abilityCooldownOverlays[i].BackgroundTransparency = 1
			abilityCooldownLabels[i].Text = ""
		end
	end
end

local function updateStreak(count: number)
	streakLabel.Text = "🔥 " .. tostring(count)
	streakContainer.Visible = count > 0

	-- Glow effect at milestones (3, 5, 7, 10)
	if count == 3 or count == 5 or count == 7 or count == 10 then
		streakGlow.Thickness = 3
		local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		local tween = TweenService:Create(streakGlow, tweenInfo, { Thickness = 0 })
		tween:Play()
	end
end

local function showKillNotification(attackerName: string, victimName: string, weaponName: string)
	local notification = createLabel({
		Name = "KillNotif",
		Parent = killFeedContainer,
		Size = UDim2.new(1, 0, 0, 24),
		Text = attackerName .. " eliminated " .. victimName .. " with " .. weaponName,
		TextColor3 = Color3.fromRGB(255, 230, 150),
		Font = Enum.Font.Gotham,
		BackgroundTransparency = 1,
	})
	notification.TextScaled = true

	-- Fade out and destroy after 3 seconds
	task.delay(3, function()
		if notification and notification.Parent then
			local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local fadeTween = TweenService:Create(notification, fadeInfo, { TextTransparency = 1 })
			fadeTween:Play()
			fadeTween.Completed:Connect(function()
				if notification and notification.Parent then
					notification:Destroy()
				end
			end)
		end
	end)

	-- Limit kill feed entries to 5 visible
	local children = killFeedContainer:GetChildren()
	local notifCount = 0
	for _, child in children do
		if child:IsA("TextLabel") then
			notifCount += 1
		end
	end
	if notifCount > 5 then
		for _, child in children do
			if child:IsA("TextLabel") then
				child:Destroy()
				break
			end
		end
	end
end

local function showDamageIndicator(direction: Vector3)
	-- Calculate angle from player facing direction to damage source
	local camera = workspace.CurrentCamera
	if not camera then return end

	local camCFrame = camera.CFrame
	local localDir = camCFrame:VectorToObjectSpace(direction.Unit)
	local angle = math.atan2(localDir.X, -localDir.Z)

	-- Create red arc indicator at the edge of the screen
	local indicator = createFrame({
		Name = "DamageArc",
		Parent = damageIndicatorContainer,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 60, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(220, 30, 30),
		BackgroundTransparency = 0.2,
	})
	indicator.Rotation = math.deg(angle)

	-- Position along the edge based on angle
	local radius = 120
	local offsetX = math.sin(angle) * radius
	local offsetY = -math.cos(angle) * radius
	indicator.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)

	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(0, 4)
	indicatorCorner.Parent = indicator

	-- Fade out over 1.5 seconds
	task.delay(0.2, function()
		if indicator and indicator.Parent then
			local fadeInfo = TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local fadeTween = TweenService:Create(indicator, fadeInfo, { BackgroundTransparency = 1 })
			fadeTween:Play()
			fadeTween.Completed:Connect(function()
				if indicator and indicator.Parent then
					indicator:Destroy()
				end
			end)
		end
	end)
end

local function showMatchResults(results: {
	standings: { { name: string, kills: number, deaths: number, assists: number } },
	personalStats: { kills: number, deaths: number, assists: number, damageDealt: number },
	coinsEarned: number,
	xpEarned: number,
	mvpName: string?,
})
	matchResultsOverlay.Visible = true

	-- Build standings text
	local standingsText = ""
	for i, entry in results.standings do
		local prefix = if i == 1 then "🥇 " elseif i == 2 then "🥈 " elseif i == 3 then "🥉 " else tostring(i) .. ". "
		standingsText ..= prefix .. entry.name .. "  K:" .. tostring(entry.kills) .. " D:" .. tostring(entry.deaths) .. " A:" .. tostring(entry.assists) .. "\n"
	end
	resultsStandingsLabel.Text = standingsText

	-- Personal stats
	resultsPersonalLabel.Text = "Your Stats:\nKills: " .. tostring(results.personalStats.kills)
		.. "  Deaths: " .. tostring(results.personalStats.deaths)
		.. "  Assists: " .. tostring(results.personalStats.assists)
		.. "\nDamage Dealt: " .. tostring(results.personalStats.damageDealt)

	-- Rewards
	resultsRewardsLabel.Text = "+" .. tostring(results.coinsEarned) .. " Coins   +" .. tostring(results.xpEarned) .. " XP"

	-- MVP
	if results.mvpName then
		resultsMVPLabel.Text = "⭐ MVP: " .. results.mvpName
	else
		resultsMVPLabel.Text = ""
	end
end

local function showMinimap(teammatePositions: { Vector3 })
	minimapFrame.Visible = true

	-- Clear existing dots
	for _, dot in minimapDots do
		if dot and dot.Parent then
			dot:Destroy()
		end
	end
	table.clear(minimapDots)

	-- Get local player position for relative mapping
	local character = LocalPlayer.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	local playerPos = rootPart.Position
	local mapScale = 150 / 200 -- 150px frame maps 200 studs radius

	for _, pos in teammatePositions do
		local relX = (pos.X - playerPos.X) * mapScale
		local relZ = (pos.Z - playerPos.Z) * mapScale

		-- Clamp to minimap bounds
		relX = math.clamp(relX, -70, 70)
		relZ = math.clamp(relZ, -70, 70)

		local dot = createFrame({
			Name = "TeammateDot",
			Parent = minimapFrame,
			Position = UDim2.new(0.5, relX, 0.5, relZ),
			Size = UDim2.new(0, 8, 0, 8),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(50, 150, 255),
			BackgroundTransparency = 0,
		})

		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot

		table.insert(minimapDots, dot)
	end
end

local function toggleScoreboard(show: boolean, data: { { name: string, kills: number, deaths: number, assists: number } }?)
	scoreboardOverlay.Visible = show

	if show and data then
		-- Clear existing rows
		for _, child in scoreboardListFrame:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end

		-- Header row
		createLabel({
			Name = "ScoreboardHeader",
			Parent = scoreboardListFrame,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Player                K      D      A",
			TextColor3 = Color3.fromRGB(150, 150, 200),
			Font = Enum.Font.GothamBold,
			BackgroundTransparency = 1,
		})

		-- Player rows
		for i, entry in data do
			local rowColor = if entry.name == LocalPlayer.Name
				then Color3.fromRGB(200, 255, 200)
				else Color3.new(1, 1, 1)

			createLabel({
				Name = "Row" .. tostring(i),
				Parent = scoreboardListFrame,
				Size = UDim2.new(1, 0, 0, 22),
				Text = entry.name .. "        " .. tostring(entry.kills) .. "      " .. tostring(entry.deaths) .. "      " .. tostring(entry.assists),
				TextColor3 = rowColor,
				Font = Enum.Font.Gotham,
				BackgroundTransparency = 1,
			})
		end
	end
end

local function hideMatchResults()
	matchResultsOverlay.Visible = false
end

--------------------------------------------------------------------------------
-- SERVER REMOTE EVENT LISTENERS
--------------------------------------------------------------------------------

if MatchStateRemote then
	MatchStateRemote.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then return end

		if data.timer ~= nil then
			updateTimer(data.timer :: number)
		end
		if data.kills ~= nil and data.deaths ~= nil and data.assists ~= nil then
			updateKDA(data.kills :: number, data.deaths :: number, data.assists :: number)
		end
		if data.health ~= nil and data.maxHealth ~= nil then
			updateHealth(data.health :: number, data.maxHealth :: number)
		end
		if data.ammo ~= nil and data.magazineSize ~= nil then
			updateAmmo(data.ammo :: number, data.magazineSize :: number)
		end
		if data.abilityCooldown1 ~= nil or data.abilityCooldown2 ~= nil then
			updateAbilityCooldowns(data.abilityCooldown1, data.abilityCooldown2)
		end
		if data.mode == "TDM" and data.teammatePositions then
			showMinimap(data.teammatePositions)
		end
		if data.matchPhase == "Results" and data.results then
			showMatchResults(data.results)
		end
		if data.matchPhase == "Active" then
			hideMatchResults()
		end
		if data.scoreboard then
			toggleScoreboard(true, data.scoreboard)
		end
	end)
end

if DamageIndicatorRemote then
	DamageIndicatorRemote.OnClientEvent:Connect(function(direction: any)
		if typeof(direction) == "Vector3" then
			showDamageIndicator(direction)
		end
	end)
end

if KillFeedRemote then
	KillFeedRemote.OnClientEvent:Connect(function(attackerName: any, victimName: any, weaponName: any)
		if typeof(attackerName) == "string" and typeof(victimName) == "string" and typeof(weaponName) == "string" then
			showKillNotification(attackerName, victimName, weaponName)
		end
	end)
end

if EconomyUpdateRemote then
	EconomyUpdateRemote.OnClientEvent:Connect(function(_data: any)
		-- Economy updates (coins/gems) can be handled by a dedicated UI or notification
		-- This listener is reserved for future economy HUD integration
	end)
end

if StreakNotificationRemote then
	StreakNotificationRemote.OnClientEvent:Connect(function(streakCount: any)
		if typeof(streakCount) == "number" then
			updateStreak(streakCount)
		end
	end)
end

--------------------------------------------------------------------------------
-- SCOREBOARD TOGGLE (Tab hold on PC)
--------------------------------------------------------------------------------

if not isMobile then
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Tab then
			scoreboardOverlay.Visible = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
		if input.KeyCode == Enum.KeyCode.Tab then
			scoreboardOverlay.Visible = false
		end
	end)
end

--------------------------------------------------------------------------------
-- LOCAL HEALTH MONITORING (character Humanoid)
--------------------------------------------------------------------------------

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then return end

	updateHealth(humanoid.Health, humanoid.MaxHealth)

	humanoid.HealthChanged:Connect(function(newHealth: number)
		updateHealth(newHealth, humanoid.MaxHealth)
	end)

	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		updateHealth(humanoid.Health, humanoid.MaxHealth)
	end)
end

if LocalPlayer.Character then
	onCharacterAdded(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

--------------------------------------------------------------------------------
-- MODULE EXPORT (for Init.client.luau wiring)
--------------------------------------------------------------------------------

local HUDController = {
	updateHealth = updateHealth,
	updateAmmo = updateAmmo,
	updateKDA = updateKDA,
	updateTimer = updateTimer,
	updateAbilityCooldowns = updateAbilityCooldowns,
	updateStreak = updateStreak,
	showKillNotification = showKillNotification,
	showDamageIndicator = showDamageIndicator,
	showMatchResults = showMatchResults,
	showMinimap = showMinimap,
	toggleScoreboard = toggleScoreboard,
	hideMatchResults = hideMatchResults,
}

return HUDController
