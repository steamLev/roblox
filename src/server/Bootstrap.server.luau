--!strict
--[[ Точка входа сервера: строим купола с луга (GlassDomeFacility), НЕ TestIqRoom. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GlassDomeFacility = require(script.Parent.Map.GlassDomeFacility)
local DoorService = require(script.Parent.Map.DoorService)
local StageConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("StageConfig"))
local MimicService = require(script.Parent.Map.MimicService)
local AnswerCubeService = require(script.Parent.Map.AnswerCubeService)

print("[99rooms] Bootstrap → GlassDomeFacility (meadow domes)")

local RunSession = require(script.Parent.Run.RunSession)

local roomModel = GlassDomeFacility.build()
roomModel:SetAttribute("MapBuildId", "meadow_v5")
DoorService.bindFacility(roomModel)

AnswerCubeService.setSubmitHandler(function(plr: Player, choiceIndex: number)
	RunSession.submitFromCube(plr, choiceIndex)
end)
AnswerCubeService.bindFacility(roomModel)

local function cell1SpawnCFrame(): CFrame?
	local cell1 = roomModel:FindFirstChild("Cell_1")
	local sp = cell1 and cell1:FindFirstChild("Spawn_Cell1")
	if sp and sp:IsA("SpawnLocation") then
		return sp.CFrame + Vector3.new(0, 3.5, 0)
	end
	return nil
end

local function disableForeignSpawns()
	for _, desc in Workspace:GetDescendants() do
		if desc:IsA("SpawnLocation") and not desc:IsDescendantOf(roomModel) then
			desc.Enabled = false
		end
	end
	local cell1 = roomModel:FindFirstChild("Cell_1")
	local mainSpawn = cell1 and cell1:FindFirstChild("Spawn_Cell1")
	if mainSpawn and mainSpawn:IsA("SpawnLocation") then
		mainSpawn.Enabled = true
	end
end

local initialSpawnDone: { [Player]: boolean } = {}

local function snapToFirstCell(player: Player)
	if initialSpawnDone[player] then
		return
	end
	local cf = cell1SpawnCFrame()
	if not cf then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = cf
		initialSpawnDone[player] = true
	end
end

local function bindFirstCellSpawn(player: Player)
	local function onCharacter(char: Model)
		task.defer(function()
			task.wait(0.05)
			if player.Parent and char.Parent then
				snapToFirstCell(player)
			end
		end)
	end
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

Players.PlayerRemoving:Connect(function(player)
	initialSpawnDone[player] = nil
end)

for _, plr in Players:GetPlayers() do
	bindFirstCellSpawn(plr)
end
Players.PlayerAdded:Connect(bindFirstCellSpawn)

MimicService.spawnDefaults()
disableForeignSpawns()

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetRunState = Remotes:WaitForChild("GetRunState") :: RemoteFunction
local SubmitAnswer = Remotes:WaitForChild("SubmitAnswer") :: RemoteFunction

for _, plr in Players:GetPlayers() do
	RunSession.onPlayerJoin(plr)
end
Players.PlayerAdded:Connect(RunSession.onPlayerJoin)

RunService.Heartbeat:Connect(function(dt)
	RunSession.tickEncounters(dt)
end)

GetRunState.OnServerInvoke = function(player: Player, fromWall: any?, domeStage: any?)
	local ds: number? = nil
	if typeof(domeStage) == "number" then
		ds = math.floor((domeStage :: number) + 0.5)
	end
	return RunSession.getState(player, fromWall == true, ds)
end

SubmitAnswer.OnServerInvoke = function(player: Player, payload: any)
	local bad = {
		ok = false,
		message = "Неверный запрос",
		stage = 1,
		maxStages = StageConfig.STAGE_COUNT,
		completed = false,
		prompt = nil,
		problemToken = nil,
		roomLabel = "",
		choices = nil,
		attemptsLeft = nil,
		domePhase = nil,
		glassIntegrity = nil,
		zeroGActive = false,
		subliminalFlash = false,
	}
	if typeof(payload) ~= "table" then
		return bad
	end
	local token = payload.problemToken
	if typeof(token) ~= "string" then
		return bad
	end
	local rawCi = (payload :: any).choiceIndex
	local ciNum = if typeof(rawCi) == "number" then rawCi elseif typeof(rawCi) == "string" then tonumber(rawCi) else nil
	if ciNum ~= nil then
		local ci = math.floor(ciNum + 0.5)
		if ci >= 0 and ci <= 3 then
			return RunSession.submit(player, {
				problemToken = token,
				choiceIndex = ci,
			})
		end
	end
	if typeof(payload.answer) == "string" then
		return RunSession.submit(player, {
			problemToken = token,
			answer = payload.answer,
		})
	end
	return bad
end
