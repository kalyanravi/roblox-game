--!strict
--[[
	WeaponInput
	Client-side weapon input handler.
	Sends aim origin and direction to the server on Tool activation.
	Handles reload input (R key).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

----------------------------------------------------------------------
-- Remotes
----------------------------------------------------------------------

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FireWeaponRemote = Remotes:WaitForChild("FireWeapon") :: RemoteEvent
local ReloadWeaponRemote = Remotes:WaitForChild("ReloadWeapon") :: RemoteEvent

----------------------------------------------------------------------
-- Module
----------------------------------------------------------------------

local WeaponInput = {}

--[[
	Fires the weapon using camera position and look direction.
	Called when the player clicks/taps while holding the tool.
]]
local function fireWeapon()
	if not camera then
		return
	end

	local aimOrigin = camera.CFrame.Position
	local aimDirection = camera.CFrame.LookVector

	print("[WeaponInput] Firing! Origin:", aimOrigin, "Direction:", aimDirection)
	FireWeaponRemote:FireServer(aimOrigin, aimDirection)
end

--[[
	Sends a reload request to the server.
]]
local function requestReload()
	ReloadWeaponRemote:FireServer()
end

----------------------------------------------------------------------
-- Input Handling
----------------------------------------------------------------------

-- Listen for mouse click (fires weapon when tool is equipped)
local mouse = player:GetMouse()
local toolEquipped = false

local function onCharacterAdded(character: Model)
	-- Watch for tool equip/unequip
	character.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Tool") and child.Name == "Assault Rifle" then
			toolEquipped = true
		end
	end)

	character.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Tool") and child.Name == "Assault Rifle" then
			toolEquipped = false
		end
	end)

	-- Check if tool is already equipped
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child.Name == "Assault Rifle" then
			toolEquipped = true
		end
	end
end

-- Mouse button fire
mouse.Button1Down:Connect(function()
	if toolEquipped then
		fireWeapon()
	end
end)

-- Keyboard input for reload
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.R then
		requestReload()
	end
end)

-- Character setup
if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

function WeaponInput.init()
	-- Already initialized via connections above
end

WeaponInput.init()

return WeaponInput
