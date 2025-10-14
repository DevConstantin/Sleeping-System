-- This script handles the sleeping system UI and sends info to the server

--- // SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

--- // OBJECTS
local localPlayer = Players.LocalPlayer

-- UI objects
local UI = script.Parent.TweenFrame
local wheelOutput = script.Parent.WheelColor
local mainFrame = UI.MainFrame
local colorFrame = UI.ColorFrame
local closeButton = mainFrame.CloseButton
local confirmColor = colorFrame.Confirm
local wheelOpen = mainFrame.ColorButton
local positionSelectionFrame = mainFrame.PositionSelectionFrame
local positionBack = positionSelectionFrame.Back
local positionLeft = positionSelectionFrame.Left
local positionRight = positionSelectionFrame.Right
local openButton = script.Parent.OpenButton

-- Remote events
local sleepSystemEvents = ReplicatedStorage.RemoteEvents.SleepingSystem
local updateBlanketColorEvent = sleepSystemEvents.UpdateBlanketColor

-- UI sounds
local uiSounds = SoundService:WaitForChild("UI_Sounds")
local clickSound = uiSounds:WaitForChild("RBLX UI Hover 02 (SFX)")
local hoverSound = uiSounds:WaitForChild("RBLX UI Hover 03 (SFX)")
local confirmSound = uiSounds:WaitForChild("RBLX UI Back (SFX)")

--- // CONFIG
local sleepConfig = ReplicatedStorage.Configurations.SleepingConfig
local SIDE_SWITCH_DELAY = sleepConfig:GetAttribute("SideSwitchDelay") or 1

--- // TWEEN SETTINGS
local TWEEN_INFO = TweenInfo.new(1.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

--- // STATE
local originalPosition = nil
local hiddenPosition = nil
local openButtonOriginalPos = nil
local openButtonHiddenPos = nil
local colorFrameOriginalSize = nil
local validSleepingPositions = { "Back", "Left", "Right" }
local lastSideSwitchTime = 0

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
	originalPosition = UI.Position
	openButtonOriginalPos = openButton.Position
	colorFrameOriginalSize = colorFrame.Size

	hiddenPosition = UDim2.new(
		originalPosition.X.Scale + 1.5,
		originalPosition.X.Offset,
		originalPosition.Y.Scale,
		originalPosition.Y.Offset
	)

	openButtonHiddenPos = UDim2.new(
		openButtonOriginalPos.X.Scale + 1.2,
		openButtonOriginalPos.X.Offset,
		openButtonOriginalPos.Y.Scale,
		openButtonOriginalPos.Y.Offset
	)

	UI.Position = hiddenPosition
	UI.Visible = false
	colorFrame.Visible = false
	colorFrame.Size = UDim2.new(0, 0, 0, 0)
	openButton.Position = openButtonHiddenPos
	openButton.Visible = false

	-- Setup hover sounds
	setupButtonHoverSounds(closeButton)
	setupButtonHoverSounds(wheelOpen)
	setupButtonHoverSounds(confirmColor)
	setupButtonHoverSounds(positionBack)
	setupButtonHoverSounds(positionLeft)
	setupButtonHoverSounds(positionRight)
	setupButtonHoverSounds(openButton)
end

------------------------------------------------------------------------------------------------------
-------------------------------------- UI INTERACTION FUNCTIONS --------------------------------------
------------------------------------------------------------------------------------------------------
local function openColorWheel()
	if colorFrame.Visible then
		return -- Already open
	end

	playUISound(clickSound)
	colorFrame.Size = colorFrameOriginalSize
	colorFrame.Visible = true
end

local function closeColorWheel()
	if not colorFrame.Visible then
		return -- Already closed
	end

	playUISound(clickSound)
	colorFrame.Visible = false
end

local function showMainUI()
	playUISound(clickSound)

	-- Hide open button
	openButton.Visible = false

	-- Show and tween main UI
	UI.Visible = true
	local tween = TweenService:Create(UI, TWEEN_INFO, { Position = originalPosition })
	tween:Play()
end

local function hideMainUI()
	playUISound(clickSound)

	-- Close color wheel if open
	if colorFrame.Visible then
		colorFrame.Size = UDim2.new(0, 0, 0, 0)
		colorFrame.Visible = false
	end

	-- Tween main UI out
	local tween = TweenService:Create(UI, TWEEN_INFO, { Position = hiddenPosition })
	tween:Play()

	tween.Completed:Once(function()
		UI.Visible = false

		-- Show open button if still sleeping
		if localPlayer:GetAttribute("Sleeping") then
			openButton.Visible = true
			local buttonTween = TweenService:Create(openButton, TWEEN_INFO, { Position = openButtonOriginalPos })
			buttonTween:Play()
		end
	end)
end

local function hideAllUI()
	-- Immediately hide everything without tweening
	UI.Visible = false
	UI.Position = hiddenPosition

	colorFrame.Visible = false
	colorFrame.Size = UDim2.new(0, 0, 0, 0)

	openButton.Visible = false
	openButton.Position = openButtonHiddenPos
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

local function changeSleepingPosition(sleepPosition)
	local currentTime = os.clock()
	if currentTime - lastSideSwitchTime < SIDE_SWITCH_DELAY then
		return
	end
	lastSideSwitchTime = currentTime

	local char = localPlayer.Character
	if not char or not localPlayer:GetAttribute("Sleeping") then
		return
	end

	if not table.find(validSleepingPositions, sleepPosition) then
		warn("Invalid sleeping position:", sleepPosition)
		return
	end

	playUISound(clickSound)
	char:SetAttribute("SleepingSide", sleepPosition)
end

local function onSleepingChanged()
	local sleeping = localPlayer:GetAttribute("Sleeping")

	if sleeping then
		-- Player started sleeping - show main UI
		showMainUI()
	else
		-- Player stopped sleeping - hide everything
		hideAllUI()
	end
end

--- // MAIN
wheelOpen.MouseButton1Click:Connect(function()
	if colorFrame.Visible then
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
		showMainUI()
	end
end)

closeButton.MouseButton1Click:Connect(hideMainUI)
localPlayer:GetAttributeChangedSignal("Sleeping"):Connect(onSleepingChanged)
confirmColor.MouseButton1Click:Connect(confirmBlanketColor)

initializePositions()
