--!strict
--[[
	First dome (stage 1) — 60 s opening slice (reference: docs + concept art).

	Design beats (DomeOpeningBeat on LocalPlayer):
	  0  Distant   [0, 12)   false sanctuary
	  1  Pressure  [12, 22)  math + distant war, laser tease end
	  2  Stress    [22, 32)  impacts pacing, crack stage 1
	  3  Breach    [32, 42)  crack stage 2, pre–zero-G warning
	  4  ZeroG     [42, 55)  zero gravity (13 s)
	  5  Resolve   [55, 60)  gravity slam / micro-relief tail

	Server DomePhase:
	  CALM    [0, 12)
	  ASSAULT [12, 42)
	  ZERO_G  [42, 55)
	  ASSAULT [55, 60) tail until WINDOW_SECONDS
]]

local FirstDomeOpening = {}

FirstDomeOpening.WINDOW_SECONDS = 60
FirstDomeOpening.OPENING_ZERO_G_DURATION = 13

FirstDomeOpening.DESIGN_CALM_UNTIL = 12
FirstDomeOpening.DESIGN_PRESSURE_UNTIL = 22
FirstDomeOpening.DESIGN_STRESS_UNTIL = 32
FirstDomeOpening.DESIGN_BREACH_UNTIL = 42
FirstDomeOpening.DESIGN_ZERO_G_UNTIL = 42 + 13 -- 55
FirstDomeOpening.FORCE_ZERO_G_AT = FirstDomeOpening.DESIGN_BREACH_UNTIL
FirstDomeOpening.CALM_UNTIL = FirstDomeOpening.DESIGN_CALM_UNTIL
FirstDomeOpening.SUBLIMINAL_ELAPSED = 48
FirstDomeOpening.SWARM_TEASE_ELAPSED = 55
FirstDomeOpening.ZERO_G_WARNING_ELAPSED = 40

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * math.clamp(t, 0, 1)
end

function FirstDomeOpening.openingBeat(elapsed: number): number
	if elapsed < FirstDomeOpening.DESIGN_CALM_UNTIL then
		return 0
	elseif elapsed < FirstDomeOpening.DESIGN_PRESSURE_UNTIL then
		return 1
	elseif elapsed < FirstDomeOpening.DESIGN_STRESS_UNTIL then
		return 2
	elseif elapsed < FirstDomeOpening.DESIGN_BREACH_UNTIL then
		return 3
	elseif elapsed < FirstDomeOpening.DESIGN_ZERO_G_UNTIL then
		return 4
	else
		return 5
	end
end

export type SessionOpeningSlice = {
	stage: number,
	encounterStartedAt: number?,
	domePhase: string,
	glassIntegrity: number,
	lastZeroGAt: number,
	openingForcedZeroGFired: boolean,
}

function FirstDomeOpening.tickOpening(s: SessionOpeningSlice, _dt: number): boolean
	if s.stage ~= 1 or s.encounterStartedAt == nil then
		return false
	end
	local started = s.encounterStartedAt :: number
	local e = tick() - started
	if e >= FirstDomeOpening.WINDOW_SECONDS then
		return false
	end

	local CALM = FirstDomeOpening.CALM_UNTIL
	local ZAT = FirstDomeOpening.FORCE_ZERO_G_AT
	local ZD = FirstDomeOpening.OPENING_ZERO_G_DURATION
	local ZEnd = ZAT + ZD
	local phase = s.domePhase
	local lzg = s.lastZeroGAt

	if phase == "ZERO_G" then
		if tick() >= lzg + ZD then
			s.domePhase = "ASSAULT"
			s.glassIntegrity = lerp(34, 30, (math.clamp(e, ZEnd, FirstDomeOpening.WINDOW_SECONDS) - ZEnd) / (FirstDomeOpening.WINDOW_SECONDS - ZEnd))
		else
			s.domePhase = "ZERO_G"
			s.glassIntegrity = lerp(34, 30, (e - ZAT) / ZD)
		end
		return true
	end

	if e < CALM then
		s.domePhase = "CALM"
		s.glassIntegrity = lerp(100, 95, e / CALM)
	elseif e < FirstDomeOpening.DESIGN_PRESSURE_UNTIL then
		s.domePhase = "ASSAULT"
		s.glassIntegrity = lerp(95, 85, (e - CALM) / (FirstDomeOpening.DESIGN_PRESSURE_UNTIL - CALM))
	elseif e < FirstDomeOpening.DESIGN_STRESS_UNTIL then
		s.domePhase = "ASSAULT"
		s.glassIntegrity = lerp(85, 55, (e - FirstDomeOpening.DESIGN_PRESSURE_UNTIL) / (FirstDomeOpening.DESIGN_STRESS_UNTIL - FirstDomeOpening.DESIGN_PRESSURE_UNTIL))
	elseif e < ZAT then
		s.domePhase = "ASSAULT"
		s.glassIntegrity = lerp(55, 34, (e - FirstDomeOpening.DESIGN_STRESS_UNTIL) / (ZAT - FirstDomeOpening.DESIGN_STRESS_UNTIL))
	elseif not s.openingForcedZeroGFired then
		s.domePhase = "ZERO_G"
		s.lastZeroGAt = tick()
		s.openingForcedZeroGFired = true
		s.glassIntegrity = math.max(s.glassIntegrity, 34)
	else
		s.domePhase = "ASSAULT"
		s.glassIntegrity = lerp(40, 30, (math.clamp(e, ZEnd, FirstDomeOpening.WINDOW_SECONDS) - ZEnd) / (FirstDomeOpening.WINDOW_SECONDS - ZEnd))
	end

	return true
end

function FirstDomeOpening.zeroGDuration(): number
	return FirstDomeOpening.OPENING_ZERO_G_DURATION
end

function FirstDomeOpening.isOpeningElapsed(elapsed: number): boolean
	return elapsed >= 0 and elapsed < FirstDomeOpening.WINDOW_SECONDS
end

function FirstDomeOpening.shouldSubliminalFlash(elapsed: number, domePhase: string): boolean
	return domePhase == "ZERO_G"
		and elapsed >= FirstDomeOpening.SUBLIMINAL_ELAPSED
		and elapsed < FirstDomeOpening.SUBLIMINAL_ELAPSED + 0.35
end

return table.freeze(FirstDomeOpening)
