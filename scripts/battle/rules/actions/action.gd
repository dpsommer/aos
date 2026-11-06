class_name Action
extends RefCounted
## An ability being used: who uses it, its targets and what it does, as the [ActionFrame] resolves it.
## Effects act on the targets through their controllers.

var entry: AbilityEntry
var army: BattleArmy
## The unit using it, or null if the player does.
var user: BattleUnit
var targets: Array[BattleUnit] = []
## The ability this reacts to, or null.
var parent: Action
## Rolls made for it, by name: "charge" and so on.
var rolls := {}
## What a reaction changed about how it resolves: "no_run_roll", or "added_move".
var flags := {}
## Each weapon's target, for an ATTACK ability: a [Weapon] to a [BattleUnit].
var attack_targets := {}
## Damage points waiting for the damage sequence (Core Rules 18.0), by unit.
var damage_pool := {}


static func create(option: ActionOption, of_parent: Action = null) -> Action:
	var action := Action.new()
	action.entry = option.entry
	action.army = option.entry.army
	action.user = option.user
	action.parent = of_parent
	return action


func ability() -> Ability:
	return entry.ability


func has_keyword(keyword: String) -> bool:
	return keyword in entry.ability.keywords


func add_damage(to: BattleUnit, points: int) -> void:
	if points > 0:
		damage_pool[to] = damage_pool.get(to, 0) + points
