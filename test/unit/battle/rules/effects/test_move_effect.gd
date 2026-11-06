extends GutTest
## Letting a unit move, and asking where to.

const RulesKit := preload("res://test/support/rules_kit.gd")

var _game: GameController
var _unit: BattleUnit
var _effect: Effect
var _action: Action


func before_each() -> void:
	_unit = RulesKit.unit("Unit", 2, Vector2(5, 5))
	_game = RulesKit.game([_unit] as Array[BattleUnit], [RulesKit.unit("Enemy", 1, Vector2(25, 18))] as Array[BattleUnit])


func after_each() -> void:
	_game.dispose()


## Starts a move of the unit, by [param action] if given, and returns what it asks.
func _move(descriptor: Dictionary, action: Action = null) -> DecisionRequest:
	descriptor["op"] = "move"
	descriptor["to"] = "user"
	_action = action if action else RulesKit.action(_game, _unit)
	_effect = RulesKit.effect(descriptor)
	return _effect.resolve(_action, _game)


func _normal_move() -> DecisionRequest:
	return _move({"kind": "normal", "distance": "6"})


func _answer(request: DecisionRequest, decision: Decision) -> String:
	return _effect.answer(_action, _game, request, decision)


func _asks_again() -> DecisionRequest:
	return _effect.resolve(_action, _game)


func _unit_move() -> float:
	return float(_game.stats.value(_unit, &"move"))


func test_it_asks_where_the_unit_moves() -> void:
	var request := _move({"kind": "normal", "distance": "move"})
	assert_eq(request.kind, DecisionRequest.Kind.MOVE)
	assert_eq(request.unit, _unit)
	assert_eq(request.army, _game.battle.player)
	assert_true(request.can_pass)


func test_the_kind_of_move_is_the_one_in_the_data() -> void:
	var cases := {"normal": MoveSpec.Kind.NORMAL, "run": MoveSpec.Kind.RUN, "retreat": MoveSpec.Kind.RETREAT, "charge": MoveSpec.Kind.CHARGE, "free": MoveSpec.Kind.FREE}
	for word: String in cases:
		assert_eq(_move({"kind": word, "distance": "4"}).move.kind, cases[word], word)


func test_move_distance_is_the_units_move() -> void:
	assert_eq(_move({"kind": "normal", "distance": "move"}).move.max_distance, _unit_move())


func test_a_move_modifier_changes_the_distance() -> void:
	RulesKit.give(_game, _unit, RulesKit.modifier(&"move", 2, _game.battle.player))
	var request := _move({"kind": "normal", "distance": "move"})
	assert_eq(request.move.max_distance, _unit_move())
	assert_eq(request.move.max_distance, 8.0)


func test_a_fixed_distance() -> void:
	assert_eq(_move({"kind": "free", "distance": "4"}).move.max_distance, 4.0)


func test_a_dice_distance_is_rolled() -> void:
	assert_between(_move({"kind": "free", "distance": "D6"}).move.max_distance, 1.0, 6.0)


func test_a_run_adds_a_run_roll_to_the_move() -> void:
	var request := _move({"kind": "run", "distance": "run"})
	var roll: int = _action.rolls["run"]
	assert_between(roll, 1, 6)
	assert_eq(request.move.max_distance, _unit_move() + roll)


func test_at_the_double_adds_a_fixed_move_and_no_roll() -> void:
	var action := RulesKit.action(_game, _unit)
	action.flags["added_move"] = 6
	var request := _move({"kind": "run", "distance": "run"}, action)
	assert_false(action.rolls.has("run"))
	assert_eq(request.move.max_distance, _unit_move() + 6.0)


func test_the_distance_can_be_a_roll_the_action_made() -> void:
	var action := RulesKit.action(_game, _unit)
	action.rolls["charge"] = 9
	assert_eq(_move({"kind": "charge", "distance": "roll", "roll": "charge"}, action).move.max_distance, 9.0)


func test_a_pile_in_is_always_three_inches() -> void:
	assert_eq(_move({"kind": "pile_in", "distance": "12"}).move.max_distance, MoveSpec.PILE_IN_DISTANCE)


func test_a_pile_in_is_towards_the_nearest_unit_in_combat() -> void:
	var enemy := _game.battle.opponent.units[0]
	enemy.positions = PackedVector2Array([Vector2(8, 5)])
	assert_eq(_move({"kind": "pile_in"}).move.pile_in_target, enemy)


func test_a_move_that_began_in_combat_has_to_end_in_combat() -> void:
	_game.battle.opponent.units[0].positions = PackedVector2Array([Vector2(8, 5)])
	assert_true(_move({"kind": "free", "distance": "4", "end_in_combat_if_was": true}).move.must_end_in_combat)


func test_a_move_that_began_out_of_combat_does_not_have_to_end_in_combat() -> void:
	assert_false(_move({"kind": "free", "distance": "4", "end_in_combat_if_was": true}).move.must_end_in_combat)


func test_a_move_that_avoids_new_combat_remembers_who_it_is_already_fighting() -> void:
	var enemy := _game.battle.opponent.units[0]
	enemy.positions = PackedVector2Array([Vector2(8, 5)])
	var request := _move({"kind": "free", "distance": "4", "avoid_new_combat": true})
	assert_true(request.move.avoid_new_combat)
	assert_eq(request.move.ignores_combat_of, [enemy] as Array[BattleUnit])


func test_a_move_of_no_distance_asks_nothing() -> void:
	assert_null(_move({"kind": "free", "distance": "0"}))


func test_a_legal_answer_moves_the_unit() -> void:
	var to := MovementRules.shifted(_unit, Vector2(4, 0))
	assert_eq(_answer(_normal_move(), Decision.move_to(to)), "")
	assert_eq(_unit.positions, to)
	assert_true(_game.controller_of(_unit).moved)


func test_after_a_legal_answer_nothing_more_is_asked() -> void:
	_answer(_normal_move(), Decision.move_to(MovementRules.shifted(_unit, Vector2(4, 0))))
	assert_null(_asks_again())


func test_an_illegal_answer_is_refused_and_the_unit_stays() -> void:
	var before := _unit.positions.duplicate()
	assert_ne(_answer(_normal_move(), Decision.move_to(MovementRules.shifted(_unit, Vector2(9, 0)))), "")
	assert_eq(_unit.positions, before)
	assert_not_null(_asks_again(), "Still asking")


func test_passing_leaves_the_unit_where_it_is() -> void:
	var before := _unit.positions.duplicate()
	assert_eq(_answer(_normal_move(), Decision.pass_it()), "")
	assert_eq(_unit.positions, before)
	assert_null(_asks_again())


func test_each_subject_moves_in_turn() -> void:
	var second := RulesKit.unit("Second", 1, Vector2(5, 15))
	_game.dispose()
	_game = RulesKit.game([_unit, second] as Array[BattleUnit], [RulesKit.unit("Enemy", 1, Vector2(25, 18))] as Array[BattleUnit])
	_effect = RulesKit.effect({"op": "move", "to": "friendly", "kind": "normal", "distance": "6"})
	_action = RulesKit.action(_game, _unit)
	var first_request := _asks_again()
	_answer(first_request, Decision.pass_it())
	var next := _asks_again()
	assert_ne(next.unit, first_request.unit)
	_answer(next, Decision.pass_it())
	assert_null(_asks_again())


func test_a_destroyed_subject_does_not_move() -> void:
	_game.command(_unit, Commands.Destroy.new(_game.battle.opponent))
	assert_null(_normal_move())
