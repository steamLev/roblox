--!strict
--[[
	Панель протокола: условие справа вверху.
	Ответы — кубы AnswerCube_0..3 в куполе: подойти + E → SubmitAnswer(choiceIndex).
	ProximityPrompt на доске — обновить задачу в других секторах.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local HUD_NAME = "DomeProtocolHud"
local REFRESH_INTERVAL = 0.45
local HUD_DISPLAY_ORDER = 500
local ZERO_G_WOBBLE_MAX = Vector2.new(3, 4)

local remotes: { getState: RemoteFunction, submit: RemoteFunction }? = nil
local facilityModel: Model? = nil
local lastRefresh = 0
local mountedToken: string? = nil
local submitting = false
local answerCubesBound = false

local mountHud: (any, RemoteFunction, Model?) -> ()

local CUBE_BIND_ATTR = "_WallTaskCubeBound"

local function flashSubliminal()
	local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
	if not pg then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "SubliminalFlash"
	g.ResetOnSpawn = false
	g.DisplayOrder = 100_000
	g.IgnoreGuiInset = true
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = 0.12
	f.BorderSizePixel = 0
	f.Parent = g
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(0.7, 0.4)
	t.Position = UDim2.fromScale(0.15, 0.28)
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.fromRGB(210, 20, 40)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = "◢▇▇▇◣"
	t.Parent = f
	g.Parent = pg
	task.delay(0.045, function()
		if g.Parent then
			g:Destroy()
		end
	end)
end

local function waitFacility(): Model?
	local existing = Workspace:FindFirstChild("MatanTestIqRoom")
	if existing and existing:IsA("Model") then
		return existing
	end
	local m = Workspace:WaitForChild("MatanTestIqRoom", 90)
	if m and m:IsA("Model") then
		return m
	end
	return nil
end

local function orientBlackboard(board: BasePart)
	local cell = board:FindFirstAncestorWhichIsA("Model")
	local ox = if cell then cell:GetAttribute("DomeCenterX") else nil
	if typeof(ox) ~= "number" then
		ox = board.Position.X
	end
	local pos = board.Position
	board.CFrame = CFrame.lookAt(pos, Vector3.new(ox :: number, pos.Y, pos.Z + 3))
	local pad = cell and cell:FindFirstChild("TaskWallButton", true)
	if pad and pad:IsA("BasePart") then
		pad.CFrame = board.CFrame * CFrame.new(0, 0, 0.55)
	end
end

local function orientAllBlackboards(facility: Model)
	for _, desc in facility:GetDescendants() do
		if desc:IsA("BasePart") and desc.Name == "MainBlackboard" then
			orientBlackboard(desc)
		end
	end
end

local function activeCellName(): string
	local stage = player:GetAttribute("DomeCellStage")
	if typeof(stage) == "number" and stage >= 1 then
		return "Cell_" .. tostring(math.floor(stage + 0.5))
	end
	return "Cell_1"
end

local function getRemotes()
	local folder = ReplicatedStorage:WaitForChild("Remotes", 60)
	if not folder then
		return nil
	end
	return {
		getState = folder:WaitForChild("GetRunState", 10) :: RemoteFunction?,
		submit = folder:WaitForChild("SubmitAnswer", 10) :: RemoteFunction?,
	}
end

local function shouldShowHud(): boolean
	if player:GetAttribute("DomeOpeningActive") == true then
		return true
	end
	if player:GetAttribute("DomeEncounterActive") == true then
		local stage = player:GetAttribute("DomeCellStage")
		return typeof(stage) == "number" and stage >= 1
	end
	local phase = player:GetAttribute("DomePhase")
	return typeof(phase) == "string" and phase ~= "IDLE"
end

local function onChoiceActivated(
	token: string,
	choiceIndex: number,
	submit: RemoteFunction,
	facility: Model?
)
	if submitting then
		return
	end
	submitting = true
	local ok, res = pcall(function()
		return submit:InvokeServer({
			problemToken = token,
			choiceIndex = choiceIndex,
		})
	end)
	submitting = false
	if ok and typeof(res) == "table" then
		local r = res :: any
		if r.subliminalFlash == true then
			flashSubliminal()
		end
		if r.ok then
			mountedToken = nil
			destroyHud()
		elseif typeof(r.problemToken) == "string" then
			mountedToken = r.problemToken
			if remotes and remotes.submit then
				mountHud(r, remotes.submit, facility)
			end
		else
			mountedToken = nil
			destroyHud()
		end
	elseif not ok then
		warn("[WallTask] SubmitAnswer failed: ", res)
	end
end

local function setLabelPassive(lbl: TextLabel)
	lbl.Active = false
	lbl.Selectable = false
end

local function updateCubeLabel(cube: BasePart, letter: string, answerText: string)
	local sg = cube:FindFirstChild("AnswerLabel")
	if not sg or not sg:IsA("SurfaceGui") then
		return
	end
	local tl = sg:FindFirstChild("Label")
	if tl and tl:IsA("TextLabel") then
		tl.Text = letter .. "\n" .. answerText
	end
end

local function isAnswerCube(inst: Instance): boolean
	return inst:IsA("BasePart") and string.match(inst.Name, "^AnswerCube_%d$") ~= nil
end

-- Только подписи; ProximityPrompt и E обрабатывает сервер (AnswerCubeService)
local function syncAnswerCubes(facility: Model?, choices: { string }?, _enabled: boolean)
	if not facility or typeof(choices) ~= "table" then
		return
	end
	local cellName = activeCellName()
	local activeCell = facility:FindFirstChild(cellName) or facility:FindFirstChild("Cell_1")
	if not activeCell then
		return
	end

	for _, desc in activeCell:GetDescendants() do
		if isAnswerCube(desc) then
			local ciAttr = desc:GetAttribute("ChoiceIndex")
			local ci = if typeof(ciAttr) == "number" then math.floor((ciAttr :: number) + 0.5) else -1
			if ci >= 0 and ci <= 3 then
				local opt = (choices :: { any })[ci + 1]
				if typeof(opt) == "string" then
					updateCubeLabel(desc :: BasePart, string.char(65 + ci), opt)
				end
			end
		end
	end
end

local function bindAnswerCubes(facility: Model)
	for _, desc in facility:GetDescendants() do
		if not isAnswerCube(desc) then
			continue
		end
		if desc:GetAttribute(CUBE_BIND_ATTR) == true then
			continue
		end
		desc:SetAttribute(CUBE_BIND_ATTR, true)

		local pp = desc:FindFirstChildOfClass("ProximityPrompt")
		if not pp then
			continue
		end

		local hl = desc:FindFirstChild("AnswerHighlight")
		if not hl then
			hl = Instance.new("Highlight")
			hl.Name = "AnswerHighlight"
			hl.Adornee = desc
			hl.FillColor = Color3.fromRGB(120, 200, 255)
			hl.OutlineColor = Color3.fromRGB(200, 240, 255)
			hl.FillTransparency = 0.55
			hl.OutlineTransparency = 0.15
			hl.Enabled = false
			hl.Parent = desc
		end

		pp.PromptShown:Connect(function()
			if pp.Enabled then
				(hl :: Highlight).Enabled = true
				desc.Color = Color3.fromRGB(90, 110, 140)
			end
		end)
		pp.PromptHidden:Connect(function()
			(hl :: Highlight).Enabled = false
			desc.Color = Color3.fromRGB(58, 64, 78)
		end)
	end
	answerCubesBound = true
end

local function destroyHud()
	mountedToken = nil
	syncAnswerCubes(facilityModel, nil, false)
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local g = pg:FindFirstChild(HUD_NAME)
	if g then
		g:Destroy()
	end
end

local function updateBlackboardPrompt(
	facility: Model?,
	prompt: string,
	choices: { string }?,
	token: string?,
	submit: RemoteFunction?
)
	if not facility or prompt == "" then
		return
	end
	local cell = facility:FindFirstChild(activeCellName())
	if not cell then
		cell = facility:FindFirstChild("Cell_1")
	end
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
	sg.Active = true
	sg.AlwaysOnTop = true
	sg.Face = Enum.NormalId.Front
	sg.ZOffset = 0.15
	local bg = sg:FindFirstChild("SignBg")
	if not bg or not bg:IsA("Frame") then
		return
	end
	bg.Active = false
	for _, ch in bg:GetChildren() do
		if ch:IsA("TextLabel") or ch:IsA("TextButton") then
			ch:Destroy()
		end
	end

	local textSize = 26
	local y = 8
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.new(1, -16, 0, textSize + 12)
	tl.Position = UDim2.fromOffset(8, y)
	tl.Font = Enum.Font.GothamBold
	tl.TextSize = textSize
	tl.TextColor3 = Color3.fromRGB(245, 250, 240)
	tl.Text = prompt
	tl.TextWrapped = true
	tl.TextStrokeTransparency = 0.55
	tl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	setLabelPassive(tl)
	tl.Parent = bg
	y += textSize + 18

	if typeof(choices) == "table" then
		local row = {}
		for i, opt in ipairs(choices :: { any }) do
			if typeof(opt) == "string" then
				table.insert(row, string.char(64 + i) .. ") " .. opt)
			end
		end
		if #row > 0 then
			local tl2 = Instance.new("TextLabel")
			tl2.BackgroundTransparency = 1
			tl2.Size = UDim2.new(1, -16, 0, textSize + 12)
			tl2.Position = UDim2.fromOffset(8, y)
			tl2.Font = Enum.Font.GothamBold
			tl2.TextSize = textSize
			tl2.TextColor3 = Color3.fromRGB(245, 250, 240)
			tl2.Text = table.concat(row, "   ")
			tl2.TextWrapped = true
			tl2.Parent = bg
		end
	end
end

function mountHud(st: any, submit: RemoteFunction, facility: Model?)
	if not shouldShowHud() then
		destroyHud()
		return
	end
	local token = st.problemToken
	local choices = st.choices
	if st.completed == true then
		destroyHud()
		return
	end
	if typeof(token) ~= "string" or typeof(choices) ~= "table" then
		-- Пока сервер готовит задачу — держим панель-заглушку (читаемость при старте opening)
		if not shouldShowHud() then
			return
		end
		local pgWait = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
		if not pgWait then
			return
		end
		destroyHud()
		local sgWait = Instance.new("ScreenGui")
		sgWait.Name = HUD_NAME
		sgWait.ResetOnSpawn = false
		sgWait.DisplayOrder = HUD_DISPLAY_ORDER
		sgWait.IgnoreGuiInset = true
		sgWait.Parent = pgWait
		local panelWait = Instance.new("Frame")
		panelWait.Name = "Panel"
		panelWait.AnchorPoint = Vector2.new(1, 0)
		panelWait.Position = UDim2.new(1, -12, 0, 12)
		panelWait.Size = UDim2.fromOffset(360, 72)
		panelWait.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
		panelWait.BackgroundTransparency = 0.06
		panelWait.BorderSizePixel = 0
		panelWait.Active = false
		panelWait.Parent = sgWait
		local waitLbl = Instance.new("TextLabel")
		waitLbl.BackgroundTransparency = 1
		waitLbl.Size = UDim2.new(1, -16, 1, -12)
		waitLbl.Position = UDim2.fromOffset(8, 6)
		waitLbl.Font = Enum.Font.GothamBold
		waitLbl.TextSize = 17
		waitLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
		waitLbl.Text = "Протокол щита загружается…"
		waitLbl.TextWrapped = true
		waitLbl.Parent = panelWait
		syncAnswerCubes(facility, nil, false)
		return
	end

	local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
	if not pg then
		return
	end

	destroyHud()

	local sg = Instance.new("ScreenGui")
	sg.Name = HUD_NAME
	sg.ResetOnSpawn = false
	sg.DisplayOrder = HUD_DISPLAY_ORDER
	sg.IgnoreGuiInset = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Global
	sg.Enabled = true
	sg.Parent = pg

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -12, 0, 12)
	panel.Size = UDim2.fromOffset(440, 200)
	panel.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
	panel.BackgroundTransparency = 0.02
	panel.BorderSizePixel = 0
	panel.Active = false
	panel.Parent = sg

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 150, 230)
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = panel

	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 12)
	pc.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -20, 0, 26)
	title.Position = UDim2.fromOffset(10, 8)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(200, 220, 255)
	title.Text = "Стабилизация щита"
	setLabelPassive(title)
	title.Parent = panel

	local integ = if typeof(st.glassIntegrity) == "number" then st.glassIntegrity else 100
	local phase = if typeof(st.domePhase) == "string" then st.domePhase else "—"
	local zeroG = st.zeroGActive == true or player:GetAttribute("DomeZeroG") == 1

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, -20, 0, 22)
	status.Position = UDim2.fromOffset(10, 34)
	status.Font = Enum.Font.GothamMedium
	status.TextSize = 14
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = if zeroG
		then Color3.fromRGB(255, 170, 100)
		elseif integ < 45 then Color3.fromRGB(255, 130, 120)
		else Color3.fromRGB(120, 190, 255)
	local phaseLabel = if zeroG then "НЕВЕСОМОСТЬ" else phase
	status.Text = string.format("Щит %d%%  ·  %s", math.floor(integ + 0.5), phaseLabel)
	setLabelPassive(status)
	status.Parent = panel

	local body = Instance.new("TextLabel")
	body.Name = "PromptBody"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -20, 0, 58)
	body.Position = UDim2.fromOffset(10, 58)
	body.Font = Enum.Font.GothamBold
	body.TextSize = 21
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	local text = st.prompt
	body.Text = if typeof(text) == "string" and text ~= "" then text else "—"
	body.TextColor3 = Color3.fromRGB(245, 248, 255)
	setLabelPassive(body)
	body.Parent = panel

	local attempts = Instance.new("TextLabel")
	attempts.Name = "Attempts"
	attempts.BackgroundTransparency = 1
	attempts.Size = UDim2.new(1, -20, 0, 18)
	attempts.Position = UDim2.fromOffset(10, 118)
	attempts.Font = Enum.Font.Gotham
	attempts.TextSize = 13
	attempts.TextXAlignment = Enum.TextXAlignment.Left
	local al = st.attemptsLeft
	attempts.Text = if typeof(al) == "number" then string.format("Попыток: %d / 3", al) else ""
	attempts.TextColor3 = Color3.fromRGB(160, 180, 220)
	setLabelPassive(attempts)
	attempts.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.Name = "CubeHint"
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.new(1, -20, 0, 36)
	hint.Position = UDim2.fromOffset(10, 138)
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 15
	hint.TextWrapped = true
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = Color3.fromRGB(150, 210, 255)
	hint.Text = "Подойдите к светящемуся кубу с ответом и нажмите E"
	setLabelPassive(hint)
	hint.Parent = panel

	local promptText = if typeof(st.prompt) == "string" then st.prompt else ""
	updateBlackboardPrompt(facility, promptText, choices :: { string }?, token, submit)

	mountedToken = token
	syncAnswerCubes(facility, choices :: { string }?, true)
end

local function updateHudLabels(st: any)
	local pg = player:FindFirstChildOfClass("PlayerGui")
	local hud = pg and pg:FindFirstChild(HUD_NAME)
	if not hud or not hud:IsA("ScreenGui") then
		return
	end
	local panel = hud:FindFirstChild("Panel")
	if not panel or not panel:IsA("Frame") then
		return
	end
	local status = panel:FindFirstChild("Status")
	if status and status:IsA("TextLabel") then
		local integ = if typeof(st.glassIntegrity) == "number" then st.glassIntegrity else 100
		local phase = if typeof(st.domePhase) == "string" then st.domePhase else "—"
		local zeroG = st.zeroGActive == true or player:GetAttribute("DomeZeroG") == 1
		status.TextColor3 = if zeroG
			then Color3.fromRGB(255, 170, 100)
			elseif integ < 45 then Color3.fromRGB(255, 130, 120)
			else Color3.fromRGB(120, 190, 255)
		local phaseLabel = if zeroG then "НЕВЕСОМОСТЬ" else phase
		status.Text = string.format("Щит %d%%  ·  %s", math.floor(integ + 0.5), phaseLabel)
	end
	local attempts = panel:FindFirstChild("Attempts")
	if attempts and attempts:IsA("TextLabel") then
		local al = st.attemptsLeft
		attempts.Text = if typeof(al) == "number" then string.format("Попыток: %d / 3", al) else ""
	end
end

local function refreshHud(fromWall: boolean, domeStage: number?, forceRemount: boolean?)
	if submitting then
		return
	end
	if not remotes or not remotes.getState or not remotes.submit then
		return
	end
	if not shouldShowHud() and not fromWall then
		destroyHud()
		return
	end
	local ok, st = pcall(function()
		return remotes.getState:InvokeServer(fromWall, domeStage)
	end)
	if not ok or typeof(st) ~= "table" then
		if shouldShowHud() or fromWall then
			mountHud({ completed = false }, remotes.submit, facilityModel)
		end
		return
	end
	local state = st :: any
	if typeof(state.problemToken) == "string" and typeof(state.choices) == "table" then
		local token = state.problemToken :: string
		local pg = player:FindFirstChildOfClass("PlayerGui")
		local hudExists = pg and pg:FindFirstChild(HUD_NAME) ~= nil
		if forceRemount == true or token ~= mountedToken or not hudExists then
			mountHud(state, remotes.submit, facilityModel)
		else
			updateHudLabels(state)
			if typeof(state.choices) == "table" then
				syncAnswerCubes(facilityModel, state.choices :: { string }, true)
			end
		end
	elseif shouldShowHud() or fromWall then
		mountHud(state, remotes.submit, facilityModel)
	elseif not shouldShowHud() then
		destroyHud()
	end
end

local function bindPrompts(facility: Model)
	local function refreshPrompts()
		local active = facility:GetAttribute("ActiveTaskStage")
		local a = 1
		if typeof(active) == "number" then
			a = math.floor((active :: number) + 0.5)
		end
		for _, d in facility:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "TaskWallButton" then
				local ds = d:GetAttribute("DomeStage")
				if typeof(ds) == "number" then
					local di = math.floor((ds :: number) + 0.5)
					local ppp = d:FindFirstChildOfClass("ProximityPrompt")
					if ppp then
						ppp.Enabled = di == a
					end
				end
			end
		end
	end

	for _, d in facility:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "TaskWallButton" then
			local domeStage = d:GetAttribute("DomeStage")
			if typeof(domeStage) == "number" then
				local di = math.floor((domeStage :: number) + 0.5)
				local pp = d:FindFirstChildOfClass("ProximityPrompt")
				if not pp then
					pp = Instance.new("ProximityPrompt")
					pp.ObjectText = "Сектор " .. tostring(di)
					pp.HoldDuration = 0
					pp.MaxActivationDistance = 18
					pp.RequiresLineOfSight = false
					pp.ClickablePrompt = true
					pp.Parent = d
				end
				pp.ActionText = "Обновить протокол"
				pp.Triggered:Connect(function()
					refreshHud(true, di, true)
				end)
			end
		end
	end

	facility:GetAttributeChangedSignal("ActiveTaskStage"):Connect(refreshPrompts)
	task.defer(refreshPrompts)
end

task.defer(function()
	local rem = getRemotes()
	if not rem or not rem.getState or not rem.submit then
		warn("[WallTask] Remotes missing — HUD disabled")
		return
	end
	remotes = { getState = rem.getState :: RemoteFunction, submit = rem.submit :: RemoteFunction }

	local function scheduleRefresh()
		refreshHud(false, nil)
	end

	player:GetAttributeChangedSignal("DomeOpeningActive"):Connect(scheduleRefresh)
	player:GetAttributeChangedSignal("DomeEncounterActive"):Connect(scheduleRefresh)
	player:GetAttributeChangedSignal("DomeCellStage"):Connect(scheduleRefresh)
	player:GetAttributeChangedSignal("DomeIntegrity"):Connect(scheduleRefresh)
	player:GetAttributeChangedSignal("DomeZeroG"):Connect(scheduleRefresh)
	player:GetAttributeChangedSignal("DomePhase"):Connect(scheduleRefresh)

	RunService.Heartbeat:Connect(function()
		if submitting then
			return
		end
		local pg = player:FindFirstChild("PlayerGui")
		local hud = pg and pg:FindFirstChild(HUD_NAME)
		if hud and hud:IsA("ScreenGui") then
			local panel = hud:FindFirstChild("Panel")
			if panel and panel:IsA("Frame") then
				if player:GetAttribute("DomeZeroG") == 1 then
					local t = os.clock()
					local ox = math.clamp(math.cos(t * 1.4) * ZERO_G_WOBBLE_MAX.X, -ZERO_G_WOBBLE_MAX.X, ZERO_G_WOBBLE_MAX.X)
					local oy = math.clamp(math.sin(t * 1.9) * ZERO_G_WOBBLE_MAX.Y, -ZERO_G_WOBBLE_MAX.Y, ZERO_G_WOBBLE_MAX.Y)
					panel.Position = UDim2.new(1, -12 + ox, 0, 12 + oy)
				else
					panel.Position = UDim2.new(1, -12, 0, 12)
				end
			end
		end

		if not shouldShowHud() then
			if hud then
				destroyHud()
			end
			return
		end
		local now = os.clock()
		if now - lastRefresh < REFRESH_INTERVAL then
			return
		end
		lastRefresh = now
		refreshHud(false, nil, false)
	end)

	task.defer(scheduleRefresh)
	task.delay(0.15, scheduleRefresh)
	task.delay(0.6, scheduleRefresh)

	local function onFacilityReady(m: Model)
		facilityModel = m
		answerCubesBound = false
		orientAllBlackboards(m)
		bindAnswerCubes(m)
		bindPrompts(m)
		scheduleRefresh()
	end

	task.defer(function()
		local m = waitFacility()
		if m then
			onFacilityReady(m)
		else
			local conn: RBXScriptConnection?
			conn = Workspace.ChildAdded:Connect(function(ch)
				if ch.Name == "MatanTestIqRoom" and ch:IsA("Model") then
					if conn then
						conn:Disconnect()
					end
					onFacilityReady(ch)
				end
			end)
			warn("[WallTask] MatanTestIqRoom not ready yet — waiting for map build")
		end
	end)
end)
