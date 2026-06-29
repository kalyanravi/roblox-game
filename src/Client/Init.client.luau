--!strict
--[[
	Client entry point for Shardstrike.
	Initializes all client-side controllers.
	Wired up in task 12.2.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Wait for Shared folder to be available in ReplicatedStorage
local Shared = ReplicatedStorage:WaitForChild("Shared")

-- Detect platform
local function detectPlatform(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Mobile"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Console"
	else
		return "PC"
	end
end

local platform = detectPlatform()

-- Require all controllers (self-initializing on require)
local Controllers = script:WaitForChild("Controllers")

require(Controllers:WaitForChild("InputController"))
require(Controllers:WaitForChild("HUDController"))
require(Controllers:WaitForChild("WeaponViewController"))
require(Controllers:WaitForChild("AbilityUIController"))
require(Controllers:WaitForChild("EmoteWheelController"))
require(Controllers:WaitForChild("ReplayController"))
require(Controllers:WaitForChild("SettingsController"))
require(Controllers:WaitForChild("ShopController"))
require(Controllers:WaitForChild("ChestUIController"))
require(Controllers:WaitForChild("PingUIController"))

-- Require gameplay modules (crosshair + weapon input)
local Gameplay = script:WaitForChild("Gameplay")

require(Gameplay:WaitForChild("CrosshairUI"))
require(Gameplay:WaitForChild("WeaponInput"))

print("[Shardstrike Client] All controllers initialized. Platform: " .. platform)
