--[[
SleepSystemServerScript:
- Updates desired blanket color data
- Keeps track of sleeping side on characters
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // OBJECTS
local sleepConfig = ReplicatedStorage.Configurations:WaitForChild("SleepingConfig")
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("SleepingSystem")
local updateBlanketColorEvent = remoteEvents:WaitForChild("UpdateBlanketColor")
local charDataTemplate = ReplicatedStorage:WaitForChild("CharacterDataTemplate")

-- // CONFIG

-- // FUNCTIONS

-- Remote event handlers
local function onUpdateBlanketColor(player, newColor)
	if typeof(newColor) ~= "Color3" then
		warn("Invalid color received from", player.Name)
		return
	end

	local characterData = player:FindFirstChild("CharacterData")
	local blanketColorValue = characterData and characterData:FindFirstChild("blanket_Color")
	if blanketColorValue then
		blanketColorValue.Value = newColor
		print(player.Name, "updated blanket color to", newColor)
	else
		warn("Failed to get blanket color value for", player, characterData, blanketColorValue)
	end
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

-- Initialize data for existing and new players
for _, player in ipairs(Players:GetPlayers()) do
	initializeData(player)
end

Players.PlayerAdded:Connect(initializeData)
