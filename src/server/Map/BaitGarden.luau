--!strict
--[[ Зона восстановления после прохождения куполов (телепорт из RunSession). ]]

local Workspace = game:GetService("Workspace")

local GARDEN_NAME = "BaitGardenZone"
local SPAWN_POS = Vector3.new(0, 4, 180)

local BaitGarden = {}

function BaitGarden.ensure()
	local existing = Workspace:FindFirstChild(GARDEN_NAME)
	if existing then
		return
	end
	local zone = Instance.new("Part")
	zone.Name = GARDEN_NAME
	zone.Size = Vector3.new(48, 1, 48)
	zone.Anchored = true
	zone.CanCollide = true
	zone.Position = SPAWN_POS + Vector3.new(0, -0.5, 0)
	zone.Color = Color3.fromRGB(72, 140, 72)
	zone.Material = Enum.Material.Grass
	zone.Parent = Workspace

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BaitGardenSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(SPAWN_POS)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Enabled = false
	spawn.Parent = zone
end

function BaitGarden.getSpawnCFrame(): CFrame
	return CFrame.new(SPAWN_POS)
end

return BaitGarden
