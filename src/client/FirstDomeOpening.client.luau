--!strict
--[[
	First dome 60 s — client readability + panic (DomeOpeningBeat / DomeIntegrity).
	Starts on spawn via server DomeOpeningActive (no wall interaction required).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local FirstDomeOpening = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("FirstDomeOpening"))

local player = Players.LocalPlayer

local PULL_STUDS = 8
local PULL_STRENGTH = 42

local lastBeat = -1
local lastImpactAt = 0
local subliminalFired = false
local swarmHintShown = false

local function waitFacility(): Model?
	return Workspace:WaitForChild("MatanTestIqRoom", 90) :: Model?
end

local function enhanceDomeVisibility(facility: Model)
	for _, desc in facility:GetDescendants() do
		if desc:IsA("BasePart") and desc.Name == "GlassDomeShell" then
			desc.Material = Enum.Material.Glass
			desc.Transparency = math.min(desc.Transparency, 0.18)
			desc.Reflectance = math.max(desc.Reflectance, 0.22)
			local hl = desc:FindFirstChild("DomeShellHighlight")
			if hl and hl:IsA("Highlight") then
				hl.FillTransparency = 0.68
				hl.OutlineTransparency = 0.04
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			end
		elseif desc:IsA("BasePart") and string.sub(desc.Name, 1, 8) == "HexRing_" then
			desc.Transparency = math.min(desc.Transparency, 0.05)
		end
	end
end

local function cell1Parts(facility: Model): (BasePart?, BasePart?, BasePart?)
	local cell = facility:FindFirstChild("Cell_1")
	if not cell or not cell:IsA("Model") then
		return nil, nil, nil
	end
	local shell = cell:FindFirstChild("GlassDomeShell") :: BasePart?
	local apex = cell:FindFirstChild("DomeApex") :: BasePart?
	local taskPad = cell:FindFirstChild("TaskWallButton", true) :: BasePart?
	return shell, apex, taskPad
end

local function isOpeningFxActive(): boolean
	if player:GetAttribute("DomeOpeningActive") == true then
		return true
	end
	return player:GetAttribute("DomeEncounterActive") == true and player:GetAttribute("DomeCellStage") == 1
end

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "FirstDomeOpeningFx"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 40
gui.Parent = player:WaitForChild("PlayerGui")

local objective = Instance.new("TextLabel")
objective.Name = "Objective"
objective.AnchorPoint = Vector2.new(0.5, 0)
objective.Position = UDim2.fromScale(0.5, 0.88)
objective.Size = UDim2.fromOffset(480, 32)
objective.BackgroundTransparency = 1
objective.Font = Enum.Font.GothamBold
objective.TextSize = 20
objective.TextColor3 = Color3.fromRGB(200, 230, 255)
objective.Text = "→ К зелёной доске: стабилизируйте щит"
objective.TextTransparency = 0
objective.Visible = false
objective.Active = false
objective.Selectable = false
objective.Parent = gui

local swarmHint = Instance.new("TextLabel")
swarmHint.Name = "SwarmHint"
swarmHint.AnchorPoint = Vector2.new(0.5, 0.5)
swarmHint.Position = UDim2.fromScale(0.5, 0.38)
swarmHint.Size = UDim2.fromOffset(400, 32)
swarmHint.BackgroundTransparency = 1
swarmHint.Font = Enum.Font.GothamMedium
swarmHint.TextSize = 18
swarmHint.TextColor3 = Color3.fromRGB(255, 120, 110)
swarmHint.Text = "Над куполом — рой"
swarmHint.TextTransparency = 1
swarmHint.Visible = false
swarmHint.Parent = gui

local integrityBar = Instance.new("Frame")
integrityBar.Name = "IntegrityBar"
integrityBar.AnchorPoint = Vector2.new(0.5, 0)
integrityBar.Position = UDim2.fromScale(0.5, 0.02)
integrityBar.Size = UDim2.fromOffset(280, 6)
integrityBar.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
integrityBar.BorderSizePixel = 0
integrityBar.Visible = false
integrityBar.Parent = gui
local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = Color3.fromRGB(90, 180, 255)
barFill.BorderSizePixel = 0
barFill.Parent = integrityBar
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = integrityBar
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = barFill

local vignette = Instance.new("Frame")
vignette.Name = "Vignette"
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundColor3 = Color3.fromRGB(80, 0, 0)
vignette.BackgroundTransparency = 1
vignette.BorderSizePixel = 0
vignette.Active = false
vignette.Selectable = false
vignette.Parent = gui

-- Audio
local audioFolder = Instance.new("Folder")
audioFolder.Name = "OpeningAudio"
audioFolder.Parent = SoundService

local function mkSound(name: string, id: string, vol: number): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = vol
	s.RollOffMaxDistance = 120
	s.Parent = audioFolder
	return s
end

local sndBuzz = mkSound("DroneBuzz", "rbxasset://sounds/electronicpingshort.wav", 0.12)
local sndImpact = mkSound("GlassHit", "rbxasset://sounds/impact_water.wav", 0.55)
local sndZG = mkSound("ZeroGSlam", "rbxasset://sounds/uuhhh.mp3", 0.35)
local sndWarning = mkSound("PreBreach", "rbxasset://sounds/electronicpingshort.wav", 0.22)

local function playOneShot(snd: Sound, pitch: number?)
	local clone = snd:Clone()
	clone.Parent = audioFolder
	if pitch then
		clone.PlaybackSpeed = pitch
	end
	clone:Play()
	clone.Ended:Once(function()
		clone:Destroy()
	end)
end

-- Laser
local laserFolder: Folder? = nil
local laserBeam: Beam? = nil
local laserOrigin: Part? = nil
local laserTarget: Part? = nil

local function ensureLaser(facility: Model, apex: BasePart)
	if laserFolder and laserFolder.Parent then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "OpeningLaserFx"
	folder.Parent = facility

	local origin = Instance.new("Part")
	origin.Name = "LaserOrigin"
	origin.Anchored = true
	origin.CanCollide = false
	origin.CanQuery = false
	origin.Transparency = 1
	origin.Size = Vector3.new(0.2, 0.2, 0.2)
	origin.Parent = folder

	local target = apex:Clone()
	target.Name = "LaserTarget"
	target.Parent = folder

	local a0 = Instance.new("Attachment")
	a0.Parent = origin
	local a1 = Instance.new("Attachment")
	a1.Parent = target

	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.35
	beam.Width1 = 0.55
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 50, 50))
	beam.Transparency = NumberSequence.new(0.08)
	beam.Enabled = false
	beam.Parent = origin

	laserFolder = folder
	laserBeam = beam
	laserOrigin = origin
	laserTarget = target
end

local function setLaser(active: boolean, apex: BasePart?)
	if not laserBeam or not laserOrigin or not laserTarget or not apex then
		return
	end
	laserBeam.Enabled = active
	if not active then
		return
	end
	local hover = apex.Position + Vector3.new(0, 14 + math.sin(os.clock() * 2) * 2, 0)
	laserOrigin.Position = hover
	laserTarget.Position = apex.Position
end

local crackDecals: { Decal } = {}

local function crackStage(integ: number): number
	if integ >= 90 then
		return 0
	elseif integ >= 60 then
		return 1
	elseif integ >= 40 then
		return 2
	else
		return 3
	end
end

local function applyCrack(shell: BasePart, stage: number)
	while #crackDecals < stage do
		local d = Instance.new("Decal")
		d.Name = "Crack_" .. (#crackDecals + 1)
		d.Face = Enum.NormalId.Top
		d.Color3 = Color3.fromRGB(255, 90, 90)
		d.Transparency = 0.15 + (#crackDecals) * 0.12
		d.Texture = "rbxasset://textures/ui/GuiImagePlaceholder.png"
		d.Parent = shell
		table.insert(crackDecals, d)
	end
	for i, d in ipairs(crackDecals) do
		d.Transparency = if i <= stage then 0.2 + (i - 1) * 0.15 else 1
	end
	if stage >= 2 then
		shell.Color = Color3.fromRGB(200, 210, 240)
	end
	if stage >= 3 then
		TweenService:Create(shell, TweenInfo.new(0.15), { Transparency = math.min(shell.Transparency + 0.08, 0.32) }):Play()
	end
end

local function pulseGlass(shell: BasePart)
	local t0 = shell.Transparency
	TweenService:Create(shell, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = math.max(0.45, t0 - 0.12),
	}):Play()
	task.delay(0.1, function()
		if shell.Parent then
			TweenService:Create(shell, TweenInfo.new(0.2), { Transparency = t0 }):Play()
		end
	end)
end

local function softPullToward(hrp: BasePart, goal: Vector3, dt: number)
	local flat = Vector3.new(goal.X - hrp.Position.X, 0, goal.Z - hrp.Position.Z)
	if flat.Magnitude > PULL_STUDS then
		hrp.AssemblyLinearVelocity += flat.Unit * PULL_STRENGTH * dt
	end
end

local function dimCoopNametags(dimming: boolean)
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if not char then
			continue
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.NameDisplayDistance = if dimming then 0 else 100
			hum.HealthDisplayDistance = if dimming then 0 else 100
		end
	end
end

local function flashSubliminal()
	local g = Instance.new("ScreenGui")
	g.Name = "OpeningSubliminal"
	g.ResetOnSpawn = false
	g.DisplayOrder = 100_000
	g.IgnoreGuiInset = true
	local f = Instance.new("ImageLabel")
	f.Size = UDim2.fromScale(0.35, 0.45)
	f.Position = UDim2.fromScale(0.62, 0.22)
	f.BackgroundTransparency = 1
	f.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
	f.ImageColor3 = Color3.fromRGB(180, 20, 35)
	f.ImageTransparency = 0.15
	f.Parent = g
	g.Parent = player:WaitForChild("PlayerGui")
	task.delay(0.05, function()
		if g.Parent then
			g:Destroy()
		end
	end)
end

local function playerLooksUp(): boolean
	local cam = Workspace.CurrentCamera
	if not cam then
		return false
	end
	return cam.CFrame.LookVector.Y > 0.55
end

local facility: Model? = nil
local shell: BasePart? = nil
local apex: BasePart? = nil
local taskPad: BasePart? = nil

local function bindFacility(m: Model)
	facility = m
	enhanceDomeVisibility(m)
	shell, apex, taskPad = cell1Parts(m)
	if shell and apex then
		ensureLaser(m, apex)
	end
end

task.defer(function()
	local m = waitFacility()
	if m then
		bindFacility(m)
	else
		Workspace.ChildAdded:Connect(function(ch)
			if ch.Name == "MatanTestIqRoom" and ch:IsA("Model") then
				bindFacility(ch)
			end
		end)
	end
end)

local function onBeatChanged(beat: number, elapsed: number)
	if beat == 1 and lastBeat < 1 then
		playOneShot(sndBuzz, 0.85)
	end
	if beat == 4 and lastBeat < 4 then
		playOneShot(sndZG, 0.7)
	end
	if beat == 5 and lastBeat < 5 then
		playOneShot(sndImpact, 1.1)
	end
	if elapsed >= FirstDomeOpening.ZERO_G_WARNING_ELAPSED and elapsed < FirstDomeOpening.ZERO_G_WARNING_ELAPSED + 0.5 and lastBeat <= 3 then
		playOneShot(sndWarning, 0.6)
	end
	lastBeat = beat
end

RunService.Heartbeat:Connect(function(dt)
	if not facility or not facility.Parent then
		facility = Workspace:FindFirstChild("MatanTestIqRoom") :: Model?
		if facility then
			enhanceDomeVisibility(facility)
			shell, apex, taskPad = cell1Parts(facility)
		else
			return
		end
	end
	if not isOpeningFxActive() then
		objective.Visible = false
		integrityBar.Visible = false
		vignette.BackgroundTransparency = 1
		swarmHint.Visible = false
		setLaser(false, apex)
		dimCoopNametags(false)
		sndBuzz:Stop()
		lastBeat = -1
		return
	end

	local beatRaw = player:GetAttribute("DomeOpeningBeat")
	local beat = if typeof(beatRaw) == "number" then math.floor(beatRaw + 0.5) else -1
	local integRaw = player:GetAttribute("DomeIntegrity")
	local integ = if typeof(integRaw) == "number" then (integRaw :: number) else 100
	local zeroG = player:GetAttribute("DomeZeroG") == 1
	local elapsedRaw = player:GetAttribute("DomeOpeningElapsed")
	local elapsed = if typeof(elapsedRaw) == "number" then (elapsedRaw :: number) else 0

	if beat ~= lastBeat and beat >= 0 then
		onBeatChanged(beat, elapsed)
	end

	-- Drone buzz layer (beats 1+)
	if beat >= 1 and beat < 5 then
		if not sndBuzz.IsPlaying then
			sndBuzz.Looped = true
			sndBuzz.PlaybackSpeed = 0.7 + beat * 0.08
			sndBuzz.Volume = 0.08 + beat * 0.03
			sndBuzz:Play()
		end
	else
		sndBuzz:Stop()
	end

	-- Objective: beats 0–1 (внизу, чтобы не перекрывать панель протокола)
	local pg = player:FindFirstChild("PlayerGui")
	local hasHud = pg and pg:FindFirstChild("DomeProtocolHud") ~= nil
	objective.Visible = beat >= 0 and beat <= 2 and not hasHud
	if beat == 0 and elapsed > 14 then
		objective.TextTransparency = math.min(objective.TextTransparency + dt * 0.7, 1)
	else
		objective.TextTransparency = math.max(0, objective.TextTransparency - dt * 2)
	end

	local warnZeroG = elapsed >= FirstDomeOpening.ZERO_G_WARNING_ELAPSED - 2
		and elapsed < FirstDomeOpening.FORCE_ZERO_G_AT
	integrityBar.Visible = integ < 90 or warnZeroG
	barFill.Size = UDim2.fromScale(math.clamp(integ / 100, 0.05, 1), 1)
	barFill.BackgroundColor3 = if warnZeroG
		then Color3.fromRGB(255, 140, 70)
		elseif integ < 45 then Color3.fromRGB(255, 90, 80)
		elseif integ < 70 then Color3.fromRGB(255, 180, 90)
		else Color3.fromRGB(90, 180, 255)
	if warnZeroG and beat < 4 then
		objective.Visible = not hasHud
		objective.Text = "⚠ Скоро невесомость — держите протокол в поле зрения"
		objective.TextTransparency = 0.15 + math.sin(os.clock() * 6) * 0.1
	end

	if shell then
		local cs = crackStage(integ)
		applyCrack(shell, cs)
		local now = os.clock()
		local impactInterval = if beat >= 3 then 2.2 elseif beat >= 2 then 4.5 else 99
		if beat >= 2 and now - lastImpactAt > impactInterval then
			lastImpactAt = now
			pulseGlass(shell)
			playOneShot(sndImpact, 0.9 + beat * 0.05)
		end
	end

	setLaser(beat >= 2 and beat < 5, apex)

	if integ < 55 or beat >= 3 then
		local targetT = if beat >= 4 then 0.72 elseif beat >= 3 then 0.82 else 0.9
		vignette.BackgroundTransparency = math.min(vignette.BackgroundTransparency, targetT)
	else
		vignette.BackgroundTransparency = 1
	end

	dimCoopNametags(beat >= 3)

	-- Subliminal ~48 s during zero-G
	if not subliminalFired and zeroG and FirstDomeOpening.shouldSubliminalFlash(elapsed, "ZERO_G") then
		subliminalFired = true
		flashSubliminal()
	end

	-- Swarm tease 55+ when looking up
	if elapsed >= FirstDomeOpening.SWARM_TEASE_ELAPSED and playerLooksUp() then
		swarmHint.Visible = true
		swarmHint.TextTransparency = math.max(0, swarmHint.TextTransparency - dt * 2)
		if not swarmHintShown then
			swarmHintShown = true
		end
	else
		swarmHint.TextTransparency = math.min(1, swarmHint.TextTransparency + dt * 3)
		if swarmHint.TextTransparency >= 0.99 then
			swarmHint.Visible = false
		end
	end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp and taskPad and zeroG then
		softPullToward(hrp, taskPad.Position, dt)
	end
end)

player:GetAttributeChangedSignal("DomeOpeningBeat"):Connect(function()
	local beatRaw = player:GetAttribute("DomeOpeningBeat")
	local beat = if typeof(beatRaw) == "number" then math.floor(beatRaw + 0.5) else -1
	if beat == 4 then
		local cam = Workspace.CurrentCamera
		if cam then
			local f0 = cam.FieldOfView
			TweenService:Create(cam, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = f0 + 6 }):Play()
			task.delay(0.4, function()
				if cam.Parent then
					TweenService:Create(cam, TweenInfo.new(0.5), { FieldOfView = f0 }):Play()
				end
			end)
		end
	end
	if beat == 5 then
		vignette.BackgroundTransparency = 1
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.CameraOffset = Vector3.new(0, -0.35, 0)
			task.delay(0.25, function()
				if hum.Parent then
					hum.CameraOffset = Vector3.zero
				end
			end)
		end
	end
end)

player:GetAttributeChangedSignal("DomeOpeningActive"):Connect(function()
	if player:GetAttribute("DomeOpeningActive") ~= true then
		subliminalFired = false
		swarmHintShown = false
		lastBeat = -1
	end
end)
