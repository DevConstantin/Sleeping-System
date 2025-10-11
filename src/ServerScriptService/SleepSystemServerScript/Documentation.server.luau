--[[
                    ROBLOX SLEEPING SYSTEM v2.0
                   Quick Reference Documentation
                        Written by: avzu_re

OVERVIEW:
Sleeping system with animated blankets, position changes, 
snoring sounds, particle effects, and color customization.

FEATURES:
- Dynamic blanket positioning using vector math for different character sizes
- Multiple sleeping positions (Back, Left, Right)
- Customizable blanket colors with color picker UI
- Proximity-based snoring sounds and ZZZ particle effects
- Smooth UI transitions with position-based animations
- Client-side blanket rendering for performance

═══════════════════════════════════════════════════════════════════════

REQUIRED STRUCTURE:

ReplicatedStorage/
├── RSModules/
│   └── DebugService                [ModuleScript - Debug visualization helper]
├── RemoteEvents/                   [Folder]
│   └── UpdateBlanketColor          [RemoteEvent - Syncs blanket color to server]
├── Configurations/                 [Folder]
│   └── SleepingConfig              [Configuration object with attributes]
└── CharacterDataTemplate           [Folder - Template for player data]
    └── blanket_Color               [Color3Value - Stores blanket color]

Workspace/
├── Blanket                         [MeshPart - Template for blankets]
└── Sleep_System_Blankets           [Folder - Contains active blankets]

ServerScriptService/
└── SleepSystemServerScript/        [Script]
    ├── init.server.luau            [Main server logic]
    └── Documentation.server.luau   [This file]

StarterGui/
└── SleepUI/                        [ScreenGui]
    ├── SleepScriptClient/          [LocalScript - Main client logic]
    │   ├── SleepBlanketService     [ModuleScript - Blanket management]
    │   └── SleepAnimationService   [ModuleScript - Animation handling]
    ├── SleepSystemUI               [LocalScript - UI management]
    ├── TweenFrame                  [Frame - Main UI container]
    ├── OpenButton                  [ImageButton - Reopens UI]
    ├── WheelColor                  [Color3Value - Color picker output]
    ├── SleepFX                     [ParticleEmitter - ZZZ effect template]
    └── SnoringSounds               [Folder - Sound instances]

SoundService/
└── UI_Sounds/                      [Folder]
    ├── RBLX UI Hover 02 (SFX)      [Sound - Click sound]
    ├── RBLX UI Hover 03 (SFX)      [Sound - Hover sound]
    └── RBLX UI Back (SFX)          [Sound - Confirm sound]

═══════════════════════════════════════════════════════════════════════
ANIMATION IDS (in SleepAnimationService.luau):

Replace these with your own animation IDs:
- Back:  rbxassetid://131934871886139
- Left:  rbxassetid://72820421782942
- Right: rbxassetid://133771894405396

═══════════════════════════════════════════════════════════════════════

PLAYER DATA STRUCTURE:

Player Attributes:
- Sleeping: boolean                 [Current sleep state]

Character Attributes:
- SleepingSide: string              [Current position: "Back", "Left", "Right"]

Player Objects (Auto-created on join):
└── CharacterData/                  [Folder in Player]
    └── blanket_Color               [Color3Value - Persistent color data]

Workspace Objects (Auto-created per sleeping player):
└── Sleep_System_Blankets/
    └── Blanket_[UserId]            [MeshPart - Individual blanket instance]

═══════════════════════════════════════════════════════════════════════

TECHNICAL NOTES:

- Blankets are rendered CLIENT-SIDE in Sleep_System_Blankets folder
- Vector math accounts for R15 character extents and proportions
- Animation tracks are managed per-client for smooth transitions
- Color data persists in CharacterData folder (can be hooked to DataStore)
- SleepingSide attribute stored on CHARACTER, not player
- Debug visualization available through DebugService module

═══════════════════════════════════════════════════════════════════════

Version: 2.0
--]]
