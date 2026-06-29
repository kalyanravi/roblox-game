--!strict
--[[
	AbilityUIController
	Manages ability cooldown display on the HUD.
	Listens to AbilityCooldown RemoteEvent from server (slotIndex, cooldownDuration).
	Tracks cooldown state for 2 ability slots locally.
	Updates HUD ability cooldown indicators using a heartbeat loop.
	Displays ability name in each slot from AbilityDefinitions.
	Shows "READY" when ability is off cooldown.

	Requirements: 4.4
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Shared definitions
local AbilityDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Definitions"):WaitForChild("AbilityDefinitions"))

-- Remote Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local AbilityCooldownRemote: RemoteEvent? = if Remotes then Remotes:FindFirstChild("AbilityCooldown") :: RemoteEvent? else nil

-- Cooldown state per slot
type CooldownState = {
	remaining: number,
	duration: number,
	abilityId: string,
}

local cooldownSlots: { CooldownState? } = { nil, nil }

-- Equipped ability IDs for each slot (default to first two available)
local equippedAbilities: { string } = { "dash", "heal" }

--------------------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AbilityUIOverlay"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = PlayerGui

local container = Instance.new("Frame")
container.Name = "AbilitySlotContainer"
container.Size = UDim2.new(0, 140, 0, 60)
container.Position = UDim2.new(0.5, 0, 1, -130)
container.AnchorPoint = Vector2.new(0.5, 1)
container.BackgroundTransparency = 1
container.BorderSizePixel = 0
container.Parent = screenGui

-- Slot UI elements
type SlotUI = {
	frame: Frame,
	nameLabel: TextLabel,
	cooldownLabel: TextLabel,
	overlay: Frame,
}

local slotUIs: { SlotUI } = {}

local function getAbilityName(abilityId: string): string
	for _, def in AbilityDefinitions do
		if def.id == abilityId then
			return def.name
		end
	end
	return abilityId
end

for i = 1, 2 do
	local slotFrame = Instance.new("Frame")
	slotFrame.Name = "AbilitySlot" .. tostring(i)
	slotFrame.Size = UDim2.new(0, 60, 0, 60)
	slotFrame.Position = UDim2.new(0, (i - 1) * 70, 0, 0)
	slotFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 70)
	slotFrame.BackgroundTransparency = 0.2
	slotFrame.BorderSizePixel = 0
	slotFrame.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = slotFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 100, 180)
	stroke.Thickness = 2
	stroke.Parent = slotFrame

	-- Ability name label (top)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "AbilityName"
	nameLabel.Size = UDim2.new(1, -4, 0, 16)
	nameLabel.Position = UDim2.new(0, 2, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = getAbilityName(equippedAbilities[i])
	nameLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.BorderSizePixel = 0
	nameLabel.Parent = slotFrame

	-- Cooldown overlay (darkens during cooldown)
	local overlay = Instance.new("Frame")
	overlay.Name = "CooldownOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Parent = slotFrame

	local overlayCorner = Instance.new("UICorner")
	overlayCorner.CornerRadius = UDim.new(0, 8)
	overlayCorner.Parent = overlay

	-- Cooldown / status label (center)
	local cooldownLabel = Instance.new("TextLabel")
	cooldownLabel.Name = "CooldownLabel"
	cooldownLabel.Size = UDim2.new(1, 0, 0, 30)
	cooldownLabel.Position = UDim2.new(0, 0, 0, 20)
	cooldownLabel.BackgroundTransparency = 1
	cooldownLabel.Text = "READY"
	cooldownLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	cooldownLabel.TextScaled = true
	cooldownLabel.Font = Enum.Font.GothamBold
	cooldownLabel.BorderSizePixel = 0
	cooldownLabel.Parent = slotFrame

	slotUIs[i] = {
		frame = slotFrame,
		nameLabel = nameLabel,
		cooldownLabel = cooldownLabel,
		overlay = overlay,
	}
end

--------------------------------------------------------------------------------
-- COOLDOWN LOGIC
--------------------------------------------------------------------------------

local function startCooldown(slotIndex: number, cooldownDuration: number)
	if slotIndex < 1 or slotIndex > 2 then
		return
	end

	cooldownSlots[slotIndex] = {
		remaining = cooldownDuration,
		duration = cooldownDuration,
		abilityId = equippedAbilities[slotIndex],
	}
end

local function updateSlotUI(slotIndex: number)
	local ui = slotUIs[slotIndex]
	if not ui then
		return
	end

	local state = cooldownSlots[slotIndex]
	if state and state.remaining > 0 then
		-- On cooldown
		ui.overlay.BackgroundTransparency = 0.5
		ui.cooldownLabel.Text = string.format("%.1f", state.remaining)
		ui.cooldownLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	else
		-- Ready
		ui.overlay.BackgroundTransparency = 1
		ui.cooldownLabel.Text = "READY"
		ui.cooldownLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	end
end

--------------------------------------------------------------------------------
-- HEARTBEAT LOOP — Decrement cooldown remaining time
--------------------------------------------------------------------------------

RunService.Heartbeat:Connect(function(deltaTime: number)
	for i = 1, 2 do
		local state = cooldownSlots[i]
		if state and state.remaining > 0 then
			state.remaining = math.max(0, state.remaining - deltaTime)
			if state.remaining <= 0 then
				cooldownSlots[i] = nil
			end
		end
		updateSlotUI(i)
	end
end)

--------------------------------------------------------------------------------
-- REMOTE EVENT LISTENER
--------------------------------------------------------------------------------

if AbilityCooldownRemote then
	AbilityCooldownRemote.OnClientEvent:Connect(function(slotIndex: any, cooldownDuration: any)
		if typeof(slotIndex) == "number" and typeof(cooldownDuration) == "number" then
			startCooldown(slotIndex, cooldownDuration)
		end
	end)
end

--------------------------------------------------------------------------------
-- PUBLIC API (for other client modules to update equipped abilities)
--------------------------------------------------------------------------------

local AbilityUIController = {}

function AbilityUIController.setEquippedAbility(slotIndex: number, abilityId: string)
	if slotIndex < 1 or slotIndex > 2 then
		return
	end
	equippedAbilities[slotIndex] = abilityId
	local ui = slotUIs[slotIndex]
	if ui then
		ui.nameLabel.Text = getAbilityName(abilityId)
	end
end

function AbilityUIController.getEquippedAbilities(): { string }
	return table.clone(equippedAbilities)
end

print("[AbilityUIController] Initialized")

return AbilityUIController
