--!strict
--[[
	WeaponSetup
	Creates a Tool-based Assault Rifle for every player on spawn.
	Wires Tool.Activated to fire the FireWeapon RemoteEvent.
	Equips "ar_standard" on the server via CombatService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Services = Server:WaitForChild("Services")
local CombatService = require(Services:WaitForChild("CombatService"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponDefinitions = require(Shared:WaitForChild("Definitions"):WaitForChild("WeaponDefinitions"))

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local STARTER_WEAPONS = {
	{ id = "ar_standard", name = "Assault Rifle", color = Color3.fromRGB(50, 50, 50), size = Vector3.new(0.4, 0.8, 2.5) },
	{ id = "sg_pump", name = "Pump Shotgun", color = Color3.fromRGB(80, 50, 20), size = Vector3.new(0.5, 0.7, 2.0) },
	{ id = "rev_sixshooter", name = "Six Shooter", color = Color3.fromRGB(120, 120, 120), size = Vector3.new(0.3, 0.6, 1.2) },
}

----------------------------------------------------------------------
-- Module
----------------------------------------------------------------------

local WeaponSetup = {}

--[[
	Creates a Tool instance for a weapon.
]]
local function createWeaponTool(weaponInfo: {id: string, name: string, color: Color3, size: Vector3}): Tool
	local tool = Instance.new("Tool")
	tool.Name = weaponInfo.name
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	-- Create handle with weapon-specific color and size
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = weaponInfo.size
	handle.Color = weaponInfo.color
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	return tool
end

--[[
	Sets up all starter weapons for a specific player character.
]]
local function setupWeaponForCharacter(player: Player, character: Model)
	-- Small delay to ensure character is fully loaded
	task.wait(0.5)

	-- Don't setup if character already destroyed
	if not character or not character.Parent then
		return
	end

	-- Check if tool already exists in backpack
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	-- Remove any existing weapon tools
	for _, child in backpack:GetChildren() do
		if child:IsA("Tool") then
			child:Destroy()
		end
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			child:Destroy()
		end
	end

	-- Create all starter weapon tools
	local ownedIds = {}
	for _, weaponInfo in STARTER_WEAPONS do
		local tool = createWeaponTool(weaponInfo)
		tool.Parent = backpack
		table.insert(ownedIds, weaponInfo.id)
	end

	-- Server-side: register weapons in CombatService
	local state = CombatService.getPlayerState(player)
	if state then
		CombatService.setOwnedWeapons(player, ownedIds)
		CombatService.equipWeapon(player, "ar_standard")
	end
end

--[[
	Initializes weapon setup for a player (called on PlayerAdded).
]]
function WeaponSetup.initPlayer(player: Player)
	-- Setup when character spawns/respawns
	player.CharacterAdded:Connect(function(character: Model)
		setupWeaponForCharacter(player, character)
	end)

	-- If character already exists (late join), set up immediately
	if player.Character then
		setupWeaponForCharacter(player, player.Character)
	end
end

----------------------------------------------------------------------
-- Auto-initialize for all players
----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player: Player)
	WeaponSetup.initPlayer(player)
end)

-- Handle players already in game (for late script loading)
for _, player in Players:GetPlayers() do
	WeaponSetup.initPlayer(player)
end

return WeaponSetup
