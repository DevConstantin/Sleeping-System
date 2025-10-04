--[[
SleepSystemServerScript:
- Updates desired blanket color data
- Keeps track of sleeping side on characters
--]]

--- // SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--- // OBJECTS

-- Remote events (WHICH ARE OBJECTS)
local remoteEvents = ReplicatedStorage.RemoteEvents
local updateBlanketColorEvent = remoteEvents.UpdateBlanketColor
local setSleepingPositionEvent = remoteEvents.SetSleepingPosition

--- // CONFIG
local sleepConfig = ReplicatedStorage.Configurations.SleepingConfig
local DEFAULT_BLANKET_COLOR = sleepConfig:GetAttribute("DefaultBlanketColor")

-- Constants
local validSleepingPositions = {
    "Back",
    "Left",
    "Right"
}

--- // FUNCTIONS

local functio
)reyalp()ataDreyalPputes 
