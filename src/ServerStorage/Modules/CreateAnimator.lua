local Players: Players = game:GetService("Players")

return function(): nil
    Players.PlayerAdded:Connect(function(player: Player): nil
        player.CharacterAdded:Connect(function(character: Model): nil
            local newAnimator: Animator = Instance.new("Animator")
            newAnimator.Parent = character.Humanoid
        end)
    end)
end