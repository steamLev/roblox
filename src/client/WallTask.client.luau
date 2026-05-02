--!strict
--[[ Задание и варианты — SurfaceGui на Screen_Surface (описание на стене). Верхний HUD не используется. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local TASK_GUI_NAME = "TaskSurfaceGui"

local function waitRoom(): Model
	return Workspace:WaitForChild("MatanTestIqRoom", 60) :: Model
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

local function destroyTaskSurface(screen: BasePart?)
	if not screen then
		return
	end
	local g = screen:FindFirstChild(TASK_GUI_NAME)
	if g then
		g:Destroy()
	end
end

local function mountWallPanel(screen: BasePart, st: any, submit: RemoteFunction)
	destroyTaskSurface(screen)

	local sg = Instance.new("SurfaceGui")
	sg.Name = TASK_GUI_NAME
	sg.Adornee = screen
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 32
	sg.LightInfluence = 0.35
	sg.AlwaysOnTop = true
	sg.ResetOnSpawn = false
	sg.ZOffset = 0.02
	sg.ClipsDescendants = false
	sg.Parent = screen

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.fromScale(1, 1)
	frame.Position = UDim2.fromScale(0, 0)
	frame.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = false
	frame.Parent = sg

	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 10)
	fc.Parent = frame

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = frame

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.Parent = frame

	-- Доли высоты канваса: сумма < 1, иначе варианты обрезаются за пределами SurfaceGui.
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.07, 0)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(230, 235, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Задание"
	title.LayoutOrder = 1
	title.Parent = frame

	local attempts = Instance.new("TextLabel")
	attempts.BackgroundTransparency = 1
	attempts.Size = UDim2.new(1, 0, 0.055, 0)
	attempts.Font = Enum.Font.Gotham
	attempts.TextScaled = true
	attempts.TextColor3 = Color3.fromRGB(160, 190, 255)
	attempts.TextXAlignment = Enum.TextXAlignment.Left
	local al = st.attemptsLeft
	if typeof(al) == "number" then
		attempts.Text = string.format("Осталось попыток: %d из 3", al)
	else
		attempts.Text = ""
	end
	attempts.LayoutOrder = 2
	attempts.Parent = frame

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 0.26, 0)
	body.Font = Enum.Font.Gotham
	body.TextScaled = true
	body.TextColor3 = Color3.fromRGB(245, 247, 255)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	local text = st.prompt
	local msg = st.message
	body.Text = if typeof(text) == "string" and text ~= "" then text elseif typeof(msg) == "string" then msg else ""
	body.LayoutOrder = 3
	body.Parent = frame

	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0.56, 0)
	grid.LayoutOrder = 4
	grid.Parent = frame

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.46, -4, 0.44, -6)
	layout.CellPadding = UDim2.new(0.04, 0, 0.04, 0)
	layout.FillDirectionMaxCells = 2
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local choices = st.choices
	local token = st.problemToken
	if typeof(choices) == "table" and typeof(token) == "string" and not st.completed then
		for i, opt in ipairs(choices :: { any }) do
			if typeof(opt) == "string" then
				local choiceIndex = i - 1
				local b = Instance.new("TextButton")
				b:SetAttribute("ChoiceIndex", choiceIndex)
				b.Text = opt
				b.Font = Enum.Font.GothamMedium
				b.TextScaled = true
				b.TextWrapped = true
				b.TextColor3 = Color3.fromRGB(255, 255, 255)
				b.BackgroundColor3 = Color3.fromRGB(55, 95, 170)
				b.AutoButtonColor = true
				b.LayoutOrder = choiceIndex
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0, 8)
				c.Parent = b
				local function doSubmit()
					local idxRaw = b:GetAttribute("ChoiceIndex")
					local idx = if typeof(idxRaw) == "number" then math.floor((idxRaw :: number) + 0.5) else choiceIndex
					local ok, res = pcall(function()
						return submit:InvokeServer({
							problemToken = token,
							choiceIndex = idx,
						})
					end)
					if ok and typeof(res) == "table" then
						local r = res :: any
						if r.ok then
							destroyTaskSurface(screen)
						else
							mountWallPanel(screen, r, submit)
						end
					end
				end
				b.Activated:Connect(doSubmit)
				b.Parent = grid
			end
		end
	end
end

task.defer(function()
	local room = waitRoom()
	local screen = room:WaitForChild("Screen_Surface", 30) :: BasePart?
	if not screen then
		return
	end
	destroyTaskSurface(screen)

	local rem = getRemotes()
	if not rem or not rem.getState or not rem.submit then
		return
	end

	local taskBtn = room:WaitForChild("TaskWallButton", 30) :: BasePart?

	if taskBtn then
		local pp = taskBtn:FindFirstChildOfClass("ProximityPrompt")
		if not pp then
			pp = Instance.new("ProximityPrompt")
			pp.ObjectText = "Панель"
			pp.HoldDuration = 0
			pp.MaxActivationDistance = 10
			pp.RequiresLineOfSight = false
			pp.Parent = taskBtn
		end
		pp.ActionText = "Показать задание"
		pp.Triggered:Connect(function()
			local ok, st = pcall(function()
				return rem.getState:InvokeServer(true)
			end)
			if not ok or typeof(st) ~= "table" then
				return
			end
			mountWallPanel(screen, st :: any, rem.submit :: RemoteFunction)
		end)
	end
end)
