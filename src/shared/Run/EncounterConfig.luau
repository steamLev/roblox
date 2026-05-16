--!strict
--[[ Тайминги энкаунтера «стеклянный купол» (после 60 с opening — RunSession). ]]

local EncounterConfig = {}

EncounterConfig.CALM_SECONDS = 3
EncounterConfig.ASSAULT_INTEGRITY_PER_SEC = 4.5
EncounterConfig.ZERO_G_DURATION = 6.5
EncounterConfig.ZERO_G_AT_INTEGRITY = 42
EncounterConfig.ZERO_G_COOLDOWN = 14
EncounterConfig.TURRET_DURATION = 5.5
EncounterConfig.DOOR_OPEN_AFTER_TURRET_SECONDS = 10
EncounterConfig.WORKSPACE_GRAVITY_DEFAULT = 196.2
EncounterConfig.WORKSPACE_GRAVITY_ZERO_G = 38

EncounterConfig.BAIT_ZONE_ENTRY_STAGE = 6
EncounterConfig.MIMIC_HUNT_AFTER_SECONDS = 120

return table.freeze(EncounterConfig)
