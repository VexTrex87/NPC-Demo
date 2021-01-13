local Workspace: Workspace = game:GetService("Workspace")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraShaker: any = require(ReplicatedStorage.Modules.CameraShaker)

local camera: Camera = Workspace.CurrentCamera
local cameraShakerRemote: RemoteEvent = ReplicatedStorage.Remotes.CameraShaker

cameraShakerRemote.OnClientEvent:Connect(function(explosionPresent: string)
    local cameraShake: any = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame: CFrame): nil
        camera.CFrame = camera.CFrame * shakeCFrame
    end)

    cameraShake:Start()
    cameraShake:Shake(CameraShaker.Presets[explosionPresent])
end)