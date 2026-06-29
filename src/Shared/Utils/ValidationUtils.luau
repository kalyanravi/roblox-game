--!strict

local ValidationUtils = {}

--[[
	Returns true if value is a string.
]]
function ValidationUtils.isString(value: any): boolean
	return type(value) == "string"
end

--[[
	Returns true if value is a number (integer or float).
]]
function ValidationUtils.isNumber(value: any): boolean
	return type(value) == "number"
end

--[[
	Returns true if value is an integer (whole number).
]]
function ValidationUtils.isInteger(value: any): boolean
	if type(value) ~= "number" then
		return false
	end
	return value == math.floor(value)
end

--[[
	Returns true if value is a number within [min, max] inclusive.
]]
function ValidationUtils.isInRange(value: number, min: number, max: number): boolean
	return value >= min and value <= max
end

--[[
	Returns true if value is a string found in the validValues array.
]]
function ValidationUtils.isValidEnum(value: any, validValues: { string }): boolean
	if type(value) ~= "string" then
		return false
	end
	for _, valid in validValues do
		if value == valid then
			return true
		end
	end
	return false
end

export type ArgSchema = {
	name: string,
	type: string,
	required: boolean,
	min: number?,
	max: number?,
}

--[[
	Validates remote arguments against a schema definition.
	Returns (true, nil) on success, or (false, errorMessage) on failure.

	Each schema entry defines:
	  - name: argument label for error messages
	  - type: expected Luau type ("string", "number", "boolean", "table", "Vector3")
	  - required: whether the argument must be present (non-nil)
	  - min/max: optional numeric range constraints (only for "number" type)
]]
function ValidationUtils.validateRemoteArgs(args: { any }, schema: { ArgSchema }): (boolean, string?)
	for i, entry in schema do
		local value = args[i]

		-- Check required
		if value == nil then
			if entry.required then
				return false, `Missing required argument: {entry.name}`
			end
			continue
		end

		-- Check type
		local expectedType = entry.type
		if expectedType == "Vector3" then
			if typeof(value) ~= "Vector3" then
				return false, `Argument {entry.name}: expected Vector3, got {typeof(value)}`
			end
		else
			if type(value) ~= expectedType then
				return false, `Argument {entry.name}: expected {expectedType}, got {type(value)}`
			end
		end

		-- Check numeric range
		if entry.type == "number" and type(value) == "number" then
			if entry.min ~= nil and value < entry.min then
				return false, `Argument {entry.name}: value {value} below minimum {entry.min}`
			end
			if entry.max ~= nil and value > entry.max then
				return false, `Argument {entry.name}: value {value} above maximum {entry.max}`
			end
		end
	end

	return true, nil
end

return table.freeze(ValidationUtils)
