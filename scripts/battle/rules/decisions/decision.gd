class_name Decision
extends RefCounted
## An answer to a [DecisionRequest].

## Whether they passed, or chose not to move.
var passed := false
var option: ActionOption
var units: Array[BattleUnit] = []
## Each weapon's target.
var attack_targets := {}
var positions := PackedVector2Array()
## The index of a choice: for [enum DecisionRequest.Kind].FIRST_TURN, 0 goes first and 1 goes second.
var choice := 0


static func pass_it() -> Decision:
	var decision := Decision.new()
	decision.passed = true
	return decision


static func use(of: ActionOption) -> Decision:
	var decision := Decision.new()
	decision.option = of
	return decision


static func pick(of: Array[BattleUnit]) -> Decision:
	var decision := Decision.new()
	decision.units = of
	return decision


static func attack(with: Dictionary) -> Decision:
	var decision := Decision.new()
	decision.attack_targets = with
	return decision


static func move_to(at: PackedVector2Array) -> Decision:
	var decision := Decision.new()
	decision.positions = at
	return decision


static func choose(index: int) -> Decision:
	var decision := Decision.new()
	decision.choice = index
	return decision
