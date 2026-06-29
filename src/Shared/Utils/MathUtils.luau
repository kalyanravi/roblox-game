--!strict

local MathUtils = {}

--[[
	Clamps a value between min and max (inclusive).
]]
function MathUtils.clamp(value: number, min: number, max: number): number
	if value < min then
		return min
	elseif value > max then
		return max
	end
	return value
end

--[[
	Linearly interpolates between a and b by factor t.
	t = 0 returns a, t = 1 returns b.
]]
function MathUtils.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

--[[
	Returns the Euclidean distance between two Vector3 positions.
]]
function MathUtils.distance(pos1: Vector3, pos2: Vector3): number
	return (pos1 - pos2).Magnitude
end

--[[
	Returns a random float between min and max (inclusive).
]]
function MathUtils.randomFloat(min: number, max: number): number
	return min + math.random() * (max - min)
end

--[[
	Rounds a number to the specified number of decimal places.
]]
function MathUtils.round(value: number, decimals: number): number
	local factor = 10 ^ decimals
	return math.floor(value * factor + 0.5) / factor
end

return table.freeze(MathUtils)
