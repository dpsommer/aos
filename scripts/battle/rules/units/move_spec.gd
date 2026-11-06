class_name MoveSpec
extends RefCounted
## What a move allows, for [MovementRules] to check against and the player and AI to plan within.

enum Kind {
	## Up to its Move; can't move into combat at any point (Normal Move, Core Rules 14.1).
	NORMAL,
	## The same, marking that it ran.
	RUN,
	## Can pass through combat ranges, can't end in one (14.1).
	RETREAT,
	## Can pass through combat ranges, must end within ½" of a visible enemy (14.3).
	CHARGE,
	## Up to 3": no further from its target, and still in combat with all it was (15.3).
	PILE_IN,
	## An ability's move that can go anywhere, in combat too. May have to end in combat.
	FREE,
}

const PILE_IN_DISTANCE := 3.0

var unit: BattleUnit
var kind := Kind.NORMAL
## How far each model can go, in inches.
var max_distance := 0.0
## The enemy a pile-in move is towards, or null if the unit isn't in combat.
var pile_in_target: BattleUnit
## Whether it has to end in combat: a FREE move that started in combat, say.
var must_end_in_combat := false
## Whether it can't end in a new combat: 'Power Through' can stay with who it's fighting.
var avoid_new_combat := false
## Enemies whose combat range it can end in when [member avoid_new_combat].
var ignores_combat_of: Array[BattleUnit] = []


static func create(of: BattleUnit, move_kind: Kind, distance: float) -> MoveSpec:
	var spec := MoveSpec.new()
	spec.unit = of
	spec.kind = move_kind
	spec.max_distance = distance
	return spec


## What the event log says it did.
func verb() -> String:
	match kind:
		Kind.RUN:
			return "runs"
		Kind.RETREAT:
			return "retreats"
		Kind.CHARGE:
			return "charges"
		Kind.PILE_IN:
			return "piles in"
	return "moves"
