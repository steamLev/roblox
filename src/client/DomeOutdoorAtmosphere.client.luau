--!strict
--[[ Дневной луг → при штурме купола атмосфера темнеет (контраст как на референсе при ударе). ]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local sunny = {
	ClockTime = 14.5,
	Brightness = 2.4,
	Ambient = Color3.fromRGB(150, 165, 150),
	OutdoorAmbient = Color3.fromRGB(130, 145, 130),
}

local assault = {
	ClockTime = 17.2,
	Brightness = 1.35,
	Ambient = Color3.fromRGB(90, 70, 75),
	OutdoorAmbient = Color3.fromRGB(70, 55, 60),
}

local tweening = false

local function applyPreset(preset: { [string]: any }, duration: number)
	if tweening then
		return
	end
	tweening = true
	local ti = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(Lighting, ti, preset):Play()
	task.delay(duration, function()
		tweening = false
	end)
end

RunService.Heartbeat:Connect(function()
	local enc = player:GetAttribute("DomeEncounterActive") == true
	local opening = player:GetAttribute("DomeOpeningActive") == true
	local phase = player:GetAttribute("DomePhase")
	local ph = if typeof(phase) == "string" then phase else "IDLE"
	local beat = player:GetAttribute("DomeOpeningBeat")
	local b = if typeof(beat) == "number" then math.floor(beat + 0.5) else -1

	if (enc or opening) and (ph == "ASSAULT" or ph == "ZERO_G" or b >= 2) then
		if Lighting.Brightness > 1.6 then
			applyPreset(assault, 1.8)
		end
	elseif (not enc and not opening) or ph == "CALM" or ph == "IDLE" then
		if Lighting.Brightness < 2 then
			applyPreset(sunny, 2.5)
		end
	end
end)
