-- This client script updates blankets of nearby players, makes nearby sleeping players snore randomly, and emits ZzZzZ FX from player heads
-- Snoring & sleep FX are optional and can be disabled through attributes under SleepingConfig

--- // SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--- // OBJECTS
local BlanketService = require(script.Parent.SleepBlanketService)
local SleepAnimationService = require(script.Parent.SleepAnimationService)
local localPlayer = Players.LocalPlayer

local sleepFXTemplate = script.SleepFX
local snoringSounds = script.SnoringSounds

--- // CONFIG
local sleepConfig = ReplicatedStorage.Configurations.SleepingConfig
local USE_SNORES = sleepConfig:GetAttribute("Snores")
local USE_FX = sleepConfig:GetAttribute("ZZZ_Effect")
local DEFAULT_SNORE_THRESHOLD = sleepConfig:GetAttribute("SnoreOdds")
local SLEEP_FX_RANGE = sleepConfig:GetAttribute("SleepFXRange")
local SIDE_SWITCH_DELAY = sleepConfig:GetAttribute("SideSwitchDelay") or 1
local BLANKET_UPDATE_DELAY = 0.1

--- // VARIABLES
local sleepAnimTrack = nil
local t, interval = 0, 3
local addingFX = {}
local lastSideSwitchTime = 0
--- // FUNCTIONS

local function shouldSnore(userId: number): boolean
	local currentTime = os.clock()
	local timeSlot = math.floor(currentTime)

	-- Combine userId with time for randomness
	local seed = userId + timeSlot
	local hash = seed * 2654435761
	hash = hash % 4294967296

	local playerChance = (userId % 20) + 10
	local roll = hash % 100

	return roll < playerChance
end

local function playRandomSnoringSound(head: BasePart)
	if not head or head:FindFirstChild("SnoreSound") then
		return
	end

	local snoreList = snoringSounds:GetChildren()
	local randSound = snoreList[math.random(#snoreList)]

	local snoreSound = randSound:Clone()
	snoreSound.Name = "SnoreSound"
	snoreSound.Parent = head
	snoreSound:Play()

	snoreSound.Ended:Once(function()
		snoreSound:Destroy()
	end)
end

-- Emit sleep FX from a character's head
local function updateSleepFX(head: BasePart, sleeping: boolean)
	if not head then
		return
	end
	local sleepFX = head:FindFirstChild("SleepFX")

	-- If sleep FX do not exist, and the player is sleeping, create them
	if not sleepFX and sleeping then
		if addingFX[head] then
			return
		end -- Debounce to ensure there's no spam
		addingFX[head] = true

		sleepFX = sleepFXTemplate:Clone()
		sleepFX.Parent = head

		task.delay(1, function()
			addingFX[head] = nil
		end)
		-- If sleep FX do not exist, and the player is not sleeping, return
	elseif not sleepFX and not sleeping then
		return
	end

	-- Delay to ensure the effects don't apply as the player is laying down, which would make them emit in wrong direction
	task.delay(0.1, function()
		sleepFX.Enabled = sleeping
	end)
end

local function onCharacterAdded(char)
	local sleepingSideChanged
	sleepingSideChanged = char:GetAttributeChangedSignal("SleepingSide"):Connect(function()
		-- Apply debounce to prevent spam
		local currentTime = os.clock()
		if currentTime - lastSideSwitchTime < SIDE_SWITCH_DELAY then
			return
		end
		lastSideSwitchTime = currentTime

		-- ALWAYS update animation when sleeping side changes, even if not sleeping
		-- This ensures animation stops when player exits bed while on Left/Right
		local sleepingSide = char:GetAttribute("SleepingSide")

		-- If switching to Back position or stopping sleep, update immediately
		-- Otherwise, add a delay to let the animation complete
		if sleepingSide == "Back" or sleepingSide == nil or not localPlayer:GetAttribute("Sleeping") then
			SleepAnimationService.updateSleepAnimation()
		else
			-- Delay animation update to prevent blanket from updating mid-rotation
			task.delay(BLANKET_UPDATE_DELAY, function()
				SleepAnimationService.updateSleepAnimation()
			end)
		end
	end)

	char.Destroying:Once(function()
		sleepingSideChanged:Disconnect()
	end)
end

-- This function will update blankets, emit snores, and sleep FX for all nearby players
-- Snores, sleep FX, & proximity range can be configured
-- No animation stuff in here. The client handles their own animations
local function updateSleepStates()
	-- Makes the code run at an interval
	if (os.clock() - t) < interval then
		return
	end
	t = os.clock()

	for _, player in ipairs(Players:GetPlayers()) do
		task.wait()
		local char = player.Character
		local head = char and char:FindFirstChild("Head")
		if not head then
			continue
		end

		-- We don't need any of the below to run for players who are very far away
		local inProximity = localPlayer:DistanceFromCharacter(head.Position) < SLEEP_FX_RANGE
		if not inProximity then
			continue
		end

		local isSleeping = player:GetAttribute("Sleeping")

		BlanketService.updateBlanket(player)

		if USE_SNORES and isSleeping and shouldSnore(player.UserId) then
			playRandomSnoringSound(head)
		end

		if USE_FX then
			updateSleepFX(head, isSleeping)
		end
	end
end

--- // MAIN
-- Update animation when sleeping state changes
localPlayer:GetAttributeChangedSignal("Sleeping"):Connect(function()
	SleepAnimationService.updateSleepAnimation()
	-- Also reset sleeping side when stopping sleep
	if not localPlayer:GetAttribute("Sleeping") and localPlayer.Character then
		localPlayer.Character:SetAttribute("SleepingSide", nil)
	end
end)

localPlayer.CharacterAdded:Connect(onCharacterAdded)
if localPlayer.Character then
	onCharacterAdded(localPlayer.Character)
end

RunService.Heartbeat:Connect(updateSleepStates)
