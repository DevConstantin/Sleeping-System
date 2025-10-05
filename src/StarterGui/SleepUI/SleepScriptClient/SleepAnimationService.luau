--[[
SleepAnimationService
- Manages sleep animations based on sleeping position
- Handles animation transitions smoothly
- Tracks active animations per player
--]]

local SleepAnimationService = {}

-- // SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // CONFIG
local sleepConfig = ReplicatedStorage.Configurations.SleepingConfig

local ANIM_IDS = {
	Back = "rbxassetid://131934871886139",
	Left = "rbxassetid://133771894405396 ",
	Right = "rbxassetid://72820421782942 "
}

-- // VARIABLES
local activeAnimTracks = {}

-- // FUNCTIONS

local function stopCurrentAnimation(userId)
	local track = activeAnimTracks[userId]
	if track and track.IsPlaying then
		track:Stop()
	end
	activeAnimTracks[userId] = nil
end

local function loadAndPlayAnimation(player, position)
	local char = player.Character
	if not char then 
		warn("No character found for", player.Name)
		return 
	end
	
	local humanoid = char:FindFirstChild("Humanoid")
	if not humanoid then 
		warn("No humanoid found for", player.Name)
		return 
	end
	
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then 
		warn("No animator found for", player.Name)
		return 
	end
	
	stopCurrentAnimation(player.UserId)
	
	local animId = ANIM_IDS[position] or ANIM_IDS.Back
	
	local sleepAnimation = Instance.new("Animation")
	sleepAnimation.AnimationId = animId
	
	local animTrack = animator:LoadAnimation(sleepAnimation)
	
	activeAnimTracks[player.UserId] = animTrack
	animTrack:Play()
	
	animTrack.Stopped:Connect(function()
		if activeAnimTracks[player.UserId] == animTrack then
			activeAnimTracks[player.UserId] = nil
		end
	end)
end

function SleepAnimationService.updateAnimation(player)
	if not player or not player:IsA("Player") then
		warn("Invalid player passed to updateAnimation")
		return
	end
	
	local isSleeping = player:GetAttribute("Sleeping")
	
	if not isSleeping then
		stopCurrentAnimation(player.UserId)
		return
	end
	
	local char = player.Character
	if not char then 
		warn("No character found for", player.Name)
		return 
	end
	
	local sleepingPosition = char:GetAttribute("SleepingSide") or "Back"
	
	if not ANIM_IDS[sleepingPosition] then
		warn("Invalid sleeping position:", sleepingPosition, "- defaulting to Back")
		sleepingPosition = "Back"
	end
	
	local currentTrack = activeAnimTracks[player.UserId]
	if currentTrack and currentTrack.IsPlaying then
		local currentAnimId = currentTrack.Animation.AnimationId
		if currentAnimId == ANIM_IDS[sleepingPosition] then
			return
		end
	end
	
	loadAndPlayAnimation(player, sleepingPosition)
end

function SleepAnimationService.stopAnimation(player)
	if not player or not player:IsA("Player") then
		warn("Invalid player passed to stopAnimation")
		return
	end
	
	stopCurrentAnimation(player.UserId)
end

function SleepAnimationService.cleanup(player)
	if not player or not player:IsA("Player") then
		return
	end
	
	stopCurrentAnimation(player.UserId)
end

--- // MAIN

Players.PlayerRemoving:Connect(function(player)
	SleepAnimationService.cleanup(player)
end)

return SleepAnimationService