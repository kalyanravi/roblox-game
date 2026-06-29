--!strict

local TableUtils = {}

--[[
	Creates a deep (recursive) copy of a table.
	Non-table values are copied by value.
]]
function TableUtils.deepCopy(tbl: { [any]: any }): { [any]: any }
	local copy = {}
	for key, value in tbl do
		if type(value) == "table" then
			copy[key] = TableUtils.deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

--[[
	Shallow merges override into base. Keys in override win conflicts.
	Returns a new table; does not mutate base or override.
]]
function TableUtils.merge(base: { [any]: any }, override: { [any]: any }): { [any]: any }
	local result = {}
	for key, value in base do
		result[key] = value
	end
	for key, value in override do
		result[key] = value
	end
	return result
end

--[[
	Returns the first element in the table that matches the predicate,
	or nil if no match is found.
]]
function TableUtils.find(tbl: { [any]: any }, predicate: (any) -> boolean): any?
	for _, value in tbl do
		if predicate(value) then
			return value
		end
	end
	return nil
end

--[[
	Returns a new array containing all elements that match the predicate.
]]
function TableUtils.filter(tbl: { [any]: any }, predicate: (any) -> boolean): { any }
	local result = {}
	for _, value in tbl do
		if predicate(value) then
			table.insert(result, value)
		end
	end
	return result
end

--[[
	Returns true if the table contains the given value.
]]
function TableUtils.contains(tbl: { [any]: any }, value: any): boolean
	for _, v in tbl do
		if v == value then
			return true
		end
	end
	return false
end

--[[
	Returns an array of all keys in the table.
]]
function TableUtils.keys(tbl: { [any]: any }): { any }
	local result = {}
	for key in tbl do
		table.insert(result, key)
	end
	return result
end

--[[
	Returns the count of entries in a dictionary/table.
	Works for non-array tables where #tbl would return 0.
]]
function TableUtils.count(tbl: { [any]: any }): number
	local n = 0
	for _ in tbl do
		n += 1
	end
	return n
end

return table.freeze(TableUtils)
