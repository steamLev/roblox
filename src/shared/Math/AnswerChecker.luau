--!strict

local Fraction = require(script.Parent.Fraction)

export type CheckResult = {
	ok: boolean,
	expected: Fraction.T?,
	message: string?,
}

local AnswerChecker = {}

function AnswerChecker.check(expected: Fraction.T, userInput: string): CheckResult
	local trimmed = string.gsub(userInput, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	if trimmed == "" then
		return { ok = false, message = "Введите ответ" }
	end

	local parsed = Fraction.parse(trimmed)
	if not parsed then
		return { ok = false, message = "Формат: a/b или целое число" }
	end

	if Fraction.equals(parsed, expected) then
		return { ok = true, expected = Fraction.simplify(expected) }
	end

	return {
		ok = false,
		expected = Fraction.simplify(expected),
		message = "Неверно",
	}
end

return AnswerChecker
