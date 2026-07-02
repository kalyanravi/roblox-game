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

local InsertService = game:GetService("InsertService")

local STARTER_WEAPONS = {
	{ id = "ar_standard", name = "Assault Rifle", assetId = 14565207244 },
	{ id = "sg_pump", name = "Pump Shotgun", assetId = 2374456368 },
	{ id = "rev_sixshooter", name = "Six Shooter", assetId = 16601591576 },
}

----------------------------------------------------------------------
-- Module
----------------------------------------------------------------------

local WeaponSetup = {}

--[[
	Creates a Tool instance for a weapon using a Roblox model asset.
	Falls back to a placeholder Part if the model fails to load.
]]
local function createWeaponTool(weaponInfo: {id: string, name: string, assetId: number}): Tool
	local tool = Instance.new("Tool")
	tool.Name = weaponInfo.name
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	-- Try to load the real model from Roblox
	local success, model = pcall(function()
		return InsertService:LoadAsset(weaponInfo.assetId)
	end)

	if success and model then
		-- Find the first BasePart or MeshPart in the model to use as Handle
		local handle: BasePart? = nil

		-- Look for a part named "Handle" first
		handle = model:FindFirstChild("Handle", true) :: BasePart?

		-- If no Handle found, find the first BasePart
		if not handle then
			for _, desc in model:GetDescendants() do
				if desc:IsA("BasePart") then
					handle = desc :: BasePart
					break
				end
			end
		end

		if handle then
			handle.Name = "Handle"
			handle.CanCollide = false
			handle.Massless = true
			handle.Parent = tool

			-- Move any other parts in the model as children of handle (welded)
			for _, desc in model:GetDescendants() do
				if desc:IsA("BasePart") and desc ~= handle then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = handle
					weld.Part1 = desc
					weld.Parent = handle
					desc.CanCollide = false
					desc.Massless = true
					desc.Anchored = false
					desc.Parent = tool
				end
			end
		else
			-- No parts found, create fallback
			local fallback = Instance.new("Part")
			fallback.Name = "Handle"
			fallback.Size = Vector3.new(0.4, 0.8, 2.5)
			fallback.Color = Color3.fromRGB(50, 50, 50)
			fallback.Material = Enum.Material.SmoothPlastic
			fallback.CanCollide = false
			fallback.Massless = true
			fallback.Parent = tool
		end

		-- Clean up the container model
		model:Destroy()
	else
		-- Failed to load asset, create placeholder
		warn("[WeaponSetup] Failed to load asset " .. tostring(weaponInfo.assetId) .. " for " .. weaponInfo.name)
		local fallback = Instance.new("Part")
		fallback.Name = "Handle"
		fallback.Size = Vector3.new(0.4, 0.8, 2.5)
		fallback.Color = Color3.fromRGB(50, 50, 50)
		fallback.Material = Enum.Material.SmoothPlastic
		fallback.CanCollide = false
		fallback.Massless = true
		fallback.Parent = tool
	end

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
