--!strict
--[[
	SettingsController
	Client-side settings UI and management for player preferences.
	Creates a ScreenGui with tabs for Sensitivity, Crosshair, Audio, Keybinds (PC only),
	and Mobile-only matchmaking toggle.

	Applies settings locally (sensitivity to camera, audio to SoundService groups)
	and fires UpdateSettings RemoteEvent to persist via server DataPersistenceService.

	Requirements: 20.1, 20.2, 20.3, 20.4, 20.5, 19.5
]]

local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Shared modules
local SharedPath = ReplicatedStorage:WaitForChild("Shared", 10)
local Constants = if SharedPath then require(SharedPath:WaitForChild("Constants")) else nil

local SENSITIVITY_MIN = if Constants then Constants.SENSITIVITY_MIN else 0.1
local SENSITIVITY_MAX = if Constants then Constants.SENSITIVITY_MAX else 5.0

-- Platform detection
local isPCPlatform = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled

-- Remote references
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local UpdateSettingsRemote: RemoteEvent? = if Remotes then Remotes:FindFirstChild("UpdateSettings") :: RemoteEvent? else nil

-- InputController reference (for keybind loading)
local InputController: any = nil
local function getInputController(): any
	if InputController then
		return InputController
	end
	local controllersFolder = script.Parent
	if controllersFolder then
		local inputModule = controllersFolder:FindFirstChild("InputController.client")
		if inputModule then
			InputController = require(inputModule)
		end
	end
	return InputController
end

--------------------------------------------------------------------------------
-- SETTINGS STATE
--------------------------------------------------------------------------------

export type CrosshairSettings = {
	shape: string, -- "dot" | "cross" | "circle"
	color: string, -- hex color string e.g. "#FFFFFF"
	size: number, -- 1-20
	opacity: number, -- 0-1
}

export type AudioSettings = {
	master: number, -- 0-100
	sfx: number, -- 0-100
	music: number, -- 0-100
	voice: number, -- 0-100
}

export type SettingsData = {
	sensitivity: number,
	crosshair: CrosshairSettings,
	audio: AudioSettings,
	keybinds: { [string]: string }?,
	mobileOnlyMatchmaking: boolean,
}

local currentSettings: SettingsData = {
	sensitivity = 1.0,
	crosshair = { shape = "cross", color = "#FFFFFF", size = 4, opacity = 1.0 },
	audio = { master = 80, sfx = 80, music = 50, voice = 70 },
	keybinds = nil,
	mobileOnlyMatchmaking = false,
}

local isSettingsVisible = false
local isRebinding = false
local rebindAction: string? = nil

-- Forward declarations for functions used in callbacks
local applySensitivity: () -> ()
local applyAudioSettings: () -> ()
local saveSettings: () -> ()

-- Module API
local SettingsController = {}

--------------------------------------------------------------------------------
-- UTILITY HELPERS
--------------------------------------------------------------------------------

local function clampSensitivity(value: number): number
	return math.clamp(value, SENSITIVITY_MIN, SENSITIVITY_MAX)
end

local function hexToColor3(hex: string): Color3
	local r = tonumber(string.sub(hex, 2, 3), 16) or 255
	local g = tonumber(string.sub(hex, 4, 5), 16) or 255
	local b = tonumber(string.sub(hex, 6, 7), 16) or 255
	return Color3.fromRGB(r, g, b)
end

--------------------------------------------------------------------------------
-- UI CREATION HELPERS
--------------------------------------------------------------------------------

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
	TextXAlignment: Enum.TextXAlignment?,
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
	label.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
	label.Parent = props.Parent
	return label
end

local function createTextButton(props: {
	Name: string,
	Parent: Instance,
	Position: UDim2?,
	Size: UDim2,
	AnchorPoint: Vector2?,
	Text: string?,
	TextColor3: Color3?,
	BackgroundColor3: Color3?,
	BackgroundTransparency: number?,
	Font: Enum.Font?,
}): TextButton
	local button = Instance.new("TextButton")
	button.Name = props.Name
	button.Size = props.Size
	button.Position = props.Position or UDim2.new(0, 0, 0, 0)
	button.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	button.Text = props.Text or ""
	button.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Font = props.Font or Enum.Font.GothamBold
	button.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(60, 60, 80)
	button.BackgroundTransparency = props.BackgroundTransparency or 0.2
	button.BorderSizePixel = 0
	button.Parent = props.Parent
	return button
end

local function createSlider(parent: Instance, name: string, yOffset: number, labelText: string, minVal: number, maxVal: number, currentVal: number, onChange: (number) -> ()): Frame
	local container = createFrame({
		Name = name .. "SliderContainer",
		Parent = parent,
		Position = UDim2.new(0, 20, 0, yOffset),
		Size = UDim2.new(1, -40, 0, 40),
		BackgroundTransparency = 1,
	})

	createLabel({
		Name = name .. "Label",
		Parent = container,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0.3, 0, 1, 0),
		Text = labelText,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Slider track
	local track = createFrame({
		Name = name .. "Track",
		Parent = container,
		Position = UDim2.new(0.32, 0, 0.5, 0),
		Size = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(50, 50, 60),
		BackgroundTransparency = 0,
	})

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 4)
	trackCorner.Parent = track

	-- Slider fill
	local normalizedVal = math.clamp((currentVal - minVal) / (maxVal - minVal), 0, 1)
	local fill = createFrame({
		Name = name .. "Fill",
		Parent = track,
		Size = UDim2.new(normalizedVal, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(80, 160, 255),
		BackgroundTransparency = 0,
	})

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	-- Slider thumb
	local thumb = createFrame({
		Name = name .. "Thumb",
		Parent = track,
		Position = UDim2.new(normalizedVal, 0, 0.5, 0),
		Size = UDim2.new(0, 16, 0, 16),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0,
	})

	local thumbCorner = Instance.new("UICorner")
	thumbCorner.CornerRadius = UDim.new(1, 0)
	thumbCorner.Parent = thumb

	-- Value display
	local valueLabel = createLabel({
		Name = name .. "Value",
		Parent = container,
		Position = UDim2.new(0.85, 0, 0, 0),
		Size = UDim2.new(0.15, 0, 1, 0),
		Text = string.format("%.1f", currentVal),
	})

	-- Slider interaction
	local dragging = false

	local function updateSlider(inputX: number)
		local trackAbsPos = track.AbsolutePosition.X
		local trackAbsSize = track.AbsoluteSize.X
		local relativeX = math.clamp((inputX - trackAbsPos) / trackAbsSize, 0, 1)
		local value = minVal + relativeX * (maxVal - minVal)

		-- Round to 1 decimal for sensitivity, integer for audio
		if maxVal <= 5 then
			value = math.floor(value * 10 + 0.5) / 10
		else
			value = math.floor(value + 0.5)
		end

		fill.Size = UDim2.new(relativeX, 0, 1, 0)
		thumb.Position = UDim2.new(relativeX, 0, 0.5, 0)
		valueLabel.Text = if maxVal <= 5 then string.format("%.1f", value) else tostring(math.floor(value))

		onChange(value)
	end

	track.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateSlider(input.Position.X)
		end
	end)

	thumb.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateSlider(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	return container
end

--------------------------------------------------------------------------------
-- SETTINGS GUI
--------------------------------------------------------------------------------

local settingsGui = Instance.new("ScreenGui")
settingsGui.Name = "SettingsGui"
settingsGui.ResetOnSpawn = false
settingsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
settingsGui.IgnoreGuiInset = true
settingsGui.Enabled = false
settingsGui.Parent = PlayerGui

-- Background overlay
local overlay = createFrame({
	Name = "Overlay",
	Parent = settingsGui,
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.4,
})

-- Main settings panel
local settingsPanel = createFrame({
	Name = "SettingsPanel",
	Parent = overlay,
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 650, 0, 500),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(25, 25, 35),
	BackgroundTransparency = 0.05,
})

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = settingsPanel

-- Title
createLabel({
	Name = "SettingsTitle",
	Parent = settingsPanel,
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.new(0.6, 0, 0, 35),
	AnchorPoint = Vector2.new(0.5, 0),
	Text = "SETTINGS",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
})

-- Close button
local closeButton = createTextButton({
	Name = "CloseButton",
	Parent = settingsPanel,
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.new(0, 30, 0, 30),
	AnchorPoint = Vector2.new(1, 0),
	Text = "X",
	TextColor3 = Color3.fromRGB(255, 100, 100),
	BackgroundColor3 = Color3.fromRGB(50, 50, 60),
})

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

--------------------------------------------------------------------------------
-- TAB SYSTEM
--------------------------------------------------------------------------------

local TAB_NAMES = { "Sensitivity", "Crosshair", "Audio", "Keybinds", "Other" }
local tabButtons: { TextButton } = {}
local tabPanels: { Frame } = {}
local activeTab = "Sensitivity"

-- Tab bar
local tabBar = createFrame({
	Name = "TabBar",
	Parent = settingsPanel,
	Position = UDim2.new(0, 10, 0, 50),
	Size = UDim2.new(1, -20, 0, 30),
	BackgroundTransparency = 1,
})

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 5)
tabLayout.Parent = tabBar

-- Content area
local contentArea = createFrame({
	Name = "ContentArea",
	Parent = settingsPanel,
	Position = UDim2.new(0, 10, 0, 90),
	Size = UDim2.new(1, -20, 1, -100),
	BackgroundColor3 = Color3.fromRGB(30, 30, 40),
	BackgroundTransparency = 0.3,
})

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 8)
contentCorner.Parent = contentArea

local function switchTab(tabName: string)
	activeTab = tabName
	for i, btn in tabButtons do
		if TAB_NAMES[i] == tabName then
			btn.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
			btn.BackgroundTransparency = 0.1
		else
			btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
			btn.BackgroundTransparency = 0.3
		end
	end
	for i, panel in tabPanels do
		panel.Visible = (TAB_NAMES[i] == tabName)
	end
end

-- Create tabs
for i, tabName in TAB_NAMES do
	-- Hide Keybinds tab on non-PC platforms
	if tabName == "Keybinds" and not isPCPlatform then
		continue
	end

	local tabBtn = createTextButton({
		Name = tabName .. "Tab",
		Parent = tabBar,
		Size = UDim2.new(0, 100, 1, 0),
		Text = tabName,
		BackgroundColor3 = if i == 1 then Color3.fromRGB(80, 160, 255) else Color3.fromRGB(50, 50, 65),
		BackgroundTransparency = if i == 1 then 0.1 else 0.3,
	})

	local tabBtnCorner = Instance.new("UICorner")
	tabBtnCorner.CornerRadius = UDim.new(0, 6)
	tabBtnCorner.Parent = tabBtn

	tabBtn.Activated:Connect(function()
		switchTab(tabName)
	end)

	table.insert(tabButtons, tabBtn)

	-- Create corresponding panel
	local panel = createFrame({
		Name = tabName .. "Panel",
		Parent = contentArea,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	})
	panel.Visible = (i == 1)
	table.insert(tabPanels, panel)
end

--------------------------------------------------------------------------------
-- SENSITIVITY TAB
--------------------------------------------------------------------------------

local sensitivityPanel = tabPanels[1]
if sensitivityPanel then
	createLabel({
		Name = "SensDesc",
		Parent = sensitivityPanel,
		Position = UDim2.new(0, 20, 0, 10),
		Size = UDim2.new(1, -40, 0, 25),
		Text = "Adjust aim sensitivity (0.1x - 5.0x)",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(180, 180, 200),
		Font = Enum.Font.Gotham,
	})

	createSlider(sensitivityPanel, "Sensitivity", 45, "Sensitivity", SENSITIVITY_MIN, SENSITIVITY_MAX, currentSettings.sensitivity, function(value: number)
		currentSettings.sensitivity = clampSensitivity(value)
		applySensitivity()
		saveSettings()
	end)
end

--------------------------------------------------------------------------------
-- CROSSHAIR TAB
--------------------------------------------------------------------------------

local crosshairPanel = tabPanels[2]
if crosshairPanel then
	-- Shape selector
	createLabel({
		Name = "ShapeLabel",
		Parent = crosshairPanel,
		Position = UDim2.new(0, 20, 0, 10),
		Size = UDim2.new(0.3, 0, 0, 30),
		Text = "Shape:",
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local shapes = { "dot", "cross", "circle" }
	local shapeButtons: { TextButton } = {}

	for idx, shape in shapes do
		local shapeBtn = createTextButton({
			Name = shape .. "Btn",
			Parent = crosshairPanel,
			Position = UDim2.new(0.3, (idx - 1) * 80, 0, 10),
			Size = UDim2.new(0, 70, 0, 30),
			Text = shape,
			BackgroundColor3 = if currentSettings.crosshair.shape == shape then Color3.fromRGB(80, 160, 255) else Color3.fromRGB(50, 50, 65),
		})

		local shapeBtnCorner = Instance.new("UICorner")
		shapeBtnCorner.CornerRadius = UDim.new(0, 6)
		shapeBtnCorner.Parent = shapeBtn

		shapeBtn.Activated:Connect(function()
			currentSettings.crosshair.shape = shape
			for _, btn in shapeButtons do
				btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
			end
			shapeBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
			saveSettings()
		end)

		table.insert(shapeButtons, shapeBtn)
	end

	-- Color picker (predefined colors)
	createLabel({
		Name = "ColorLabel",
		Parent = crosshairPanel,
		Position = UDim2.new(0, 20, 0, 50),
		Size = UDim2.new(0.3, 0, 0, 30),
		Text = "Color:",
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local colorOptions = {
		{ name = "White", hex = "#FFFFFF" },
		{ name = "Red", hex = "#FF0000" },
		{ name = "Green", hex = "#00FF00" },
		{ name = "Cyan", hex = "#00FFFF" },
		{ name = "Yellow", hex = "#FFFF00" },
		{ name = "Magenta", hex = "#FF00FF" },
	}

	local colorButtons: { TextButton } = {}
	for idx, colorOpt in colorOptions do
		local colorBtn = createTextButton({
			Name = colorOpt.name .. "ColorBtn",
			Parent = crosshairPanel,
			Position = UDim2.new(0.3, (idx - 1) * 40, 0, 55),
			Size = UDim2.new(0, 35, 0, 25),
			Text = "",
			BackgroundColor3 = hexToColor3(colorOpt.hex),
			BackgroundTransparency = 0,
		})

		local colorBtnCorner = Instance.new("UICorner")
		colorBtnCorner.CornerRadius = UDim.new(0, 4)
		colorBtnCorner.Parent = colorBtn

		-- Highlight border for active
		local colorStroke = Instance.new("UIStroke")
		colorStroke.Color = Color3.new(1, 1, 1)
		colorStroke.Thickness = if currentSettings.crosshair.color == colorOpt.hex then 2 else 0
		colorStroke.Parent = colorBtn

		colorBtn.Activated:Connect(function()
			currentSettings.crosshair.color = colorOpt.hex
			for _, btn in colorButtons do
				local stroke = btn:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Thickness = 0
				end
			end
			colorStroke.Thickness = 2
			saveSettings()
		end)

		table.insert(colorButtons, colorBtn)
	end

	-- Size slider
	createSlider(crosshairPanel, "CrosshairSize", 95, "Size", 1, 20, currentSettings.crosshair.size, function(value: number)
		currentSettings.crosshair.size = math.floor(value + 0.5)
		saveSettings()
	end)

	-- Opacity slider
	createSlider(crosshairPanel, "CrosshairOpacity", 145, "Opacity", 0, 1, currentSettings.crosshair.opacity, function(value: number)
		currentSettings.crosshair.opacity = math.clamp(value, 0, 1)
		saveSettings()
	end)
end

--------------------------------------------------------------------------------
-- AUDIO TAB
--------------------------------------------------------------------------------

local audioTabIndex = 3
local audioPanel = tabPanels[audioTabIndex]
if audioPanel then
	createLabel({
		Name = "AudioDesc",
		Parent = audioPanel,
		Position = UDim2.new(0, 20, 0, 10),
		Size = UDim2.new(1, -40, 0, 25),
		Text = "Volume levels (0 - 100)",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(180, 180, 200),
		Font = Enum.Font.Gotham,
	})

	createSlider(audioPanel, "MasterVol", 45, "Master", 0, 100, currentSettings.audio.master, function(value: number)
		currentSettings.audio.master = math.clamp(math.floor(value), 0, 100)
		applyAudioSettings()
		saveSettings()
	end)

	createSlider(audioPanel, "SFXVol", 95, "SFX", 0, 100, currentSettings.audio.sfx, function(value: number)
		currentSettings.audio.sfx = math.clamp(math.floor(value), 0, 100)
		applyAudioSettings()
		saveSettings()
	end)

	createSlider(audioPanel, "MusicVol", 145, "Music", 0, 100, currentSettings.audio.music, function(value: number)
		currentSettings.audio.music = math.clamp(math.floor(value), 0, 100)
		applyAudioSettings()
		saveSettings()
	end)

	createSlider(audioPanel, "VoiceVol", 195, "Voice Chat", 0, 100, currentSettings.audio.voice, function(value: number)
		currentSettings.audio.voice = math.clamp(math.floor(value), 0, 100)
		applyAudioSettings()
		saveSettings()
	end)
end

--------------------------------------------------------------------------------
-- KEYBINDS TAB (PC only)
--------------------------------------------------------------------------------

local keybindTabIndex = 4
local keybindPanel = tabPanels[keybindTabIndex]

local REBINDABLE_ACTIONS = {
	"Reload", "Ability1", "Ability2", "EmoteWheel", "Scoreboard", "Ping",
}

local keybindRows: { [string]: TextButton } = {}

if keybindPanel and isPCPlatform then
	createLabel({
		Name = "KeybindDesc",
		Parent = keybindPanel,
		Position = UDim2.new(0, 20, 0, 10),
		Size = UDim2.new(1, -40, 0, 25),
		Text = "Click a key to rebind. Press new key to assign.",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(180, 180, 200),
		Font = Enum.Font.Gotham,
	})

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "KeybindScroll"
	scrollFrame.Position = UDim2.new(0, 10, 0, 40)
	scrollFrame.Size = UDim2.new(1, -20, 1, -50)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #REBINDABLE_ACTIONS * 45)
	scrollFrame.Parent = keybindPanel

	local keybindListLayout = Instance.new("UIListLayout")
	keybindListLayout.FillDirection = Enum.FillDirection.Vertical
	keybindListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	keybindListLayout.Padding = UDim.new(0, 5)
	keybindListLayout.Parent = scrollFrame

	for _, action in REBINDABLE_ACTIONS do
		local row = createFrame({
			Name = action .. "Row",
			Parent = scrollFrame,
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = Color3.fromRGB(35, 35, 45),
			BackgroundTransparency = 0.3,
		})

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = row

		createLabel({
			Name = action .. "ActionLabel",
			Parent = row,
			Position = UDim2.new(0, 15, 0, 0),
			Size = UDim2.new(0.5, 0, 1, 0),
			Text = action,
			TextXAlignment = Enum.TextXAlignment.Left,
		})

		-- Get current key name
		local currentKey = "None"
		local inputCtrl = getInputController()
		if inputCtrl and inputCtrl.getKeybind then
			local keyCode = inputCtrl.getKeybind(action)
			if keyCode then
				currentKey = keyCode.Name
			end
		end

		local keyButton = createTextButton({
			Name = action .. "KeyBtn",
			Parent = row,
			Position = UDim2.new(1, -15, 0.5, 0),
			Size = UDim2.new(0, 100, 0, 28),
			AnchorPoint = Vector2.new(1, 0.5),
			Text = currentKey,
			BackgroundColor3 = Color3.fromRGB(60, 60, 80),
		})

		local keyBtnCorner = Instance.new("UICorner")
		keyBtnCorner.CornerRadius = UDim.new(0, 6)
		keyBtnCorner.Parent = keyButton

		keybindRows[action] = keyButton

		keyButton.Activated:Connect(function()
			if isRebinding then
				return
			end
			isRebinding = true
			rebindAction = action
			keyButton.Text = "Press key..."
			keyButton.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
		end)
	end
end

-- Keybind listener (captures next key press when rebinding)
if isPCPlatform then
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if not isRebinding or not rebindAction then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			local keyCode = input.KeyCode

			-- Cancel rebind with Escape
			if keyCode == Enum.KeyCode.Escape then
				local btn = keybindRows[rebindAction]
				if btn then
					local inputCtrl = getInputController()
					if inputCtrl and inputCtrl.getKeybind then
						local current = inputCtrl.getKeybind(rebindAction)
						btn.Text = if current then current.Name else "None"
					end
					btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
				end
				isRebinding = false
				rebindAction = nil
				return
			end

			-- Apply new keybind
			local btn = keybindRows[rebindAction]
			if btn then
				btn.Text = keyCode.Name
				btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
			end

			-- Update InputController
			local inputCtrl = getInputController()
			if inputCtrl and inputCtrl.setKeybind then
				inputCtrl.setKeybind(rebindAction, keyCode)
			end

			-- Store in settings state
			if not currentSettings.keybinds then
				currentSettings.keybinds = {}
			end
			currentSettings.keybinds[rebindAction] = keyCode.Name

			-- Notify InputController of keybind changes
			if inputCtrl and inputCtrl.loadKeybinds then
				local keybindMap: { [string]: Enum.KeyCode } = {}
				for act, keyName in currentSettings.keybinds :: { [string]: string } do
					local kc = (Enum.KeyCode :: any)[keyName]
					if kc then
						keybindMap[act] = kc
					end
				end
				inputCtrl.loadKeybinds(keybindMap)
			end

			isRebinding = false
			rebindAction = nil
			saveSettings()
		end
	end)
end

--------------------------------------------------------------------------------
-- OTHER TAB (Mobile-only matchmaking toggle)
--------------------------------------------------------------------------------

local otherTabIndex = 5
local otherPanel = tabPanels[otherTabIndex]
if otherPanel then
	-- Mobile-only matchmaking toggle
	createLabel({
		Name = "MobileMatchLabel",
		Parent = otherPanel,
		Position = UDim2.new(0, 20, 0, 15),
		Size = UDim2.new(0.6, 0, 0, 30),
		Text = "Mobile-Only Matchmaking",
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local toggleBg = createFrame({
		Name = "ToggleBg",
		Parent = otherPanel,
		Position = UDim2.new(0.7, 0, 0, 18),
		Size = UDim2.new(0, 50, 0, 26),
		BackgroundColor3 = if currentSettings.mobileOnlyMatchmaking then Color3.fromRGB(80, 200, 100) else Color3.fromRGB(80, 80, 90),
		BackgroundTransparency = 0,
	})

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(1, 0)
	toggleCorner.Parent = toggleBg

	local toggleKnob = createFrame({
		Name = "ToggleKnob",
		Parent = toggleBg,
		Position = if currentSettings.mobileOnlyMatchmaking then UDim2.new(1, -4, 0.5, 0) else UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.new(0, 20, 0, 20),
		AnchorPoint = if currentSettings.mobileOnlyMatchmaking then Vector2.new(1, 0.5) else Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
	})

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = toggleKnob

	-- Toggle button (invisible overlay)
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "ToggleBtn"
	toggleBtn.Size = UDim2.new(1, 0, 1, 0)
	toggleBtn.BackgroundTransparency = 1
	toggleBtn.Text = ""
	toggleBtn.Parent = toggleBg

	toggleBtn.Activated:Connect(function()
		currentSettings.mobileOnlyMatchmaking = not currentSettings.mobileOnlyMatchmaking
		local enabled = currentSettings.mobileOnlyMatchmaking

		-- Animate toggle
		local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local bgColor = if enabled then Color3.fromRGB(80, 200, 100) else Color3.fromRGB(80, 80, 90)
		TweenService:Create(toggleBg, tweenInfo, { BackgroundColor3 = bgColor }):Play()

		if enabled then
			toggleKnob.AnchorPoint = Vector2.new(1, 0.5)
			TweenService:Create(toggleKnob, tweenInfo, { Position = UDim2.new(1, -4, 0.5, 0) }):Play()
		else
			toggleKnob.AnchorPoint = Vector2.new(0, 0.5)
			TweenService:Create(toggleKnob, tweenInfo, { Position = UDim2.new(0, 4, 0.5, 0) }):Play()
		end

		saveSettings()
	end)

	-- Description for mobile-only matchmaking
	createLabel({
		Name = "MobileMatchDesc",
		Parent = otherPanel,
		Position = UDim2.new(0, 20, 0, 50),
		Size = UDim2.new(0.9, 0, 0, 20),
		Text = "Only match with other mobile players (mobile only feature)",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(140, 140, 160),
		Font = Enum.Font.Gotham,
	})
end

--------------------------------------------------------------------------------
-- APPLY SETTINGS FUNCTIONS
--------------------------------------------------------------------------------

applySensitivity = function()
	local clampedSens = clampSensitivity(currentSettings.sensitivity)
	UserInputService.MouseDeltaSensitivity = clampedSens
end

applyAudioSettings = function()
	-- Apply volumes to SoundService groups
	local masterGroup = SoundService:FindFirstChild("Master") :: SoundGroup?
	local sfxGroup = SoundService:FindFirstChild("SFX") :: SoundGroup?
	local musicGroup = SoundService:FindFirstChild("Music") :: SoundGroup?
	local voiceGroup = SoundService:FindFirstChild("VoiceChat") :: SoundGroup?

	-- Master volume applies to SoundService.Volume directly
	SoundService.Volume = currentSettings.audio.master / 100

	if sfxGroup then
		sfxGroup.Volume = currentSettings.audio.sfx / 100
	end
	if musicGroup then
		musicGroup.Volume = currentSettings.audio.music / 100
	end
	if voiceGroup then
		voiceGroup.Volume = currentSettings.audio.voice / 100
	end

	-- Fallback: if no groups, just apply master to SoundService
	if not masterGroup and not sfxGroup and not musicGroup then
		SoundService.Volume = currentSettings.audio.master / 100
	end
end

--------------------------------------------------------------------------------
-- SAVE/LOAD SETTINGS
--------------------------------------------------------------------------------

local saveDebounce = false

saveSettings = function()
	if saveDebounce then
		return
	end
	saveDebounce = true

	-- Debounce to avoid spamming server
	task.delay(0.5, function()
		saveDebounce = false

		-- Fire remote to server for persistence
		if UpdateSettingsRemote then
			local settingsPayload = {
				sensitivity = clampSensitivity(currentSettings.sensitivity),
				crosshair = currentSettings.crosshair,
				audio = currentSettings.audio,
				keybinds = currentSettings.keybinds,
				mobileOnlyMatchmaking = currentSettings.mobileOnlyMatchmaking,
			}
			UpdateSettingsRemote:FireServer(settingsPayload)
		end
	end)
end

--[[
	Loads settings received from the server on join and applies them locally.
]]
function SettingsController.loadSettings(settingsData: SettingsData?)
	if not settingsData then
		return
	end

	-- Apply sensitivity
	if settingsData.sensitivity then
		currentSettings.sensitivity = clampSensitivity(settingsData.sensitivity)
	end

	-- Apply crosshair
	if settingsData.crosshair then
		currentSettings.crosshair = settingsData.crosshair
	end

	-- Apply audio
	if settingsData.audio then
		currentSettings.audio = settingsData.audio
	end

	-- Apply keybinds (PC only)
	if settingsData.keybinds and isPCPlatform then
		currentSettings.keybinds = settingsData.keybinds

		-- Convert string key names back to Enum.KeyCode and apply
		local inputCtrl = getInputController()
		if inputCtrl and inputCtrl.loadKeybinds then
			local keybindMap: { [string]: Enum.KeyCode } = {}
			for action, keyName in settingsData.keybinds do
				local keyCode = (Enum.KeyCode :: any)[keyName]
				if keyCode then
					keybindMap[action] = keyCode
				end
			end
			inputCtrl.loadKeybinds(keybindMap)
		end
	end

	-- Apply mobile-only matchmaking
	if settingsData.mobileOnlyMatchmaking ~= nil then
		currentSettings.mobileOnlyMatchmaking = settingsData.mobileOnlyMatchmaking
	end

	-- Apply local effects
	applySensitivity()
	applyAudioSettings()
end

--[[
	Returns current settings state for external modules.
]]
function SettingsController.getSettings(): SettingsData
	return currentSettings
end

--[[
	Returns the current sensitivity value (clamped).
]]
function SettingsController.getSensitivity(): number
	return clampSensitivity(currentSettings.sensitivity)
end

--------------------------------------------------------------------------------
-- TOGGLE VISIBILITY
--------------------------------------------------------------------------------

function SettingsController.toggle()
	isSettingsVisible = not isSettingsVisible
	settingsGui.Enabled = isSettingsVisible
end

function SettingsController.show()
	isSettingsVisible = true
	settingsGui.Enabled = true
end

function SettingsController.hide()
	isSettingsVisible = false
	settingsGui.Enabled = false
	-- Cancel any active rebind
	if isRebinding and rebindAction then
		local btn = keybindRows[rebindAction]
		if btn then
			btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
			local inputCtrl = getInputController()
			if inputCtrl and inputCtrl.getKeybind then
				local current = inputCtrl.getKeybind(rebindAction)
				btn.Text = if current then current.Name else "None"
			end
		end
		isRebinding = false
		rebindAction = nil
	end
end

function SettingsController.isVisible(): boolean
	return isSettingsVisible
end

--------------------------------------------------------------------------------
-- INPUT: Toggle with Escape key / Settings button
--------------------------------------------------------------------------------

-- Close button event
closeButton.Activated:Connect(function()
	SettingsController.hide()
end)

-- Escape key toggles settings panel
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	-- Don't process Escape while rebinding (handled separately in rebind listener)
	if isRebinding then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		if isSettingsVisible then
			SettingsController.hide()
		else
			SettingsController.show()
		end
	end
end)

-- Click on overlay background to close
overlay.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		-- Only close if clicking the overlay directly, not the panel
		local mousePos = input.Position
		local panelAbsPos = settingsPanel.AbsolutePosition
		local panelAbsSize = settingsPanel.AbsoluteSize

		local isInsidePanel = mousePos.X >= panelAbsPos.X
			and mousePos.X <= panelAbsPos.X + panelAbsSize.X
			and mousePos.Y >= panelAbsPos.Y
			and mousePos.Y <= panelAbsPos.Y + panelAbsSize.Y

		if not isInsidePanel then
			SettingsController.hide()
		end
	end
end)

--------------------------------------------------------------------------------
-- LISTEN FOR SETTINGS FROM SERVER ON JOIN
--------------------------------------------------------------------------------

local function onSettingsReceived(settingsData: any)
	if typeof(settingsData) == "table" then
		SettingsController.loadSettings(settingsData :: SettingsData)
	end
end

-- Listen for settings load from server (sent on join via a remote)
if Remotes then
	local loadSettingsRemote = Remotes:FindFirstChild("LoadSettings") :: RemoteEvent?
	if loadSettingsRemote then
		loadSettingsRemote.OnClientEvent:Connect(onSettingsReceived)
	end
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

local function initialize()
	-- Apply default settings on startup
	applySensitivity()
	applyAudioSettings()

	print("[SettingsController] Initialized")
end

initialize()

return SettingsController
