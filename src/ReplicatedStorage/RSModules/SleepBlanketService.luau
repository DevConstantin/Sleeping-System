-- This script contains code for managing blankets on characters

local SleepBlanketService = {}

-- // SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--- // OBJECTS
local debugServiceModule = ReplicatedStorage.RSModules:FindFirstChild("DebugService")
local DebugService = debugServiceModule and require(debugServiceModule)

local sleepConfig = ReplicatedStorage.Configurations.SleepingConfig
local blanketTemplate = sleepConfig.BlanketMesh
local blanketsFolder = workspace.Sleep_System_Blankets

--- // CONFIG
local USE_DEBUG = sleepConfig:GetAttribute("UseDebugVisualization") or false
local DEBUG_DELAY = 5
local DEFAULT_BLANKET_COLOR = sleepConfig:GetAttribute("DefaultBlanketColor")

--- // FUNCTIONS
local function updateBlanketColor(player, blanket: BasePart)
	-- Update blanket color from player's CharacterData with tween
	local desiredColor = DEFAULT_BLANKET_COLOR -- Start with default

	local characterData = player:FindFirstChild("CharacterData")
	local blanketColorValue = characterData and characterData:FindFirstChild("blanket_Color")
	if blanketColorValue then
		-- Only use the saved color if it's not black (0,0,0) or nil
		local savedColor = blanketColorValue.Value
		if savedColor then
			desiredColor = savedColor
		end
	end

	-- Tween to the desired color
	if blanket.Color ~= desiredColor then
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(blanket, tweenInfo, { Color = desiredColor })
		tween:Play()
	end
end

-- Get position between the player's feet
local function getFeetPosition(char: Model): Vector3
	local leftFoot = char:FindFirstChild("LeftFoot")
	local leftAtt = leftFoot and leftFoot:FindFirstChildWhichIsA("Attachment")
	local rightFoot = char:FindFirstChild("RightFoot")
	local rightAtt = rightFoot and rightFoot:FindFirstChildWhichIsA("Attachment")
	if not leftAtt or not rightAtt then -- return if either foot attachment is missing. May be needed in situations where a character is somehow missing feet
		return
	end

	local posL = leftAtt.WorldCFrame.Position
	local posR = rightAtt.WorldCFrame.Position
	local feetPos = leftAtt.WorldCFrame.Position

	local offsetVector = CFrame.lookAt(posL, posR).LookVector.Unit * (posL - posR).Magnitude / 2 -- The line between the feet, divided by 2 to get the midpoint
	feetPos += offsetVector

	if USE_DEBUG and DebugService then
		DebugService:placeNode(feetPos, nil, nil, DEBUG_DELAY)
		DebugService:connectPositions(feetPos, feetPos + offsetVector, Color3.new(0, 1, 0), 0.05, DEBUG_DELAY)
		DebugService:placeNode(feetPos, nil, nil, DEBUG_DELAY)
	end

	return feetPos
end

-- Function to get a blanket for the player, or create a new one if the player's blanket doesn't exist
-- Should only be called on the client
function SleepBlanketService.getBlanketMesh(player, addingBlanket: boolean?)
	local userId = player.UserId
	local blanket = blanketsFolder:FindFirstChild("Blanket_" .. tostring(userId))
	if not blanket and addingBlanket then
		blanket = blanketTemplate:Clone()
		blanket.Name = "Blanket_" .. tostring(userId)
		blanket.Anchored = true -- Ensure blanket is always anchored
		-- placeBlanket(player.Character, blanket)
		blanket.Parent = blanketsFolder
	end
	return blanket
end

-- Calculate the appropriate CFrame and size for a blanket based on character position and size
function SleepBlanketService.getBlanketCFrameAndSize(char: Model): (CFrame, Vector3)
	local targetCFrame, targetSize
	local success, result = pcall(function()
		local torso = char:FindFirstChild("UpperTorso")
		local lowerTorso = char:FindFirstChild("LowerTorso")
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

		-- Scale based on character size
		local baseLength = (feetPos - neckPos).Magnitude
		local FEET_EXTRA_PERCENT = 0.25 -- 25% extra length past feet
		local ARM_WIDTH_MULTIPLIER = 1.4 -- 40% wider for arms

		local blanketSizeZ = baseLength * (1 + FEET_EXTRA_PERCENT)
		local extents = char:GetExtentsSize()
		local ySize = torso.Size.Y + 0.1
		targetSize = Vector3.new(
			extents.X * ARM_WIDTH_MULTIPLIER, -- Wider for arms
			ySize + ySize * 0.1,
			blanketSizeZ -- Longer for feet
		)

		local previousPos = waistCF.Position

		-- Shift down slightly
		waistCF -= (waistCF.UpVector * blanketSizeZ * 0.1)

		if USE_DEBUG and DebugService then
			DebugService:placeNode(waistCF.Position, Color3.new(1, 1, 1), nil, DEBUG_DELAY)
			DebugService:placeNode(neckPos, Color3.new(1, 1, 1), nil, DEBUG_DELAY)
			DebugService:connectPositions(feetPos, neckPos, Color3.new(0.490196, 0.254902, 1), 0.05, DEBUG_DELAY)

			DebugService:placeNode(waistCF.Position, Color3.new(0.666667, 1, 1), nil, DEBUG_DELAY)
			DebugService:connectPositions(previousPos, waistCF.Position, Color3.new(0.666667, 1, 1), 0.05, DEBUG_DELAY)
			DebugService:placeNode(waistCF.Position, Color3.new(0, 1, 0.835294), nil, DEBUG_DELAY)
		end

		local targetCFrame = waistCF * CFrame.Angles(math.rad(-90), 0, 0)
	end)

	if not success then
		warn("Error calculating blanket position for", char, result)
		return nil, nil
	end

	return targetCFrame, targetSize
end

-- Update the player blanket's color & position
function SleepBlanketService.updateBlanket(player)
	local isSleeping = player:GetAttribute("Sleeping")

	-- Ensure character exists
	local char = player.Character
	if not char then
		warn("No character found for", player)
		return
	end

	-- If not sleeping, remove blanket and exit
	if not isSleeping then
		SleepBlanketService.removeBlanket(player)
		return
	end

	-- Player is sleeping, continue with blanket logic
	local blanket = SleepBlanketService.getBlanketMesh(player, true)

	-- Update blanket color only (no position updates)
	updateBlanketColor(player, blanket)

	local targetCframe = char:GetAttribute("BlanketCFrame")
	local targetSize = char:GetAttribute("BlanketSize")
	if targetCframe == nil or targetSize == nil then
		-- Blanket position not yet set
		warn("Blanket position/size not set for", player, "Cannot update blanket position")
		return
	end

	-- Update blanket position & size if changed
	if blanket.CFrame ~= targetCframe then
		blanket.CFrame = targetCframe
	end

	if blanket.Size ~= targetSize then
		blanket.Size = targetSize
	end
end

function SleepBlanketService.removeBlanket(player)
	local blanket = SleepBlanketService.getBlanketMesh(player, false)
	if blanket then
		blanket:Destroy()
	end
end

return SleepBlanketService