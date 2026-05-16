--!strict
--[[
	Кубы AnswerCube_0..3: ProximityPrompt (E) на сервере → RunSession.submitFromCube.
	Клиент только подписи на кубах; Enabled управляется здесь.
]]

local Workspace = game:GetService("Workspace")

local AnswerCubeService = {}

local bound: { [BasePart]: boolean } = {}
local submitHandler: ((Player, number) -> ())? = nil

local function isAnswerCube(inst: Instance): boolean
	return inst:IsA("BasePart") and string.match(inst.Name, "^AnswerCube_%d$") ~= nil
end

local function updateCubeTopLabel(cube: BasePart, letter: string, answerText: string)
	local sg = cube:FindFirstChild("AnswerLabel")
	if not sg or not sg:IsA("SurfaceGui") then
		return
	end
	local tl = sg:FindFirstChild("Label")
	if tl and tl:IsA("TextLabel") then
		tl.Text = letter .. "\n" .. answerText
	end
end

local function ensurePrompt(cube: BasePart): ProximityPrompt
	local pp = cube:FindFirstChildOfClass("ProximityPrompt")
	if not pp then
		pp = Instance.new("ProximityPrompt")
		pp.Name = "AnswerPrompt"
		pp.KeyboardKeyCode = Enum.KeyCode.E
		pp.GamepadKeyCode = Enum.KeyCode.ButtonX
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 14
		pp.RequiresLineOfSight = false
		pp.ClickablePrompt = true
		pp.Enabled = false
		pp.Parent = cube
	end
	return pp
end

function AnswerCubeService.setSubmitHandler(fn: (Player, number) -> ())
	submitHandler = fn
end

function AnswerCubeService.bindCube(cube: BasePart)
	if bound[cube] then
		return
	end
	bound[cube] = true

	local pp = ensurePrompt(cube)

	pp.Triggered:Connect(function(triggerPlayer: Player)
		if not pp.Enabled then
			return
		end
		local ciAttr = cube:GetAttribute("ChoiceIndex")
		if typeof(ciAttr) ~= "number" then
			return
		end
		local choiceIndex = math.floor((ciAttr :: number) + 0.5)
		if choiceIndex < 0 or choiceIndex > 3 then
			return
		end
		local cubeStage = cube:GetAttribute("DomeStage")
		if typeof(cubeStage) == "number" then
			local root = Workspace:FindFirstChild("MatanTestIqRoom")
			local activeStage = root and root:GetAttribute("ActiveTaskStage")
			if typeof(activeStage) == "number" then
				if math.floor((cubeStage :: number) + 0.5) ~= math.floor((activeStage :: number) + 0.5) then
					return
				end
			end
		end
		if submitHandler then
			submitHandler(triggerPlayer, choiceIndex)
		end
	end)
end

function AnswerCubeService.bindFacility(facility: Model)
	for _, desc in facility:GetDescendants() do
		if isAnswerCube(desc) then
			AnswerCubeService.bindCube(desc :: BasePart)
		end
	end
end

function AnswerCubeService.sync(stage: number, enabled: boolean, choices: { string }?)
	local root = Workspace:FindFirstChild("MatanTestIqRoom")
	if not root or not root:IsA("Model") then
		return
	end

	local activeCell = root:FindFirstChild("Cell_" .. tostring(stage))
	if not activeCell then
		return
	end

	for _, desc in root:GetDescendants() do
		if isAnswerCube(desc) then
			local cube = desc :: BasePart
			local pp = ensurePrompt(cube)
			local inCell = cube:IsDescendantOf(activeCell)
			local ciAttr = cube:GetAttribute("ChoiceIndex")
			local ci = if typeof(ciAttr) == "number" then math.floor((ciAttr :: number) + 0.5) else -1
			local on = enabled and inCell and ci >= 0 and ci <= 3

			pp.Enabled = on
			if on and typeof(choices) == "table" then
				local opt = choices[ci + 1]
				if typeof(opt) == "string" then
					pp.ActionText = "Выбрать: " .. opt
					pp.ObjectText = string.char(65 + ci)
					updateCubeTopLabel(cube, string.char(65 + ci), opt)
				end
			elseif not on then
				pp.ActionText = "Ответ"
				pp.ObjectText = ""
			end
		end
	end
end

return AnswerCubeService
