--[[
SleepSystemServerScript:
- Updates desired blanket color data
- Keeps track of sleeping side on characters
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // OBJECTS
local sleepConfig = ReplicatedStorage.Configurations:WaitForChild("SleepingConfig")
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local updateBlanketColorEvent = remoteEvents:WaitForChild("UpdateBlanketColor")
local setSleepingPositionEvent = remoteEvents:WaitForChild("SetSleepingPosition")
local charDataTemplate = ReplicatedStorage:WaitForChild("CharacterDataTemplate")

-- // CONFIG
local DEFAULT_BLANKET_COLOR = sleepConfig:GetAttribute("DefaultBlanketColor")
local validSleepingPositions = {"Back", "Left", "Right"}

-- // FUNCTIONS

-- Remote event handlers
local function onUpdateBlanketColor(player, newColor)
	if typeof(newColor) ~= "Color3" then 
		warn("Invalid color received from", player.Name)
		return 
	end

	local characterData = player:FindFirstChild("CharacterData")
	if characterData then
		local blanketColorValue = characterData:FindFirstChild("blanket_Color")
		if blanketColorValue then
			blanketColorValue.Value = newColor
			print(player.Name, "updated blanket color to", newColor)
		end
	end
end

local function onSetSleepingPosition(player, position)
	if not table.find(validSleepingPositions, position) then 
		warn("Invalid sleeping position received from", player.Name, ":", position)
		return 
	end

	if not player:GetAttribute("Sleeping") then 
		warn(player.Name, "tried to change position while not sleeping")
		return 
	end

	if not player.Character then 
		warn("No character found for", player.Name)
		return 
	end

	player.Character:SetAttribute("SleepingSide", position)
	print(player.Name, "changed sleeping position to", position)
end

-- // MAIN

-- Player initialization
local function initializeData(player)
	local charData = charDataTemplate:Clone()
	charData.Name = "CharacterData"
	charData.Parent = player
end

-- Connect events
updateBlanketColorEvent.OnServerEvent:Connect(onUpdateBlanketColor)
setSleepingPositionEvent.OnServerEvent:Connect(onSetSleepingPosition)

-- Initialize data for existing and new players
for _, player in ipairs(Players:GetPlayers()) do
	initializeData(player)
end

Players.PlayerAdded:Connect(initializeData)