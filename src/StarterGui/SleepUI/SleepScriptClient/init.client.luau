--- // SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--- // OBJECTS
local DebugService =
	require(game:GetService("ReplicatedStorage"):WaitForChild("RSModules"):WaitForChild("DebugService"))
local localPlayer = Players.LocalPlayer

local sleepFXTemplate = script.SleepFX
local snoringSounds = script.SnoringSounds

local blanketTemplate = workspace:WaitForChild("Blanket")

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
local function ShouldSnore(userId)
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

local function playRandomSnoringSound(head)
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

local function updateSleepFX(head, sleeping)
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

local DEBUG_DELAY = 5

local function getFeetPosition(char)
	local leftFoot = char:FindFirstChild("LeftFoot")
	local leftAtt = leftFoot and leftFoot:FindFirstChildWhichIsA("Attachment")
	local rightFoot = char:FindFirstChild("RightFoot")
	local rightAtt = rightFoot and rightFoot:FindFirstChildWhichIsA("Attachment")
	if not leftAtt and not rightAtt then
		return
	end

	local posL = leftAtt.WorldCFrame.Position
	local posR = rightAtt.WorldCFrame.Position
	local feetPos = leftAtt.WorldCFrame.Position

	DebugService:placeNode(feetPos, nil, nil, DEBUG_DELAY)

	local offsetVector = CFrame.lookAt(posL, posR).LookVector.Unit * (posL - posR).Magnitude / 2 -- The line between the feet, divided by 2 to get the midpoint
	DebugService:connectPositions(feetPos, feetPos + offsetVector, Color3.new(0, 1, 0), 0.05, DEBUG_DELAY)

	feetPos += offsetVector

	DebugService:placeNode(feetPos, nil, nil, DEBUG_DELAY)
	return feetPos
end

local function getBlanket(player, addingBlanket: boolean)
	local blanketsFolder = workspace:FindFirstChild("Sleep_System_Blankets")
	if not blanketsFolder then
		blanketsFolder = Instance.new("Folder")
		blanketsFolder.Name = "Sleep_System_Blankets"
		blanketsFolder.Parent = workspace
	end

	local blanket = blanketsFolder:FindFirstChild("Blanket_" .. tostring(player.UserId))
	if not blanket and addingBlanket then
		blanket = blanketTemplate:Clone()
		blanket.Name = "Blanket_" .. tostring(player.UserId)
		blanket.Parent = blanketsFolder
	end

	return blanket
end

local function updateBlanket(player)
	local isSleeping = player:GetAttribute("Sleeping")
	if isSleeping then
		local char = player.Character
		local torso = char and char:FindFirstChild("UpperTorso")
		local lowerTorso = char and char:FindFirstChild("LowerTorso")
		if not torso or not lowerTorso then
			warn("Missing UpperTorso/LowerTorso for", char, torso, lowerTorso)
			return
		end

		local feetPos = getFeetPosition(char)
		if not feetPos then
			warn("Failed to get feet position for", char)
			return
		end

		local waistAtt = lowerTorso:FindFirstChild("WaistCenterAttachment")
		local waistCF = waistAtt and waistAtt.WorldCFrame
		local neckAtt = torso:FindFirstChild("NeckAttachment")
		local neckPos = neckAtt and neckAtt.WorldCFrame.Position
		if not waistCF or not neckPos then
			warn("Missing NeckAttachment/WaistCenterAttachment for", char, waistCF, neckPos)
			return
		end

		DebugService:placeNode(waistCF.Position, Color3.new(1, 1, 1), nil, DEBUG_DELAY)
		DebugService:placeNode(neckPos, Color3.new(1, 1, 1), nil, DEBUG_DELAY)
		DebugService:connectPositions(feetPos, neckPos, Color3.new(0.490196, 0.254902, 1), 0.05, DEBUG_DELAY)

		local blanket = getBlanket(player, true)
		local blanketSizeZ = (feetPos - neckPos).Magnitude
		local extents = char:GetExtentsSize()
		local ySize = torso.Size.Y
		blanket.Size = Vector3.new(extents.X + extents.X * 0.1, ySize + ySize * 0.1, blanketSizeZ)

		DebugService:placeNode(waistCF.Position, Color3.new(0.666667, 1, 1), nil, DEBUG_DELAY)
		local previousPos = waistCF.Position
		waistCF -= (waistCF.UpVector * blanketSizeZ * 0.1)
		DebugService:connectPositions(previousPos, waistCF.Position, Color3.new(0.666667, 1, 1), 0.05, DEBUG_DELAY)
		DebugService:placeNode(waistCF.Position, Color3.new(0, 1, 0.835294), nil, DEBUG_DELAY)

		blanket.CFrame = waistCF * CFrame.Angles(math.rad(90), 0, 0)
	else
		local blanket = getBlanket(player, false)
		if blanket then
			blanket:Destroy()
		end
	end
end

local function playSleepAnim(player)
	local sleeping = player:GetAttribute("Sleeping")

	updateBlanket(player)

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

		local isSleeping = player:GetAttribute("Sleeping")
		local inProximity = localPlayer:DistanceFromCharacter(head.Position) < SLEEP_FX_RANGE

		updateBlanket(player)

		if USE_SNORES and isSleeping and inProximity and ShouldSnore(player.UserId) then
			playRandomSnoringSound(head)
		end

		if USE_FX then
			updateSleepFX(head, isSleeping and inProximity)
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