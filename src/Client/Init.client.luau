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
local Controllers = script.Parent:WaitForChild("Controllers")

require(Controllers.InputController)
require(Controllers.HUDController)
require(Controllers.WeaponViewController)
require(Controllers.AbilityUIController)
require(Controllers.EmoteWheelController)
require(Controllers.ReplayController)
require(Controllers.SettingsController)
require(Controllers.ShopController)
require(Controllers.ChestUIController)
require(Controllers.PingUIController)

print("[Shardstrike Client] All controllers initialized. Platform: " .. platform)
