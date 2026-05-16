--!strict
--[[ Мимики в саду — заглушка; полная охота подключается позже. ]]

local MimicService = {}

local gardenEnteredAt: { [Player]: number } = {}

function MimicService.spawnDefaults()
	-- no-op until forest mimics are wired
end

function MimicService.markPlayerEnteredGarden(player: Player)
	gardenEnteredAt[player] = os.clock()
end

function MimicService.tick(_dt: number, _huntAfterSeconds: number)
	-- hunt logic TBD
end

return MimicService
