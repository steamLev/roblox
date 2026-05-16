--!strict
--[[ Камера / ощущение давления по фазам купола (атрибуты сервера на LocalPlayer). ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local rng = Random.new()

local function currentHumanoid(): Humanoid?
	local ch = player.Character
	if not ch then
		return nil
	end
	return ch:FindFirstChildWhichIsA("Humanoid")
end

RunService.RenderStepped:Connect(function()
	local hum = currentHumanoid()
	if not hum then
		return
	end
	local phase = player:GetAttribute("DomePhase")
	local enc = player:GetAttribute("DomeEncounterActive")
	local opening = player:GetAttribute("DomeOpeningActive") == true
	local beat = player:GetAttribute("DomeOpeningBeat")
	local ph = if typeof(phase) == "string" then phase else "IDLE"
	local openingBeat = if typeof(beat) == "number" then math.floor(beat + 0.5) else -1
	local assaultShake = if openingBeat >= 3 then 0.38 elseif openingBeat >= 2 then 0.24 else 0.28
	if ph == "ZERO_G" and opening and openingBeat == 4 then
		hum.CameraOffset = Vector3.new(
			rng:NextNumber(-0.12, 0.12),
			rng:NextNumber(0.06, 0.18),
			rng:NextNumber(-0.1, 0.1)
		)
	elseif ph == "ASSAULT" and enc == true then
		hum.CameraOffset = Vector3.new(
			rng:NextNumber(-assaultShake, assaultShake),
			rng:NextNumber(-0.1, 0.1),
			rng:NextNumber(-assaultShake * 0.7, assaultShake * 0.7)
		)
	elseif ph == "ZERO_G" then
		hum.CameraOffset = Vector3.new(
			rng:NextNumber(-0.16, 0.16),
			rng:NextNumber(0.04, 0.22),
			rng:NextNumber(-0.14, 0.14)
		)
	elseif ph == "TURRET" then
		hum.CameraOffset = Vector3.new(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.05, 0.05))
	else
		hum.CameraOffset = Vector3.zero
	end
end)

player.CharacterAdded:Connect(function(char)
	local hum = char:WaitForChild("Humanoid", 5)
	if hum and hum:IsA("Humanoid") then
		hum.CameraOffset = Vector3.zero
	end
end)
