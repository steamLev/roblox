--!strict
--[[
	Цепочка стеклянных куполов на лугу (референс: hex-стекло, доска, арки, лес).
	Корень: Workspace.MatanTestIqRoom
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local DOME_COUNT = 5
local INNER = Vector3.new(34, 12, 34)
local WALL_T = 0.75
local STRIDE = INNER.X + 6

local COL_STONE = Color3.fromRGB(118, 122, 128)
local COL_STONE_DARK = Color3.fromRGB(88, 92, 98)
local COL_BOARD = Color3.fromRGB(28, 58, 38)
local COL_GLASS = Color3.fromRGB(130, 200, 255)
local COL_HEX = Color3.fromRGB(70, 160, 255)
local COL_GRASS = Color3.fromRGB(72, 132, 62)
local COL_ARCH = Color3.fromRGB(102, 108, 118)

local GlassDomeFacility = {}

GlassDomeFacility.DOME_COUNT = DOME_COUNT
GlassDomeFacility.STRIDE = STRIDE

local function mk(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material,
	collide: boolean
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide
	p.CastShadow = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function addSurfaceText(part: BasePart, face: Enum.NormalId, lines: { string }, textSize: number, textColor: Color3)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "SignGui"
	sg.Adornee = part
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.ResetOnSpawn = false
	sg.AlwaysOnTop = true
	sg.Active = true
	sg.ZOffset = 0.12
	sg.MaxDistance = 280
	sg.Parent = part

	local bg = Instance.new("Frame")
	bg.Name = "SignBg"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(8, 22, 14)
	bg.BackgroundTransparency = 0.02
	bg.BorderSizePixel = 0
	bg.Active = false
	bg.Parent = sg

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 200, 140)
	stroke.Thickness = 2
	stroke.Transparency = 0.35
	stroke.Parent = bg

	local y = 8
	for _, line in ipairs(lines) do
		local tl = Instance.new("TextLabel")
		tl.BackgroundTransparency = 1
		tl.Size = UDim2.new(1, -16, 0, textSize + 12)
		tl.Position = UDim2.fromOffset(8, y)
		tl.Font = Enum.Font.GothamBold
		tl.TextSize = textSize
		tl.TextColor3 = textColor
		tl.Text = line
		tl.TextWrapped = true
		tl.TextStrokeTransparency = 0.55
		tl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		tl.Active = false
		tl.Parent = bg
		y += textSize + 14
	end
end

local function mkGlassHemisphere(parent: Instance, ox: number, radius: number, wallTopY: number): Part
	-- Полусфера: Sphere mesh с Scale.y = 50% (не целый Ball), низ на wallTopY
	local diameter = radius * 2
	local shell = Instance.new("Part")
	shell.Name = "GlassDomeShell"
	shell.Size = Vector3.new(1, 1, 1)
	shell.CFrame = CFrame.new(ox, wallTopY + diameter * 0.25, 0)
	shell.Anchored = true
	shell.CanCollide = false
	shell.Material = Enum.Material.Glass
	shell.Color = COL_GLASS
	shell.Transparency = 0.14
	shell.Reflectance = 0.28
	shell.CastShadow = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.Parent = parent

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(diameter, diameter * 0.5, diameter)
	mesh.Parent = shell

	local rim = mk(
		"HemisphereRim",
		Vector3.new(diameter * 0.98, 0.2, diameter * 0.98),
		CFrame.new(ox, wallTopY + 0.08, 0),
		COL_HEX,
		Enum.Material.Neon,
		false
	)
	rim.Transparency = 0.35
	rim.CanCollide = false
	rim.Parent = parent

	local highlight = Instance.new("Highlight")
	highlight.Name = "DomeShellHighlight"
	highlight.Adornee = shell
	highlight.FillTransparency = 0.72
	highlight.FillColor = COL_HEX
	highlight.OutlineTransparency = 0.05
	highlight.OutlineColor = COL_HEX
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = shell

	local glow = Instance.new("PointLight")
	glow.Name = "DomeGlow"
	glow.Color = COL_HEX
	glow.Brightness = 1.15
	glow.Range = radius * 1.5
	glow.Parent = shell

	local grid = Instance.new("Folder")
	grid.Name = "HexGrid"
	grid.Parent = parent
	local capSpan = diameter * 0.5
	local yBase = wallTopY
	for ring = 1, 4 do
		local t = ring / 4
		local ry = yBase + capSpan * (0.18 + t * 0.78)
		local ringR = radius * math.sqrt(math.max(0, 1 - t * t * 0.88)) * 0.94
		local segments = 10 + ring * 2
		for s = 0, segments - 1 do
			local ang = (s / segments) * math.pi * 2
			local seg = mk(
				"HexRing_" .. ring .. "_" .. s,
				Vector3.new(0.12, 0.12, ringR * 0.5),
				CFrame.new(ox + math.cos(ang) * ringR, ry, math.sin(ang) * ringR) * CFrame.Angles(0, ang, math.pi / 2),
				COL_HEX,
				Enum.Material.Neon,
				false
			)
			seg.Transparency = 0.02
			seg.CanCollide = false
			seg.CastShadow = false
			seg.Parent = grid
		end
	end

	return shell
end

local function mkBlackboard(cell: Model, ox: number, yWall: number, backZ: number, stage: number)
	local boardW, boardH = 13, 8.5
	local boardY = yWall * 0.88
	-- Задняя стена (−Z): −Z доски в стену → Front (+Z) к игроку; SurfaceGui на Front
	local boardPos = Vector3.new(ox, boardY, backZ + 0.45)
	local boardCf = CFrame.lookAt(boardPos, Vector3.new(ox, boardY, backZ + 2))
	local board = mk(
		"MainBlackboard",
		Vector3.new(boardW, boardH, 0.45),
		boardCf,
		COL_BOARD,
		Enum.Material.SmoothPlastic,
		true
	)
	board.Parent = cell

	local lines = if stage == 1
		then { "Вычислите выражение:", "2/3 + 1/6 = ?", "A) 1/2   B) 5/6   C) 3/4" }
		else { "Стабилизируйте щит", "Сектор " .. tostring(stage), "Откройте протокол" }
	addSurfaceText(board, Enum.NormalId.Front, lines, 28, Color3.fromRGB(245, 250, 240))

	local taskPad = mk(
		"TaskWallButton",
		Vector3.new(boardW * 0.85, boardH * 0.85, 0.5),
		board.CFrame * CFrame.new(0, 0, 0.55),
		Color3.fromRGB(40, 100, 60),
		Enum.Material.SmoothPlastic,
		false
	)
	taskPad.Transparency = 1
	taskPad.CanQuery = false
	taskPad:SetAttribute("DomeStage", stage)
	taskPad.Parent = cell
end

local function mkTerminal(cell: Model, cf: CFrame, label: string)
	local ped = mk("Pedestal", Vector3.new(1.2, 2.2, 1.2), cf * CFrame.new(0, -1.1, 0), COL_STONE_DARK, Enum.Material.Slate, true)
	ped.Parent = cell
	local screen = mk("TerminalScreen", Vector3.new(1.5, 1.1, 0.25), cf, Color3.fromRGB(40, 120, 220), Enum.Material.Neon, false)
	screen.Parent = cell
	addSurfaceText(screen, Enum.NormalId.Front, { label }, 22, Color3.fromRGB(200, 230, 255))
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(80, 160, 255)
	pl.Brightness = 1.2
	pl.Range = 10
	pl.Parent = screen
end

local ANSWER_CUBE_GLOWS = {
	Color3.fromRGB(80, 140, 255),
	Color3.fromRGB(160, 90, 255),
	Color3.fromRGB(90, 200, 140),
	Color3.fromRGB(255, 160, 90),
}

local function addCubeTopLabel(part: BasePart, text: string)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "AnswerLabel"
	sg.Face = Enum.NormalId.Top
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 50
	sg.LightInfluence = 0
	sg.AlwaysOnTop = false
	sg.Parent = part

	local tl = Instance.new("TextLabel")
	tl.Name = "Label"
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamBlack
	tl.TextScaled = true
	tl.TextColor3 = Color3.fromRGB(245, 250, 255)
	tl.TextStrokeTransparency = 0.4
	tl.Text = text
	tl.Parent = sg
end

-- Четыре куба-ответа в куполе: клиент вешает ProximityPrompt (E) и шлёт choiceIndex
local function mkAnswerCubes(cell: Model, ox: number, sz: number, stage: number)
	local folder = Instance.new("Folder")
	folder.Name = "AnswerCubes"
	folder.Parent = cell

	local offsets = {
		Vector3.new(-sz * 0.32, 0.95, sz * 0.18),
		Vector3.new(-sz * 0.1, 0.95, sz * 0.26),
		Vector3.new(sz * 0.1, 0.95, sz * 0.26),
		Vector3.new(sz * 0.32, 0.95, sz * 0.18),
	}

	for i = 0, 3 do
		local off = offsets[i + 1]
		local glow = ANSWER_CUBE_GLOWS[i + 1]
		local cube = mk(
			"AnswerCube_" .. tostring(i),
			Vector3.new(1.45, 1.45, 1.45),
			CFrame.new(ox + off.X, off.Y, off.Z),
			Color3.fromRGB(58, 64, 78),
			Enum.Material.SmoothPlastic,
			true
		)
		cube:SetAttribute("ChoiceIndex", i)
		cube:SetAttribute("DomeStage", stage)
		cube.Parent = folder

		local cap = mk(
			"AnswerCubeGlow_" .. tostring(i),
			Vector3.new(1.2, 0.18, 1.2),
			cube.CFrame * CFrame.new(0, cube.Size.Y * 0.5 + 0.06, 0),
			glow,
			Enum.Material.Neon,
			false
		)
		cap.CanCollide = false
		cap.Parent = folder

		local pl = Instance.new("PointLight")
		pl.Color = glow
		pl.Brightness = 0.35
		pl.Range = 10
		pl.Parent = cube

		addCubeTopLabel(cube, string.char(65 + i))

		local pp = Instance.new("ProximityPrompt")
		pp.Name = "AnswerPrompt"
		pp.KeyboardKeyCode = Enum.KeyCode.E
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 14
		pp.RequiresLineOfSight = false
		pp.ClickablePrompt = true
		pp.Enabled = false
		pp.Parent = cube
	end
end

local function mkStoneArch(cell: Model, ox: number, halfX: number, yWall: number, stage: number, hasExit: boolean)
	local archX = ox + halfX - WALL_T * 0.5
	local archZ = 0
	local pillarH = yWall + 1.5
	local gapW, gapH = 8, yWall + 0.5

	local arch = Instance.new("Model")
	arch.Name = "ExitArch"
	arch.Parent = cell

	local pL = mk("ArchPillarL", Vector3.new(1.4, pillarH, 1.4), CFrame.new(archX, pillarH / 2, archZ - gapW / 2), COL_ARCH, Enum.Material.Slate, true)
	pL.Parent = arch
	local pR = mk("ArchPillarR", Vector3.new(1.4, pillarH, 1.4), CFrame.new(archX, pillarH / 2, archZ + gapW / 2), COL_ARCH, Enum.Material.Slate, true)
	pR.Parent = arch
	local lintel = mk("ArchLintel", Vector3.new(1.6, 1.2, gapW + 2.2), CFrame.new(archX, pillarH + 0.4, archZ), COL_ARCH, Enum.Material.Slate, true)
	lintel.Parent = arch

	if hasExit then
		local field = mk(
			"ExitDoor",
			Vector3.new(0.5, gapH, gapW - 0.5),
			CFrame.new(archX + 0.3, gapH / 2, archZ),
			Color3.fromRGB(60, 180, 255),
			Enum.Material.Neon,
			true
		)
		field.Transparency = 0.55
		field:SetAttribute("HingeWorldX", archX)
		field:SetAttribute("HingeWorldY", gapH / 2)
		field:SetAttribute("HingeWorldZ", archZ)
		field:SetAttribute("ExitFromStage", stage)
		field:SetAttribute("IsEnergyField", true)
		field.Parent = arch

		local spark = Instance.new("ParticleEmitter")
		spark.Name = "FieldSparks"
		spark.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		spark.Rate = 12
		spark.Lifetime = NumberRange.new(0.2, 0.5)
		spark.Speed = NumberRange.new(0.5, 2)
		spark.Color = ColorSequence.new(COL_HEX)
		spark.LightEmission = 1
		spark.Parent = field
	end
end

local function buildForest(parent: Model, center: Vector3, radius: number)
	local trees = Instance.new("Folder")
	trees.Name = "Forest"
	trees.Parent = parent

	local rng = Random.new(42)
	for i = 1, 48 do
		local ang = rng:NextNumber(0, math.pi * 2)
		local dist = radius * (0.55 + rng:NextNumber() * 0.45)
		local tx = center.X + math.cos(ang) * dist
		local tz = center.Z + math.sin(ang) * dist
		local th = 14 + rng:NextNumber() * 10

		local trunk = mk("Trunk", Vector3.new(1.2, th * 0.55, 1.2), CFrame.new(tx, th * 0.28, tz), Color3.fromRGB(92, 62, 38), Enum.Material.Wood, true)
		trunk.Parent = trees
		for layer = 0, 2 do
			local cone = mk(
				"Needles",
				Vector3.new(7 - layer * 1.5, 5, 7 - layer * 1.5),
				CFrame.new(tx, th * 0.55 + 2 + layer * 3.2, tz),
				Color3.fromRGB(34, 78 + layer * 8, 38),
				Enum.Material.Grass,
				true
			)
			cone.Parent = trees
		end
	end
end

local function buildMeadow(parent: Model, size: number)
	local ground = mk("Meadow", Vector3.new(size, 1, size), CFrame.new(0, -0.5, 0), COL_GRASS, Enum.Material.Grass, true)
	ground.CastShadow = false
	ground.Parent = parent

	local flowers = Instance.new("Folder")
	flowers.Name = "Flowers"
	flowers.Parent = parent
	local rng = Random.new(7)
	for i = 1, 120 do
		local fx = rng:NextNumber(-size * 0.4, size * 0.4)
		local fz = rng:NextNumber(-size * 0.4, size * 0.4)
		local petal = mk(
			"Flower",
			Vector3.new(0.35, 0.35, 0.35),
			CFrame.new(fx, 0.2, fz),
			if i % 3 == 0 then Color3.fromRGB(255, 240, 120) else Color3.fromRGB(245, 245, 250),
			Enum.Material.SmoothPlastic,
			false
		)
		petal.CanCollide = false
		petal.Parent = flowers
	end
end

local function applyOutdoorLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.4
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.Ambient = Color3.fromRGB(150, 165, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 145, 130)
	Lighting.GeographicLatitude = 32
end

local function buildCell(index: number, rootX: number, isLast: boolean): Model
	local cell = Instance.new("Model")
	cell.Name = "Cell_" .. index

	local sx, sy, sz = INNER.X, INNER.Y, INNER.Z
	local t = WALL_T
	local halfX = sx / 2 + t / 2
	local halfZ = sz / 2 + t / 2
	local yWall = sy / 2
	local ox = rootX
	local domeR = math.max(sx, sz) * 0.52

	-- Каменная плитка (пол купола)
	local floor = mk("Floor", Vector3.new(sx + t, 1, sz + t), CFrame.new(ox, 0, 0), COL_STONE, Enum.Material.Slate, true)
	floor.CastShadow = false
	floor.Parent = cell

	for tx = -2, 2 do
		for tz = -2, 2 do
			local tile = mk(
				"FloorTile",
				Vector3.new(sx / 5, 0.15, sz / 5),
				CFrame.new(ox + tx * (sx / 5), 0.08, tz * (sz / 5)),
				Color3.fromRGB(108 + tx, 112, 118 + tz),
				Enum.Material.Cobblestone,
				false
			)
			tile.CanCollide = false
			tile.Parent = cell
		end
	end

	local yGlass = yWall * 0.5
	local archGapZ = 8
	local function glassWall(name: string, size: Vector3, cf: CFrame)
		local w = mk(name, size, cf, COL_GLASS, Enum.Material.Glass, true)
		w.Transparency = 0.72
		w.Parent = cell
	end
	glassWall("Wall_Back", Vector3.new(sx, sy, t), CFrame.new(ox, yGlass, -halfZ))
	glassWall("Wall_Front", Vector3.new(sx, sy, t), CFrame.new(ox, yGlass, halfZ))
	if index == 1 then
		glassWall("Wall_Left", Vector3.new(t, sy, sz), CFrame.new(ox - halfX, yGlass, 0))
	end
	if isLast then
		glassWall("Wall_Right", Vector3.new(t, sy, sz), CFrame.new(ox + halfX, yGlass, 0))
	else
		local segZ = (sz - archGapZ) / 2
		if segZ > 0.5 then
			glassWall(
				"Wall_Right_N",
				Vector3.new(t, sy, segZ),
				CFrame.new(ox + halfX, yGlass, -(archGapZ / 2 + segZ / 2))
			)
			glassWall(
				"Wall_Right_S",
				Vector3.new(t, sy, segZ),
				CFrame.new(ox + halfX, yGlass, archGapZ / 2 + segZ / 2)
			)
		end
	end
	-- между куполами: со стороны −X у ячеек 2+ проход от арки предыдущего сектора

	local wallTopY = yGlass + sy * 0.5
	local dome = mkGlassHemisphere(cell, ox, domeR, wallTopY)

	mkBlackboard(cell, ox, yWall, -halfZ + t, index)
	mkAnswerCubes(cell, ox, sz, index)

	-- Терминалы по бокам (как на референсе)
	mkTerminal(cell, CFrame.new(ox - sx * 0.32, 2.8, sz * 0.1), "3/8 + 1/4")
	mkTerminal(cell, CFrame.new(ox + sx * 0.3, 2.8, -sz * 0.15), "5/6 − 1/3")
	mkTerminal(cell, CFrame.new(ox - sx * 0.12, 2.8, sz * 0.32), "2/5 + 1/10")

	if index == 1 then
		local apex = mk(
			"DomeApex",
			Vector3.new(0.6, 0.6, 0.6),
			CFrame.new(ox, wallTopY + domeR * 2.04 + 0.2, 0),
			Color3.fromRGB(255, 60, 60),
			Enum.Material.Neon,
			false
		)
		apex.Transparency = 1
		apex.CanCollide = false
		apex.CanQuery = false
		apex.Parent = cell

		for fi, off in ipairs({
			Vector3.new(-sx * 0.28, 1.2, sz * 0.12),
			Vector3.new(sx * 0.22, 1.5, -sz * 0.18),
			Vector3.new(0, 1.0, sz * 0.25),
		}) do
			local crate = mk("FloatProp_" .. fi, Vector3.new(1.4, 1.1, 1.4), CFrame.new(ox + off.X, off.Y, off.Z), Color3.fromRGB(72, 88, 118), Enum.Material.Metal, true)
			crate.Anchored = true
			crate.Parent = cell
		end
	end

	-- Турель на ободе купола
	local turret = mk(
		"DomeTurret",
		Vector3.new(1.6, 0.55, 2),
		CFrame.new(ox + halfX - 2.5, sy - 0.5, halfZ - 2),
		Color3.fromRGB(48, 52, 58),
		Enum.Material.Metal,
		false
	)
	turret.Parent = cell
	local spot = Instance.new("SpotLight")
	spot.Name = "TurretLight"
	spot.Brightness = 0
	spot.Range = 48
	spot.Angle = 36
	spot.Color = Color3.fromRGB(255, 235, 190)
	spot.Parent = turret

	if not isLast then
		mkStoneArch(cell, ox, halfX, yWall, index, true)
	end

	local anchor = mk("DroneAnchor", Vector3.new(0.4, 0.4, 0.4), CFrame.new(ox, sy + 1.5, 0), COL_HEX, Enum.Material.Neon, false)
	anchor.Transparency = 1
	anchor.CanQuery = false
	anchor.Parent = cell

	cell:SetAttribute("DomeCenterX", ox)
	cell:SetAttribute("DomeCenterZ", 0)
	cell:SetAttribute("DomeRadius", domeR)

	return cell
end

function GlassDomeFacility.build(): Model
	for _, n in { "MatanCorridor", "MatanTestIqRoom", "GlassDomeFacility" } do
		local old = Workspace:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end

	applyOutdoorLighting()

	local facility = Instance.new("Model")
	facility.Name = "MatanTestIqRoom"

	buildMeadow(facility, 320)
	buildForest(facility, Vector3.zero, 130)

	local totalW = (DOME_COUNT - 1) * STRIDE
	local startX = -totalW / 2

	local cell1: Model? = nil
	for i = 1, DOME_COUNT do
		local rootX = startX + (i - 1) * STRIDE
		local cell = buildCell(i, rootX, i == DOME_COUNT)
		cell.Parent = facility
		if i == 1 then
			cell1 = cell
		end
	end

	local firstX = startX
	local sx, _, sz = INNER.X, INNER.Y, INNER.Z
	local halfZ = sz / 2 + WALL_T / 2
	local backZ = -halfZ + WALL_T
	local spawnPos = Vector3.new(firstX, 4, sz * 0.12)
	local lookAt = Vector3.new(firstX, INNER.Y * 0.75, backZ)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn_Cell1"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.lookAt(spawnPos, lookAt)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.Duration = 0
	spawn.AllowTeamChangeOnTouch = false
	if cell1 then
		spawn.Parent = cell1
	else
		spawn.Parent = facility
	end
	facility:SetAttribute("SpawnCell", "Cell_1")

	facility.WorldPivot = CFrame.new(0, 0, 0)
	facility.Parent = Workspace
	return facility
end

function GlassDomeFacility.getCellSpawnCFrame(cellIndex: number): CFrame?
	local root = Workspace:FindFirstChild("MatanTestIqRoom")
	if not root or not root:IsA("Model") then
		return nil
	end
	local cell = root:FindFirstChild("Cell_" .. tostring(cellIndex))
	if cellIndex == 1 then
		local sp = cell and cell:FindFirstChild("Spawn_Cell1")
		if sp and sp:IsA("SpawnLocation") then
			return sp.CFrame + Vector3.new(0, 3.5, 0)
		end
	end
	local sx, _, sz = INNER.X, INNER.Y, INNER.Z
	local totalW = (DOME_COUNT - 1) * STRIDE
	local startX = -totalW / 2
	local ox = startX + (cellIndex - 1) * STRIDE
	local halfZ = sz / 2 + WALL_T / 2
	local backZ = -halfZ + WALL_T
	local spawnPos = Vector3.new(ox, 4, sz * 0.12)
	local lookAt = Vector3.new(ox, INNER.Y * 0.75, backZ)
	return CFrame.lookAt(spawnPos, lookAt)
end

return GlassDomeFacility
