--!strict
--[[
	Economy Type Definitions
	Defines currency types, transaction records, and purchase request schema.
	Requirements: 6.7
]]

export type CurrencyType = "coins" | "gems" | "robux"

export type TransactionRecord = {
	id: string,
	playerId: number,
	currency: CurrencyType,
	amount: number, -- positive for credit, negative for debit
	reason: string, -- e.g., "kill_reward", "purchase", "daily_login"
	itemId: string?, -- associated item if applicable
	timestamp: number, -- os.time()
}

export type PurchaseRequest = {
	playerId: number,
	itemId: string,
	currency: CurrencyType,
	expectedCost: number,
}

export type PurchaseResult = {
	success: boolean,
	message: string?,
	newBalance: number?,
}

local Types = {}
return Types
