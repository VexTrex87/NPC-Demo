local NPC_TAG: String = "NPC"

local ServerStorage: ServerStorage = game:GetService("ServerStorage")
local CollectionService: CollectionService = game:GetService("CollectionService")

local collection: Function = require(ServerStorage.Modules.Core.Collection)
local module = {}

function module.start(): nil
    collection(NPC_TAG, function(NPC: Model): nil
        for _: nil, tag: String in pairs(CollectionService:GetTags(NPC)) do
            local possibleModule: ModuleScript = script:FindFirstChild(tag)
            if possibleModule then
                require(possibleModule).new(NPC)
                break
            end
        end
    end)
end

return module