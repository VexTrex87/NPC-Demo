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
        },
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
        FireWind: {
            ExplosionTweenInfo: TweenInfo,
            FadeTweenInfo: TweenInfo,
            DespawnDelay: number,
            Size: number,
            Chance: number,
            Cooldown: number,
            RequiredDistance: number,
        },
        Fire: {
            Duration: number,
            Delay: number,
            Despawndelay: number,
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
            Chance = 10,
            MaxHeight = Vector3.new(0, 50, 0),
            MaxForce = Vector3.new(0, 100000, 0),
            FlyDuration = 5,
        },
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
        FireWind = {
            Chance = 1,
            ExplosionTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
            FadeTweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.In),
            DespawnDelay = 1,
            Size = 50,
            Cooldown = 5,
            RequiredDistance = 20,
        },
        Fire = {
            Damage = 5,
            Delay = 1.5,
            DespawnDelay = 5,
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
    local humanoidRootPart: MeshPart = NPC.HumanoidRootPart

    local self: SELF_TYPE = setmetatable({
        Character = NPC,
        Humanoid = humanoid,
        HumanoidRootPart = humanoidRootPart,
        Animations = {
            Walking = humanoid.Animator:LoadAnimation(npcObjects.Animations.Walk),
            Flying = humanoid.Animator:LoadAnimation(npcObjects.Animations.Fly)
        },
        Sounds = {
            Footsteps = humanoidRootPart.Footsteps,
            Thrust = humanoidRootPart.Thrust,
            Explosion = humanoidRootPart.Explosion,
        },
        Temporary = {
            FlyCooldown = os.time(),
            FireWindCooldown = os.time(),
            States = {
                Flying = false,
            }
        },
    }, module)

    self.Animations.Walking:GetMarkerReachedSignal("FootHitGound"):Connect(function(value: String): nil
        self.Sounds.Footsteps:Play()
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
        math.random(CONFIGURATION.Abilities.LavaPool.MinStartSize.X, CONFIGURATION.Abilities.LavaPool.MaxStartSize.X),
        CONFIGURATION.Abilities.LavaPool.MinStartSize.Y,
        math.random(CONFIGURATION.Abilities.LavaPool.MinStartSize.Z, CONFIGURATION.Abilities.LavaPool.MaxStartSize.Z)
    )
    newLavaPool.Position = hitPosition + CONFIGURATION.Abilities.LavaPool.HitOffset
    newLavaPool.Rotation = Vector3.new(0, math.random(0, 90), 0)
    newLavaPool.Fire.Rate = CONFIGURATION.Abilities.LavaPool.MinParticleRate
    newLavaPool.Parent = debrisStorage.Trash

    newLavaPool.Touched:Connect(function(object: BasePart): nil
        local character: Model = getCharacterFromBodyPart(object)
        if character and Players:GetPlayerFromCharacter(character) then
            self:setCharacterOnFire(character)
        end
    end)

    newTween(newLavaPool.Fire, CONFIGURATION.Abilities.LavaPool.ShrinkTweenInfo, {Rate = CONFIGURATION.Abilities.LavaPool.MinParticleRate})
    newTween(newLavaPool, CONFIGURATION.Abilities.LavaPool.ShrinkTweenInfo, {Size = CONFIGURATION.Abilities.LavaPool.EndSize}).Completed:Wait()
    newLavaPool:Destroy()
end

function module:setCharacterOnFire(character: Model): nil
    local humanoidRootPart: MeshPart = character.HumanoidRootPart
    if not humanoidRootPart:FindFirstChild("Fire") then
        local newFire = npcObjects.Effects.LavaPool.Fire:Clone()
        newFire.Parent = humanoidRootPart
        Debris:AddItem(newFire, CONFIGURATION.Abilities.Fire.DespawnDelay)

        newFire.Sound:Play()

        while newFire.Parent ~= nil do
            character.Humanoid:TakeDamage(CONFIGURATION.Abilities.Fire.Damage)
            wait(CONFIGURATION.Abilities.Fire.Delay)
        end
    end
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
    elseif
        os.time() - self.Temporary.FireWindCooldown >= CONFIGURATION.Abilities.FireWind.Cooldown and
        getMagnitude(self.HumanoidRootPart, target) <= CONFIGURATION.Abilities.FireWind.RequiredDistance and
        math.random(CONFIGURATION.Abilities.FireWind.Chance) == 1 
    then
        self:createFireWind()
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

    self.Sounds.Thrust:Play()
    self.Character.LeftFoot.Thrust.Enabled = true
    self.Character.RightFoot.Thrust.Enabled = true

    wait(CONFIGURATION.Abilities.Fly.FlyDuration)

    bodyPosition.MaxForce = Vector3.new(0, 0, 0)
    self.Character.LeftFoot.Thrust.Enabled = false
    self.Character.RightFoot.Thrust.Enabled = false
    self.Sounds.Thrust:Stop()

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

    local origin: Vector3 = hitPosition + CONFIGURATION.Abilities.Shockwave.HitOffset

    local newShockwave = npcObjects.Effects.Shockwave:Clone()
    newShockwave.Size = CONFIGURATION.Abilities.Shockwave.StartSize
    newShockwave.Position = origin
    newShockwave.Rotation = Vector3.new(0, math.random(0, 90), 0)
    newShockwave.Parent = debrisStorage.Trash
    newTween(newShockwave, CONFIGURATION.Abilities.Shockwave.SizeTweenInfo, {Size = CONFIGURATION.Abilities.Shockwave.EndSize})
        
    local explosionEffect: Explosion = Instance.new("Explosion")
    explosionEffect.BlastPressure = CONFIGURATION.Abilities.Shockwave.BlastPressure
    explosionEffect.DestroyJointRadiusPercent = CONFIGURATION.Abilities.Shockwave.DestroyJointRadiusPercent
    explosionEffect.BlastRadius = CONFIGURATION.Abilities.Shockwave.BlastRadius
    explosionEffect.ExplosionType = CONFIGURATION.Abilities.Shockwave.ExplosionType
    explosionEffect.Position = origin
    explosionEffect.Visible = false
    explosionEffect.Parent = debrisStorage.Trash

    self.Sounds.Explosion:Play()

    for _: nil, player: Players in pairs(Players:GetPlayers()) do
        local character = player.Character
        if character then
            local humanoidRootPart: MeshPart = character:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart and getMagnitude(self.HumanoidRootPart, humanoidRootPart) <= CONFIGURATION.Abilities.Shockwave.ShakeDistance then
                cameraShakerRemote:FireClient(player, "Explosion")
            end
        end
    end

    wait(CONFIGURATION.Abilities.Shockwave.SizeTweenInfo.Time - 0.3)
    newTween(newShockwave, CONFIGURATION.Abilities.Shockwave.FadeTweenInfo, {Transparency = 1}).Completed:Wait()
    newShockwave:Destroy()
end

function module:createFireWind(): nil
    local fireWindEffect: Model = npcObjects.Effects.FireWind:Clone()
    fireWindEffect.PrimaryPart.Position = self.HumanoidRootPart.Position
    fireWindEffect.Parent = debrisStorage.Trash

    Debris:AddItem(fireWindEffect, CONFIGURATION.Abilities.FireWind.DespawnDelay)

    local primaryPart: BasePart = fireWindEffect.PrimaryPart
    local primaryPartCFrame: CFrame = primaryPart.CFrame
    local explosionTweenInfo: TweenInfo = CONFIGURATION.Abilities.FireWind.ExplosionTweenInfo
    local fadeTweenInfo: TweenInfo = CONFIGURATION.Abilities.FireWind.FadeTweenInfo
    local fireWindSize: number = CONFIGURATION.Abilities.FireWind.Size
    local charactersHit: {Model} = {}

    for _: nil, basePart: BasePart in pairs(fireWindEffect:GetChildren()) do
        if basePart:IsA("BasePart") then
            newTween(basePart, explosionTweenInfo, {Size = basePart.Size * Vector3.new(fireWindSize, 0, fireWindSize)})	
            newTween(basePart, fadeTweenInfo, {Size = basePart.Size * Vector3.new(fireWindSize, 0, fireWindSize)})	

            if basePart ~= primaryPart then					
                local positionGoal = primaryPartCFrame.Position + (basePart.Position - primaryPartCFrame.Position) * Vector3.new(fireWindSize, 0, fireWindSize)
                newTween(basePart, CONFIGURATION.Abilities.FireWind.ExplosionTweenInfo, {Position = positionGoal})				
            end	
            
            basePart.Touched:Connect(function(object: any)
                local character = getCharacterFromBodyPart(object)
                if character and not table.find(charactersHit, character) then
                    table.insert(charactersHit, character)
                    self:setCharacterOnFire(character)
                end
            end)
        end
    end

    self.Temporary.FireWindCooldown = os.time()
end

return module