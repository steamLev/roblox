--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestIqRoom = require(script.Parent.Map.TestIqRoom)
local DoorService = require(script.Parent.Map.DoorService)

local roomModel = TestIqRoom.build(nil)
DoorService.bind(roomModel)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetRunState = Remotes:WaitForChild("GetRunState") :: RemoteFunction
local SubmitAnswer = Remotes:WaitForChild("SubmitAnswer") :: RemoteFunction

local RunSession = require(script.Parent.Run.RunSession)

GetRunState.OnServerInvoke = function(player: Player, fromWall: any?)
	return RunSession.getState(player, fromWall == true)
end

SubmitAnswer.OnServerInvoke = function(player: Player, payload: any)
	local bad = {
		ok = false,
		message = "Неверный запрос",
		stage = 1,
		maxStages = 99,
		completed = false,
		prompt = nil,
		problemToken = nil,
		roomLabel = "",
		choices = nil,
		attemptsLeft = nil,
	}
	if typeof(payload) ~= "table" then
		return bad
	end
	local token = payload.problemToken
	if typeof(token) ~= "string" then
		return bad
	end
	local rawCi = (payload :: any).choiceIndex
	local ciNum = if typeof(rawCi) == "number" then rawCi elseif typeof(rawCi) == "string" then tonumber(rawCi) else nil
	if ciNum ~= nil then
		local ci = math.floor(ciNum + 0.5)
		if ci >= 0 and ci <= 3 then
			return RunSession.submit(player, {
				problemToken = token,
				choiceIndex = ci,
			})
		end
	end
	if typeof(payload.answer) == "string" then
		return RunSession.submit(player, {
			problemToken = token,
			answer = payload.answer,
		})
	end
	return bad
end
