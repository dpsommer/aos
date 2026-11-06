class_name Commands
extends RefCounted
## What can be asked of a [BattlefieldController]. An effect makes one of these and hands it to its
## target through [method GameController.command]; the target resolves it. Each says what it wants
## and nothing about how: damage doesn't know about wards, say.


## Puts [member points] into the target's damage pool, for the damage sequence (Core Rules 18.0).
class DealDamage extends RefCounted:
	var points: int
	## Who dealt it, for destroyed-unit tallies, or null.
	var source_army: BattleArmy

	func _init(amount: int, from: BattleArmy = null) -> void:
		points = amount
		source_army = from


## Heal (N) (Core Rules 21.0).
class Heal extends RefCounted:
	var points: int

	func _init(amount: int) -> void:
		points = amount


## Moves the models to [member positions]. Already checked by [MovementRules].
class MoveModels extends RefCounted:
	var positions: PackedVector2Array
	var spec: MoveSpec

	func _init(to: PackedVector2Array, of: MoveSpec) -> void:
		positions = to
		spec = of


## Holds [member modifier].
class ApplyModifier extends RefCounted:
	var modifier: Modifier

	func _init(of: Modifier) -> void:
		modifier = of


## Returns up to [member count] slain models, near the unit (Core Rules 22.0).
class ReturnModels extends RefCounted:
	var count: int

	func _init(how_many: int) -> void:
		count = how_many


## Sets the unit up at [member positions] (Core Rules 24.0).
class SetUp extends RefCounted:
	var positions: PackedVector2Array

	func _init(at: PackedVector2Array) -> void:
		positions = at


## Takes the unit off the battlefield, into [member reserve_name].
class Remove extends RefCounted:
	var reserve_name: String

	func _init(reserve_as := "in reserve") -> void:
		reserve_name = reserve_as


## Destroys the unit, whatever its models (Core Rules 18.4).
class Destroy extends RefCounted:
	var source_army: BattleArmy

	func _init(from: BattleArmy = null) -> void:
		source_army = from


## Adds [member by] to the counter called [member counter_name], e.g. Ironjawz' momentum.
class ChangeCounter extends RefCounted:
	var counter_name: StringName
	var by: int

	func _init(of: StringName, amount: int) -> void:
		counter_name = of
		by = amount
