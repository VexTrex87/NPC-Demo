local HEAL_RATE: Number = 1
local HEAL_DELAY: Number = 1

local Players: Players = game:GetService("Players")

return function(): nil
	Players.PlayerAdded:Connect(function(player: Player): nil
		player.CharacterAdded:Connect(function(character: Model): nil
			local regenerationScript: Script = character:FindFirstChild("Health")
			regenerationScript = regenerationScript and regenerationScript:Destroy()
		
			local humanoid: Humanoid = character.Humanoid
			while wait(HEAL_DELAY) do
				humanoid.Health = humanoid.Health + (humanoid.MaxHealth * HEAL_RATE / 100)
			end
		end)
	end)
end