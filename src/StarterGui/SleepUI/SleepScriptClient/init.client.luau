-- This client script updates blankets of nearby players, makes nearby sleeping players snore randomly, and emits ZzZzZ FX from player heads
-- Snoring & sleep FX are optional and can be disabled through attributes under SleepingConfig

--- // SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--- // OBJECTS
local BlanketService = require(game.ReplicatedStorage.RSModules.SleepBlanketService)

local localPlayer = Players.LocalPlayer

local sleepFXTemplate = script.SleepFX
local snoringSounds = script.SnoringSounds

--- // CONFIG
local sleepConfig = ReplicatedStorage.Configurations.SleepingConfig
local USE_SNORES = sleepConfig:GetAttribute("Snores")
local USE_FX = sleepConfig:GetAttribute("ZZZ_Effect")
local DEFAULT_SNORE_THRESHOLD = sleepConfig:GetAttribute("SnoreOdds")
local SLEEP_FX_RANGE = sleepConfig:GetAttribute("SleepFXRange")

--- // SLEEP ANIMATION IDS
local SLEEP_ANIMATIONS = {
	Right = "rbxassetid://72820421782942",
	Back = "rbxassetid://131934871886139",
	Left = "rbxassetid://133771894405396"
}

--- // VARIABLES
local sleepAnimTracks = {} -- Changed to store multiple tracks per player
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
-- Now accounts for desired sleeping side
local function playSleepAnim(player)
	local sleeping = player:GetAttribute("Sleeping")
	
	-- Get sleeping side from character
	local char = player.Character
	if not char then
		return
	end
	
	local sleepingSide = char:GetAttribute("SleepingSide") or "Back" -- Default to back if not specified

	BlanketService.updateBlanket(player)

	-- Since this code is run within the RunService loop, this makes sure it is only run on your own character
	if player ~= localPlayer then
		return
	end

	local animator = char:WaitForChild("Humanoid"):WaitForChild("Animator")

	print(player.Name, sleeping and ("is sleeping on " .. sleepingSide .. " side!") or "is NOT sleeping.")

	-- Initialize player's anim tracks table if it doesn't exist
	if not sleepAnimTracks[player] then
		sleepAnimTracks[player] = {}
	end

	if sleeping then
		-- Stop any currently playing sleep animation
		for side, track in pairs(sleepAnimTracks[player]) do
			if track.IsPlaying then
				track:Stop()
			end
		end

		-- Get or create the animation track for the current side
		if not sleepAnimTracks[player][sleepingSide] then
			local animationId = SLEEP_ANIMATIONS[sleepingSide]
			if animationId then
				local sleepAnimation = Instance.new("Animation")
				sleepAnimation.AnimationId = animationId
				sleepAnimTracks[player][sleepingSide] = animator:LoadAnimation(sleepAnimation)
			else
				warn("Invalid sleeping side: " .. tostring(sleepingSide))
				return
			end
		end

		-- Play the animation for the current side
		sleepAnimTracks[player][sleepingSide]:Play()
	elseif not sleeping then
		-- Stop all sleep animations when waking up
		for side, track in pairs(sleepAnimTracks[player]) do
			if track.IsPlaying then
				track:Stop()
			end
		end
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
		local sleepingPosition = player:GetAttribute("SleepingPosition")
		
		-- Only update blanket if not in a side position (Left/Right blocks position calculation)
		-- Color will still update via the early return in updateBlanket
		if isSleeping and (sleepingPosition ~= "Left" and sleepingPosition ~= "Right") then
			BlanketService.updateBlanket(player)
		elseif isSleeping then
			-- For Left/Right positions, still call update for color changes only
			BlanketService.updateBlanket(player)
		elseif not isSleeping then
			BlanketService.updateBlanket(player) -- This will destroy the blanket
		end

		if USE_SNORES and isSleeping and shouldSnore(player.UserId) then
			playRandomSnoringSound(head)
		end

		if USE_FX then
			updateSleepFX(head, isSleeping)
		end
	end
end

local function initPlayer(player)
	-- Initialize the animation tracks table for this player
	sleepAnimTracks[player] = {}
	
	-- Listen for sleeping state changes on the player
	player:GetAttributeChangedSignal("Sleeping"):Connect(function()
		playSleepAnim(player)
	end)
	
	-- Function to set up character-specific listeners
	local function onCharacterAdded(character)
		-- Listen for sleeping side changes on the CHARACTER (not player)
		character:GetAttributeChangedSignal("SleepingSide"):Connect(function()
			-- Only update if currently sleeping
			if player:GetAttribute("Sleeping") then
				print(player.Name, "SleepingSide changed to", character:GetAttribute("SleepingSide"))
				playSleepAnim(player)
			end
		end)
	end
	
	-- Set up for current character if it exists
	if player.Character then
		onCharacterAdded(player.Character)
	end
	
	-- Set up for future characters (respawns)
	player.CharacterAdded:Connect(onCharacterAdded)
	
	-- Clean up when player is removed
	player.AncestryChanged:Connect(function()
		if not player:IsDescendantOf(game) then
			sleepAnimTracks[player] = nil
		end
	end)
end

--- // MAIN

initPlayer(localPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	initPlayer(player)
end

Players.PlayerAdded:Connect(initPlayer)
RunService.Heartbeat:Connect(updateSleepStates)