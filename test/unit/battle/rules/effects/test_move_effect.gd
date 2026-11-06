extends GutTest
## Letting a unit move, and asking where to.

const RulesKit := preload("res://test/support/rules_kit.gd")

var _game: GameController
var _unit: BattleUnit


func before_each() -> void:
	_unit = RulesKit.unit("Unit", 2, Vector2(5, 5))
	_game = RulesKit.game([_unit] as Array[BattleUnit], [RulesKit.unit("Enemy", 1, Vector2(25, 18))] as Array[BattleUnit])


func after_each() -> void:
	_game.dispose()


func _move(descriptor: Dictionary, action: Action = null) -> Array:
	descriptor["op"] = "move"
	descriptor["to"] = "user"
	var used := action if action else RulesKit.action(_game, _unit)
	var effect := RulesKit.effect(descriptor)
	return [effect, used, effect.resolve(used, _game)]


func test_it_asks_where_the_unit_moves() -> void:
	var request: DecisionRequest = _move({"kind": "normal", "distance": "move"})[2]
	assert_eq(request.kind, DecisionRequest.Kind.MOVE)
	assert_eq(request.unit, _unit)
	assert_eq(request.army, _game.battle.player)
	assert_true(request.can_pass)


func test_the_kind_of_move_is_the_one_in_the_data() -> void:
	var cases := {"normal": MoveSpec.Kind.NORMAL, "run": MoveSpec.Kind.RUN, "retreat": MoveSpec.Kind.RETREAT, "charge": MoveSpec.Kind.CHARGE, "free": MoveSpec.Kind.FREE}
	for word: String in cases:
		var request: DecisionRequest = _move({"kind": word, "distance": "4"})[2]
		assert_eq(request.move.kind, cases[word], word)


func test_move_distance_is_the_units_move() -> void:
	var request: DecisionRequest = _move({"kind": "normal", "distance": "move"})[2]
	assert_eq(request.move.max_distance, float(_game.stats.value(_unit, &"move")))


func test_a_move_modifier_changes_the_distance() -> void:
	RulesKit.give(_game, _unit, RulesKit.modifier(&"move", 2, _game.battle.player))
	var request: DecisionRequest = _move({"kind": "normal", "distance": "move"})[2]
	assert_eq(request.move.max_distance, float(_game.stats.value(_unit, &"move")))
	assert_eq(request.move.max_distance, 8.0)


func test_a_fixed_distance() -> void:
	var request: DecisionRequest = _move({"kind": "free", "distance": "4"})[2]
	assert_eq(request.move.max_distance, 4.0)


func test_a_dice_distance_is_rolled() -> void:
	var request: DecisionRequest = _move({"kind": "free", "distance": "D6"})[2]
	assert_between(request.move.max_distance, 1.0, 6.0)


func test_a_run_adds_a_run_roll_to_the_move() -> void:
	var moved := _move({"kind": "run", "distance": "run"})
	var request: DecisionRequest = moved[2]
	var roll: int = moved[1].rolls["run"]
	assert_between(roll, 1, 6)
	assert_eq(request.move.max_distance, float(_game.stats.value(_unit, &"move")) + roll)


func test_at_the_double_adds_a_fixed_move_and_no_roll() -> void:
	var action := RulesKit.action(_game, _unit)
	action.flags["added_move"] = 6
	var request: DecisionRequest = _move({"kind": "run", "distance": "run"}, action)[2]
	assert_false(action.rolls.has("run"))
	assert_eq(request.move.max_distance, float(_game.stats.value(_unit, &"move")) + 6.0)


func test_the_distance_can_be_a_roll_the_action_made() -> void:
	var action := RulesKit.action(_game, _unit)
	action.rolls["charge"] = 9
	var request: DecisionRequest = _move({"kind": "charge", "distance": "roll", "roll": "charge"}, action)[2]
	assert_eq(request.move.max_distance, 9.0)


func test_a_pile_in_is_always_three_inches() -> void:
	var request: DecisionRequest = _move({"kind": "pile_in", "distance": "12"})[2]
	assert_eq(request.move.max_distance, MoveSpec.PILE_IN_DISTANCE)


func test_a_pile_in_is_towards_the_nearest_unit_in_combat() -> void:
	var enemy := _game.battle.opponent.units[0]
	enemy.positions = PackedVector2Array([Vector2(8, 5)])
	var request: DecisionRequest = _move({"kind": "pile_in"})[2]
	assert_eq(request.move.pile_in_target, enemy)


func test_a_move_that_has_to_end_in_combat_if_it_began_in_combat() -> void:
	_game.battle.opponent.units[0].positions = PackedVector2Array([Vector2(8, 5)])
	var request: DecisionRequest = _move({"kind": "free", "distance": "4", "end_in_combat_if_was": true})[2]
	assert_true(request.move.must_end_in_combat)
	_game.battle.opponent.units[0].positions = PackedVector2Array([Vector2(25, 18)])
	request = _move({"kind": "free", "distance": "4", "end_in_combat_if_was": true})[2]
	assert_false(request.move.must_end_in_combat)


func test_a_move_that_avoids_new_combat_remembers_who_it_is_already_fighting() -> void:
	var enemy := _game.battle.opponent.units[0]
	enemy.positions = PackedVector2Array([Vector2(8, 5)])
	var request: DecisionRequest = _move({"kind": "free", "distance": "4", "avoid_new_combat": true})[2]
	assert_true(request.move.avoid_new_combat)
	assert_eq(request.move.ignores_combat_of, [enemy] as Array[BattleUnit])


func test_a_move_of_no_distance_asks_nothing() -> void:
	assert_null(_move({"kind": "free", "distance": "0"})[2])


func test_a_legal_answer_moves_the_unit() -> void:
	var moved := _move({"kind": "normal", "distance": "6"})
	var to := MovementRules.shifted(_unit, Vector2(4, 0))
	assert_eq(moved[0].answer(moved[1], _game, moved[2], Decision.move_to(to)), "")
	assert_eq(_unit.positions, to)
	assert_true(_game.controller_of(_unit).moved)


func test_after_a_legal_answer_nothing_more_is_asked() -> void:
	var moved := _move({"kind": "normal", "distance": "6"})
	moved[0].answer(moved[1], _game, moved[2], Decision.move_to(MovementRules.shifted(_unit, Vector2(4, 0))))
	assert_null(moved[0].resolve(moved[1], _game))


func test_an_illegal_answer_is_refused_and_the_unit_stays() -> void:
	var moved := _move({"kind": "normal", "distance": "6"})
	var before := _unit.positions.duplicate()
	var reason: String = moved[0].answer(moved[1], _game, moved[2], Decision.move_to(MovementRules.shifted(_unit, Vector2(9, 0))))
	assert_ne(reason, "")
	assert_eq(_unit.positions, before)
	assert_not_null(moved[0].resolve(moved[1], _game), "Still asking")


func test_passing_leaves_the_unit_where_it_is() -> void:
	var moved := _move({"kind": "normal", "distance": "6"})
	var before := _unit.positions.duplicate()
	assert_eq(moved[0].answer(moved[1], _game, moved[2], Decision.pass_it()), "")
	assert_eq(_unit.positions, before)
	assert_null(moved[0].resolve(moved[1], _game))


func test_each_subject_moves_in_turn() -> void:
	var second := RulesKit.unit("Second", 1, Vector2(5, 15))
	_game.dispose()
	_game = RulesKit.game([_unit, second] as Array[BattleUnit], [RulesKit.unit("Enemy", 1, Vector2(25, 18))] as Array[BattleUnit])
	var effect := RulesKit.effect({"op": "move", "to": "friendly", "kind": "normal", "distance": "6"})
	var action := RulesKit.action(_game, _unit)
	var first_request: DecisionRequest = effect.resolve(action, _game)
	effect.answer(action, _game, first_request, Decision.pass_it())
	var next: DecisionRequest = effect.resolve(action, _game)
	assert_ne(next.unit, first_request.unit)
	effect.answer(action, _game, next, Decision.pass_it())
	assert_null(effect.resolve(action, _game))


func test_a_destroyed_subject_does_not_move() -> void:
	_game.command(_unit, Commands.Destroy.new(_game.battle.opponent))
	assert_null(_move({"kind": "normal", "distance": "6"})[2])
