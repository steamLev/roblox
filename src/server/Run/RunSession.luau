--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local function studioPrint(msg: string)
	if RunService:IsStudio() then
		print("[Matan][Run] " .. msg)
	end
end

local Math = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Math"))
local StageConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("StageConfig"))
local EncounterConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("EncounterConfig"))
local FirstDomeOpening = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("FirstDomeOpening"))
local Choices = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Math"):WaitForChild("Choices"))
local DoorService = require(script.Parent.Parent.Map.DoorService)
local GlassDomeFacility = require(script.Parent.Parent.Map.GlassDomeFacility)
local MimicService = require(script.Parent.Parent.Map.MimicService)
local DomeDroneService = require(script.Parent.Parent.Map.DomeDroneService)
local AnswerCubeService = require(script.Parent.Parent.Map.AnswerCubeService)

local Fraction = Math.Fraction
local ProblemGenerator = Math.ProblemGenerator
local AnswerChecker = Math.AnswerChecker

local MAX_ATTEMPTS = 3

export type PublicState = {
	stage: number,
	maxStages: number,
	completed: boolean,
	prompt: string?,
	problemToken: string?,
	roomLabel: string,
	choices: { string }?,
	attemptsLeft: number?,
	domePhase: string?,
	glassIntegrity: number?,
	zeroGActive: boolean?,
	subliminalFlash: boolean?,
}

export type SubmitPayload = {
	problemToken: string,
	answer: string?,
	choiceIndex: number?,
}

export type SubmitResult = PublicState & {
	ok: boolean,
	message: string?,
}

type DomePhase = "IDLE" | "CALM" | "ASSAULT" | "ZERO_G" | "TURRET"

type Session = {
	stage: number,
	rng: Random,
	problemToken: string?,
	problem: any?,
	choiceTexts: { string }?,
	correctChoiceIndex: number?,
	attemptsLeft: number?,
	taskLocked: boolean,
	domePhase: DomePhase,
	glassIntegrity: number,
	encounterStartedAt: number?,
	firstDomeOpeningStartedAt: number?,
	firstDomeOpeningComplete: boolean,
	lastZeroGAt: number,
	awaitingDoorAfterTurret: boolean,
	turretEndTime: number?,
	sentToBait: boolean,
	turretDomeStage: number?,
	openingForcedZeroGFired: boolean,
	floatPropsReleased: boolean,
}

local sessions: { [Player]: Session } = {}

local function defaultSession(rng: Random): Session
	return {
		stage = 1,
		rng = rng,
		problemToken = nil,
		problem = nil,
		choiceTexts = nil,
		correctChoiceIndex = nil,
		attemptsLeft = nil,
		taskLocked = true,
		domePhase = "IDLE",
		glassIntegrity = 100,
		encounterStartedAt = nil,
		firstDomeOpeningStartedAt = nil,
		firstDomeOpeningComplete = false,
		lastZeroGAt = -1e9,
		awaitingDoorAfterTurret = false,
		turretEndTime = nil,
		sentToBait = false,
		turretDomeStage = nil,
		openingForcedZeroGFired = false,
		floatPropsReleased = false,
	}
end

local function isFirstDomeOpeningActive(s: Session): boolean
	if s.stage ~= 1 or s.firstDomeOpeningComplete or s.firstDomeOpeningStartedAt == nil then
		return false
	end
	return tick() - (s.firstDomeOpeningStartedAt :: number) < FirstDomeOpening.WINDOW_SECONDS
end

local function getSession(player: Player): Session
	local s = sessions[player]
	if s then
		return s
	end
	local rng = Random.new((math.floor(tick() * 1000) + player.UserId * 7919) % 2 ^ 31)
	s = defaultSession(rng)
	sessions[player] = s
	return s
end

local function clearProblem(s: Session)
	s.problemToken = nil
	s.problem = nil
	s.choiceTexts = nil
	s.correctChoiceIndex = nil
	s.attemptsLeft = nil
	AnswerCubeService.sync(s.stage, false, nil)
end

local function refreshCubePrompts(s: Session)
	local active = s.problemToken ~= nil and not s.taskLocked
	AnswerCubeService.sync(s.stage, active, if active then s.choiceTexts else nil)
end

local function resetEncounter(s: Session)
	if isFirstDomeOpeningActive(s) then
		return
	end
	s.domePhase = "CALM"
	s.glassIntegrity = 100
	s.encounterStartedAt = tick()
	s.lastZeroGAt = -1e9
	s.openingForcedZeroGFired = false
	s.floatPropsReleased = false
end

local DOME_CELL_RADIUS = 22

local function physicalCellStage(player: Player): number?
	local root = Workspace:FindFirstChild("MatanTestIqRoom")
	if not root or not root:IsA("Model") then
		return nil
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return nil
	end
	local pos = hrp.Position
	local bestIdx: number? = nil
	local bestDist = math.huge
	for _, ch in root:GetChildren() do
		if ch:IsA("Model") then
			local n = string.match(ch.Name, "^Cell_(%d+)$")
			if n then
				local ox = ch:GetAttribute("DomeCenterX")
				if typeof(ox) == "number" then
					local dx = pos.X - (ox :: number)
					local dz = pos.Z
					local dist = math.sqrt(dx * dx + dz * dz)
					if dist < DOME_CELL_RADIUS and dist < bestDist then
						bestDist = dist
						bestIdx = tonumber(n)
					end
				end
			end
		end
	end
	return bestIdx
end

local function releaseOpeningFloatProps()
	local root = Workspace:FindFirstChild("MatanTestIqRoom")
	if not root or not root:IsA("Model") then
		return
	end
	local cell = root:FindFirstChild("Cell_1")
	if not cell then
		return
	end
	for _, ch in cell:GetChildren() do
		if ch:IsA("BasePart") and string.sub(ch.Name, 1, 10) == "FloatProp_" then
			ch.Anchored = false
		end
	end
end

local function syncBlackboard(stage: number, prompt: string, choices: { string }?)
	local root = Workspace:FindFirstChild("MatanTestIqRoom")
	if not root or not root:IsA("Model") then
		return
	end
	local cell = root:FindFirstChild("Cell_" .. tostring(stage))
	if not cell then
		return
	end
	local board = cell:FindFirstChild("MainBlackboard")
	if not board or not board:IsA("BasePart") then
		return
	end
	local sg = board:FindFirstChild("SignGui")
	if not sg or not sg:IsA("SurfaceGui") then
		return
	end
	local bg = sg:FindFirstChild("SignBg")
	if not bg or not bg:IsA("Frame") then
		return
	end
	for _, ch in bg:GetChildren() do
		if ch:IsA("TextLabel") or ch:IsA("TextButton") then
			ch:Destroy()
		end
	end
	local lines = { prompt }
	if choices then
		local row = {}
		for i, opt in ipairs(choices) do
			table.insert(row, string.char(64 + i) .. ") " .. opt)
		end
		if #row > 0 then
			table.insert(lines, table.concat(row, "   "))
		end
	end
	local textSize = 28
	local y = 8
	for _, line in ipairs(lines) do
		local tl = Instance.new("TextLabel")
		tl.BackgroundTransparency = 1
		tl.Size = UDim2.new(1, -16, 0, textSize + 12)
		tl.Position = UDim2.fromOffset(8, y)
		tl.Font = Enum.Font.GothamBold
		tl.TextSize = textSize
		tl.TextColor3 = Color3.fromRGB(245, 250, 240)
		tl.Text = line
		tl.TextWrapped = true
		tl.TextStrokeTransparency = 0.45
		tl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		tl.Parent = bg
		y += textSize + 14
	end
end

local function setTurretVisual(active: boolean, onlyStage: number?)
	local root = Workspace:FindFirstChild("MatanTestIqRoom")
	if not root or not root:IsA("Model") then
		return
	end
	for i = 1, StageConfig.STAGE_COUNT do
		local cell = root:FindFirstChild("Cell_" .. i)
		local turret = cell and cell:FindFirstChild("DomeTurret")
		if turret and turret:IsA("BasePart") then
			local light = turret:FindFirstChild("TurretLight")
			if light and light:IsA("SpotLight") then
				local on = active and onlyStage ~= nil and onlyStage == i
				light.Brightness = if on then 4.2 else 0
			end
		end
	end
end

local function pushDomeAttributes(player: Player, s: Session)
	local zeroG = s.domePhase == "ZERO_G"
	local mathActive = s.problemToken ~= nil and not s.taskLocked
	local openingActive = isFirstDomeOpeningActive(s)
	local showEncounter = openingActive or mathActive
	player:SetAttribute("DomePhase", s.domePhase)
	player:SetAttribute("DomeIntegrity", math.floor(s.glassIntegrity + 0.5))
	player:SetAttribute("DomeZeroG", if zeroG then 1 else 0)
	player:SetAttribute("DomeOpeningActive", openingActive)
	player:SetAttribute("DomeEncounterActive", showEncounter)
	player:SetAttribute("DomeCellStage", if showEncounter and s.stage <= StageConfig.STAGE_COUNT then s.stage else 0)
	local root = Workspace:FindFirstChild("MatanTestIqRoom")
	if root and root:IsA("Model") then
		root:SetAttribute("ActiveTaskStage", s.stage)
	end

	if openingActive and s.firstDomeOpeningStartedAt ~= nil then
		local e = tick() - (s.firstDomeOpeningStartedAt :: number)
		player:SetAttribute("DomeOpeningElapsed", e)
		player:SetAttribute("DomeOpeningBeat", FirstDomeOpening.openingBeat(e))
	else
		player:SetAttribute("DomeOpeningElapsed", nil)
		player:SetAttribute("DomeOpeningBeat", nil)
	end
end

local function teleportToFacilityCell(player: Player, cellIndex: number, attempt: number?)
	local n = attempt or 0
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local cf = GlassDomeFacility.getCellSpawnCFrame(cellIndex)
	if hrp and hrp:IsA("BasePart") and cf then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = cf
		studioPrint(string.format("teleport to Cell_%d: %s", cellIndex, player.Name))
	elseif n < 16 then
		task.delay(0.25, function()
			teleportToFacilityCell(player, cellIndex, n + 1)
		end)
	end
end

local function toPublic(player: Player): PublicState
	local s = getSession(player)
	if s.stage == EncounterConfig.BAIT_ZONE_ENTRY_STAGE then
		return {
			stage = s.stage,
			maxStages = StageConfig.STAGE_COUNT,
			completed = false,
			prompt = nil,
			problemToken = nil,
			roomLabel = "Зона восстановления",
			choices = nil,
			attemptsLeft = nil,
			domePhase = "IDLE",
			glassIntegrity = 100,
			zeroGActive = false,
			subliminalFlash = false,
		}
	end
	if s.stage > EncounterConfig.BAIT_ZONE_ENTRY_STAGE then
		return {
			stage = StageConfig.STAGE_COUNT,
			maxStages = StageConfig.STAGE_COUNT,
			completed = true,
			prompt = "Вы прошли все сектора.",
			problemToken = nil,
			roomLabel = "Финиш",
			choices = nil,
			attemptsLeft = nil,
			domePhase = "IDLE",
			glassIntegrity = 100,
			zeroGActive = false,
			subliminalFlash = false,
		}
	end
	if not s.taskLocked then
		ensureProblem(player, s)
	end
	local p = s.problem
	return {
		stage = s.stage,
		maxStages = StageConfig.STAGE_COUNT,
		completed = false,
		prompt = if p then p.prompt else nil,
		problemToken = s.problemToken,
		roomLabel = StageConfig.label(s.stage),
		choices = s.choiceTexts,
		attemptsLeft = s.attemptsLeft,
		domePhase = s.domePhase,
		glassIntegrity = s.glassIntegrity,
		zeroGActive = s.domePhase == "ZERO_G",
		subliminalFlash = false,
	}
end

local function ensureProblem(player: Player, s: Session)
	if s.taskLocked then
		return
	end
	if s.problem and s.problemToken then
		return
	end
	if s.stage > StageConfig.STAGE_COUNT then
		return
	end

	resetEncounter(s)

	if s.stage == 1 then
		local left = Fraction.new(2, 3)
		local right = Fraction.new(1, 6)
		local correct = Fraction.add(left, right)
		local p = {
			id = "demo_1",
			operation = "add",
			left = left,
			right = right,
			prompt = "Вычислите выражение: 2/3 + 1/6 = ?",
			correct = correct,
		}
		local pack = {
			{ t = "5/6", ok = true },
			{ t = "1/2", ok = false },
			{ t = "3/4", ok = false },
			{ t = "2/3", ok = false },
		}
		for i = 4, 2, -1 do
			local j = s.rng:NextInteger(1, i)
			pack[i], pack[j] = pack[j], pack[i]
		end
		local texts: { string } = {}
		local idx = 0
		for i, o in ipairs(pack) do
			texts[i] = o.t
			if o.ok then
				idx = i - 1
			end
		end
		s.problem = p
		s.problemToken = HttpService:GenerateGUID(false)
		s.choiceTexts = texts
		s.correctChoiceIndex = idx
		s.attemptsLeft = MAX_ATTEMPTS
		syncBlackboard(s.stage, p.prompt, s.choiceTexts)
		refreshCubePrompts(s)
		return
	end

	local maxD = StageConfig.maxDenominator(s.stage)
	local allowImp = StageConfig.allowImproper(s.stage)
	local op: "add" | "subtract" = if s.rng:NextNumber() < 0.5 then "add" else "subtract"
	local p = ProblemGenerator.generate(s.rng, op, {
		maxDenominator = maxD,
		allowImproper = allowImp,
		ensureNonNegativeResult = true,
	})
	local texts, idx = Choices.buildFour(s.rng, p.correct, maxD)
	local token = HttpService:GenerateGUID(false)
	s.problem = p
	s.problemToken = token
	s.choiceTexts = texts
	s.correctChoiceIndex = idx
	s.attemptsLeft = MAX_ATTEMPTS
	syncBlackboard(s.stage, p.prompt, s.choiceTexts)
	refreshCubePrompts(s)
end

local function beginFirstDomeOpening(player: Player, s: Session)
	if s.stage ~= 1 or s.firstDomeOpeningComplete or s.firstDomeOpeningStartedAt ~= nil then
		return
	end
	s.firstDomeOpeningStartedAt = tick()
	s.domePhase = "CALM"
	s.glassIntegrity = 100
	s.openingForcedZeroGFired = false
	s.floatPropsReleased = false
	s.lastZeroGAt = -1e9
	s.taskLocked = false
	ensureProblem(player, s)
	refreshCubePrompts(s)
	pushDomeAttributes(player, s)
	studioPrint("first dome opening started: " .. player.Name)
end

-- Сектор 2+ : как в первом куполе — сразу задача, кубы и HUD (после прохождения предыдущего сектора)
local function beginDomeEncounter(player: Player, s: Session)
	if s.stage > StageConfig.STAGE_COUNT or s.stage >= EncounterConfig.BAIT_ZONE_ENTRY_STAGE then
		return
	end
	s.taskLocked = false
	resetEncounter(s)
	ensureProblem(player, s)
	refreshCubePrompts(s)
	pushDomeAttributes(player, s)
	studioPrint(string.format("dome encounter sector %d player=%s", s.stage, player.Name))
end

local function finalizeCorrectAnswer(player: Player, s: Session): SubmitResult
	s.turretDomeStage = s.stage
	s.awaitingDoorAfterTurret = true
	s.turretEndTime = tick() + EncounterConfig.TURRET_DURATION
	s.domePhase = "TURRET"
	clearProblem(s)
	s.taskLocked = true
	setTurretVisual(true, s.turretDomeStage)

	local st = toPublic(player)
	local r: SubmitResult = table.clone(st) :: any
	r.ok = true
	r.message = "Сектор стабилизирован. Турели. Успей к выходу."
	r.subliminalFlash = s.rng:NextNumber() < 0.72
	if not r.completed then
		r.prompt = "Турель активна. Дверь откроется через несколько секунд."
	end
	pushDomeAttributes(player, s)
	return r
end

local RunSession = {}

function RunSession.submitFromCube(player: Player, choiceIndex: number): SubmitResult
	local s = getSession(player)
	ensureProblem(player, s)
	local token = s.problemToken
	if s.taskLocked or typeof(token) ~= "string" then
		local st = toPublic(player)
		local r: SubmitResult = table.clone(st) :: any
		r.ok = false
		r.message = "Сначала дождитесь задачи на щите."
		return r
	end
	return RunSession.submit(player, {
		problemToken = token,
		choiceIndex = choiceIndex,
	})
end

function RunSession.getState(player: Player, fromWall: boolean?, domeStage: number?)
	local s = getSession(player)
	if isFirstDomeOpeningActive(s) and (s.problemToken == nil or s.taskLocked) then
		s.taskLocked = false
	end
	if fromWall == true and s.taskLocked then
		if typeof(domeStage) == "number" then
			local di = math.floor((domeStage :: number) + 0.5)
			if di < 1 or di > StageConfig.STAGE_COUNT then
				-- ignore invalid
			elseif di ~= s.stage then
				local st = toPublic(player)
				local out = table.clone(st) :: any
				out.prompt = string.format("Сейчас активен сектор %d. Откройте протокол в том куполе.", s.stage)
				out.choices = nil
				out.problemToken = nil
				out.attemptsLeft = nil
				pushDomeAttributes(player, s)
				return out
			end
		end
		s.taskLocked = false
	end
	local st = toPublic(player)
	pushDomeAttributes(player, s)
	if s.problemToken ~= nil and not s.taskLocked then
		refreshCubePrompts(s)
	end
	return st
end

function RunSession.submit(player: Player, payload: SubmitPayload): SubmitResult
	local s = getSession(player)
	if s.stage > StageConfig.STAGE_COUNT then
		local st = toPublic(player)
		local done: SubmitResult = table.clone(st) :: any
		done.ok = st.completed == true
		done.message = if st.completed then nil else "Сектора завершены."
		return done
	end
	ensureProblem(player, s)
	local token = s.problemToken
	local prob = s.problem
	if not token or not prob or payload.problemToken ~= token then
		local st = toPublic(player)
		local r: SubmitResult = table.clone(st) :: any
		r.ok = false
		r.message = "Задача устарела, обновите."
		return r
	end

	local correctIdx = s.correctChoiceIndex
	local rawChoice = (payload :: any).choiceIndex
	local ci: number? = nil
	if typeof(rawChoice) == "number" then
		ci = math.floor((rawChoice :: number) + 0.5)
	elseif typeof(rawChoice) == "string" then
		local n = tonumber(rawChoice :: string)
		if n then
			ci = math.floor(n + 0.5)
		end
	end

	local function openingSubliminal(): boolean
		if not isFirstDomeOpeningActive(s) or s.firstDomeOpeningStartedAt == nil then
			return false
		end
		local e = tick() - (s.firstDomeOpeningStartedAt :: number)
		return FirstDomeOpening.shouldSubliminalFlash(e, s.domePhase)
	end

	local function wrongAttempts(msg: string): SubmitResult
		s.attemptsLeft = (s.attemptsLeft :: number) - 1
		if s.attemptsLeft <= 0 then
			clearProblem(s)
			s.taskLocked = true
			s.domePhase = "IDLE"
			local st = toPublic(player)
			local r: SubmitResult = table.clone(st) :: any
			r.ok = false
			r.message = "Попытки кончились. Снова «Показать задание»."
			pushDomeAttributes(player, s)
			return r
		end
		local st = toPublic(player)
		local r: SubmitResult = table.clone(st) :: any
		r.ok = false
		r.message = string.format("%s Осталось попыток: %d", msg, s.attemptsLeft :: number)
		r.subliminalFlash = openingSubliminal()
		pushDomeAttributes(player, s)
		return r
	end

	if ci ~= nil then
		if ci < 0 or ci > 3 then
			local st = toPublic(player)
			local r: SubmitResult = table.clone(st) :: any
			r.ok = false
			r.message = "Неверный вариант."
			return r
		end
		if correctIdx == nil or s.attemptsLeft == nil then
			local st = toPublic(player)
			local r: SubmitResult = table.clone(st) :: any
			r.ok = false
			r.message = "Нет активной задачи."
			return r
		end
		if ci == correctIdx then
			studioPrint(string.format("верный вариант choiceIndex=%d игрок=%s", ci, player.Name))
			return finalizeCorrectAnswer(player, s)
		end
		return wrongAttempts("Неверно.")
	elseif typeof(payload.answer) == "string" then
		local check = AnswerChecker.check(prob.correct, payload.answer)
		if check.ok then
			studioPrint(string.format("верный текстовый ответ игрок=%s", player.Name))
			return finalizeCorrectAnswer(player, s)
		end
		return wrongAttempts("Неверно.")
	end

	local st = toPublic(player)
	local r: SubmitResult = table.clone(st) :: any
	r.ok = false
	r.message = "Подойдите к кубу с ответом и нажмите E."
	return r
end

function RunSession.reset(player: Player)
	sessions[player] = nil
	player:SetAttribute("DomePhase", nil)
	player:SetAttribute("DomeIntegrity", nil)
	player:SetAttribute("DomeZeroG", nil)
	player:SetAttribute("DomeEncounterActive", nil)
	player:SetAttribute("DomeOpeningActive", nil)
	player:SetAttribute("DomeCellStage", nil)
	player:SetAttribute("DomeOpeningElapsed", nil)
	player:SetAttribute("DomeOpeningBeat", nil)
end

function RunSession.tickEncounters(dt: number)
	local anyZeroG = false
	for player, s in pairs(sessions) do
		if s.awaitingDoorAfterTurret and s.turretEndTime ~= nil then
			if tick() >= (s.turretEndTime :: number) then
				s.awaitingDoorAfterTurret = false
				s.turretEndTime = nil
				s.domePhase = "IDLE"
				local completedStage = s.turretDomeStage or s.stage
				s.turretDomeStage = nil
				setTurretVisual(false, nil)
				local doorOk, doorErr = pcall(function()
					DoorService.openExitFromStage(completedStage)
				end)
				if not doorOk then
					warn("[RunSession] DoorService.openExitFromStage: ", doorErr)
				end
				s.stage += 1
				if s.stage == EncounterConfig.BAIT_ZONE_ENTRY_STAGE and not s.sentToBait then
					-- 5 куполов пройдены: новый круг с сектора 1 (не выброс в траву BaitGarden)
					s.sentToBait = true
					s.stage = 1
					s.firstDomeOpeningComplete = true
					teleportToFacilityCell(player, 1)
					beginDomeEncounter(player, s)
				elseif s.stage <= StageConfig.STAGE_COUNT then
					beginDomeEncounter(player, s)
				end
				local closeStage = completedStage
				task.delay(EncounterConfig.DOOR_OPEN_AFTER_TURRET_SECONDS, function()
					pcall(function()
						DoorService.closeForStage(closeStage)
					end)
				end)
				studioPrint("door opened after turret, stage=" .. tostring(s.stage))
			else
				s.domePhase = "TURRET"
			end
			pushDomeAttributes(player, s)
		else
			local mathActive = s.problemToken ~= nil and not s.taskLocked
			local openingActive = isFirstDomeOpeningActive(s)

			if openingActive and s.firstDomeOpeningStartedAt ~= nil then
				local slice: FirstDomeOpening.SessionOpeningSlice = {
					stage = s.stage,
					encounterStartedAt = s.firstDomeOpeningStartedAt,
					domePhase = s.domePhase,
					glassIntegrity = s.glassIntegrity,
					lastZeroGAt = s.lastZeroGAt,
					openingForcedZeroGFired = s.openingForcedZeroGFired,
				}
				local openingHandled = FirstDomeOpening.tickOpening(slice, dt)
				s.domePhase = slice.domePhase :: DomePhase
				s.glassIntegrity = slice.glassIntegrity
				s.lastZeroGAt = slice.lastZeroGAt
				s.openingForcedZeroGFired = slice.openingForcedZeroGFired

				if tick() - (s.firstDomeOpeningStartedAt :: number) >= FirstDomeOpening.WINDOW_SECONDS then
					s.firstDomeOpeningComplete = true
					openingHandled = false
					if not mathActive then
						s.domePhase = "IDLE"
					elseif s.encounterStartedAt == nil then
						s.encounterStartedAt = tick()
					end
				end

				if openingHandled and s.domePhase == "ZERO_G" then
					anyZeroG = true
					if not s.floatPropsReleased then
						s.floatPropsReleased = true
						releaseOpeningFloatProps()
					end
				end
			elseif not mathActive then
				if s.domePhase ~= "IDLE" and s.domePhase ~= "TURRET" then
					s.domePhase = "IDLE"
				end
			else
				local started = s.encounterStartedAt or tick()
				s.encounterStartedAt = started

				if tick() - started < EncounterConfig.CALM_SECONDS then
					s.domePhase = "CALM"
				elseif s.domePhase == "ZERO_G" then
					local zEnd = s.lastZeroGAt + EncounterConfig.ZERO_G_DURATION
					if tick() >= zEnd then
						s.domePhase = "ASSAULT"
						s.glassIntegrity = math.min(100, s.glassIntegrity + 6)
					else
						anyZeroG = true
					end
				else
					s.domePhase = "ASSAULT"
					s.glassIntegrity -= EncounterConfig.ASSAULT_INTEGRITY_PER_SEC * dt
					local sinceZeroEnd = tick() - (s.lastZeroGAt + EncounterConfig.ZERO_G_DURATION)
					if s.glassIntegrity <= EncounterConfig.ZERO_G_AT_INTEGRITY and sinceZeroEnd >= EncounterConfig.ZERO_G_COOLDOWN then
						s.domePhase = "ZERO_G"
						s.lastZeroGAt = tick()
						anyZeroG = true
					end
				end

				if s.domePhase == "ZERO_G" then
					anyZeroG = true
				end
			end

			pushDomeAttributes(player, s)

			-- Запасной старт: вошли в купол своего сектора, а задача ещё не выдана
			if
				not s.awaitingDoorAfterTurret
				and s.stage >= 2
				and s.stage < EncounterConfig.BAIT_ZONE_ENTRY_STAGE
				and s.taskLocked
				and s.problemToken == nil
			then
				local here = physicalCellStage(player)
				if here == s.stage then
					beginDomeEncounter(player, s)
				end
			end
		end
	end

	Workspace.Gravity = if anyZeroG then EncounterConfig.WORKSPACE_GRAVITY_ZERO_G else EncounterConfig.WORKSPACE_GRAVITY_DEFAULT

	for pl, s in pairs(sessions) do
		local mathActive = s.problemToken ~= nil and not s.taskLocked
		local openingActive = isFirstDomeOpeningActive(s)
		DomeDroneService.sync(pl, openingActive or mathActive, s.stage)
	end

	MimicService.tick(dt, EncounterConfig.MIMIC_HUNT_AFTER_SECONDS)
end

function RunSession.onPlayerJoin(player: Player)
	local s = getSession(player)
	-- Сразу выдаём протокол и атрибуты — клиент может монтировать HUD до CharacterAdded
	beginFirstDomeOpening(player, s)
	local function tryStart()
		if player.Parent then
			beginFirstDomeOpening(player, s)
			pushDomeAttributes(player, s)
		end
	end
	if player.Character then
		tryStart()
	end
	player.CharacterAdded:Connect(tryStart)
end

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)

return RunSession
