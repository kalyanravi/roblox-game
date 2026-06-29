--!strict
--[[
	EmoteWheelController
	Creates a radial menu UI (ScreenGui) with up to 8 emote slots arranged in a circle.
	Toggles visibility when emote wheel input is triggered (from InputController).
	On emote selection: fires PlayEmote RemoteEvent with emoteId, closes wheel.
	Cancels emote on any movement or combat input.
	Displays emote names in each slot.
	Default emotes: "wave" and "thumbs_up" (free, always available).

	Requirements: 4.4, 18.1, 18.2, 18.3, 18.4, 18.5
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Remote Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local PlayEmoteRemote: RemoteEvent? = if Remotes then Remotes:FindFirstChild("PlayEmote") :: RemoteEvent? else nil

-- Constants
local MAX_EMOTE_SLOTS = 8
local WHEEL_RADIUS = 120
local SLOT_SIZE = 70

-- Movement/combat keys that cancel an emote
local CANCEL_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.Q] = true, -- Ability1
	[Enum.KeyCode.E] = true, -- Ability2
}

local CANCEL_INPUT_TYPES: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.MouseButton1] = true, -- Fire
	[Enum.UserInputType.MouseButton2] = true, -- ADS
}

-- Emote definitions
type EmoteSlot = {
	id: string,
	name: string,
}

-- Default equipped emotes (wave and thumbs_up are free)
local equippedEmotes: { EmoteSlot } = {
	{ id = "wave", name = "Wave" },
	{ id = "thumbs_up", name = "Thumbs Up" },
}

-- State
local isWheelVisible = false
local isEmotePlaying = false

--------------------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EmoteWheelGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Enabled = true
screenGui.Parent = PlayerGui

-- Background overlay (semi-transparent when wheel is open)
local backgroundOverlay = Instance.new("Frame")
backgroundOverlay.Name = "EmoteWheelBackground"
backgroundOverlay.Size = UDim2.new(1, 0, 1, 0)
backgroundOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
backgroundOverlay.BackgroundTransparency = 0.7
backgroundOverlay.BorderSizePixel = 0
backgroundOverlay.Visible = false
backgroundOverlay.Parent = screenGui

-- Wheel container (centered)
local wheelContainer = Instance.new("Frame")
wheelContainer.Name = "EmoteWheelContainer"
wheelContainer.Size = UDim2.new(0, WHEEL_RADIUS * 2 + SLOT_SIZE, 0, WHEEL_RADIUS * 2 + SLOT_SIZE)
wheelContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
wheelContainer.AnchorPoint = Vector2.new(0.5, 0.5)
wheelContainer.BackgroundTransparency = 1
wheelContainer.BorderSizePixel = 0
wheelContainer.Visible = false
wheelContainer.Parent = screenGui

-- Center label
local centerLabel = Instance.new("TextLabel")
centerLabel.Name = "CenterLabel"
centerLabel.Size = UDim2.new(0, 80, 0, 30)
centerLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
centerLabel.AnchorPoint = Vector2.new(0.5, 0.5)
centerLabel.BackgroundTransparency = 1
centerLabel.Text = "EMOTES"
centerLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
centerLabel.TextScaled = true
centerLabel.Font = Enum.Font.GothamBold
centerLabel.BorderSizePixel = 0
centerLabel.Parent = wheelContainer

-- Slot buttons arranged in a circle
type SlotButton = {
	button: TextButton,
	emoteId: string?,
}

local slotButtons: { SlotButton } = {}

--------------------------------------------------------------------------------
-- WHEEL VISIBILITY (forward-declared for use in selectEmote)
--------------------------------------------------------------------------------

local function openWheel()
	isWheelVisible = true
	backgroundOverlay.Visible = true
	wheelContainer.Visible = true
end

local function closeWheel()
	isWheelVisible = false
	backgroundOverlay.Visible = false
	wheelContainer.Visible = false
end

--------------------------------------------------------------------------------
-- EMOTE SELECTION (forward-declared for use in createSlotButtons)
--------------------------------------------------------------------------------

local function selectEmote(emoteId: string)
	-- Fire remote event to server
	if PlayEmoteRemote then
		PlayEmoteRemote:FireServer(emoteId)
	end

	-- Mark emote as playing
	isEmotePlaying = true

	-- Close the wheel
	closeWheel()
end

--------------------------------------------------------------------------------
-- SLOT BUTTON CREATION
--------------------------------------------------------------------------------

local function createSlotButtons()
	-- Clear existing slot buttons
	for _, slot in slotButtons do
		if slot.button and slot.button.Parent then
			slot.button:Destroy()
		end
	end
	table.clear(slotButtons)

	local totalSlots = math.min(MAX_EMOTE_SLOTS, math.max(#equippedEmotes, 2))

	for i = 1, totalSlots do
		local angle = (2 * math.pi / totalSlots) * (i - 1) - math.pi / 2
		local offsetX = math.cos(angle) * WHEEL_RADIUS
		local offsetY = math.sin(angle) * WHEEL_RADIUS

		local button = Instance.new("TextButton")
		button.Name = "EmoteSlot" .. tostring(i)
		button.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
		button.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.TextScaled = true
		button.Parent = wheelContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = button

		local emote = equippedEmotes[i]
		if emote then
			button.Text = emote.name
			button.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
			button.BackgroundTransparency = 0.2
			button.TextColor3 = Color3.new(1, 1, 1)
		else
			button.Text = ""
			button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			button.BackgroundTransparency = 0.6
			button.TextColor3 = Color3.fromRGB(100, 100, 100)
		end

		local slotEntry: SlotButton = {
			button = button,
			emoteId = if emote then emote.id else nil,
		}
		table.insert(slotButtons, slotEntry)

		-- Click handler for emote selection
		local emoteId = if emote then emote.id else nil
		button.Activated:Connect(function()
			if emoteId then
				selectEmote(emoteId)
			end
		end)
	end
end

local function toggleWheel()
	if isWheelVisible then
		closeWheel()
	else
		openWheel()
	end
end

--------------------------------------------------------------------------------
-- EMOTE CANCELLATION — Movement or combat input cancels playing emote
--------------------------------------------------------------------------------

local function cancelEmote()
	if not isEmotePlaying then
		return
	end
	isEmotePlaying = false
	-- Server will handle stopping the animation via the CancelEmote remote or
	-- the next movement input sent via character movement.
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	-- Cancel emote on movement/combat input
	if isEmotePlaying then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if CANCEL_KEYS[input.KeyCode] then
				cancelEmote()
				return
			end
		end

		if CANCEL_INPUT_TYPES[input.UserInputType] then
			cancelEmote()
			return
		end
	end
end)

--------------------------------------------------------------------------------
-- TOGGLE LISTENER — Listen for emote wheel keybind (T key / DPadUp)
-- The InputController handles primary routing; this listens directly as backup
-- and for the toggle behavior.
--------------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.T then
			toggleWheel()
		end
	elseif input.UserInputType == Enum.UserInputType.Gamepad1 then
		if input.KeyCode == Enum.KeyCode.DPadUp then
			toggleWheel()
		end
	end
end)

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

local EmoteWheelController = {}

function EmoteWheelController.setEquippedEmotes(emotes: { { id: string, name: string } })
	equippedEmotes = {}
	for i = 1, math.min(MAX_EMOTE_SLOTS, #emotes) do
		table.insert(equippedEmotes, { id = emotes[i].id, name = emotes[i].name })
	end
	createSlotButtons()
end

function EmoteWheelController.isVisible(): boolean
	return isWheelVisible
end

function EmoteWheelController.open()
	openWheel()
end

function EmoteWheelController.close()
	closeWheel()
end

function EmoteWheelController.toggle()
	toggleWheel()
end

function EmoteWheelController.isEmotePlaying(): boolean
	return isEmotePlaying
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

createSlotButtons()
print("[EmoteWheelController] Initialized with", #equippedEmotes, "emotes")

return EmoteWheelController
