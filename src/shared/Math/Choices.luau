--!strict
--[[ Четыре варианта ответа-дроби: один верный, три отвлекающих, порядок случайный. ]]

local Fraction = require(script.Parent.Fraction)

local Choices = {}

local function listHas(t: { string }, s: string): boolean
	for _, v in t do
		if v == s then
			return true
		end
	end
	return false
end

function Choices.buildFour(rng: Random, correct: Fraction.T, maxDen: number): ({ string }, number)
	local cSimp = Fraction.simplify(correct)
	local cStr = Fraction.toString(cSimp, false)
	local wrongs: { string } = {}

	local tries = 0
	while #wrongs < 3 and tries < 250 do
		tries += 1
		local dn = rng:NextInteger(-2, 2)
		local nn = rng:NextInteger(-3, 3)
		local d = math.clamp(cSimp.denominator + dn, 2, math.max(8, maxDen + 4))
		local n = cSimp.numerator + nn
		if n > 0 and n < d * 2 then
			local cand = Fraction.simplify(Fraction.new(n, d))
			local s = Fraction.toString(cand, false)
			if s ~= cStr and not listHas(wrongs, s) and not Fraction.equals(cand, cSimp) then
				table.insert(wrongs, s)
			end
		end
	end

	local fill = 0
	while #wrongs < 3 and fill < 80 do
		fill += 1
		local a = rng:NextInteger(1, 9)
		local b = rng:NextInteger(2, 9)
		local s = Fraction.toString(Fraction.simplify(Fraction.new(a, b)), false)
		if s ~= cStr and not listHas(wrongs, s) then
			table.insert(wrongs, s)
		end
	end

	local pack = {
		{ t = cStr, ok = true },
		{ t = wrongs[1], ok = false },
		{ t = wrongs[2], ok = false },
		{ t = wrongs[3], ok = false },
	}

	for i = 4, 2, -1 do
		local j = rng:NextInteger(1, i)
		pack[i], pack[j] = pack[j], pack[i]
	end

	local texts: { string } = {}
	local correctIdx = 0
	for i, o in ipairs(pack) do
		texts[i] = o.t
		if o.ok then
			correctIdx = i - 1
		end
	end

	return texts, correctIdx
end

return Choices
