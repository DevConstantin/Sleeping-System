-- This client script updates blankets of nearby players, makes nearby sleeping players snore randomly, and emits ZzZzZ FX from player heads
-- Snoring & sleep FX are optional and can be disabled through attributes under SleepingConfig

--- // SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--- // OBJECTS
local BlanketService = require(script.Parent.SleepBlanketService)

local localPlayer = Players.LocalPlayer

local sleepFXTemplate = script.SleepFX
local snoringSounds = script.SnoringSounds

--- // CONFIG
local sleepConfig = ReplicatedStorage.Configurations.SleepingConfig
local USE_SNORES = sleepConfig:GetAttribute("Snores")
local USE_FX = sleepConfig:GetAttribute("ZZZ_Effect")
local DEFAULT_SNORE_THRESHOLD = sleepConfig:GetAttribute("SnoreOdds")
local SLEEP_FX_RANGE = sleepConfig:GetAttribute("SleepFXRange")

--- // VARIABLES
local sleepAnimTrack = nil
local t, interval = 0, 3
local addingFX = {}

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

	local soundEnded
	soundEnded = snoreSound.Ended:Connect(function()
		soundEnded:Disconnect()
		snoreSound:Destroy()
	end)
end

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

-- This will play a sleep animation on the player character, if they are sleeping
-- Doesn't currently account for desired sleeping side
local function playSleepAnim(player)
	local sleeping = player:GetAttribute("Sleeping")

	BlanketService.updateBlanket(player)

	-- Since this code is run within the RunService loop, this makes sure it is only run on your own character
	if player ~= localPlayer then
		return
	end

	local char = player.Character
	if not char then
		return
	end
	local animator = char:WaitForChild("Humanoid"):WaitForChild("Animator")

	print(player, sleeping and "is sleeping!" or "is NOT sleeping.")

	if sleeping then
		if not sleepAnimTrack then
			local sleepAnimation = Instance.new("Animation")
			sleepAnimation.AnimationId = "rbxassetid://77400291260696"
			sleepAnimTrack = animator:LoadAnimation(sleepAnimation)
		end
		sleepAnimTrack:Play()
	elseif not sleeping and sleepAnimTrack then
		sleepAnimTrack:Stop()
	end
end

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

local function initPlayer(player)
	-- This will memory leak but I don't currently care
	player:GetAttributeChangedSignal("Sleeping"):Connect(function()
		playSleepAnim(player)
	end)
end

--- // MAIN

initPlayer(localPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	initPlayer(player)
end

Players.PlayerAdded:Connect(initPlayer)
RunService.Heartbeat:Connect(updateSleepStates)
