--!strict
--[[ Генерация заданий: сложение / вычитание дробей. ]]

local Fraction = require(script.Parent.Fraction)

export type Operation = "add" | "subtract"

export type Problem = {
	id: string,
	operation: Operation,
	left: Fraction.T,
	right: Fraction.T,
	prompt: string,
	correct: Fraction.T,
}

local ProblemGenerator = {}

local function randomInt(rng: Random, a: number, b: number): number
	return rng:NextInteger(a, b)
end

local function randomPositiveFraction(rng: Random, maxDen: number, allowImproper: boolean): Fraction.T
	local den = randomInt(rng, 2, maxDen)
	local maxNum = if allowImproper then den * 2 else den - 1
	local num = randomInt(rng, 1, math.max(1, maxNum))
	return Fraction.simplify(Fraction.new(num, den))
end

function ProblemGenerator.generate(
	rng: Random,
	operation: Operation,
	options: {
		maxDenominator: number?,
		allowImproper: boolean?,
		ensureNonNegativeResult: boolean?,
	}?
): Problem
	local maxDen = (options and options.maxDenominator) or 12
	local allowImproper = (options and options.allowImproper) or false
	local ensureNonNegative = (options and options.ensureNonNegativeResult) ~= false

	local left: Fraction.T
	local right: Fraction.T
	local correct: Fraction.T

	for _ = 1, 80 do
		if operation == "add" then
			left = randomPositiveFraction(rng, maxDen, allowImproper)
			right = randomPositiveFraction(rng, maxDen, allowImproper)
			correct = Fraction.add(left, right)
		else
			left = randomPositiveFraction(rng, maxDen, allowImproper)
			right = randomPositiveFraction(rng, maxDen, allowImproper)
			if ensureNonNegative and Fraction.compare(left, right) < 0 then
				left, right = right, left
			end
			correct = Fraction.subtract(left, right)
		end
		if correct.denominator <= maxDen * 2 then
			break
		end
	end

	local opSymbol = if operation == "add" then "+" else "−"
	local prompt = string.format(
		"Вычислите: %s %s %s",
		Fraction.toString(left, false),
		opSymbol,
		Fraction.toString(right, false)
	)

	local id = string.format(
		"%s|%d/%d|%d/%d",
		operation,
		left.numerator,
		left.denominator,
		right.numerator,
		right.denominator
	)

	return {
		id = id,
		operation = operation,
		left = left,
		right = right,
		prompt = prompt,
		correct = correct,
	}
end

function ProblemGenerator.generateMixed(rng: Random, maxDen: number?): Problem
	local maxD = maxDen or 9
	local op: Operation = if rng:NextNumber() < 0.5 then "add" else "subtract"
	return ProblemGenerator.generate(rng, op, {
		maxDenominator = maxD,
		allowImproper = false,
		ensureNonNegativeResult = true,
	})
end

function ProblemGenerator.generateEasy(rng: Random): Problem
	return ProblemGenerator.generate(rng, if rng:NextNumber() < 0.5 then "add" else "subtract", {
		maxDenominator = 8,
		allowImproper = false,
		ensureNonNegativeResult = true,
	})
end

return ProblemGenerator
