--!strict
--[[
  Комната в духе «IQ / test» в Roblox: светлый куб, «экран» на стене,
  нейтральный пол, потолочные «лампы». Подходит под HUD с задачами.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Plan = {
	innerSize: Vector3, -- X и Z — пол, Y — высота стен (внутри)
	wallThickness: number,
}

local DEFAULT: Plan = {
	innerSize = Vector3.new(42, 14, 32),
	wallThickness = 1,
}

local COL_FLOOR = Color3.fromRGB(232, 234, 238)
local COL_WALL = Color3.fromRGB(248, 249, 252)
local COL_CEIL = Color3.fromRGB(238, 240, 245)
local COL_TRIM = Color3.fromRGB(52, 152, 219)
local COL_SCREEN_FRAME = Color3.fromRGB(28, 30, 36)
local COL_SCREEN = Color3.fromRGB(44, 48, 58)
local COL_LIGHT_BAR = Color3.fromRGB(255, 255, 255)

local TestIqRoom = {}

local function attachSurfaceText(part: BasePart, face: Enum.NormalId, text: string, pixelsPerStud: number, bg: Color3)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "WallTextGui"
	sg.Adornee = part
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = pixelsPerStud
	sg.LightInfluence = 0.25
	sg.ResetOnSpawn = false
	sg.Parent = part
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = bg
	f.BackgroundTransparency = 0.12
	f.BorderSizePixel = 0
	f.Parent = sg
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, -12, 1, -12)
	tl.Position = UDim2.fromOffset(6, 6)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamBold
	tl.TextScaled = true
	tl.TextWrapped = true
	tl.TextColor3 = Color3.fromRGB(255, 255, 255)
	tl.Text = text
	tl.Parent = f
end

local function normalizeTextureId(raw: string): string
	local s = string.gsub(raw, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	if s == "" then
		return ""
	end
	if string.match(s, "^%d+$") then
		return "rbxassetid://" .. s
	end
	return s
end

-- Рисунок на стене: при заданном rbxassetid — Decal (надёжно на тонкой части); иначе текст на SurfaceGui.
local function attachFractionHintBoard(part: BasePart, face: Enum.NormalId, imageUriRaw: string)
	local imageUri = normalizeTextureId(imageUriRaw)
	if imageUri ~= "" then
		local d = Instance.new("Decal")
		d.Name = "FractionHintDecal"
		d.Face = face
		d.Texture = imageUri
		d.Color3 = Color3.new(1, 1, 1)
		d.Transparency = 0
		d.Parent = part
		return
	end

	local sg = Instance.new("SurfaceGui")
	sg.Name = "HintDiagramGui"
	sg.Adornee = part
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 24
	sg.LightInfluence = 0.2
	sg.ResetOnSpawn = false
	sg.Parent = part
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.fromRGB(52, 100, 168)
	f.BackgroundTransparency = 0.05
	f.BorderSizePixel = 0
	f.Parent = sg
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, -10, 1, -10)
	tl.Position = UDim2.fromOffset(5, 5)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.Gotham
	tl.TextScaled = true
	tl.TextWrapped = true
	tl.TextColor3 = Color3.fromRGB(255, 255, 255)
	tl.Text =
		"Схема: 1/2 + 1/3 = 3/6 + 2/6 = 5/6\n\nФайл картинки в репо: assets/FractionHint.png\nЗагрузите в Creator (вкладка Создать → Decal) и вставьте rbxassetid в Shared.AssetIds.FractionHintImage"
	tl.Parent = f
end

local function mk(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, collide: boolean): Part
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

function TestIqRoom.build(plan: Plan?): Model
	local pl = plan or DEFAULT
	local sx, sy, sz = pl.innerSize.X, pl.innerSize.Y, pl.innerSize.Z
	local t = pl.wallThickness

	for _, n in { "MatanCorridor", "MatanTestIqRoom" } do
		local old = Workspace:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end

	local model = Instance.new("Model")
	model.Name = "MatanTestIqRoom"

	-- Пол чуть ниже плоскости y=0 (стык со стенами), чтобы не z-fight со стенами и платформой.
	local floor = mk("Floor", Vector3.new(sx, 1, sz), CFrame.new(0, -0.515, 0), COL_FLOOR, Enum.Material.SmoothPlastic, true)
	floor.CastShadow = false
	floor.Parent = model

	-- Стены (высота sy, толщина t)
	local halfX = sx / 2 + t / 2
	local halfZ = sz / 2 + t / 2
	local yWall = sy / 2

	local wallBack = mk(
		"Wall_Back",
		Vector3.new(sx + 2 * t, sy, t),
		CFrame.new(0, yWall, -halfZ),
		COL_WALL,
		Enum.Material.SmoothPlastic,
		true
	)
	wallBack.Parent = model

	-- Передняя стена с проёмом под дверь (выход в +Z)
	local doorW = 8
	local doorH = sy - 1.5
	local halfTotalX = (sx + 2 * t) / 2
	local doorHalf = doorW / 2
	local flankW = halfTotalX - doorHalf
	local flankCenterX = (halfTotalX + doorHalf) / 2

	local wallFrontL = mk(
		"Wall_Front_Left",
		Vector3.new(flankW, sy, t),
		CFrame.new(-flankCenterX, yWall, halfZ),
		COL_WALL,
		Enum.Material.SmoothPlastic,
		true
	)
	wallFrontL.Parent = model

	local wallFrontR = mk(
		"Wall_Front_Right",
		Vector3.new(flankW, sy, t),
		CFrame.new(flankCenterX, yWall, halfZ),
		COL_WALL,
		Enum.Material.SmoothPlastic,
		true
	)
	wallFrontR.Parent = model

	local yDoor = yWall - 0.35
	local door = mk(
		"DoorPanel",
		Vector3.new(doorW, doorH, t),
		CFrame.new(0, yDoor, halfZ),
		Color3.fromRGB(118, 92, 72),
		Enum.Material.Wood,
		true
	)
	door:SetAttribute("HingeWorldX", -doorHalf)
	door:SetAttribute("HingeWorldY", yDoor)
	door:SetAttribute("HingeWorldZ", halfZ)
	door.Parent = model

	local doorPad = mk(
		"DoorInteract",
		Vector3.new(3, 4, 1),
		CFrame.new(0, 3, halfZ - 1.2),
		Color3.fromRGB(200, 200, 210),
		Enum.Material.SmoothPlastic,
		false
	)
	doorPad.Transparency = 1
	doorPad.CanQuery = true
	doorPad.Parent = model

	local wallLeft = mk(
		"Wall_Left",
		Vector3.new(t, sy, sz),
		CFrame.new(-halfX, yWall, 0),
		COL_WALL,
		Enum.Material.SmoothPlastic,
		true
	)
	wallLeft.Parent = model

	local wallRight = mk(
		"Wall_Right",
		Vector3.new(t, sy, sz),
		CFrame.new(halfX, yWall, 0),
		COL_WALL,
		Enum.Material.SmoothPlastic,
		true
	)
	wallRight.Parent = model

	-- Потолок
	local ceil = mk("Ceiling", Vector3.new(sx + 2 * t, 1, sz + 2 * t), CFrame.new(0, sy + 0.5, 0), COL_CEIL, Enum.Material.SmoothPlastic, true)
	ceil.Parent = model

	-- Потолочные «люминесцентные» полосы
	for _, zOff in { -sz * 0.22, sz * 0.22 } do
		local bar = mk(
			string.format("LightBar_%d", math.floor(zOff * 10)),
			Vector3.new(sx * 0.75, 0.25, 1.1),
			CFrame.new(0, sy - 0.35, zOff),
			COL_LIGHT_BAR,
			Enum.Material.Neon,
			false
		)
		bar.Transparency = 0.15
		bar.CastShadow = false
		local pl = Instance.new("PointLight")
		pl.Brightness = 1.2
		pl.Range = 22
		pl.Color = Color3.fromRGB(230, 240, 255)
		pl.Parent = bar
		bar.Parent = model
	end

	-- «Экран» на задней стене: центр Z по плоскости стены (halfZ), иначе панель уезжает в комнату и «висит» перед игроком.
	local innerBackZ = -halfZ + t / 2
	local screenW = sx * 0.72
	local screenH = sy * 0.55
	local frameTh = 0.35
	local screenTh = 0.2
	local taskTh = 0.35
	local frameZ = innerBackZ + frameTh / 2
	local screenZ = innerBackZ + frameTh + screenTh / 2
	local taskPadZ = innerBackZ + frameTh + screenTh + taskTh / 2
	local frame = mk(
		"Screen_Frame",
		Vector3.new(screenW + 1.2, screenH + 1.2, frameTh),
		CFrame.new(0, yWall * 0.92, frameZ),
		COL_SCREEN_FRAME,
		Enum.Material.SmoothPlastic,
		false
	)
	frame.Parent = model

	local screen = mk(
		"Screen_Surface",
		Vector3.new(screenW, screenH, screenTh),
		CFrame.new(0, yWall * 0.92, screenZ),
		COL_SCREEN,
		Enum.Material.SmoothPlastic,
		false
	)
	screen.Parent = model

	local taskPad = mk(
		"TaskWallButton",
		Vector3.new(2.2, 1.4, taskTh),
		CFrame.new(-screenW * 0.42, yWall * 0.72, taskPadZ),
		Color3.fromRGB(60, 140, 230),
		Enum.Material.SmoothPlastic,
		false
	)
	taskPad.Parent = model

	local AssetIds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AssetIds"))

	-- Текст задания на стене (над экраном)
	local missionY = yWall * 0.92 + screenH / 2 + 1.1
	local missionBoard = mk(
		"MissionBoard",
		Vector3.new(screenW + 0.5, 1.4, 0.12),
		CFrame.new(0, missionY, innerBackZ + 0.06),
		Color3.fromRGB(44, 90, 150),
		Enum.Material.SmoothPlastic,
		false
	)
	missionBoard.Parent = model
	attachSurfaceText(missionBoard, Enum.NormalId.Back, AssetIds.MissionText, 14, Color3.fromRGB(36, 72, 130))

	-- Схема дробей на правой стене (другая поверхность)
	local hintLookY = yWall * 0.78
	local hintPos = Vector3.new(halfX - t / 2 - 0.09, hintLookY, 0)
	local hintCF = CFrame.lookAt(hintPos, Vector3.new(0, hintLookY, 0))
	local hintBoard = mk(
		"HintDiagramBoard",
		Vector3.new(0.12, 8, 11),
		hintCF,
		COL_SCREEN_FRAME,
		Enum.Material.SmoothPlastic,
		false
	)
	hintBoard.Parent = model
	-- Локальный +Z (Front) у доски смотрит в толщину стены; игрок внутри комнаты видит −Z → Back.
	attachFractionHintBoard(hintBoard, Enum.NormalId.Back, AssetIds.FractionHintImage)

	-- Та же схема на задней стене под экраном (центр), лицом в комнату — Front тонкой пластины по +Z.
	local backHintW = math.min(screenW * 0.92, sx * 0.44)
	local backHintH = 4.1
	local belowScreenY = yWall * 0.92 - screenH * 0.5 - backHintH * 0.5 - 0.55
	local backHintBoard = mk(
		"HintDiagramBoard_BackWall",
		Vector3.new(backHintW, backHintH, 0.12),
		CFrame.new(0, belowScreenY, innerBackZ + 0.07),
		COL_SCREEN_FRAME,
		Enum.Material.SmoothPlastic,
		false
	)
	backHintBoard.Parent = model
	attachFractionHintBoard(backHintBoard, Enum.NormalId.Front, AssetIds.FractionHintImage)

	-- Синяя полоса «бренда IQ-теста»
	local trim = mk(
		"AccentTrim",
		Vector3.new(sx * 0.55, 0.35, 0.15),
		CFrame.new(0, 0.2, innerBackZ + 0.15 / 2),
		COL_TRIM,
		Enum.Material.SmoothPlastic,
		false
	)
	trim.CanCollide = false
	trim.Parent = model

	-- Платформа явно выше пола — иначе с верхом пола z-fighting при ходьбе.
	local stand = mk(
		"PlayerStand",
		Vector3.new(12, 0.35, 10),
		CFrame.new(0, 0.23, -2),
		Color3.fromRGB(210, 214, 222),
		Enum.Material.SmoothPlastic,
		true
	)
	stand.Parent = model

	-- Спавн строго внутри: центр по X, между экраном (-Z) и дверью (+Z)
	local spawnZ = math.clamp(sz * 0.05, -sz * 0.35, sz * 0.35)
	local lookAt = Vector3.new(0, yWall * 0.75, screenZ + 1.5)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn_TestRoom"
	spawn.Size = Vector3.new(5, 1, 5)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 3, spawnZ), lookAt)
	spawn.Anchored = true
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(80, 170, 255)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CastShadow = false
	spawn.CanCollide = false
	spawn.Parent = model

	model.WorldPivot = CFrame.new(0, 0, 0)
	model.Parent = Workspace
	return model
end

return TestIqRoom
