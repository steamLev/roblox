--!strict
--[[
  Карта «по плану»: один основной коридор (ось +X), пол, две длинные стены,
  торцы, потолок-перемычки через заданный шаг — визуально делит на «комнаты».
  Модель пересоздаётся при каждом запуске сервера (старая MatanCorridor удаляется).
]]

local Workspace = game:GetService("Workspace")

export type Plan = {
	-- длина коридора по X (внутренний проход между стенами)
	lengthStuds: number,
	-- ширина пола между внутренними гранями стен
	innerWidthStuds: number,
	wallHeightStuds: number,
	wallThicknessStuds: number,
	-- каждые N студов — перемычка сверху (как проём между зонами)
	segmentStepStuds: number,
}

local DEFAULT_PLAN: Plan = {
	lengthStuds = 198,
	innerWidthStuds = 14,
	wallHeightStuds = 14,
	wallThicknessStuds = 1,
	segmentStepStuds = 18,
}

local COL_FLOOR = Color3.fromRGB(88, 88, 94)
local COL_WALL = Color3.fromRGB(62, 64, 72)
local COL_LINTEL = Color3.fromRGB(48, 50, 58)
local COL_STRIPE = Color3.fromRGB(214, 178, 48)

local CorridorMap = {}

local function mkPart(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.CastShadow = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

function CorridorMap.build(plan: Plan?): Model
	local pl = plan or DEFAULT_PLAN
	local L = pl.lengthStuds
	local W = pl.innerWidthStuds
	local H = pl.wallHeightStuds
	local T = pl.wallThicknessStuds
	local step = math.max(8, pl.segmentStepStuds)

	local old = Workspace:FindFirstChild("MatanCorridor")
	if old then
		old:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "MatanCorridor"

	local halfInner = W / 2
	-- внешняя ширина по Z (пол и торцевые стены совпадают)
	local outerZ = W + 2 * T

	-- Пол: лежит Y=0 сверху (центр -0.5 при толщине 1)
	local floor = mkPart(
		"Floor",
		Vector3.new(L, 1, outerZ),
		CFrame.new(L / 2, -0.5, 0),
		COL_FLOOR,
		Enum.Material.Concrete
	)
	floor.Parent = model

	-- Жёлтая полоса по центру (как на плане «опасная зона»)
	local stripe = mkPart(
		"CenterStripe",
		Vector3.new(L, 0.08, 1.2),
		CFrame.new(L / 2, 0.06, 0),
		COL_STRIPE,
		Enum.Material.SmoothPlastic
	)
	stripe.CanCollide = false
	stripe.Parent = model

	-- Длинные стены (внутренний проход между Z = ±halfInner)
	local wallLeft = mkPart(
		"Wall_Left",
		Vector3.new(L, H, T),
		CFrame.new(L / 2, H / 2, -halfInner - T / 2),
		COL_WALL,
		Enum.Material.Concrete
	)
	wallLeft.Parent = model

	local wallRight = mkPart(
		"Wall_Right",
		Vector3.new(L, H, T),
		CFrame.new(L / 2, H / 2, halfInner + T / 2),
		COL_WALL,
		Enum.Material.Concrete
	)
	wallRight.Parent = model

	-- Торцы
	local wallStart = mkPart(
		"Wall_Start",
		Vector3.new(T, H, outerZ),
		CFrame.new(-T / 2, H / 2, 0),
		COL_WALL,
		Enum.Material.Concrete
	)
	wallStart.Parent = model

	local wallEnd = mkPart(
		"Wall_End",
		Vector3.new(T, H, outerZ),
		CFrame.new(L + T / 2, H / 2, 0),
		COL_WALL,
		Enum.Material.Concrete
	)
	wallEnd.Parent = model

	-- Перемычки / «проёмы» между зонами: не полный потолок, только перекрытие у стен
	local lintelDepth = 2.2
	local lintelThick = 1.0
	for x = step, L - 1, step do
		local leftLint = mkPart(
			string.format("Lintel_L_%d", x),
			Vector3.new(lintelThick, 1.4, lintelDepth),
			CFrame.new(x, H - 0.8, -halfInner + lintelDepth / 2 - 0.2),
			COL_LINTEL,
			Enum.Material.Metal
		)
		leftLint.Parent = model

		local rightLint = mkPart(
			string.format("Lintel_R_%d", x),
			Vector3.new(lintelThick, 1.4, lintelDepth),
			CFrame.new(x, H - 0.8, halfInner - lintelDepth / 2 + 0.2),
			COL_LINTEL,
			Enum.Material.Metal
		)
		rightLint.Parent = model
	end

	-- Точка спавна у входа в коридор
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn_Corridor"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.lookAt(Vector3.new(6, 3, 0), Vector3.new(40, 3, 0))
	spawn.Anchored = true
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(70, 140, 255)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 0.25
	spawn.Parent = model

	model.WorldPivot = CFrame.new(L / 2, 0, 0)
	model.Parent = Workspace
	return model
end

return CorridorMap
