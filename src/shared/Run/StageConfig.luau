--!strict
--[[ Параметры сложности по номеру комнаты 1..99 (карта маршрута → данные). ]]

local StageConfig = {}

StageConfig.STAGE_COUNT = 99

function StageConfig.maxDenominator(stage: number): number
	return math.clamp(6 + stage // 6, 6, 16)
end

function StageConfig.allowImproper(stage: number): boolean
	return stage >= 45
end

function StageConfig.label(stage: number): string
	return string.format("Комната %d / %d", stage, StageConfig.STAGE_COUNT)
end

return StageConfig
