--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local function studioPrint(msg: string)
	if RunService:IsStudio() then
		print("[Matan][Run] " .. msg)
	end
end

local Math = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Math"))
local StageConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("StageConfig"))
local Choices = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Math"):WaitForChild("Choices"))
local DoorService = require(script.Parent.Parent.Map.DoorService)

local Fraction = Math.Fraction
local ProblemGenerator = Math.ProblemGenerator
local AnswerChecker = Math.AnswerChecker

local MAX_ATTEMPTS = 3
local DOOR_STAY_OPEN_SECONDS = 5

export type PublicState = {
	stage: number,
	maxStages: number,
	completed: boolean,
	prompt: string?,
	problemToken: string?,
	roomLabel: string,
	choices: { string }?,
	attemptsLeft: number?,
}

type Session = {
	stage: number,
	rng: Random,
	problemToken: string?,
	problem: any?,
	choiceTexts: { string }?,
	correctChoiceIndex: number?,
	attemptsLeft: number?,
	taskLocked: boolean,
}

local sessions: { [Player]: Session } = {}

local function getSession(player: Player): Session
	local s = sessions[player]
	if s then
		return s
	end
	local rng = Random.new((math.floor(tick() * 1000) + player.UserId * 7919) % 2 ^ 31)
	s = {
		stage = 1,
		rng = rng,
		problemToken = nil,
		problem = nil,
		choiceTexts = nil,
		correctChoiceIndex = nil,
		attemptsLeft = nil,
		taskLocked = true,
	}
	sessions[player] = s
	return s
end

local function clearProblem(s: Session)
	s.problemToken = nil
	s.problem = nil
	s.choiceTexts = nil
	s.correctChoiceIndex = nil
	s.attemptsLeft = nil
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

	-- Демо: комната 1 — строго 1/2 + 1/3 = 5/6
	if s.stage == 1 then
		local left = Fraction.new(1, 2)
		local right = Fraction.new(1, 3)
		local correct = Fraction.add(left, right)
		local p = {
			id = "demo_1",
			operation = "add",
			left = left,
			right = right,
			prompt = "Вычислите: 1/2 + 1/3",
			correct = correct,
		}
		local pack = {
			{ t = "5/6", ok = true },
			{ t = "7/6", ok = false },
			{ t = "2/5", ok = false },
			{ t = "4/12", ok = false },
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
end

local function toPublic(player: Player): PublicState
	local s = getSession(player)
	if s.stage > StageConfig.STAGE_COUNT then
		return {
			stage = StageConfig.STAGE_COUNT,
			maxStages = StageConfig.STAGE_COUNT,
			completed = true,
			prompt = "Вы прошли все комнаты!",
			problemToken = nil,
			roomLabel = "Финиш",
			choices = nil,
			attemptsLeft = nil,
		}
	end
	ensureProblem(player, s)
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
	}
end

local RunSession = {}

function RunSession.getState(player: Player, fromWall: boolean?)
	local s = getSession(player)
	if fromWall == true and s.taskLocked then
		s.taskLocked = false
	end
	return toPublic(player)
end

export type SubmitPayload = {
	problemToken: string,
	answer: string?,
	choiceIndex: number?,
}

export type SubmitResult = PublicState & {
	ok: boolean,
	message: string?,
}

function RunSession.submit(player: Player, payload: SubmitPayload): SubmitResult
	local s = getSession(player)
	if s.stage > StageConfig.STAGE_COUNT then
		local st = toPublic(player)
		local done: SubmitResult = table.clone(st) :: any
		done.ok = true
		done.message = nil
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
			local doorOk, doorErr = pcall(function()
				DoorService.open()
			end)
			if not doorOk then
				warn("[RunSession] DoorService.open() ошибка: ", doorErr)
				studioPrint("DoorService.open упал: " .. tostring(doorErr))
			end
			s.stage += 1
			clearProblem(s)
			s.taskLocked = true
			local st = toPublic(player)
			task.delay(DOOR_STAY_OPEN_SECONDS, function()
				DoorService.close()
			end)
			local r: SubmitResult = table.clone(st) :: any
			r.ok = true
			r.message = nil
			if not r.completed then
				r.prompt = "Верно! Дверь открыта несколько секунд. Следующая задача — снова «Показать задание» у экрана."
			end
			return r
		end
		s.attemptsLeft = (s.attemptsLeft :: number) - 1
		if s.attemptsLeft <= 0 then
			clearProblem(s)
			s.taskLocked = true
			local st = toPublic(player)
			local r: SubmitResult = table.clone(st) :: any
			r.ok = false
			r.message = "Попытки кончились. Нажмите «Показать задание» снова."
			return r
		end
		local st = toPublic(player)
		local r: SubmitResult = table.clone(st) :: any
		r.ok = false
		r.message = string.format("Неверно. Осталось попыток: %d", s.attemptsLeft :: number)
		return r
	elseif typeof(payload.answer) == "string" then
		local check = AnswerChecker.check(prob.correct, payload.answer)
		if check.ok then
			studioPrint(string.format("верный текстовый ответ игрок=%s", player.Name))
			local doorOk, doorErr = pcall(function()
				DoorService.open()
			end)
			if not doorOk then
				warn("[RunSession] DoorService.open() ошибка: ", doorErr)
				studioPrint("DoorService.open упал: " .. tostring(doorErr))
			end
			s.stage += 1
			clearProblem(s)
			s.taskLocked = true
			local st = toPublic(player)
			task.delay(DOOR_STAY_OPEN_SECONDS, function()
				DoorService.close()
			end)
			local r: SubmitResult = table.clone(st) :: any
			r.ok = true
			r.message = nil
			if not r.completed then
				r.prompt = "Верно! Дверь открыта несколько секунд. Следующая задача — снова «Показать задание» у экрана."
			end
			return r
		end
		s.attemptsLeft = (s.attemptsLeft :: number) - 1
		if s.attemptsLeft <= 0 then
			clearProblem(s)
			s.taskLocked = true
			local st = toPublic(player)
			local r: SubmitResult = table.clone(st) :: any
			r.ok = false
			r.message = "Попытки кончились. Нажмите «Показать задание» снова."
			return r
		end
		local st = toPublic(player)
		local r: SubmitResult = table.clone(st) :: any
		r.ok = false
		r.message = string.format("Неверно. Осталось попыток: %d", s.attemptsLeft :: number)
		return r
	end

	local st = toPublic(player)
	local r: SubmitResult = table.clone(st) :: any
	r.ok = false
	r.message = "Выберите один из 4 вариантов на экране."
	return r
end

function RunSession.reset(player: Player)
	sessions[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)

return RunSession
