--!strict

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local function studioPrint(msg: string)
	if RunService:IsStudio() then
		print("[Matan][Door] " .. msg)
	end
end

local OPEN_ANGLE = math.rad(88)
local SLIDE_FALLBACK_Z = -2.8

type DoorRec = {
	door: Part,
	closedCF: CFrame,
	isOpen: boolean,
}

local doors: { [number]: DoorRec } = {}
local lastOpenedStage: number? = nil

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

function DoorService.bindFacility(facility: Model)
	doors = {}
	for _, child in facility:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, 1, 5) == "Cell_" then
			local n = tonumber(string.sub(child.Name, 6))
			if n then
				local door = child:FindFirstChild("ExitDoor", true)
				if door and door:IsA("BasePart") then
					local p = door :: Part
					p.Anchored = true
					p.CanCollide = true
					doors[n] = {
						door = p,
						closedCF = p.CFrame,
						isOpen = false,
					}
					studioPrint("bind ExitDoor cell " .. tostring(n))
				end
			end
		end
	end
end

function DoorService.openExitFromStage(stage: number)
	local rec = doors[stage]
	if not rec then
		warn("[DoorService] нет двери для сектора " .. tostring(stage))
		studioPrint("openExitFromStage ABORT " .. tostring(stage))
		return
	end
	if rec.isOpen then
		return
	end
	local door = rec.door
	if door:GetAttribute("IsEnergyField") == true then
		door.Transparency = 1
		door.CanCollide = false
		local sparks = door:FindFirstChild("FieldSparks")
		if sparks and sparks:IsA("ParticleEmitter") then
			sparks.Enabled = false
		end
		rec.isOpen = true
		lastOpenedStage = stage
		studioPrint("openExitFromStage OK energy " .. tostring(stage))
		return
	end
	local closed = rec.closedCF
	door.CFrame = closed
	door.CFrame = bestOpenCFrame(door, closed)
	rec.isOpen = true
	lastOpenedStage = stage
	studioPrint("openExitFromStage OK " .. tostring(stage))
end

function DoorService.closeForStage(stage: number)
	local rec = doors[stage]
	if not rec or not rec.isOpen then
		return
	end
	if rec.door:GetAttribute("IsEnergyField") == true then
		rec.door.Transparency = 0.55
		rec.door.CanCollide = true
		local sparks = rec.door:FindFirstChild("FieldSparks")
		if sparks and sparks:IsA("ParticleEmitter") then
			sparks.Enabled = true
		end
	else
		rec.door.CFrame = rec.closedCF
	end
	rec.isOpen = false
	studioPrint("closeForStage " .. tostring(stage))
end

function DoorService.close()
	if lastOpenedStage then
		DoorService.closeForStage(lastOpenedStage)
		lastOpenedStage = nil
	end
end

function DoorService.open()
	warn("[DoorService] open() устарел — используйте openExitFromStage")
end

function DoorService.bind(room: Model)
	DoorService.bindFacility(room)
end

function DoorService.ensureLegacyRoom(): boolean
	local room = Workspace:FindFirstChild("MatanTestIqRoom")
	if room and room:IsA("Model") then
		DoorService.bindFacility(room)
		return true
	end
	return false
end

return DoorService
