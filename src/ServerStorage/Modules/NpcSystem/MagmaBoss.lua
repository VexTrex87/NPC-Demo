local module = {}
module.__index = module

type CONFIGURATION_TYPE = {
    NPC: {
        UpdateDelay: number,
        JumpDelay: number,
        DetectionDistance: number,
        TimeoutDistance: number,
        DirectLineOfSightDistance: number,
        PovY: number,
        AgentParameters: {
            AgentRadius: number,
            AgentHeight: number,
            AgentCanJump: boolean,
        }
    },
    Abilities: {
        Fly: {
            Cooldown: number,
            RequiredDistance: number,
            Chance: number,
            MaxHeight: Vector3,
            MaxForce: Vector3,
            FlyDuration: number,
            FlyDelay: number,
        },
    },
    Effects: {
        Shockwave: {
            StartSize: Vector3,
            EndSize: Vector3,
            HitOffset: Vector3,
            SizeTweenInfo: TweenInfo,
            FadeTweenInfo: TweenInfo,
            ShakeDistance: number,
            BlastPressure: number,
            DestroyJointRadiusPercent: number,
            BlastRadius: number,
            ExplosionType: Enum.ExplosionType,        
        },
        LavaPool: {
            MinStartSize: Vector3,
            MaxStartSize: Vector3,
            MinParticleRate: number,
            MaxParticleRate: number,
            EndSize: Vector3,
            HitOffset: Vector3,
            ShrinkTweenInfo: TweenInfo,
            FireDamage: number,
            FireDamageDelay: number,
        },
    },
}

type SELF_TYPE = {
    Character: Model,
    Humanoid: MeshPart,
    HumanoidRootPart: MeshPart,
    Animations: {
        [string]: AnimationTrack,
    },
    Temporary: {
        [string]: any,
    },
}

local CONFIGURATION: CONFIGURATION_TYPE = {
    NPC = {
        UpdateDelay = 0.5,
        JumpDelay = 1,
        DetectionDistance = 50,
        TimeoutDistance = 10,
        DirectLineOfSightDistance = 100,
        PovY = 5,
        AgentParameters = {
            AgentRadius = 8,
            AgentHeight = 10,
            AgentCanJump = true,
        }
    },
    Abilities = {
        Fly = {
            Cooldown = 10,
            RequiredDistance = 30,
            Chance = 1,
            MaxHeight = Vector3.new(0, 50, 0),
            MaxForce = Vector3.new(0, 100000, 0),
            FlyDuration = 6,
            FlyDelay = 1.5,
        },
    },
    Effects = {
        Shockwave = {
            StartSize = Vector3.new(0, 0, 0),
            EndSize = Vector3.new(100, 0.5, 100),
            HitOffset = Vector3.new(0, 0.5, 0),
            SizeTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
            FadeTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
            ShakeDistance = 100,
            BlastPressure = 500000,
            DestroyJointRadiusPercent = 0,
            BlastRadius = 100,
            ExplosionType = Enum.ExplosionType.NoCraters,
        },
        LavaPool = {
            MinStartSize = Vector3.new(8, 0.5, 8),
            MaxStartSize = Vector3.new(15, 0.5, 15),
            MinParticleRate = 3,
            MaxParticleRate = 10,
            EndSize = Vector3.new(0, 0.5, 0),
            HitOffset = Vector3.new(0, 0.3, 0),
            ShrinkTweenInfo = TweenInfo.new(15, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
            FireDamage = 5,
            FireDamageDelay = 1,
        },
    },
}

local Workspace: Workspace = game:GetService("Workspace")
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")
local PathfindingService: PathfindingService = game:GetService("PathfindingService")
local Debris: Debris = game:GetService("Debris")

local core: Folder = ServerStorage.Modules.Core
local newTween: Function = require(core.NewTween)
local newThread: Function = require(core.NewThread)
local getMagnitude: Function = require(core.GetMagnitude)
local getCharacterFromBodyPart: Function = require(core.GetCharacterFromBodyPart)

local camera: Camera = Workspace.Camera
local debrisStorage: Folder = Workspace.Debris
local npcObjects: Folder = ServerStorage.Objects.NpcSystem.MagmaBoss
local cameraShakerRemote: RemoteEvent = ReplicatedStorage.Remotes.CameraShaker

local function findFloor(origin: BasePart): Vector3
    local direction: Vector3 = Vector3.new(0, -100, 0) 
    
	local raycastParameters: RaycastParams = RaycastParams.new()
	raycastParameters.FilterDescendantsInstances = {debrisStorage}
    raycastParameters.FilterType = Enum.RaycastFilterType.Blacklist
    
	local hit = Workspace:Raycast(origin.Position, direction, raycastParameters)
	if hit then
		local hitPart: BasePart = hit.Instance
		if hitPart:IsDescendantOf(Workspace.Map) then
			return hit.Position
		end
	end
end	

function module.new(NPC: Model): nil
    local humanoid: Humanoid = NPC.Humanoid

    local self: SELF_TYPE = setmetatable({
        Character = NPC,
        Humanoid = humanoid,
        HumanoidRootPart = NPC.HumanoidRootPart,
        Animations = {
            Walking = humanoid.Animator:LoadAnimation(npcObjects.Animations.Walk),
            Flying = humanoid.Animator:LoadAnimation(npcObjects.Animations.Fly)
        },
        Temporary = {
            FlyCooldown = os.time(),
            States = {
                Flying = false,
            }
        },
    }, module)

    self.Animations.Walking:GetMarkerReachedSignal("FootHitGound"):Connect(function(value: String): nil
        local bodyPart: MeshPart = value == "LeftFoot" and self.Character.LeftFoot or self.Character.RightFoot
        self:createLavaPool(findFloor(bodyPart))
    end)

    self.Humanoid.Running:Connect(function(speed: Number)
        self:startRunningAnimation(speed)
    end)

    while true do
        local target = self:findTarget()
        if target then
            self:followTarget(target)
        end
        wait(CONFIGURATION.NPC)
    end
end

function module:startRunningAnimation(speed: Number): nil
    if speed > 0 and not self.Temporary.States.Flying then
        self.Animations.Walking:Play(0.1, 1, 0.5)
    else
        self.Animations.Walking:Stop()
    end
end

function module:createLavaPool(hitPosition: Vector3): nil
    if not hitPosition then
        return
    end

    local newLavaPool = npcObjects.Effects.LavaPool:Clone()
    newLavaPool.Size = Vector3.new(
        math.random(CONFIGURATION.Effects.LavaPool.MinStartSize.X, CONFIGURATION.Effects.LavaPool.MaxStartSize.X),
        CONFIGURATION.Effects.LavaPool.MinStartSize.Y,
        math.random(CONFIGURATION.Effects.LavaPool.MinStartSize.Z, CONFIGURATION.Effects.LavaPool.MaxStartSize.Z)
    )
    newLavaPool.Position = hitPosition + CONFIGURATION.Effects.LavaPool.HitOffset
    newLavaPool.Rotation = Vector3.new(0, math.random(0, 90), 0)
    newLavaPool.Fire.Rate = CONFIGURATION.Effects.LavaPool.MinParticleRate
    newLavaPool.Parent = debrisStorage.Trash
    
    newLavaPool.Touched:Connect(function(object: BasePart): nil
        local character: Model = getCharacterFromBodyPart(object)
        if character and Players:GetPlayerFromCharacter(character) then
            local humanoidRootPart: MeshPart = character.HumanoidRootPart
            if not humanoidRootPart:FindFirstChild("Fire") then
                local newFire = npcObjects.Effects.LavaPool.Fire:Clone()
                newFire.Parent = humanoidRootPart
                Debris:AddItem(newFire, CONFIGURATION.NPC.FireDuration)

                while newFire.Parent ~= nil do
                    character.Humanoid:TakeDamage(CONFIGURATION.Effects.LavaPool.FireDamage)
                    wait(CONFIGURATION.Effects.LavaPool.FireDamageDelay)
                end
            end
        end
    end)

    newTween(newLavaPool.Fire, CONFIGURATION.Effects.LavaPool.ShrinkTweenInfo, {Rate = CONFIGURATION.Effects.LavaPool.MinParticleRate})
    newTween(newLavaPool, CONFIGURATION.Effects.LavaPool.ShrinkTweenInfo, {Size = CONFIGURATION.Effects.LavaPool.EndSize}).Completed:Wait()
    newLavaPool:Destroy()
end

function module:findTarget(): Model
    local farthestTargetDistance: Number = CONFIGURATION.NPC.DetectionDistance
    local farthestTarget: MeshPart

    for _: nil, player: Player in pairs(Players:GetPlayers()) do
        local character: Model = player.Character
        if character then
            local targetMagnitude: Number = getMagnitude(self.HumanoidRootPart, character.HumanoidRootPart)
            if targetMagnitude < farthestTargetDistance then
                farthestTarget = character.HumanoidRootPart
                farthestTargetDistance = targetMagnitude
            end
        end
    end

    return farthestTarget
end

function module:followTarget(target: MeshPart): nil
    if not self.Character or not target then
        return
    end

    local path: Instance = PathfindingService:CreatePath(CONFIGURATION.NPC.AgentParameters)
    path:ComputeAsync(self.HumanoidRootPart.Position, target.Position)
    local waypoints: {} = path:GetWaypoints()

    if path.Status == Enum.PathStatus.Success then
        for _: nil, point: PathWaypoint in pairs(waypoints) do
            if point.Action == Enum.PathWaypointAction.Jump then
                self.Humanoid.Jump = true
            end
    
            -- jump if target point is higher than the NPC
            newThread(function()
                wait(CONFIGURATION.NPC.JumpDelay)
                if self.Humanoid.WalkToPoint.Y > math.round(self.HumanoidRootPart.Position.Y) then
                    self.Humanoid.Jump = true
                end
            end)
    
            self.Humanoid:MoveTo(point.Position)
    
            local timeout: Boolean = self.Humanoid.MoveToFinished:Wait()
            if not timeout then
                self.Humanoid.Jump = true
                self:followTarget(target)
                return
            end

            if not target or getMagnitude(self.HumanoidRootPart, target) > CONFIGURATION.NPC.DetectionDistance then
                return
            elseif getMagnitude(target, waypoints[#waypoints]) > CONFIGURATION.NPC.TimeoutDistance then
                self:followTarget(target)
                return
            end

            self:attack(target)
        end
    else
        -- find another path
        self.Humanoid.Jump = true
        self:followTarget(target)
        return
    end
end

function module:attack(target: MeshPart): nil
    if 
        os.time() - self.Temporary.FlyCooldown >= CONFIGURATION.Abilities.Fly.Cooldown and
        getMagnitude(self.HumanoidRootPart, target) <= CONFIGURATION.Abilities.Fly.RequiredDistance and
        math.random(CONFIGURATION.Abilities.Fly.Chance) == 1 
    then
        self:fly()
    end
end

function module:fly(): nil
    self.Temporary.States.Flying = true
    self.Animations.Walking:Stop()
    wait(CONFIGURATION.Abilities.Fly.FlyDelay)
    self.Animations.Flying:Play()

    local bodyPosition: BodyPosition = self.HumanoidRootPart.BodyPosition
    bodyPosition.Position = self.HumanoidRootPart.Position + CONFIGURATION.Abilities.Fly.MaxHeight
    bodyPosition.MaxForce = CONFIGURATION.Abilities.Fly.MaxForce

    self.Character.LeftFoot.Thrust.Enabled = true
    self.Character.RightFoot.Thrust.Enabled = true

    wait(CONFIGURATION.Abilities.Fly.FlyDuration)

    bodyPosition.MaxForce = Vector3.new(0, 0, 0)
    self.Character.LeftFoot.Thrust.Enabled = false
    self.Character.RightFoot.Thrust.Enabled = false

    self.Humanoid:GetPropertyChangedSignal("FloorMaterial"):Wait()
    self.Animations.Flying:Stop()
    self:createShockwave(findFloor(self.HumanoidRootPart))
    wait(CONFIGURATION.Abilities.Fly.FlyDelay)
    self.Temporary.States.Flying = false
    self.Temporary.FlyCooldown = os.time()
end

function module:createShockwave(hitPosition: Vector3): nil
    if not hitPosition then
        return
    end

    local origin: Vector3 = hitPosition + CONFIGURATION.Effects.Shockwave.HitOffset

    local newShockwave = npcObjects.Effects.Shockwave:Clone()
    newShockwave.Size = CONFIGURATION.Effects.Shockwave.StartSize
    newShockwave.Position = origin
    newShockwave.Rotation = Vector3.new(0, math.random(0, 90), 0)
    newShockwave.Parent = debrisStorage.Trash
    newTween(newShockwave, CONFIGURATION.Effects.Shockwave.SizeTweenInfo, {Size = CONFIGURATION.Effects.Shockwave.EndSize})
        
    local explosionEffect: Explosion = Instance.new("Explosion")
    explosionEffect.BlastPressure = CONFIGURATION.Effects.Shockwave.BlastPressure
    explosionEffect.DestroyJointRadiusPercent = CONFIGURATION.Effects.Shockwave.DestroyJointRadiusPercent
    explosionEffect.BlastRadius = CONFIGURATION.Effects.Shockwave.BlastRadius
    explosionEffect.ExplosionType = CONFIGURATION.Effects.Shockwave.ExplosionType
    explosionEffect.Position = origin
    explosionEffect.Visible = false
    explosionEffect.Parent = debrisStorage.Trash

    for _: nil, player: Players in pairs(Players:GetPlayers()) do
        local character = player.Character
        if character then
            local humanoidRootPart: MeshPart = character:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart and getMagnitude(self.HumanoidRootPart, humanoidRootPart) <= CONFIGURATION.Effects.Shockwave.ShakeDistance then
                cameraShakerRemote:FireClient(player, "Explosion")
            end
        end
    end

    wait(CONFIGURATION.Effects.Shockwave.SizeTweenInfo.Time - 0.3)
    newTween(newShockwave, CONFIGURATION.Effects.Shockwave.FadeTweenInfo, {Transparency = 1}).Completed:Wait()
    newShockwave:Destroy()
end

return module