--!strict

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local function studioPrint(msg: string)
	if RunService:IsStudio() then
		print("[Matan][Door] " .. msg)
	end
end

local OPEN_ANGLE = math.rad(88)
-- Если поворот почти не сдвигает центр полотна (ошибка шарнира/оси), сдвигаем в −Z «внутрь» комнаты.
local SLIDE_FALLBACK_Z = -2.8

local doorPart: Part? = nil
local closedCF: CFrame? = nil
local isOpen = false

local DoorService = {}

local function hingeWorld(door: BasePart, hingeLocal: Vector3): Vector3
	return door.CFrame:PointToWorldSpace(hingeLocal)
end

local function rotateAroundY(closed: CFrame, door: BasePart, hingeLocal: Vector3, angleY: number): CFrame
	local pivot = CFrame.new(hingeWorld(door, hingeLocal))
	return pivot * CFrame.Angles(0, angleY, 0) * pivot:Inverse() * closed
end

local function flatDistFromClosed(open: CFrame, closed: CFrame): number
	local d = open.Position - closed.Position
	return math.sqrt(d.X * d.X + d.Z * d.Z)
end

local function bestOpenCFrame(door: BasePart, closed: CFrame): CFrame
	-- Два классических шарнира (−X / +X ребро) и оба знака угла — выбираем максимальный сдвиг в плоскости XZ.
	local best = closed
	local bestDist = 0
	for _, hingeSign in { -1, 1 } do
		local hingeLocal = Vector3.new(hingeSign * door.Size.X / 2, 0, 0)
		for _, angleSign in { -1, 1 } do
			local openCF = rotateAroundY(closed, door, hingeLocal, angleSign * OPEN_ANGLE)
			local dist = flatDistFromClosed(openCF, closed)
			if dist > bestDist then
				bestDist = dist
				best = openCF
			end
		end
	end
	if bestDist < 0.08 then
		return closed * CFrame.new(0, 0, SLIDE_FALLBACK_Z)
	end
	return best
end

function DoorService.bind(room: Model)
	local door = room:WaitForChild("DoorPanel", 10) :: Part?
	if not door then
		warn("[DoorService] DoorPanel не найден — автоматическое открытие двери не будет работать.")
		studioPrint("bind FAILED: нет DoorPanel (смотри warn выше)")
		doorPart = nil
		closedCF = nil
		return
	end

	doorPart = door
	closedCF = door.CFrame
	isOpen = false
	door.Anchored = true
	door.CanCollide = true
	door.CFrame = closedCF :: CFrame
	studioPrint("bind OK на DoorPanel")
end

local function ensureBound(): boolean
	if doorPart and doorPart.Parent and closedCF then
		return true
	end
	doorPart = nil
	closedCF = nil
	local room = Workspace:FindFirstChild("MatanTestIqRoom")
	if room and room:IsA("Model") then
		DoorService.bind(room)
	end
	return doorPart ~= nil and closedCF ~= nil
end

function DoorService.close()
	if not ensureBound() then
		return
	end
	local door = doorPart :: Part
	door.CFrame = closedCF :: CFrame
	isOpen = false
end

function DoorService.open()
	if not ensureBound() then
		warn("[DoorService] open: нет комнаты MatanTestIqRoom или DoorPanel в Workspace.")
		studioPrint("open ABORT: ensureBound=false (смотри warn выше)")
		return
	end
	if isOpen then
		studioPrint("open SKIP: дверь уже помечена как открытая (isOpen)")
		return
	end
	local door = doorPart :: Part
	local closed = closedCF :: CFrame
	door.CFrame = closed
	local openCF = bestOpenCFrame(door, closed)
	local shift = flatDistFromClosed(openCF, closed)
	door.CFrame = openCF
	isOpen = true
	studioPrint(string.format("open OK, сдвиг центра в XZ ≈ %.2f ст.", shift))
end

return DoorService
