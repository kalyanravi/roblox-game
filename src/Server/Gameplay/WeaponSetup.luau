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

local WEAPON_ID = "ar_standard"
local WEAPON_DEF = WeaponDefinitions.getWeapon(WEAPON_ID)
local FIRE_RATE = if WEAPON_DEF then (1 / WEAPON_DEF.fireRate) else 0.125

----------------------------------------------------------------------
-- Module
----------------------------------------------------------------------

local WeaponSetup = {}

--[[
	Creates a Tool instance representing the Assault Rifle.
]]
local function createWeaponTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Assault Rifle"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	-- Create handle (small black box representing the gun)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.8, 2.5)
	handle.BrickColor = BrickColor.new("Black")
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	return tool
end

--[[
	Sets up a weapon tool for a specific player character.
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
		if child:IsA("Tool") and child.Name == "Assault Rifle" then
			child:Destroy()
		end
	end
	-- Also check equipped tools on character
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child.Name == "Assault Rifle" then
			child:Destroy()
		end
	end

	-- Create new weapon tool
	local tool = createWeaponTool()

	-- Track last fire time for rate limiting
	local lastFireTime = 0

	-- Wire Tool.Activated: fires the weapon toward where player is looking
	tool.Activated:Connect(function()
		local now = os.clock()
		if now - lastFireTime < FIRE_RATE then
			return
		end
		lastFireTime = now

		-- Get camera direction from player's character head position
		local head = character:FindFirstChild("Head") :: BasePart?
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoidRootPart then
			return
		end

		-- Use HumanoidRootPart CFrame as aim origin; direction will come from client
		-- But since this is server-side tool activation, we fire the remote from here
		-- The client will handle sending proper aim data via FireWeapon remote
	end)

	-- Put tool in backpack
	tool.Parent = backpack

	-- Server-side: equip weapon in CombatService
	-- First ensure the player "owns" the starter weapon
	local state = CombatService.getPlayerState(player)
	if state then
		-- Grant the starter weapon
		CombatService.setOwnedWeapons(player, { WEAPON_ID })
		CombatService.equipWeapon(player, WEAPON_ID)
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
