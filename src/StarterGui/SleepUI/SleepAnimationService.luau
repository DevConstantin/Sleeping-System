--[[
SleepAnimationService
- Manages sleep animations based on sleeping position
- Handles animation transitions smoothly
- Tracks active animations per player
--]]

local SleepAnimationService = {}

--- // SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--- // OBJECTS
local localPlayer = Players.LocalPlayer

--- // CONFIG
local sleepConfig = ReplicatedStorage.Configurations.SleepingConfig

local ANIM_IDS = {
	Back = "rbxassetid://125086013362856",
	Left = "rbxassetid://138119398121379",
	Right = "rbxassetid://75579541303045",
}

--- // VARIABLES
local activeAnimTrack = nil
local activeAnimationId = nil -- Track which animation is currently playing

--- // FUNCTIONS

local function getAnimator()
	local hum = localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid")
	return hum and hum:FindFirstChildOfClass("Animator")
end

local function getSleepingAnimID(sleepPosition: string)
	-- Override desired sleeping position
	if sleepPosition == nil or not ANIM_IDS[sleepPosition] then
		sleepPosition = "Back"
	end

	return ANIM_IDS[sleepPosition] or ANIM_IDS.Back
end

local function loadAndPlayAnimation(sleepAnimId: string)
	local animator = getAnimator()
	if not animator then
		--warn("SleepAnimationService: Failed to get own animator!")
		return
	end

	-- Stop existing animation first
	SleepAnimationService.stopSleepAnim()

	-- Play animation
	local sleepAnimation = Instance.new("Animation")
	sleepAnimation.AnimationId = sleepAnimId

	local animTrack = animator:LoadAnimation(sleepAnimation)

	activeAnimTrack = animTrack
	activeAnimationId = sleepAnimId
	animTrack:Play()

	-- Clean up when animation stops
	animTrack.Stopped:Once(function()
		print("Animation has stopped.")

		if activeAnimTrack == animTrack then -- Only clear if this is still the active track
			activeAnimTrack = nil
			activeAnimationId = nil
		end
	end)
end

-- Method to update the sleeping animation
function SleepAnimationService.updateSleepAnimation()
	local char = localPlayer.Character
	if not char then
		return
	end

	local isSleeping = localPlayer:GetAttribute("Sleeping")
	if isSleeping then
		local desiredAnimId = getSleepingAnimID(char:GetAttribute("SleepingSide"))

		-- Check if the desired animation is already playing
		if activeAnimationId == desiredAnimId and activeAnimTrack and activeAnimTrack.IsPlaying then
			return -- Already playing the correct animation
		end

		-- Play the new animation
		loadAndPlayAnimation(desiredAnimId)
	else
		-- Not sleeping, stop any active sleep animation
		SleepAnimationService.stopSleepAnim()
	end
end

-- Method to stop the active sleeping animation, if it exists/is playing
function SleepAnimationService.stopSleepAnim()
	if activeAnimTrack then
		if activeAnimTrack.IsPlaying then
			activeAnimTrack:Stop()
		end
		activeAnimTrack = nil
		activeAnimationId = nil
	end
end

-- Clean up animations when character is removed
function SleepAnimationService.cleanUp()
	SleepAnimationService.stopSleepAnim()
end

return SleepAnimationService
