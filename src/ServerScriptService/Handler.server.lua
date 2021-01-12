local ServerStorage: ServerStorage = game:GetService("ServerStorage")

local newThread: Function = require(ServerStorage.Modules.Core.NewThread)
local npcSystem: any = require(ServerStorage.Modules.NpcSystem)
local createAnimator: Function = require(ServerStorage.Modules.CreateAnimator)

newThread(createAnimator)
newThread(npcSystem.start)

-- temp code

workspace.Debris.NPC.MagmaBoss.Humanoid:MoveTo(Vector3.new(100, 0, 100))