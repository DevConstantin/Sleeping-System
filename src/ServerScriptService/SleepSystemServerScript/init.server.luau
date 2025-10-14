--[[
SleepSystemServerScript:
- Updates desired blanket color data
- Keeps track of sleeping side on characters
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // OBJECTS
local BlanketService = require(ReplicatedStorage.RSModules.SleepBlanketService)
local sleepConfig = ReplicatedStorage.Configurations.SleepingConfig
local sleepSystemEvents = ReplicatedStorage.RemoteEvents.SleepingSystem
local updateBlanketColorEvent = sleepSystemEvents.UpdateBlanketColor

local charDataTemplate = ReplicatedStorage.CharacterDataTemplate

-- // CONFIG
local SLEEP_EXPERIENCE_ID = 85240340440833
local BLANKET_STABILIZE_INTERVAL = 0.3 -- Time to wait between blanket position samples
local BLANKET_STABILIZE_COUNT = 5 -- Max number of position samples to take before settling

local sleepConnections = {}

-- // FUNCTIONS

-- Remote event handlers
local function onUpdateBlanketColor(player, newColor)
	if typeof(newColor) ~= "Color3" then
		warn("Invalid color received from", player.Name, "- Possible exploit attempt?")
		return
	end

	local characterData = player:FindFirstChild("CharacterData")
	local blanketColorValue = characterData and characterData:FindFirstChild("blanket_Color")
	if blanketColorValue then
		blanketColorValue.Value = newColor
		--print(player.Name, "updated blanket color to", newColor)
	else
		--warn("Failed to get blanket color value for", player, characterData, blanketColorValue)
	end
end

-- Player initialization
local function initializeData(player)
	local charData = charDataTemplate:Clone()
	charData.Name = "CharacterData"
	charData.Parent = player
end

local function sleepAttributeChanged(player)
	local character = player.Character
	if not character then
		return
	end

	local isSleeping = player:GetAttribute("Sleeping")
	if not isSleeping then
		-- Clear blanket attributes when waking up
		character:SetAttribute("BlanketCFrame", nil)
		character:SetAttribute("BlanketSize", nil)
		character:SetAttribute("SleepingSide", nil)
		return
	end

	local blanketCFrame, blanketSize = BlanketService.getBlanketCFrameAndSize(character)
	local blanketPositions = {}
	print("Calculated blanket CFrame:", blanketCFrame, "Size:", blanketSize)
	-- Wait until blanket position stabilizes before tracking
	repeat
		task.wait(BLANKET_STABILIZE_INTERVAL)
		blanketCFrame, blanketSize = BlanketService.getBlanketCFrameAndSize(character)
		if not blanketCFrame or not blanketSize then
			blanketPositions = nil
			break
		end
		table.insert(blanketPositions, blanketCFrame.Position)

		local matchingPositions = 0
		for _, pos in ipairs(blanketPositions) do
			if (pos - blanketCFrame.Position).Magnitude < 0.1 then
				matchingPositions += 1
			end
		end
	until (#blanketPositions >= BLANKET_STABILIZE_COUNT and matchingPositions >= 3) or not player:GetAttribute("Sleeping")
	blanketPositions = nil -- Clear memory

	if player:GetAttribute("Sleeping") and blanketCFrame and blanketSize then
		print("Finalized blanket position for", player.Name, "at", blanketCFrame, "Size:", blanketSize)
		character:SetAttribute("BlanketCFrame", blanketCFrame)
		character:SetAttribute("BlanketSize", blanketSize)
	end
end

local function playerAdded(player)
	local sleepingChangedConnect
	sleepingChangedConnect = player:GetAttributeChangedSignal("Sleeping"):Connect(function()
		sleepAttributeChanged(player)
	end)
	sleepConnections[player.UserId] = sleepingChangedConnect
end

local function playerRemoving(player)
	-- Clean up connections
	local conn = sleepConnections[player.UserId]
	if conn then
		conn:Disconnect()
		sleepConnections[player.UserId] = nil
	end
end

-- // MAIN

-- Connect events
updateBlanketColorEvent.OnServerEvent:Connect(onUpdateBlanketColor)

Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(playerRemoving)

-- Set up fake-data for testing outside WOS
if game.PlaceId == SLEEP_EXPERIENCE_ID then
	-- Initialize data for existing players
	for _, player in ipairs(Players:GetPlayers()) do
		initializeData(player)
	end

	Players.PlayerAdded:Connect(function(player)
		initializeData(player)
	end)
end