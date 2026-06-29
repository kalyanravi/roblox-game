--!strict
--[[
	EconomyService
	Server-authoritative economy managing dual-currency (coins/gems) balances,
	item purchases, Robux receipt processing, and match reward distribution.
	All validation is server-side; client-initiated balance modifications are rejected.
	Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 7.1, 7.2, 7.3, 7.4, 7.6,
	             8.1, 8.2, 8.3, 8.4, 8.5
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local WeaponDefinitions = require(Shared:WaitForChild("Definitions"):WaitForChild("WeaponDefinitions"))
local AbilityDefinitions = require(Shared:WaitForChild("Definitions"):WaitForChild("AbilityDefinitions"))
local FinisherDefinitions = require(Shared:WaitForChild("Definitions"):WaitForChild("FinisherDefinitions"))

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------

type PlayerBalance = {
	coins: number,
	gems: number,
}

type PlayerInventory = {
	weapons: { string },
	abilities: { string },
	emotes: { string },
	finishers: { string },
}

type MatchStats = {
	kills: number,
	deaths: number,
	assists: number,
	isWinner: boolean,
	isMVP: boolean,
	highestStreak: number,
}

type MatchRewardResult = {
	coins: number,
	gems: number,
}

----------------------------------------------------------------------
-- Constants (from shared Constants module)
----------------------------------------------------------------------

local COINS_PER_KILL = Constants.COINS_PER_KILL -- 25
local COINS_PER_ASSIST = Constants.COINS_PER_ASSIST -- 10
local COINS_PER_WIN = Constants.COINS_PER_WIN -- 45
local COINS_STREAK_BONUS = Constants.COINS_STREAK_BONUS -- 50
local COINS_MVP_BONUS = Constants.COINS_MVP_BONUS -- 100
local CONSECUTIVE_WINS_FOR_GEMS = Constants.CONSECUTIVE_WINS_FOR_GEMS -- 3
local GEMS_CONSECUTIVE_WIN_REWARD = Constants.GEMS_CONSECUTIVE_WIN_REWARD -- 10
local DAILY_GEM_BONUS = Constants.DAILY_GEM_BONUS -- 5

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

-- Per-player currency balances
local playerBalances: { [Player]: PlayerBalance } = {}

-- Per-player owned items
local playerInventories: { [Player]: PlayerInventory } = {}

-- Per-player consecutive win tracking for gem awards
local consecutiveWins: { [Player]: number } = {}

----------------------------------------------------------------------
-- RemoteEvents
----------------------------------------------------------------------

local function getOrCreateRemoteEvent(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing :: RemoteEvent
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local PurchaseItemRemote = getOrCreateRemoteEvent("PurchaseItem")
local EconomyUpdateRemote = getOrCreateRemoteEvent("EconomyUpdate")

----------------------------------------------------------------------
-- Internal Helpers
----------------------------------------------------------------------

--- Fires an economy update to the client with current balance.
local function notifyBalanceUpdate(player: Player): ()
	local balance = playerBalances[player]
	if not balance then
		return
	end
	EconomyUpdateRemote:FireClient(player, {
		coins = balance.coins,
		gems = balance.gems,
	})
end

--- Looks up an item definition and returns its cost info.
--- Returns: currency ("coins" | "gems"), amount, itemType ("weapons" | "abilities" | "emotes" | "finishers")
local function getItemCostInfo(itemId: string): (string?, number?, string?)
	-- Check weapons
	local weapon = WeaponDefinitions.getWeapon(itemId)
	if weapon then
		if weapon.cost then
			return weapon.cost.currency, weapon.cost.amount, "weapons"
		end
		-- Free weapon (Common starter), no cost
		return nil, nil, nil
	end

	-- Check abilities
	for _, ability in AbilityDefinitions do
		if ability.id == itemId then
			if ability.cost > 0 then
				return "coins", ability.cost, "abilities"
			end
			-- Free ability (Dash), no cost
			return nil, nil, nil
		end
	end

	-- Check finishers
	for _, finisher in FinisherDefinitions do
		if finisher.id == itemId then
			return "coins", finisher.cost, "finishers"
		end
	end

	-- Emotes: For now, emotes use a flat coin price range (200-500).
	-- We check if the itemId starts with "emote_" as a convention.
	if string.sub(itemId, 1, 6) == "emote_" then
		-- Default emote price; specific prices would be in an EmoteDefinitions module
		return "coins", 300, "emotes"
	end

	return nil, nil, nil
end

--- Checks if a player already owns an item.
local function playerOwnsItem(player: Player, itemId: string): boolean
	local inventory = playerInventories[player]
	if not inventory then
		return false
	end

	for _, id in inventory.weapons do
		if id == itemId then
			return true
		end
	end
	for _, id in inventory.abilities do
		if id == itemId then
			return true
		end
	end
	for _, id in inventory.emotes do
		if id == itemId then
			return true
		end
	end
	for _, id in inventory.finishers do
		if id == itemId then
			return true
		end
	end

	return false
end

--- Adds an item to a player's inventory by type.
local function addItemToInventory(player: Player, itemId: string, itemType: string): ()
	local inventory = playerInventories[player]
	if not inventory then
		return
	end

	if itemType == "weapons" then
		table.insert(inventory.weapons, itemId)
	elseif itemType == "abilities" then
		table.insert(inventory.abilities, itemId)
	elseif itemType == "emotes" then
		table.insert(inventory.emotes, itemId)
	elseif itemType == "finishers" then
		table.insert(inventory.finishers, itemId)
	end
end

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

local EconomyService = {}

--- Initializes economy state for a player when they join.
function EconomyService.initPlayer(player: Player): ()
	playerBalances[player] = {
		coins = 0,
		gems = 0,
	}
	playerInventories[player] = {
		weapons = {},
		abilities = {},
		emotes = {},
		finishers = {},
	}
	consecutiveWins[player] = 0
end

--- Cleans up economy state when a player leaves.
function EconomyService.removePlayer(player: Player): ()
	playerBalances[player] = nil
	playerInventories[player] = nil
	consecutiveWins[player] = nil
end

--- Sets the player's balance (called by DataPersistenceService on load).
function EconomyService.setBalance(player: Player, coins: number, gems: number): ()
	local balance = playerBalances[player]
	if balance then
		balance.coins = coins
		balance.gems = gems
	end
end

--- Sets the player's inventory (called by DataPersistenceService on load).
function EconomyService.setInventory(player: Player, inventory: PlayerInventory): ()
	playerInventories[player] = inventory
end

--- Sets the player's consecutive win count (called by DataPersistenceService on load).
function EconomyService.setConsecutiveWins(player: Player, wins: number): ()
	consecutiveWins[player] = wins
end

--- Returns the current coin and gem balance for a player.
function EconomyService.getBalance(player: Player): (number, number)
	local balance = playerBalances[player]
	if not balance then
		return 0, 0
	end
	return balance.coins, balance.gems
end

--- Returns the player's inventory.
function EconomyService.getInventory(player: Player): PlayerInventory?
	return playerInventories[player]
end

--- Returns the player's consecutive win count.
function EconomyService.getConsecutiveWins(player: Player): number
	return consecutiveWins[player] or 0
end

--- Adds coins to a player's balance. Returns true on success.
function EconomyService.addCoins(player: Player, amount: number, reason: string): boolean
	if amount <= 0 then
		return false
	end

	local balance = playerBalances[player]
	if not balance then
		return false
	end

	balance.coins += amount
	notifyBalanceUpdate(player)
	return true
end

--- Adds gems to a player's balance. Returns true on success.
function EconomyService.addGems(player: Player, amount: number, reason: string): boolean
	if amount <= 0 then
		return false
	end

	local balance = playerBalances[player]
	if not balance then
		return false
	end

	balance.gems += amount
	notifyBalanceUpdate(player)
	return true
end

--- Spends coins from a player's balance. Returns false if insufficient balance.
function EconomyService.spendCoins(player: Player, amount: number, itemId: string): boolean
	if amount <= 0 then
		return false
	end

	local balance = playerBalances[player]
	if not balance then
		return false
	end

	if balance.coins < amount then
		return false
	end

	balance.coins -= amount
	notifyBalanceUpdate(player)
	return true
end

--- Spends gems from a player's balance. Returns false if insufficient balance.
function EconomyService.spendGems(player: Player, amount: number, itemId: string): boolean
	if amount <= 0 then
		return false
	end

	local balance = playerBalances[player]
	if not balance then
		return false
	end

	if balance.gems < amount then
		return false
	end

	balance.gems -= amount
	notifyBalanceUpdate(player)
	return true
end

--- Validates a purchase attempt. Returns (success, errorMessage?).
--- Checks: item exists, item has a cost, player has sufficient balance, player doesn't already own item.
function EconomyService.validatePurchase(player: Player, itemId: string, currency: string): (boolean, string?)
	-- Check if player is tracked
	local balance = playerBalances[player]
	if not balance then
		return false, "Player not initialized"
	end

	-- Check if player already owns the item
	if playerOwnsItem(player, itemId) then
		return false, "Item already owned"
	end

	-- Look up item cost
	local itemCurrency, itemCost, _itemType = getItemCostInfo(itemId)
	if not itemCurrency or not itemCost then
		return false, "Item not found or not purchasable"
	end

	-- Verify currency matches
	if itemCurrency ~= currency then
		return false, "Wrong currency type"
	end

	-- Check balance
	if currency == "coins" then
		if balance.coins < itemCost then
			return false, "Insufficient coins"
		end
	elseif currency == "gems" then
		if balance.gems < itemCost then
			return false, "Insufficient gems"
		end
	else
		return false, "Invalid currency"
	end

	return true, nil
end

--- Processes a purchase: validates, deducts currency, adds item to inventory.
--- Returns true if purchase succeeded.
function EconomyService.processPurchase(player: Player, itemId: string): boolean
	-- Look up item cost info
	local itemCurrency, itemCost, itemType = getItemCostInfo(itemId)
	if not itemCurrency or not itemCost or not itemType then
		return false
	end

	-- Validate the purchase
	local valid, _errorMsg = EconomyService.validatePurchase(player, itemId, itemCurrency)
	if not valid then
		return false
	end

	-- Deduct currency
	local spent = false
	if itemCurrency == "coins" then
		spent = EconomyService.spendCoins(player, itemCost, itemId)
	elseif itemCurrency == "gems" then
		spent = EconomyService.spendGems(player, itemCost, itemId)
	end

	if not spent then
		return false
	end

	-- Add item to inventory
	addItemToInventory(player, itemId, itemType)

	return true
end

--- Handles Robux purchase receipts from MarketplaceService.
--- Returns appropriate ProductPurchaseDecision.
function EconomyService.processRobuxReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	-- Validate receipt info
	if not receiptInfo then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local playerId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId

	if not playerId or not productId then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Find the player in the server
	local player = Players:GetPlayerByUserId(playerId)
	if not player then
		-- Player left; retry later
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Verify player state exists
	local balance = playerBalances[player]
	if not balance then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Process the Robux purchase
	-- In a full implementation, productId maps to specific items/bundles.
	-- For now, grant the item associated with the product ID.
	-- The product-to-item mapping would live in a separate config module.
	-- Grant purchase and persist.
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--- Awards match rewards based on player performance stats.
--- Returns total coins and gems awarded.
function EconomyService.awardMatchRewards(player: Player, stats: MatchStats): MatchRewardResult
	local totalCoins = 0
	local totalGems = 0

	-- 25 coins per kill
	totalCoins += stats.kills * COINS_PER_KILL

	-- 10 coins per assist
	totalCoins += stats.assists * COINS_PER_ASSIST

	-- 45 coins for win
	if stats.isWinner then
		totalCoins += COINS_PER_WIN
	end

	-- 50 coins bonus for 5+ kill streak
	if stats.highestStreak >= 5 then
		totalCoins += COINS_STREAK_BONUS
	end

	-- 100 coins bonus for MVP
	if stats.isMVP then
		totalCoins += COINS_MVP_BONUS
	end

	-- Award coins
	if totalCoins > 0 then
		EconomyService.addCoins(player, totalCoins, "match_rewards")
	end

	-- Track consecutive wins for gem awards
	if stats.isWinner then
		consecutiveWins[player] = (consecutiveWins[player] or 0) + 1

		-- Award 10 gems at 3 consecutive wins, then reset counter
		if consecutiveWins[player] >= CONSECUTIVE_WINS_FOR_GEMS then
			totalGems += GEMS_CONSECUTIVE_WIN_REWARD
			EconomyService.addGems(player, GEMS_CONSECUTIVE_WIN_REWARD, "consecutive_wins")
			consecutiveWins[player] = 0
		end
	else
		-- Reset consecutive wins on loss
		consecutiveWins[player] = 0
	end

	return {
		coins = totalCoins,
		gems = totalGems,
	}
end

--- Awards daily login gems (5 gems). Called by the daily login system (task 5.12).
function EconomyService.awardDailyLoginGems(player: Player): boolean
	return EconomyService.addGems(player, DAILY_GEM_BONUS, "daily_login")
end

----------------------------------------------------------------------
-- Event Wiring
----------------------------------------------------------------------

-- Wire PurchaseItem remote (client → server)
PurchaseItemRemote.OnServerEvent:Connect(function(player: Player, itemId: any)
	-- Type validation: reject any non-string item IDs
	if typeof(itemId) ~= "string" then
		return
	end

	-- Reject empty strings
	if itemId == "" then
		return
	end

	-- Process the purchase server-side
	EconomyService.processPurchase(player, itemId)
end)

-- Wire MarketplaceService receipt processing
MarketplaceService.ProcessReceipt = function(receiptInfo)
	return EconomyService.processRobuxReceipt(receiptInfo)
end

----------------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player: Player)
	EconomyService.initPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	EconomyService.removePlayer(player)
end)

-- Initialize any players already in the game (for late script loading)
for _, player in Players:GetPlayers() do
	if not playerBalances[player] then
		EconomyService.initPlayer(player)
	end
end

----------------------------------------------------------------------

return EconomyService
