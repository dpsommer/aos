class_name CharacteristicsController
extends RefCounted
## The base characteristics of anything that has them: a unit's from its warscroll, or a faction
## terrain feature's. Knows nothing about what holds them. Each is a [DiceExpr], as a Move or a
## banishment value may be random; what modifiers do to it is the [StatResolver]'s job.

var _base := {}


## From [param scroll], or zeroes without one.
static func from_warscroll(scroll: Warscroll) -> CharacteristicsController:
	var result := CharacteristicsController.new()
	if scroll == null:
		return result
	result.set_base(&"move", DiceExpr.parse(scroll.move))
	result.set_base(&"health", DiceExpr.of_value(scroll.health))
	result.set_base(&"save", DiceExpr.of_value(scroll.save))
	result.set_base(&"ward", DiceExpr.of_value(scroll.ward))
	result.set_base(&"control", DiceExpr.of_value(scroll.control))
	result.set_base(&"banishment", DiceExpr.of_value(scroll.banishment))
	return result


func set_base(stat: StringName, value: DiceExpr) -> void:
	_base[stat] = value


func base(stat: StringName) -> DiceExpr:
	return _base.get(stat, DiceExpr.of_value(0))
