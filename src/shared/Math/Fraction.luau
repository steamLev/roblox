--!strict
--[[ Дроби: сокращение, сложение, вычитание, сравнение. Знаменатель > 0. ]]

local Fraction = {}

export type T = {
	numerator: number,
	denominator: number,
}

local function gcd(a: number, b: number): number
	a = math.abs(a)
	b = math.abs(b)
	while b ~= 0 do
		a, b = b, a % b
	end
	return math.max(a, 1)
end

local function lcm(a: number, b: number): number
	return math.abs(a * b) // gcd(a, b)
end

function Fraction.new(numerator: number, denominator: number): T
	assert(denominator ~= 0, "denominator cannot be 0")
	if denominator < 0 then
		numerator = -numerator
		denominator = -denominator
	end
	return { numerator = numerator, denominator = denominator }
end

function Fraction.simplify(f: T): T
	local g = gcd(f.numerator, f.denominator)
	local n = f.numerator // g
	local d = f.denominator // g
	if d < 0 then
		n = -n
		d = -d
	end
	return { numerator = n, denominator = d }
end

function Fraction.equals(a: T, b: T): boolean
	local as = Fraction.simplify(a)
	local bs = Fraction.simplify(b)
	return as.numerator == bs.numerator and as.denominator == bs.denominator
end

function Fraction.add(a: T, b: T): T
	local den = lcm(a.denominator, b.denominator)
	local num = a.numerator * (den // a.denominator) + b.numerator * (den // b.denominator)
	return Fraction.simplify(Fraction.new(num, den))
end

function Fraction.subtract(a: T, b: T): T
	return Fraction.add(a, Fraction.new(-b.numerator, b.denominator))
end

function Fraction.compare(a: T, b: T): number
	local lhs = a.numerator * b.denominator
	local rhs = b.numerator * a.denominator
	if lhs < rhs then
		return -1
	elseif lhs > rhs then
		return 1
	end
	return 0
end

function Fraction.toString(f: T, mixed: boolean?): string
	local s = Fraction.simplify(f)
	if s.denominator == 1 then
		return tostring(s.numerator)
	end
	if mixed and math.abs(s.numerator) >= s.denominator then
		local whole = s.numerator // s.denominator
		local rem = math.abs(s.numerator) % s.denominator
		if rem == 0 then
			return tostring(whole)
		end
		local sign = if s.numerator < 0 then "-" else ""
		return string.format("%s%d %d/%d", sign, math.abs(whole), rem, s.denominator)
	end
	return string.format("%d/%d", s.numerator, s.denominator)
end

function Fraction.parse(text: string): T?
	local t = string.gsub(text, "^%s+", "")
	t = string.gsub(t, "%s+$", "")
	-- смешанная дробь: "1 1/2" (пробелы сохраняем до схлопывания)
	local w, n, d = string.match(t, "^(-?%d+)%s+(%d+)/(%d+)$")
	if w and n and d then
		local ww = tonumber(w) :: number
		local nn = tonumber(n) :: number
		local dd = tonumber(d) :: number
		if dd == 0 then
			return nil
		end
		local sign = if ww < 0 then -1 else 1
		ww = math.abs(ww)
		return Fraction.simplify(Fraction.new(sign * (ww * dd + nn), dd))
	end
	t = string.gsub(t, "%s+", "")
	local num, den = string.match(t, "^(-?%d+)/(%d+)$")
	if num and den then
		local nn = tonumber(num) :: number
		local dd = tonumber(den) :: number
		if dd == 0 then
			return nil
		end
		return Fraction.simplify(Fraction.new(nn, dd))
	end
	local only = tonumber(t)
	if only then
		return Fraction.new(only, 1)
	end
	return nil
end

return Fraction
