--!strict
--[[
	ShopController (Client)
	Creates a shop ScreenGui with categories (Weapons, Abilities, Emotes, Finishers, Bundles).
	Displays item grid with name, rarity, cost, and icon placeholder.
	Shows bundle contents and pricing before purchase confirmation.
	Fires PurchaseItem RemoteEvent to server on purchase.
	Listens to EconomyUpdate RemoteEvent to refresh displayed balance.
	Toggle visibility with a shop button.
	Requirements: 8.5
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

local PurchaseItemRemote: RemoteEvent? = if Remotes
	then Remotes:FindFirstChild("PurchaseItem") :: RemoteEvent?
	else ReplicatedStorage:FindFirstChild("PurchaseItem") :: RemoteEvent?

local EconomyUpdateRemote: RemoteEvent? = if Remotes
	then Remotes:FindFirstChild("EconomyUpdate") :: RemoteEvent?
	else ReplicatedStorage:FindFirstChild("EconomyUpdate") :: RemoteEvent?

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local CATEGORIES = { "Weapons", "Abilities", "Emotes", "Finishers", "Bundles" }

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

local isShopVisible = false
local currentCategory = "Weapons"
local currentBalance = { coins = 0, gems = 0 }

-- UI References (set during creation)
local shopGui: ScreenGui? = nil
local shopFrame: Frame? = nil
local balanceLabel: TextLabel? = nil
local itemGridFrame: Frame? = nil
local confirmationFrame: Frame? = nil

----------------------------------------------------------------------
-- UI Creation
----------------------------------------------------------------------

local function createShopGui(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopGui"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = PlayerGui
	return gui
end

local function createToggleButton(parent: ScreenGui): TextButton
	local button = Instance.new("TextButton")
	button.Name = "ShopToggleButton"
	button.Size = UDim2.new(0, 80, 0, 35)
	button.Position = UDim2.new(1, -100, 0, 10)
	button.AnchorPoint = Vector2.new(1, 0)
	button.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
	button.BackgroundTransparency = 0.2
	button.Text = "🛒 Shop"
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.BorderSizePixel = 0
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	return button
end

local function createMainFrame(parent: ScreenGui): Frame
	local frame = Instance.new("Frame")
	frame.Name = "ShopMainFrame"
	frame.Size = UDim2.new(0.8, 0, 0.8, 0)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local border = Instance.new("UIStroke")
	border.Color = Color3.fromRGB(80, 80, 120)
	border.Thickness = 2
	border.Parent = frame

	return frame
end

local function createTitleBar(parent: Frame): (TextLabel, TextLabel, TextButton)
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "ShopTitle"
	title.Size = UDim2.new(0.3, 0, 0, 40)
	title.Position = UDim2.new(0, 15, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "SHOP"
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = parent

	-- Balance display
	local balance = Instance.new("TextLabel")
	balance.Name = "BalanceLabel"
	balance.Size = UDim2.new(0.4, 0, 0, 30)
	balance.Position = UDim2.new(0.5, 0, 0, 15)
	balance.AnchorPoint = Vector2.new(0.5, 0)
	balance.BackgroundTransparency = 1
	balance.Text = "💰 0  💎 0"
	balance.TextColor3 = Color3.new(1, 1, 1)
	balance.TextScaled = true
	balance.Font = Enum.Font.GothamBold
	balance.Parent = parent

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 35, 0, 35)
	closeBtn.Position = UDim2.new(1, -10, 0, 10)
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	closeBtn.BackgroundTransparency = 0.3
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = parent

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeBtn

	return title, balance, closeBtn
end

local function createCategoryTabs(parent: Frame): { TextButton }
	local tabContainer = Instance.new("Frame")
	tabContainer.Name = "CategoryTabs"
	tabContainer.Size = UDim2.new(1, -30, 0, 35)
	tabContainer.Position = UDim2.new(0, 15, 0, 55)
	tabContainer.BackgroundTransparency = 1
	tabContainer.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = tabContainer

	local tabs: { TextButton } = {}

	for i, category in CATEGORIES do
		local tab = Instance.new("TextButton")
		tab.Name = "Tab_" .. category
		tab.Size = UDim2.new(0, 100, 1, 0)
		tab.LayoutOrder = i
		tab.BackgroundColor3 = if category == currentCategory
			then Color3.fromRGB(60, 90, 180)
			else Color3.fromRGB(40, 40, 60)
		tab.BackgroundTransparency = 0.3
		tab.Text = category
		tab.TextColor3 = Color3.new(1, 1, 1)
		tab.TextScaled = true
		tab.Font = Enum.Font.GothamBold
		tab.BorderSizePixel = 0
		tab.Parent = tabContainer

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 6)
		tabCorner.Parent = tab

		table.insert(tabs, tab)
	end

	return tabs
end

local function createItemGrid(parent: Frame): Frame
	local gridFrame = Instance.new("Frame")
	gridFrame.Name = "ItemGrid"
	gridFrame.Size = UDim2.new(1, -30, 1, -110)
	gridFrame.Position = UDim2.new(0, 15, 0, 100)
	gridFrame.BackgroundTransparency = 1
	gridFrame.ClipsDescendants = true
	gridFrame.Parent = parent

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 150, 0, 180)
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = gridFrame

	return gridFrame
end

local function createConfirmationDialog(parent: Frame): Frame
	local overlay = Instance.new("Frame")
	overlay.Name = "ConfirmationDialog"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Visible = false
	overlay.ZIndex = 10
	overlay.Parent = parent

	local dialog = Instance.new("Frame")
	dialog.Name = "DialogBox"
	dialog.Size = UDim2.new(0, 350, 0, 200)
	dialog.Position = UDim2.new(0.5, 0, 0.5, 0)
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	dialog.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	dialog.BackgroundTransparency = 0.1
	dialog.BorderSizePixel = 0
	dialog.ZIndex = 11
	dialog.Parent = overlay

	local dialogCorner = Instance.new("UICorner")
	dialogCorner.CornerRadius = UDim.new(0, 10)
	dialogCorner.Parent = dialog

	local dialogTitle = Instance.new("TextLabel")
	dialogTitle.Name = "DialogTitle"
	dialogTitle.Size = UDim2.new(1, 0, 0, 30)
	dialogTitle.Position = UDim2.new(0, 0, 0, 10)
	dialogTitle.BackgroundTransparency = 1
	dialogTitle.Text = "Confirm Purchase"
	dialogTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
	dialogTitle.TextScaled = true
	dialogTitle.Font = Enum.Font.GothamBold
	dialogTitle.ZIndex = 12
	dialogTitle.Parent = dialog

	local dialogDetails = Instance.new("TextLabel")
	dialogDetails.Name = "DialogDetails"
	dialogDetails.Size = UDim2.new(0.9, 0, 0, 80)
	dialogDetails.Position = UDim2.new(0.5, 0, 0, 45)
	dialogDetails.AnchorPoint = Vector2.new(0.5, 0)
	dialogDetails.BackgroundTransparency = 1
	dialogDetails.Text = ""
	dialogDetails.TextColor3 = Color3.new(1, 1, 1)
	dialogDetails.TextScaled = true
	dialogDetails.Font = Enum.Font.Gotham
	dialogDetails.TextWrapped = true
	dialogDetails.ZIndex = 12
	dialogDetails.Parent = dialog

	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Name = "ConfirmButton"
	confirmBtn.Size = UDim2.new(0, 120, 0, 35)
	confirmBtn.Position = UDim2.new(0.3, 0, 1, -50)
	confirmBtn.AnchorPoint = Vector2.new(0.5, 0)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
	confirmBtn.BackgroundTransparency = 0.2
	confirmBtn.Text = "Buy"
	confirmBtn.TextColor3 = Color3.new(1, 1, 1)
	confirmBtn.TextScaled = true
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.BorderSizePixel = 0
	confirmBtn.ZIndex = 12
	confirmBtn.Parent = dialog

	local confirmBtnCorner = Instance.new("UICorner")
	confirmBtnCorner.CornerRadius = UDim.new(0, 6)
	confirmBtnCorner.Parent = confirmBtn

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Name = "CancelButton"
	cancelBtn.Size = UDim2.new(0, 120, 0, 35)
	cancelBtn.Position = UDim2.new(0.7, 0, 1, -50)
	cancelBtn.AnchorPoint = Vector2.new(0.5, 0)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	cancelBtn.BackgroundTransparency = 0.2
	cancelBtn.Text = "Cancel"
	cancelBtn.TextColor3 = Color3.new(1, 1, 1)
	cancelBtn.TextScaled = true
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.BorderSizePixel = 0
	cancelBtn.ZIndex = 12
	cancelBtn.Parent = dialog

	local cancelBtnCorner = Instance.new("UICorner")
	cancelBtnCorner.CornerRadius = UDim.new(0, 6)
	cancelBtnCorner.Parent = cancelBtn

	return overlay
end

----------------------------------------------------------------------
-- Item Card Creation
----------------------------------------------------------------------

local function createItemCard(parent: Frame, itemData: {
	id: string,
	name: string,
	rarity: string,
	cost: number,
	currency: string,
}, layoutOrder: number): TextButton
	local card = Instance.new("TextButton")
	card.Name = "Item_" .. itemData.id
	card.Size = UDim2.new(0, 150, 0, 180)
	card.LayoutOrder = layoutOrder
	card.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	card.BackgroundTransparency = 0.2
	card.Text = ""
	card.BorderSizePixel = 0
	card.AutoButtonColor = true
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	-- Rarity border
	local rarityColor = RARITY_COLORS[itemData.rarity] or Color3.fromRGB(180, 180, 180)
	local rarityStroke = Instance.new("UIStroke")
	rarityStroke.Color = rarityColor
	rarityStroke.Thickness = 2
	rarityStroke.Parent = card

	-- Icon placeholder
	local iconFrame = Instance.new("Frame")
	iconFrame.Name = "IconPlaceholder"
	iconFrame.Size = UDim2.new(0.8, 0, 0, 80)
	iconFrame.Position = UDim2.new(0.5, 0, 0, 10)
	iconFrame.AnchorPoint = Vector2.new(0.5, 0)
	iconFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	iconFrame.BackgroundTransparency = 0.3
	iconFrame.BorderSizePixel = 0
	iconFrame.Parent = card

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 6)
	iconCorner.Parent = iconFrame

	-- Item name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	nameLabel.Size = UDim2.new(0.9, 0, 0, 25)
	nameLabel.Position = UDim2.new(0.5, 0, 0, 95)
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemData.name
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = card

	-- Rarity label
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Size = UDim2.new(0.9, 0, 0, 18)
	rarityLabel.Position = UDim2.new(0.5, 0, 0, 120)
	rarityLabel.AnchorPoint = Vector2.new(0.5, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = itemData.rarity
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.Parent = card

	-- Cost label
	local currencyIcon = if itemData.currency == "gems" then "💎" else "💰"
	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "CostLabel"
	costLabel.Size = UDim2.new(0.9, 0, 0, 22)
	costLabel.Position = UDim2.new(0.5, 0, 0, 145)
	costLabel.AnchorPoint = Vector2.new(0.5, 0)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = currencyIcon .. " " .. tostring(itemData.cost)
	costLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	costLabel.TextScaled = true
	costLabel.Font = Enum.Font.GothamBold
	costLabel.Parent = card

	return card
end

----------------------------------------------------------------------
-- Shop Logic
----------------------------------------------------------------------

local function clearItemGrid()
	if not itemGridFrame then return end
	for _, child in (itemGridFrame :: Frame):GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function updateBalanceDisplay()
	if balanceLabel then
		(balanceLabel :: TextLabel).Text = "💰 " .. tostring(currentBalance.coins) .. "  💎 " .. tostring(currentBalance.gems)
	end
end

local function showConfirmation(itemId: string, itemName: string, cost: number, currency: string, bundleContents: string?)
	if not confirmationFrame then return end
	local dialog = confirmationFrame :: Frame
	dialog.Visible = true

	local details = dialog:FindFirstChild("DialogBox")
	if details then
		local detailsLabel = details:FindFirstChild("DialogDetails") :: TextLabel?
		if detailsLabel then
			local currencyIcon = if currency == "gems" then "💎" else "💰"
			local text = "Purchase " .. itemName .. "\nCost: " .. currencyIcon .. " " .. tostring(cost)
			if bundleContents then
				text ..= "\n\nBundle includes:\n" .. bundleContents
			end
			detailsLabel.Text = text
		end

		-- Wire confirm button
		local confirmBtn = details:FindFirstChild("ConfirmButton") :: TextButton?
		if confirmBtn then
			-- Disconnect any previous connections by recreating button behavior
			confirmBtn.Activated:Once(function()
				dialog.Visible = false
				-- Fire purchase to server
				local remote = PurchaseItemRemote
				if not remote then
					remote = ReplicatedStorage:FindFirstChild("PurchaseItem") :: RemoteEvent?
				end
				if remote then
					remote:FireServer(itemId)
				end
			end)
		end

		-- Wire cancel button
		local cancelBtn = details:FindFirstChild("CancelButton") :: TextButton?
		if cancelBtn then
			cancelBtn.Activated:Once(function()
				dialog.Visible = false
			end)
		end
	end
end

local function populateItems(_category: string)
	clearItemGrid()
	if not itemGridFrame then return end

	-- Placeholder items for each category. In a real implementation,
	-- these would be loaded from shared Definitions modules.
	local placeholderItems: { { id: string, name: string, rarity: string, cost: number, currency: string } } = {}

	if _category == "Weapons" then
		placeholderItems = {
			{ id = "smg_viper", name = "Viper SMG", rarity = "Rare", cost = 500, currency = "coins" },
			{ id = "ar_phantom", name = "Phantom AR", rarity = "Epic", cost = 1200, currency = "coins" },
			{ id = "sniper_eclipse", name = "Eclipse Sniper", rarity = "Legendary", cost = 300, currency = "gems" },
		}
	elseif _category == "Abilities" then
		placeholderItems = {
			{ id = "ability_shield", name = "Energy Shield", rarity = "Rare", cost = 400, currency = "coins" },
			{ id = "ability_grapple", name = "Grapple Hook", rarity = "Epic", cost = 800, currency = "coins" },
		}
	elseif _category == "Emotes" then
		placeholderItems = {
			{ id = "emote_dance", name = "Victory Dance", rarity = "Common", cost = 200, currency = "coins" },
			{ id = "emote_wave", name = "Wave", rarity = "Common", cost = 150, currency = "coins" },
		}
	elseif _category == "Finishers" then
		placeholderItems = {
			{ id = "finisher_slam", name = "Ground Slam", rarity = "Epic", cost = 1000, currency = "coins" },
			{ id = "finisher_lightning", name = "Lightning Strike", rarity = "Legendary", cost = 250, currency = "gems" },
		}
	elseif _category == "Bundles" then
		placeholderItems = {
			{ id = "bundle_starter", name = "Starter Pack", rarity = "Rare", cost = 1500, currency = "coins" },
			{ id = "bundle_elite", name = "Elite Bundle", rarity = "Legendary", cost = 500, currency = "gems" },
		}
	end

	for i, itemData in placeholderItems do
		local card = createItemCard(itemGridFrame :: Frame, itemData, i)
		card.Activated:Connect(function()
			local bundleContents: string? = nil
			if _category == "Bundles" then
				bundleContents = "• Multiple items included\n• Discounted from individual prices"
			end
			showConfirmation(itemData.id, itemData.name, itemData.cost, itemData.currency, bundleContents)
		end)
	end
end

local function switchCategory(category: string)
	currentCategory = category
	populateItems(category)

	-- Update tab highlights
	if shopFrame then
		local tabContainer = (shopFrame :: Frame):FindFirstChild("CategoryTabs")
		if tabContainer then
			for _, tab in tabContainer:GetChildren() do
				if tab:IsA("TextButton") then
					local tabCategory = string.gsub(tab.Name, "Tab_", "")
					if tabCategory == category then
						tab.BackgroundColor3 = Color3.fromRGB(60, 90, 180)
					else
						tab.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
					end
				end
			end
		end
	end
end

local function toggleShop()
	isShopVisible = not isShopVisible
	if shopGui then
		(shopGui :: ScreenGui).Enabled = isShopVisible
	end
	if isShopVisible then
		populateItems(currentCategory)
		updateBalanceDisplay()
	end
end

----------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------

local function initialize()
	-- Create shop GUI
	local gui = createShopGui()
	shopGui = gui

	-- Create toggle button (always visible on main HUD)
	local toggleBtn = createToggleButton(gui)
	toggleBtn.Visible = true
	-- The toggle button should be visible even when shop panel is hidden,
	-- so parent it to a separate always-visible GUI
	local toggleGui = Instance.new("ScreenGui")
	toggleGui.Name = "ShopToggleGui"
	toggleGui.ResetOnSpawn = false
	toggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	toggleGui.Parent = PlayerGui
	toggleBtn.Parent = toggleGui
	toggleBtn.Activated:Connect(toggleShop)

	-- Create main shop frame
	local mainFrame = createMainFrame(gui)
	shopFrame = mainFrame

	-- Create title bar with balance and close button
	local _title, balance, closeBtn = createTitleBar(mainFrame)
	balanceLabel = balance

	closeBtn.Activated:Connect(function()
		isShopVisible = false
		if shopGui then
			(shopGui :: ScreenGui).Enabled = false
		end
	end)

	-- Create category tabs
	local tabs = createCategoryTabs(mainFrame)
	for i, tab in tabs do
		local category = CATEGORIES[i]
		tab.Activated:Connect(function()
			switchCategory(category)
		end)
	end

	-- Create item grid
	local grid = createItemGrid(mainFrame)
	itemGridFrame = grid

	-- Create confirmation dialog
	local confirm = createConfirmationDialog(mainFrame)
	confirmationFrame = confirm
end

initialize()

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

-- Listen for economy updates to refresh balance
local function getEconomyRemote(): RemoteEvent?
	if EconomyUpdateRemote then
		return EconomyUpdateRemote
	end
	local remote = ReplicatedStorage:FindFirstChild("EconomyUpdate")
	if remote and remote:IsA("RemoteEvent") then
		return remote :: RemoteEvent
	end
	return nil
end

local economyRemote = getEconomyRemote()
if economyRemote then
	economyRemote.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then return end
		if typeof(data.coins) == "number" then
			currentBalance.coins = data.coins
		end
		if typeof(data.gems) == "number" then
			currentBalance.gems = data.gems
		end
		updateBalanceDisplay()
	end)
end

----------------------------------------------------------------------

return nil
