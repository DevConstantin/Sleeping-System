-- This script contains code for managing blankets on characters

local SleepBlanketService = {}

-- // SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--- // OBJECTS
local DebugService = require(ReplicatedStorage.RSModules.DebugService)

local blanketTemplate = workspace:WaitForChild("Blanket")

-- // CONFIG
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

function SleepBlanketService.updateBlanket(player)
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

return SleepBlanketService
