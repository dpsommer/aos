extends GutTest
## Resolving the attacks that were picked.

const RulesKit := preload("res://test/support/rules_kit.gd")

var _game: GameController
var _attacker: BattleUnit
var _target: BattleUnit
var _axe: Weapon


func before_each() -> void:
	_axe = RulesKit.weapon("600", 2, 2)
	_axe.name = "Axe"
	_attacker = RulesKit.unit("Attacker", 1, Vector2(5, 5), PackedStringArray(), 1, 0, [_axe] as Array[Weapon])
	_target = RulesKit.unit("Target", 1, Vector2(6.5, 5))
	_game = RulesKit.game([_attacker] as Array[BattleUnit], [_target] as Array[BattleUnit])


func after_each() -> void:
	_game.dispose()


func _events() -> Array[BattleEvent]:
	var result: Array[BattleEvent] = []
	for event in _game.events.log_entries:
		if event.kind == BattleEvent.ATTACKS_RESOLVED:
			result.append(event)
	return result


func _attack(action: Action, type := "melee") -> void:
	RulesKit.effect({"op": "attack", "type": type}).resolve(action, _game)


func test_the_picked_weapons_attack_the_picked_targets() -> void:
	var action := RulesKit.action(_game, _attacker, [_target] as Array[BattleUnit])
	action.attack_targets = {_axe: _target}
	_attack(action)
	assert_gt(action.damage_pool.get(_target, 0), 0)


func test_the_attack_is_announced() -> void:
	var action := RulesKit.action(_game, _attacker, [_target] as Array[BattleUnit])
	action.attack_targets = {_axe: _target}
	_attack(action)
	assert_eq(_events().size(), 1)
	assert_eq(_events()[0].data.target, _target)
	assert_eq(_events()[0].data.result.damage, action.damage_pool[_target])


func test_a_target_picked_by_the_ability_is_attacked_by_every_weapon_that_can_reach_it() -> void:
	var action := RulesKit.action(_game, _attacker, [_target] as Array[BattleUnit])
	_attack(action)
	assert_eq(_events().size(), 1)
	assert_gt(action.damage_pool.get(_target, 0), 0)


func test_weapons_of_the_other_type_do_not_attack() -> void:
	var action := RulesKit.action(_game, _attacker, [_target] as Array[BattleUnit])
	_attack(action, "shooting")
	assert_true(_events().is_empty())


func test_a_destroyed_target_is_not_attacked() -> void:
	var action := RulesKit.action(_game, _attacker, [_target] as Array[BattleUnit])
	action.attack_targets = {_axe: _target}
	_game.command(_target, Commands.Destroy.new(_game.battle.player))
	_attack(action)
	assert_true(_events().is_empty())
	assert_true(action.damage_pool.is_empty())


func test_a_destroyed_attacker_does_not_attack() -> void:
	var action := RulesKit.action(_game, _attacker, [_target] as Array[BattleUnit])
	action.attack_targets = {_axe: _target}
	_game.command(_attacker, Commands.Destroy.new(_game.battle.opponent))
	_attack(action)
	assert_true(_events().is_empty())


func test_the_player_using_the_ability_attacks_with_nothing() -> void:
	var action := RulesKit.action(_game, _attacker, [_target] as Array[BattleUnit])
	action.user = null
	_attack(action)
	assert_true(_events().is_empty())
