--!strict
--[[
  FractionHintImage: в репозитории лежит assets/FractionHint.png — в Roblox Studio:
  Создать → Decal (или Image) → выберите этот файл → скопируйте из свойств Texture/Image
  строку вида rbxassetid://… или только числовой id (оба формата поддерживаются).
  После этого вставьте значение ниже — на правой стене появится Decal с диаграммой.
]]

return table.freeze({
	MissionText = "Реши дробное выражение и выйди из комнаты",
	FractionHintImage = "" :: string,
})
