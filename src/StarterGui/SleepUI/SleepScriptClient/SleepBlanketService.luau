-- This script contains code for managing blankets on characters

local SleepBlanketService = {}

-- // SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
--- // OBJECTS
local DebugService = require(ReplicatedStorage.RSModules.DebugService)

local blanketTemplate = workspace:WaitForChild("Blanket")

-- // CONFIG
local DEBUG_DELAY = 5
local sleepConfig = ReplicatedStorage.Configurations.SleepingConfig
local DEFAULT_BLANKET_COLOR = sleepConfig:GetAttribute("DefaultBlanketColor")

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

function SleepBlanketService.updateBlanket(player)
	local isSleeping = player:GetAttribute("Sleeping")
	if isSleeping then
		local char = player.Character
		if not char then
			warn("No character found for", player)
			return
		end
		
		-- Get sleeping side from CHARACTER, not player
		local sleepingSide = char:GetAttribute("SleepingSide")
		local isSideSleeping = sleepingSide == "Left" or sleepingSide == "Right"
		
		local torso = char:FindFirstChild("UpperTorso")
		local lowerTorso = char:FindFirstChild("LowerTorso")
		if not torso or not lowerTorso then
			warn("Missing UpperTorso/LowerTorso for", char, torso, lowerTorso)
			return
		end

		local blanket = getBlanket(player, true)

		-- Update blanket color from player's CharacterData with tween
		local desiredColor = DEFAULT_BLANKET_COLOR -- Start with default

		local characterData = player:FindFirstChild("CharacterData")
		if characterData then
			local blanketColorValue = characterData:FindFirstChild("blanket_Color")
			if blanketColorValue then
				-- Only use the saved color if it's not black (0,0,0) or nil
				local savedColor = blanketColorValue.Value
				if savedColor and savedColor ~= Color3.new(0, 0, 0) then
					desiredColor = savedColor
				end
			end
		end

		-- Tween to the desired color
		if blanket.Color ~= desiredColor then
			local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = TweenService:Create(blanket, tweenInfo, { Color = desiredColor })
			tween:Play()
		end
		
		-- Exit early for side sleeping - color is updated, but skip position/size
		if isSideSleeping then
			return
		end
		
		-- Check if position was recently locked due to position change
		local positionLockTime = blanket:GetAttribute("PositionLockUntil")
		if positionLockTime and os.clock() < positionLockTime then
			return -- Skip position updates while locked
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
		
		-- Scale based on character size
		local baseLength = (feetPos - neckPos).Magnitude
		local FEET_EXTRA_PERCENT = 0.25  -- 25% extra length past feet
		local ARM_WIDTH_MULTIPLIER = 1.4  -- 40% wider for arms
		
		local blanketSizeZ = baseLength * (1 + FEET_EXTRA_PERCENT)
		local extents = char:GetExtentsSize()
		local ySize = torso.Size.Y + 0.1
		blanket.Size = Vector3.new(
			extents.X * ARM_WIDTH_MULTIPLIER,  -- Wider for arms
			ySize + ySize * 0.1,
			blanketSizeZ  -- Longer for feet
		)

		DebugService:placeNode(waistCF.Position, Color3.new(0.666667, 1, 1), nil, DEBUG_DELAY)
		local previousPos = waistCF.Position
		
		-- Shift down slightly
		waistCF -= (waistCF.UpVector * blanketSizeZ * 0.1)
		
		DebugService:connectPositions(previousPos, waistCF.Position, Color3.new(0.666667, 1, 1), 0.05, DEBUG_DELAY)
		DebugService:placeNode(waistCF.Position, Color3.new(0, 1, 0.835294), nil, DEBUG_DELAY)

		blanket.CFrame = waistCF * CFrame.Angles(math.rad(-90), 0, 0)
		blanket.Anchored = true -- Lock position after calculation
	else
		local blanket = getBlanket(player, false)
		if blanket then
			blanket:Destroy()
		end
	end
end

return SleepBlanketService