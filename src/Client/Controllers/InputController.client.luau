--!strict
--[[
	InputController
	Handles all player input across PC, Console, and Mobile platforms.
	Detects platform and routes input to appropriate RemoteEvents.
	Supports keybind remapping via player settings.

	Requirements: 1.1, 19.1, 19.2, 20.4
]]

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Platform detection
export type Platform = "PC" | "Console" | "Mobile"

local function detectPlatform(): Platform
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Mobile"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Console"
	else
		return "PC"
	end
end

-- Default keybind mappings
local DEFAULT_KEYBINDS: { [string]: Enum.KeyCode } = {
	Fire = Enum.KeyCode.Unknown, -- Mouse handled separately (MouseButton1)
	ADS = Enum.KeyCode.Unknown, -- Mouse handled separately (MouseButton2)
	Reload = Enum.KeyCode.R,
	Ability1 = Enum.KeyCode.Q,
	Ability2 = Enum.KeyCode.E,
	EmoteWheel = Enum.KeyCode.T,
	Scoreboard = Enum.KeyCode.Tab,
	Ping = Enum.KeyCode.M,
	MoveForward = Enum.KeyCode.W,
	MoveBackward = Enum.KeyCode.S,
	MoveLeft = Enum.KeyCode.A,
	MoveRight = Enum.KeyCode.D,
}

-- Console button mappings
local GAMEPAD_MAPPINGS: { [string]: Enum.KeyCode } = {
	Fire = Enum.KeyCode.ButtonR2,
	ADS = Enum.KeyCode.ButtonL2,
	Reload = Enum.KeyCode.ButtonX,
	Ability1 = Enum.KeyCode.ButtonL1,
	Ability2 = Enum.KeyCode.ButtonR1,
	EmoteWheel = Enum.KeyCode.DPadUp,
	Scoreboard = Enum.KeyCode.ButtonSelect,
	Ping = Enum.KeyCode.DPadDown,
}

-- Module state
local InputController = {}
local currentPlatform: Platform = detectPlatform()
local activeKeybinds: { [string]: Enum.KeyCode } = table.clone(DEFAULT_KEYBINDS)
local isADS = false
local isEmoteWheelOpen = false
local isScoreboardOpen = false

-- Remote references (lazily fetched)
local remotes: { [string]: RemoteEvent } = {}

local function getRemote(name: string): RemoteEvent?
	if remotes[name] then
		return remotes[name]
	end

	local remote = ReplicatedStorage:FindFirstChild("Remotes")
	if remote then
		local event = remote:FindFirstChild(name) :: RemoteEvent?
		if event then
			remotes[name] = event
			return event
		end
	end

	-- Fallback: try direct child of ReplicatedStorage
	local directEvent = ReplicatedStorage:FindFirstChild(name) :: RemoteEvent?
	if directEvent then
		remotes[name] = directEvent
		return directEvent
	end

	return nil
end

--[[
	Gets the camera aim data for fire requests.
	Returns origin (CFrame position) and direction (lookVector).
]]
local function getAimData(): (Vector3, Vector3)
	local cam = Camera or workspace.CurrentCamera
	if cam then
		local cframe = cam.CFrame
		return cframe.Position, cframe.LookVector
	end
	-- Fallback if camera is unavailable
	return Vector3.zero, Vector3.new(0, 0, -1)
end

--[[
	Performs a raycast from the camera to get the mouse hit position in the world.
	Used for ping system.
]]
local function getMouseHitPosition(): Vector3?
	local cam = Camera or workspace.CurrentCamera
	if not cam then
		return nil
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = cam:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local character = LocalPlayer.Character
	if character then
		raycastParams.FilterDescendantsInstances = { character }
	end

	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
	if result then
		return result.Position
	end

	-- If no hit, return a point far along the ray
	return ray.Origin + ray.Direction * 1000
end

--[[
	Loads keybinds from player settings module.
	Falls back to defaults if settings are unavailable.
]]
function InputController.loadKeybinds(customBinds: { [string]: Enum.KeyCode }?)
	if customBinds then
		for action, keyCode in customBinds do
			if DEFAULT_KEYBINDS[action] ~= nil then
				activeKeybinds[action] = keyCode
			end
		end
	else
		activeKeybinds = table.clone(DEFAULT_KEYBINDS)
	end
end

--[[
	Updates a single keybind for remapping support.
]]
function InputController.setKeybind(action: string, keyCode: Enum.KeyCode)
	if DEFAULT_KEYBINDS[action] ~= nil then
		activeKeybinds[action] = keyCode
	end
end

--[[
	Returns the current keybind for an action.
]]
function InputController.getKeybind(action: string): Enum.KeyCode?
	return activeKeybinds[action]
end

--[[
	Returns the detected platform.
]]
function InputController.getPlatform(): Platform
	return currentPlatform
end

-- =====================
-- INPUT HANDLERS
-- =====================

local function handleFireInput()
	local remote = getRemote("FireWeapon")
	if remote then
		local origin, direction = getAimData()
		remote:FireServer(origin, direction)
	end
end

local function handleReloadInput()
	local remote = getRemote("ReloadWeapon")
	if remote then
		remote:FireServer()
	end
end

local function handleAbilityInput(slotIndex: number)
	local remote = getRemote("ActivateAbility")
	if remote then
		remote:FireServer(slotIndex)
	end
end

local function handlePingInput()
	local remote = getRemote("SendPing")
	if remote then
		local hitPos = getMouseHitPosition()
		if hitPos then
			remote:FireServer(hitPos)
		end
	end
end

local function handleEmoteSelection(emoteId: string)
	local remote = getRemote("PlayEmote")
	if remote then
		remote:FireServer(emoteId)
	end
end

local function handleToggleEmoteWheel()
	isEmoteWheelOpen = not isEmoteWheelOpen
	-- EmoteWheelController handles the UI display; this toggles state
end

local function handleToggleScoreboard(show: boolean)
	isScoreboardOpen = show
	-- HUDController handles scoreboard rendering; this tracks state
end

-- =====================
-- PC INPUT (Keyboard + Mouse)
-- =====================

local function setupPCInput()
	-- Mouse button input
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		-- Mouse fire (left click)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			handleFireInput()
			return
		end

		-- Mouse ADS (right click)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			isADS = true
			return
		end

		-- Keyboard input
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local keyCode = input.KeyCode

			if keyCode == activeKeybinds.Reload then
				handleReloadInput()
			elseif keyCode == activeKeybinds.Ability1 then
				handleAbilityInput(1)
			elseif keyCode == activeKeybinds.Ability2 then
				handleAbilityInput(2)
			elseif keyCode == activeKeybinds.EmoteWheel then
				handleToggleEmoteWheel()
			elseif keyCode == activeKeybinds.Scoreboard then
				handleToggleScoreboard(true)
			elseif keyCode == activeKeybinds.Ping then
				handlePingInput()
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		-- Release ADS (right click)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			isADS = false
			return
		end

		-- Release scoreboard
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == activeKeybinds.Scoreboard then
				handleToggleScoreboard(false)
			end
		end
	end)
end

-- =====================
-- CONSOLE INPUT (Gamepad)
-- =====================

local function setupConsoleInput()
	ContextActionService:BindAction("GamepadFire", function(_actionName, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin then
			handleFireInput()
		end
		return Enum.ContextActionResult.Sink
	end, false, GAMEPAD_MAPPINGS.Fire)

	ContextActionService:BindAction("GamepadADS", function(_actionName, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin then
			isADS = true
		elseif inputState == Enum.UserInputState.End then
			isADS = false
		end
		return Enum.ContextActionResult.Sink
	end, false, GAMEPAD_MAPPINGS.ADS)

	ContextActionService:BindAction("GamepadReload", function(_actionName, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin then
			handleReloadInput()
		end
		return Enum.ContextActionResult.Sink
	end, false, GAMEPAD_MAPPINGS.Reload)

	ContextActionService:BindAction("GamepadAbility1", function(_actionName, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin then
			handleAbilityInput(1)
		end
		return Enum.ContextActionResult.Sink
	end, false, GAMEPAD_MAPPINGS.Ability1)

	ContextActionService:BindAction("GamepadAbility2", function(_actionName, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin then
			handleAbilityInput(2)
		end
		return Enum.ContextActionResult.Sink
	end, false, GAMEPAD_MAPPINGS.Ability2)

	ContextActionService:BindAction("GamepadEmoteWheel", function(_actionName, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin then
			handleToggleEmoteWheel()
		end
		return Enum.ContextActionResult.Sink
	end, false, GAMEPAD_MAPPINGS.EmoteWheel)

	ContextActionService:BindAction("GamepadScoreboard", function(_actionName, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin then
			handleToggleScoreboard(true)
		elseif inputState == Enum.UserInputState.End then
			handleToggleScoreboard(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, GAMEPAD_MAPPINGS.Scoreboard)

	ContextActionService:BindAction("GamepadPing", function(_actionName, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin then
			handlePingInput()
		end
		return Enum.ContextActionResult.Sink
	end, false, GAMEPAD_MAPPINGS.Ping)
end

-- =====================
-- MOBILE INPUT (Touch)
-- =====================

local function setupMobileInput()
	--[[
		Mobile virtual UI buttons are created and managed by HUDController.
		This controller provides the action handlers that HUDController invokes
		when the player taps virtual buttons.
		
		HUDController calls these exported functions:
		- InputController.onMobileFire()
		- InputController.onMobileReload()
		- InputController.onMobileAbility(slotIndex)
		- InputController.onMobilePing()
		- InputController.onMobileEmoteWheel()
		- InputController.onMobileADS(active)
	]]

	-- Touch-based fire can also be handled through ContextActionService for direct screen tap
	ContextActionService:BindAction("MobileFire", function(_actionName, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin then
			handleFireInput()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.UserInputType.Touch)
end

-- Mobile action handlers (called by HUDController virtual buttons)
function InputController.onMobileFire()
	handleFireInput()
end

function InputController.onMobileReload()
	handleReloadInput()
end

function InputController.onMobileAbility(slotIndex: number)
	handleAbilityInput(slotIndex)
end

function InputController.onMobilePing()
	handlePingInput()
end

function InputController.onMobileEmoteWheel()
	handleToggleEmoteWheel()
end

function InputController.onMobileADS(active: boolean)
	isADS = active
end

-- Public emote selection handler (called by EmoteWheelController)
function InputController.selectEmote(emoteId: string)
	handleEmoteSelection(emoteId)
end

-- =====================
-- STATE QUERIES
-- =====================

function InputController.isAiming(): boolean
	return isADS
end

function InputController.isEmoteWheelVisible(): boolean
	return isEmoteWheelOpen
end

function InputController.isScoreboardVisible(): boolean
	return isScoreboardOpen
end

-- =====================
-- PLATFORM RE-DETECTION
-- =====================

-- Re-detect platform if input type changes (e.g., plugging in controller)
local function onLastInputTypeChanged(lastInputType: Enum.UserInputType)
	local newPlatform: Platform

	if lastInputType == Enum.UserInputType.Touch then
		newPlatform = "Mobile"
	elseif lastInputType == Enum.UserInputType.Gamepad1 then
		newPlatform = "Console"
	elseif lastInputType == Enum.UserInputType.Keyboard or lastInputType == Enum.UserInputType.MouseMovement then
		newPlatform = "PC"
	else
		return
	end

	if newPlatform ~= currentPlatform then
		currentPlatform = newPlatform
	end
end

-- =====================
-- INITIALIZATION
-- =====================

local function initialize()
	-- Detect initial platform
	currentPlatform = detectPlatform()

	-- Set up platform-specific input handling
	if currentPlatform == "PC" then
		setupPCInput()
	elseif currentPlatform == "Console" then
		setupConsoleInput()
		-- Also set up PC input as fallback for keyboard
		setupPCInput()
	elseif currentPlatform == "Mobile" then
		setupMobileInput()
	end

	-- Listen for platform changes
	UserInputService.LastInputTypeChanged:Connect(onLastInputTypeChanged)

	-- Load custom keybinds from settings if available
	-- (SettingsController will call InputController.loadKeybinds when settings load)

	print("[InputController] Initialized for platform:", currentPlatform)
end

initialize()

return InputController
