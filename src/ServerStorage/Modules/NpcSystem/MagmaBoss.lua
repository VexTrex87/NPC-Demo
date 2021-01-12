local module = {}
module.__index = module

type CONFIGURATION = {
    Shockwave: {
        StartSize: Vector3,
        EndSize: Vector3,
        HitOffset: Vector3,
        SizeTweenInfo: TweenInfo,
        FadeTweenInfo: TweenInfo,
    },
    LavaPool: {
        MinStartSize: Vector3,
        MaxStartSize: Vector3,
        MinParticleRate: Number,
        MaxParticleRate: Number,
        EndSize: Vector3,
        HitOffset: Vector3,
        ShrinkTweenInfo: TweenInfo,
    },
}

local CONFIGURATION: CONFIGURATION = {
    Shockwave = {
        StartSize = Vector3.new(0, 0, 0),
        EndSize = Vector3.new(10, 0.5, 10),
        HitOffset = Vector3.new(0, 0.5, 0),
        SizeTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
        FadeTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
    },
    LavaPool = {
        MinStartSize = Vector3.new(8, 0.5, 8),
        MaxStartSize = Vector3.new(15, 0.5, 15),
        MinParticleRate = 3,
        MaxParticleRate = 10,
        EndSize = Vector3.new(0, 0.5, 0),
        HitOffset = Vector3.new(0, 0.3, 0),
        ShrinkTweenInfo = TweenInfo.new(15, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
    }
}

local Workspace: Workspace = game:GetService("Workspace")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

local core: Folder = ServerStorage.Modules.Core
local newTween: Function = require(core.NewTween)
local newThread: Function = require(core.NewThread)

local debrisStorage: Folder = Workspace.Debris
local npcObjects: Folder = ServerStorage.Objects.NpcSystem.MagmaBoss

local function findFloor(origin: BasePart): Vector3
    local direction: Vector3 = Vector3.new(0, -100, 0) 
    
	local raycastParameters: RaycastParams = RaycastParams.new()
	raycastParameters.FilterDescendantsInstances = {origin.Parent}
    raycastParameters.FilterType = Enum.RaycastFilterType.Blacklist
    
	local hit = Workspace:Raycast(origin.Position, direction, raycastParameters)
	if hit then
		local hitPart: BasePart = hit.Instance
		if hitPart:IsDescendantOf(Workspace.Map) then
			return hit.Position
		end
	end
end	

local function createShockwave(hitPosition: Position): nil
    local newShockwave = npcObjects.Effects.Shockwave:Clone()
    newShockwave.Size = CONFIGURATION.Shockwave.StartSize
    newShockwave.Position = hitPosition + CONFIGURATION.Shockwave.HitOffset
    newShockwave.Rotation = Vector3.new(0, math.random(0, 90), 0)
    newShockwave.Parent = debrisStorage.Trash
    
    newTween(newShockwave, CONFIGURATION.Shockwave.SizeTweenInfo, {Size = CONFIGURATION.Shockwave.EndSize})
    wait(CONFIGURATION.Shockwave.SizeTweenInfo.Time - 0.3)
    newTween(newShockwave, CONFIGURATION.Shockwave.FadeTweenInfo, {Transparency = 1}).Completed:Wait()
    newShockwave:Destroy()
end

local function createLavaPool(hitPosition: Position): nil
    local newLavaPool = npcObjects.Effects.LavaPool:Clone()
    newLavaPool.Size = Vector3.new(
        math.random(CONFIGURATION.LavaPool.MinStartSize.X, CONFIGURATION.LavaPool.MaxStartSize.X),
        CONFIGURATION.LavaPool.MinStartSize.Y,
        math.random(CONFIGURATION.LavaPool.MinStartSize.Z, CONFIGURATION.LavaPool.MaxStartSize.Z)
    )
    newLavaPool.Position = hitPosition + CONFIGURATION.LavaPool.HitOffset
    newLavaPool.Rotation = Vector3.new(0, math.random(0, 90), 0)
    newLavaPool.FireCore.Rate = CONFIGURATION.LavaPool.MinParticleRate
    newLavaPool.Parent = debrisStorage.Trash
    
    newTween(newLavaPool.FireCore, CONFIGURATION.LavaPool.ShrinkTweenInfo, {Rate = CONFIGURATION.LavaPool.MinParticleRate})
    newTween(newLavaPool, CONFIGURATION.LavaPool.ShrinkTweenInfo, {Size = CONFIGURATION.LavaPool.EndSize}).Completed:Wait()
    newLavaPool:Destroy()
end

function module.new(NPC: Model): nil
    local humanoid: Humanoid = NPC.Humanoid

    local self = setmetatable({
        Character = NPC,
        Humanoid = humanoid,
        Animations = {
            Walking = humanoid.Animator:LoadAnimation(npcObjects.Animations.Walk)
        }
    }, module)

    self.Animations.Walking:GetMarkerReachedSignal("FootHitGound"):Connect(function(value: String): nil
        self:showFootstepEffects(value == "LeftFoot" and self.Character.LeftFoot or self.Character.RightFoot)
    end)

    self.Humanoid.Running:Connect(function(speed: Number)
        self:startRunningAnimation(speed)
    end)
end

function module:startRunningAnimation(speed: Number): nil
    if speed > 0 then
        self.Animations.Walking:Play(0.1, 1, 0.5)
    else
        self.Animations.Walking:Stop()
    end
end

function module:showFootstepEffects(bodypart: MeshPart): nil
    local hitPosition: Vector3 = findFloor(bodypart)
    if hitPosition then	
        newThread(createShockwave, hitPosition)
        newThread(createLavaPool, hitPosition)
    end
end

return module