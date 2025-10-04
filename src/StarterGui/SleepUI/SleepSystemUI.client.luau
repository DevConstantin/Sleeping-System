-- This script handles the sleeping system UI and sends info to the server

--- // SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

--- // OBJECTS
local localPlayer = Players.LocalPlayer

-- UI objects
local UI = script.Parent.TweenFrame1
local wheelOutput = script.Parent.WheelColor
local mainFrame = UI.MainFrame
local closeButton = mainFrame.CloseButton
local confirmColor = script.Parent.TweenFrame2.Confirm
local wheelOpen = mainFrame.ColorButton
local positionSelectionFrame = UI.MainFrame.PositionSelectionFrame
local positionBack = positionSelectionFrame.Back
local positionLeft = positionSelectionFrame.Left
local positionRight = positionSelectionFrame.Right
local TweenFrame1 = UI
local TweenFrame2 = script.Parent.TweenFrame2
local openButton = script.Parent.OpenButton

-- Remote events
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local updateBlanketColorEvent = remoteEvents:WaitForChild("UpdateBlanketColor")
local setSleepingPositionEvent = remoteEvents:WaitForChild("SetSleepingPosition")

-- UI sounds
local uiSounds = SoundService:WaitForChild("UI_Sounds")
local clickSound = uiSounds:WaitForChild("RBLX UI Hover 02 (SFX)")
local hoverSound = uiSounds:WaitForChild("RBLX UI Hover 03 (SFX)")
local confirmSound = uiSounds:WaitForChild("RBLX UI Back (SFX)")

--- // TWEEN SETTINGS
local TWEEN_INFO_OPEN = TweenInfo.new(1.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TWEEN_INFO_CLOSE = TweenInfo.new(1.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

--- // STATE TRACKING
local originalPositions = {}
local hiddenPositions = {}
local currentTweens = {}
local openButtonOriginalPosition = nil
local validSleepingPositions = {"Back", "Left", "Right"}


--- // FUNCTIONS
-----------------------------------------------------------------------------------------------
--------------------------------------- SOUND FUNCTIONS ---------------------------------------
-----------------------------------------------------------------------------------------------
local function playHoverSound()
	if hoverSound and hoverSound.Parent then 
		hoverSound:Play()
	end
end

local function playUISound(sound)
	if sound and sound.Parent then 
		sound:Play()
	end
end

local function setupButtonHoverSounds(button)
	button.MouseEnter:Connect(playHoverSound)
end

-----------------------------------------------------------------------------------------------
--------------------------------------- TWEEN FUNCTIONS ---------------------------------------
-----------------------------------------------------------------------------------------------

local function initializePositions()
    originalPositions.TweenFrame1 = TweenFrame1.Position
    openButtonOriginalPosition = openButton.Position

   	hiddenPositions.TweenFrame1 = UDim2.new(
		originalPositions.TweenFrame1.X.Scale + 1.5,
		originalPositions.TweenFrame1.X.Offset,
		originalPositions.TweenFrame1.Y.Scale,
		originalPositions.TweenFrame1.Y.Offset
	)

    	hiddenPositions.OpenButton = UDim2.new(
		openButtonOriginalPosition.X.Scale + 1.2,
		openButtonOriginalPosition.X.Offset,
		openButtonOriginalPosition.Y.Scale,
		openButtonOriginalPosition.Y.Offset
	)

    TweenFrame1.Position = hiddenPositions.TweenFrame1
	TweenFrame1.Visible = false
	TweenFrame2.Visible = false
	openButton.Position = hiddenPositions.OpenButton
	openButton.Visible = false

	setupButtonHoverSounds(closeButton)
	setupButtonHoverSounds(wheelOpen)
	setupButtonHoverSounds(confirmColor)
	setupButtonHoverSounds(positionBack)
	setupButtonHoverSounds(positionLeft)
	setupButtonHoverSounds(positionRight)
	setupButtonHoverSounds(openButton)
end

local function stopCurrentTween(frame)
    if currentTweens[frame] then
        currentTweens[frame]:Cancel()
        currentTweens[frame] = nil
    end
end

local function tweenFrameIn(frame, frameName)
	stopCurrentTween(frameName)
	frame.Visible = true
	local tween = TweenService:Create(frame, TWEEN_INFO_OPEN, {Position = originalPositions[frameName]})
	currentTweens[frameName] = tween
	tween:Play()
	return tween
end

local function tweenFrameOut(frame, frameName, callback)
	stopCurrentTween(frameName)
	local tween = TweenService:Create(frame, TWEEN_INFO_CLOSE, {Position = hiddenPositions[frameName]})
	currentTweens[frameName] = tween
	tween:Play()
	tween.Completed:Connect(function()
		frame.Visible = false
		currentTweens[frameName] = nil
		if callback then callback() end
	end)
	return tween
end

local function tweenOpenButtonIn()
	stopCurrentTween("OpenButton")
	openButton.Visible = true
	local tween = TweenService:Create(openButton, TWEEN_INFO_OPEN, {Position = openButtonOriginalPosition})
	currentTweens.OpenButton = tween
	tween:Play()
	return tween
end

local function tweenOpenButtonOut(callback)
	stopCurrentTween("OpenButton")
	local tween = TweenService:Create(openButton, TWEEN_INFO_CLOSE, {Position = hiddenPositions.OpenButton})
	currentTweens.OpenButton = tween
	tween:Play()
	tween.Completed:Connect(function()
		openButton.Visible = false
		currentTweens.OpenButton = nil
		if callback then callback() end
	end)
	return tween
end

------------------------------------------------------------------------------------------------------
-------------------------------------- UI INTERACTION FUNCTIONS --------------------------------------
------------------------------------------------------------------------------------------------------

local function openColorWheel()
	playUISound(clickSound)
	TweenFrame2.Visible = true
end

local function closeColorWheel()
	playUISound(clickSound)
	TweenFrame2.Visible = false
end

local function openSleepUI()
	playUISound(clickSound)
	tweenFrameIn(TweenFrame1, "TweenFrame1")
	tweenOpenButtonOut()
end

local function closeSleepUI()
	playUISound(clickSound)
	tweenFrameOut(TweenFrame1, "TweenFrame1")

	if TweenFrame2.Visible then
		closeColorWheel()
	end

	if localPlayer:GetAttribute("Sleeping") then
		task.delay(0.3, function()
			tweenOpenButtonIn()
		end)
	end
end

------------------------------------------------------------------------------------------------
-------------------------------------- SLEEPING FUNCTIONS --------------------------------------
------------------------------------------------------------------------------------------------

local function confirmBlanketColor()
	local newColor = wheelOutput.Value

	if typeof(newColor) ~= "Color3" then
		warn("Invalid color from wheel output")
		return
	end

	playUISound(confirmSound)
	updateBlanketColorEvent:FireServer(newColor)
	closeColorWheel()
end

local function changeSleepingPosition(position)
	if not table.find(validSleepingPositions, position) then
		warn("Invalid sleeping position:", position)
		return
	end

	if not localPlayer:GetAttribute("Sleeping") then
		warn("Cannot change sleeping position - player is not sleeping")
		return
	end

	playUISound(clickSound)
	setSleepingPositionEvent:FireServer(position)
end

local function onSleepingChanged()
	local sleeping = localPlayer:GetAttribute("Sleeping")

	if sleeping then
		openSleepUI()
	else
		closeSleepUI()
		tweenOpenButtonOut()
	end
end

--- // MAIN

-- Event setup
wheelOpen.MouseButton1Click:Connect(function()
	if TweenFrame2.Visible then
		closeColorWheel()
	else
		openColorWheel()
	end
end)

positionBack.MouseButton1Click:Connect(function()
	changeSleepingPosition("Back")
end)

positionLeft.MouseButton1Click:Connect(function()
	changeSleepingPosition("Left")
end)

positionRight.MouseButton1Click:Connect(function()
	changeSleepingPosition("Right")
end)

openButton.MouseButton1Click:Connect(function()
	if localPlayer:GetAttribute("Sleeping") then
		openSleepUI()
	end
end)

closeButton.MouseButton1Click:Connect(closeSleepUI)
localPlayer:GetAttributeChangedSignal("Sleeping"):Connect(onSleepingChanged)
confirmColor.MouseButton1Click:Connect(confirmBlanketColor)

-- Initialization
initializePositions()