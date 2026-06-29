--!strict
--[[
	ChestUIController (Client)
	Listens to ChestAwarded RemoteEvent from server (receives tier and rewards).
	Displays a chest opening animation: chest model appears, opens with tween, reveals items.
	Shows reward items one by one with rarity glow effect.
	Shows total coins and gems awarded.
	Auto-dismisses after 5 seconds or on click/tap.
	Requirements: 9.7
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

----------------------------------------------------------------------
-- Remote Events
----------------------------------------------------------------------

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local ChestAwardedRemote: RemoteEvent? = if Remotes
	then Remotes:FindFirstChild("ChestAwarded") :: RemoteEvent?
	else ReplicatedStorage:FindFirstChild("ChestAwarded") :: RemoteEvent?

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local AUTO_DISMISS_SECONDS = 5
local ITEM_REVEAL_DELAY = 0.6 -- seconds between revealing each item

local TIER_COLORS: { [string]: Color3 } = {
	Bronze = Color3.fromRGB(205, 127, 50),
	Silver = Color3.fromRGB(192, 192, 192),
	Gold = Color3.fromRGB(255, 215, 0),
}

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(50, 130, 255),
	Epic = Color3.fromRGB(160, 50, 255),
	Legendary = Color3.fromRGB(255, 180, 0),
	Mythic = Color3.fromRGB(255, 50, 80),
}

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local isChestAnimPlaying = false
local activeGui: ScreenGui? = nil

----------------------------------------------------------------------
-- UI Helpers
----------------------------------------------------------------------

local function createChestGui(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChestOpeningGui"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 90
	gui.Parent = PlayerGui
	return gui
end

local function createOverlay(parent: ScreenGui): Frame
	local overlay = Instance.new("Frame")
	overlay.Name = "ChestOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.Parent = parent
	return overlay
end

local function createChestModel(parent: Frame, tier: string): Frame
	local tierColor = TIER_COLORS[tier] or TIER_COLORS.Bronze

	-- Chest body (represented as a styled frame since we're in 2D ScreenGui)
	local chestFrame = Instance.new("Frame")
	chestFrame.Name = "ChestModel"
	chestFrame.Size = UDim2.new(0, 160, 0, 140)
	chestFrame.Position = UDim2.new(0.5, 0, 0.35, 0)
	chestFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	chestFrame.BackgroundColor3 = tierColor
	chestFrame.BackgroundTransparency = 0.1
	chestFrame.BorderSizePixel = 0
	chestFrame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = chestFrame

	-- Glow border
	local glow = Instance.new("UIStroke")
	glow.Color = tierColor
	glow.Thickness = 3
	glow.Transparency = 0.2
	glow.Parent = chestFrame

	-- Tier label on chest
	local tierLabel = Instance.new("TextLabel")
	tierLabel.Name = "TierLabel"
	tierLabel.Size = UDim2.new(1, 0, 0.4, 0)
	tierLabel.Position = UDim2.new(0, 0, 0.1, 0)
	tierLabel.BackgroundTransparency = 1
	tierLabel.Text = "📦"
	tierLabel.TextScaled = true
	tierLabel.Font = Enum.Font.GothamBold
	tierLabel.Parent = chestFrame

	local tierNameLabel = Instance.new("TextLabel")
	tierNameLabel.Name = "TierName"
	tierNameLabel.Size = UDim2.new(1, 0, 0.3, 0)
	tierNameLabel.Position = UDim2.new(0, 0, 0.55, 0)
	tierNameLabel.BackgroundTransparency = 1
	tierNameLabel.Text = tier .. " Chest"
	tierNameLabel.TextColor3 = Color3.new(1, 1, 1)
	tierNameLabel.TextScaled = true
	tierNameLabel.Font = Enum.Font.GothamBold
	tierNameLabel.Parent = chestFrame

	-- Start small for opening animation
	chestFrame.Size = UDim2.new(0, 0, 0, 0)

	return chestFrame
end

local function createRewardCard(parent: Frame, itemId: string, index: number, totalItems: number): Frame
	local card = Instance.new("Frame")
	card.Name = "RewardCard_" .. tostring(index)
	-- Spread items horizontally
	local spacing = 1 / (totalItems + 1)
	card.Size = UDim2.new(0, 100, 0, 100)
	card.Position = UDim2.new(spacing * index, 0, 0.6, 0)
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	card.BackgroundTransparency = 0.2
	card.BorderSizePixel = 0
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	-- Rarity glow (default to Rare for placeholder)
	local rarityColor = RARITY_COLORS.Rare
	local glowStroke = Instance.new("UIStroke")
	glowStroke.Name = "RarityGlow"
	glowStroke.Color = rarityColor
	glowStroke.Thickness = 2
	glowStroke.Transparency = 0.3
	glowStroke.Parent = card

	-- Item name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	nameLabel.Size = UDim2.new(0.9, 0, 0.4, 0)
	nameLabel.Position = UDim2.new(0.5, 0, 0.55, 0)
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemId
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextWrapped = true
	nameLabel.Parent = card

	-- Icon placeholder
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0.8, 0, 0.45, 0)
	icon.Position = UDim2.new(0.5, 0, 0.05, 0)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "🎁"
	icon.TextScaled = true
	icon.Font = Enum.Font.GothamBold
	icon.Parent = card

	-- Start invisible for reveal animation
	card.BackgroundTransparency = 1
	nameLabel.TextTransparency = 1
	icon.TextTransparency = 1
	glowStroke.Transparency = 1

	return card
end

local function createCurrencyDisplay(parent: Frame, coins: number, gems: number): TextLabel
	local currencyLabel = Instance.new("TextLabel")
	currencyLabel.Name = "CurrencyRewards"
	currencyLabel.Size = UDim2.new(0.6, 0, 0, 40)
	currencyLabel.Position = UDim2.new(0.5, 0, 0.85, 0)
	currencyLabel.AnchorPoint = Vector2.new(0.5, 0)
	currencyLabel.BackgroundTransparency = 1
	currencyLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	currencyLabel.TextScaled = true
	currencyLabel.Font = Enum.Font.GothamBold
	currencyLabel.TextTransparency = 1
	currencyLabel.Parent = parent

	local parts: { string } = {}
	if coins > 0 then
		table.insert(parts, "💰 +" .. tostring(coins))
	end
	if gems > 0 then
		table.insert(parts, "💎 +" .. tostring(gems))
	end
	currencyLabel.Text = table.concat(parts, "   ")

	return currencyLabel
end

----------------------------------------------------------------------
-- Animation Logic
----------------------------------------------------------------------

local function dismissChest()
	if not isChestAnimPlaying then return end
	isChestAnimPlaying = false

	if activeGui then
		local gui = activeGui :: ScreenGui
		-- Fade out
		local overlay = gui:FindFirstChild("ChestOverlay") :: Frame?
		if overlay then
			local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local fadeTween = TweenService:Create(overlay, fadeInfo, { BackgroundTransparency = 1 })
			fadeTween:Play()
			fadeTween.Completed:Connect(function()
				gui:Destroy()
			end)
		else
			gui:Destroy()
		end
		activeGui = nil
	end
end

local function playChestAnimation(tier: string, rewards: { items: { string }, coins: number, gems: number })
	if isChestAnimPlaying then
		return
	end
	isChestAnimPlaying = true

	-- Create GUI
	local gui = createChestGui()
	activeGui = gui

	-- Overlay (click/tap to dismiss)
	local overlay = createOverlay(gui)

	-- Dismiss on click/tap
	local dismissButton = Instance.new("TextButton")
	dismissButton.Name = "DismissButton"
	dismissButton.Size = UDim2.new(1, 0, 1, 0)
	dismissButton.BackgroundTransparency = 1
	dismissButton.Text = ""
	dismissButton.Parent = overlay
	dismissButton.Activated:Connect(dismissChest)

	-- Create chest model
	local chestFrame = createChestModel(overlay, tier)

	-- Animate chest appearing (scale up)
	local openInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local openTween = TweenService:Create(chestFrame, openInfo, {
		Size = UDim2.new(0, 160, 0, 140),
	})
	openTween:Play()

	-- After chest opens, reveal items one by one
	task.delay(0.8, function()
		if not isChestAnimPlaying then return end

		local items = rewards.items or {}
		local totalItems = #items

		-- Reveal each item with a delay
		for i, itemId in items do
			if not isChestAnimPlaying then return end

			task.delay((i - 1) * ITEM_REVEAL_DELAY, function()
				if not isChestAnimPlaying then return end

				local card = createRewardCard(overlay, itemId, i, totalItems)

				-- Animate card reveal
				local revealInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				TweenService:Create(card, revealInfo, { BackgroundTransparency = 0.2 }):Play()

				local nameLabel = card:FindFirstChild("ItemName") :: TextLabel?
				if nameLabel then
					TweenService:Create(nameLabel, revealInfo, { TextTransparency = 0 }):Play()
				end

				local icon = card:FindFirstChild("Icon") :: TextLabel?
				if icon then
					TweenService:Create(icon, revealInfo, { TextTransparency = 0 }):Play()
				end

				local glowStroke = card:FindFirstChild("RarityGlow") :: UIStroke?
				if glowStroke then
					TweenService:Create(glowStroke, revealInfo, { Transparency = 0.3 }):Play()
				end
			end)
		end

		-- Show currency rewards after all items revealed
		local currencyDelay = totalItems * ITEM_REVEAL_DELAY + 0.3
		task.delay(currencyDelay, function()
			if not isChestAnimPlaying then return end

			local currencyLabel = createCurrencyDisplay(overlay, rewards.coins or 0, rewards.gems or 0)
			local fadeInInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(currencyLabel, fadeInInfo, { TextTransparency = 0 }):Play()
		end)
	end)

	-- Auto-dismiss after AUTO_DISMISS_SECONDS
	task.delay(AUTO_DISMISS_SECONDS, function()
		dismissChest()
	end)
end

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

local function getChestRemote(): RemoteEvent?
	if ChestAwardedRemote then
		return ChestAwardedRemote
	end
	local remote = ReplicatedStorage:FindFirstChild("ChestAwarded")
	if remote and remote:IsA("RemoteEvent") then
		return remote :: RemoteEvent
	end
	return nil
end

local remote = getChestRemote()
if remote then
	remote.OnClientEvent:Connect(function(tier: any, rewards: any)
		if typeof(tier) ~= "string" then return end
		if typeof(rewards) ~= "table" then return end

		-- Validate rewards structure
		local validatedRewards = {
			items = if typeof(rewards.items) == "table" then rewards.items else {},
			coins = if typeof(rewards.coins) == "number" then rewards.coins else 0,
			gems = if typeof(rewards.gems) == "number" then rewards.gems else 0,
		}

		playChestAnimation(tier, validatedRewards)
	end)
end

----------------------------------------------------------------------

return nil
