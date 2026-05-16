--!strict
--[[ Визуальные «дроны» вокруг активного купола (сервер, все видят). ]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DRONE_COUNT_DEFAULT = 8

local function droneCountForPlayer(player: Player, stage: number): number
	if stage ~= 1 then
		return DRONE_COUNT_DEFAULT
	end
	local beat = player:GetAttribute("DomeOpeningBeat")
	if typeof(beat) ~= "number" then
		return 2
	end
	local b = math.floor(beat + 0.5)
	if b <= 0 then
		return 2
	elseif b == 1 then
		return 3
	elseif b == 2 then
		return 5
	elseif b == 3 then
		return 8
	elseif b == 4 then
		return 10
	else
		return 6
	end
end

type Swarm = {
	folder: Folder,
	angle: number,
}

local swarms: { [Player]: Swarm } = {}

local function destroySwarm(player: Player)
	local s = swarms[player]
	if s then
		s.folder:Destroy()
		swarms[player] = nil
	end
end

local function anchorWorld(stage: number): CFrame?
	local root = Workspace:FindFirstChild("MatanTestIqRoom")
	if not root or not root:IsA("Model") then
		return nil
	end
	local cell = root:FindFirstChild("Cell_" .. tostring(stage))
	if not cell or not cell:IsA("Model") then
		return nil
	end
	local a = cell:FindFirstChild("DroneAnchor")
	if a and a:IsA("BasePart") then
		return a.CFrame
	end
	return cell:GetPivot()
end

local function ensureSwarm(player: Player, stage: number): Swarm?
	local existing = swarms[player]
	if existing and existing.folder.Parent then
		return existing
	end
	destroySwarm(player)

	local cf0 = anchorWorld(stage)
	if not cf0 then
		return nil
	end

	local folder = Instance.new("Folder")
	folder.Name = "DroneSwarm_" .. player.UserId
	folder.Parent = Workspace

	local count = droneCountForPlayer(player, stage)
	for i = 1, count do
		local p = Instance.new("Part")
		p.Name = "Drone_" .. i
		p.Size = Vector3.new(0.55, 0.35, 0.9)
		p.Color = Color3.fromRGB(200, 60, 55)
		p.Material = Enum.Material.Metal
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.Parent = folder
	end

	local swarm: Swarm = { folder = folder, angle = (player.UserId % 360) * 0.01 }
	swarms[player] = swarm
	return swarm
end

local DomeDroneService = {}

function DomeDroneService.sync(player: Player, active: boolean, stage: number)
	if not active then
		destroySwarm(player)
		return
	end
	local want = droneCountForPlayer(player, stage)
	local existing = swarms[player]
	if existing and existing.folder.Parent and #existing.folder:GetChildren() ~= want then
		destroySwarm(player)
	end
	local swarm = ensureSwarm(player, stage)
	if not swarm or not swarm.folder.Parent then
		return
	end
	local cf0 = anchorWorld(stage)
	if not cf0 then
		return
	end
	swarm.angle += 0.045
	local base = cf0.Position
	local r = 11 + math.sin(swarm.angle * 0.5) * 2
	local yWave = math.sin(swarm.angle * 1.3) * 1.2
	local idx = 0
	for _, ch in ipairs(swarm.folder:GetChildren()) do
		if ch:IsA("BasePart") then
			idx = idx + 1
			local n = math.max(1, #swarm.folder:GetChildren())
			local ang = swarm.angle + (idx / n) * math.pi * 2
			local offset = Vector3.new(math.cos(ang) * r, 4 + yWave + (idx % 3) * 0.4, math.sin(ang) * r)
			ch.CFrame = CFrame.new(base + offset) * CFrame.Angles(0, ang + 1.57, 0.1)
		end
	end
end

Players.PlayerRemoving:Connect(function(p)
	destroySwarm(p)
end)

return DomeDroneService
