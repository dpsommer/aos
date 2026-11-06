class_name DiceExpr
extends RefCounted
## A characteristic or roll that may be random: "4", "D3", "2D6" or "D6+3". "-" is 0 (a Rend or Move
## of none). See Core Rules 26.0.

var count := 0
var sides := 0
var bonus := 0


static func of_value(value: int) -> DiceExpr:
	var expr := DiceExpr.new()
	expr.bonus = value
	return expr


## [param text] as an expression. Anything it can't read counts as 0.
static func parse(text: String) -> DiceExpr:
	var expr := DiceExpr.new()
	var clean := text.strip_edges().to_upper().replace("\"", "").replace("+", " +").replace("-", " -")
	for part in clean.split(" ", false):
		var at := part.find("D")
		if at < 0:
			expr.bonus += part.to_int()
			continue
		var before := part.substr(0, at).trim_prefix("+")
		expr.count = before.to_int() if before.is_valid_int() else 1
		expr.sides = part.substr(at + 1).to_int()
	return expr


func is_fixed() -> bool:
	return count == 0 or sides == 0


func roll(rng: RandomNumberGenerator) -> int:
	var total := bonus
	if sides > 0:
		for _i in count:
			total += rng.randi_range(1, sides)
	return total


## What it comes to on average, for the AI.
func average() -> float:
	return bonus + count * (sides + 1) / 2.0


func _to_string() -> String:
	if is_fixed():
		return str(bonus)
	var dice := "%sD%d" % ["" if count == 1 else str(count), sides]
	return dice if bonus == 0 else "%s%+d" % [dice, bonus]
