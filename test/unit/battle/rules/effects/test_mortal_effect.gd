extends GutTest
## Mortal damage.

const RulesKit := preload("res://test/support/rules_kit.gd")

var _game: GameController
var _user: BattleUnit
var _target: BattleUnit


func before_each() -> void:
	_user = RulesKit.unit("User", 3, Vector2(10, 10))
	_target = RulesKit.unit("Target", 1, Vector2(14.5, 10), PackedStringArray(["MONSTER"]))
	_game = RulesKit.game([_user] as Array[BattleUnit], [_target] as Array[BattleUnit])


func after_each() -> void:
	_game.dispose()


func _resolve(descriptor: Dictionary, action: Action = null) -> Action:
	var used := action if action else RulesKit.action(_game, _user, [_target] as Array[BattleUnit])
	RulesKit.effect(descriptor).resolve(used, _game)
	return used


func _pool(action: Action, unit: BattleUnit = _target) -> int:
	return action.damage_pool.get(unit, 0)


func test_the_amount_goes_into_the_targets_damage_pool() -> void:
	assert_eq(_pool(_resolve({"op": "mortal", "amount": "3"})), 3)


func test_it_does_no_damage_to_the_unit_yet() -> void:
	_resolve({"op": "mortal", "amount": "3"})
	assert_eq(_game.controller_of(_target).damage_points, 0, "The damage sequence comes after the ability")


func test_dice_are_rolled() -> void:
	var pool := _pool(_resolve({"op": "mortal", "amount": "D3"}))
	assert_between(pool, 1, 3)


func test_it_can_hurt_the_user() -> void:
	var action := _resolve({"op": "mortal", "to": "user", "amount": "2"})
	assert_eq(_pool(action, _user), 2)
	assert_eq(_pool(action), 0)


func test_an_amount_against_a_keyword_replaces_the_amount() -> void:
	var data := {"op": "mortal", "amount": "1", "amount_against": {"keyword": "MONSTER", "amount": "4"}}
	assert_eq(_pool(_resolve(data)), 4)
	data.amount_against = {"keyword": "HERO", "amount": "4"}
	assert_eq(_pool(_resolve(data)), 1)


func test_a_bonus_against_a_keyword_adds_one() -> void:
	assert_eq(_pool(_resolve({"op": "mortal", "amount": "2", "bonus_against": "MONSTER"})), 3)
	assert_eq(_pool(_resolve({"op": "mortal", "amount": "2", "bonus_against": "HERO"})), 2)


func test_a_flag_on_the_action_stops_it() -> void:
	var action := RulesKit.action(_game, _user, [_target] as Array[BattleUnit])
	action.flags["no_damage"] = true
	_resolve({"op": "mortal", "amount": "3", "unless_flag": "no_damage"}, action)
	assert_eq(_pool(action), 0)


func test_a_flag_it_does_not_name_does_not_stop_it() -> void:
	var action := RulesKit.action(_game, _user, [_target] as Array[BattleUnit])
	action.flags["something_else"] = true
	_resolve({"op": "mortal", "amount": "3", "unless_flag": "no_damage"}, action)
	assert_eq(_pool(action), 3)


func test_the_gate_roll_can_be_the_amount() -> void:
	var action := RulesKit.action(_game, _user, [_target] as Array[BattleUnit])
	action.rolls["gate"] = 5
	_resolve({"op": "mortal", "amount": "gate"}, action)
	assert_eq(_pool(action), 5)


func test_a_dice_for_each_model_near_the_target_that_succeeds_does_the_amount() -> void:
	# The user's three models are in a row, the nearest a quarter of an inch from the target.
	var data := {"op": "mortal", "amount": "2", "per_model_within": 1, "on": 1}
	assert_eq(_pool(_resolve(data)), 2, "One model within 1\"")
	data.per_model_within = 10
	assert_eq(_pool(_resolve(data)), 6, "All three")
	data.per_model_within = 2
	assert_eq(_pool(_resolve(data)), 4, "Two")


func test_a_dice_that_cannot_succeed_does_nothing() -> void:
	assert_eq(_pool(_resolve({"op": "mortal", "amount": "2", "per_model_within": 10, "on": 8})), 0)


func test_a_roll_modifier_helps_the_dice_succeed() -> void:
	RulesKit.give(_game, _user, RulesKit.modifier(&"mortal_roll", 2, _game.battle.player))
	var data := {"op": "mortal", "amount": "1", "per_model_within": 10, "on": 3, "roll_stat": "mortal_roll"}
	assert_eq(_pool(_resolve(data)), 3, "Even a 1 and 2 reaches 3")
