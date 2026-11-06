extends GutTest
## Taking a unit off the battlefield and setting it up again.

const RulesKit := preload("res://test/support/rules_kit.gd")
const BattleSim := preload("res://test/support/battle_sim.gd")

var _game: GameController
var _unit: BattleUnit


func before_each() -> void:
	_unit = RulesKit.unit("Unit", 2, Vector2(5, 5))
	_game = RulesKit.game([_unit] as Array[BattleUnit], [RulesKit.unit("Enemy", 1, Vector2(25, 18))] as Array[BattleUnit])
	_game.command(_unit, Commands.Remove.new("in reserve"))


func after_each() -> void:
	_game.dispose()


func _start(extra := {}) -> Array:
	var descriptor := {"op": "setup", "to": "user"}
	descriptor.merge(extra)
	var effect := RulesKit.effect(descriptor)
	var action := RulesKit.action(_game, _unit)
	return [effect, action, effect.resolve(action, _game)]


func _at(x: float, y: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + 1.5, y)])


func test_it_asks_where_to_set_the_unit_up() -> void:
	var request: DecisionRequest = _start()[2]
	assert_eq(request.kind, DecisionRequest.Kind.SET_UP)
	assert_eq(request.unit, _unit)
	assert_true(request.can_pass)


func test_the_minimum_gap_from_enemies_is_in_the_request() -> void:
	var request: DecisionRequest = _start({"min_enemy_gap": 6})[2]
	assert_eq(request.min_enemy_gap, 6.0)


func test_a_legal_spot_sets_the_unit_up() -> void:
	var started := _start()
	assert_eq(started[0].answer(started[1], _game, started[2], Decision.move_to(_at(10, 10))), "")
	assert_true(_unit.is_on_battlefield())
	assert_eq(_unit.positions, _at(10, 10))
	assert_eq(_unit.reserve, "")


func test_a_spot_too_near_an_enemy_is_refused() -> void:
	var started := _start({"min_enemy_gap": 9})
	var reason: String = started[0].answer(started[1], _game, started[2], Decision.move_to(_at(20, 16)))
	assert_ne(reason, "")
	assert_false(_unit.is_on_battlefield())


func test_a_spot_off_the_battlefield_is_refused() -> void:
	var started := _start()
	assert_ne(started[0].answer(started[1], _game, started[2], Decision.move_to(_at(-5, 5))), "")


func test_a_spot_that_breaks_coherency_is_refused() -> void:
	var started := _start()
	var apart := PackedVector2Array([Vector2(5, 5), Vector2(15, 5)])
	assert_ne(started[0].answer(started[1], _game, started[2], Decision.move_to(apart)), "")


func test_every_model_has_to_be_set_up() -> void:
	var started := _start()
	assert_ne(started[0].answer(started[1], _game, started[2], Decision.move_to(PackedVector2Array([Vector2(5, 5)]))), "")


func test_a_spot_that_has_to_be_near_the_user_is_refused_if_it_is_not() -> void:
	var anchor := RulesKit.unit("Anchor", 1, Vector2(5, 15))
	_game.dispose()
	_unit = RulesKit.unit("Unit", 2, Vector2(5, 5))
	_game = RulesKit.game([_unit, anchor] as Array[BattleUnit], [RulesKit.unit("Enemy", 1, Vector2(25, 18))] as Array[BattleUnit])
	_game.command(_unit, Commands.Remove.new("in reserve"))
	var effect := RulesKit.effect({"op": "setup", "near_user": 6})
	var action := RulesKit.action(_game, anchor, [_unit] as Array[BattleUnit])
	action.targets = [_unit] as Array[BattleUnit]
	var request: DecisionRequest = effect.resolve(action, _game)
	assert_eq(request.near_unit, anchor)
	assert_ne(effect.answer(action, _game, request, Decision.move_to(_at(5, 5))), "", "Ten inches away")
	assert_eq(effect.answer(action, _game, request, Decision.move_to(_at(5, 13))), "")


func test_passing_leaves_the_unit_in_reserve() -> void:
	var started := _start()
	assert_eq(started[0].answer(started[1], _game, started[2], Decision.pass_it()), "")
	assert_false(_unit.is_on_battlefield())


func test_once_answered_it_asks_nothing_more() -> void:
	var started := _start()
	started[0].answer(started[1], _game, started[2], Decision.pass_it())
	assert_null(started[0].resolve(started[1], _game))


func test_a_unit_set_up_is_marked_as_set_up_this_turn() -> void:
	var started := _start()
	started[0].answer(started[1], _game, started[2], Decision.move_to(_at(10, 10)))
	assert_true(_game.was_set_up_this_turn(_unit))


func test_a_unit_with_no_positions_is_laid_out_in_the_request() -> void:
	var unit := RulesKit.unit("Mob", 5, Vector2(5, 5))
	_game.dispose()
	_game = RulesKit.game([unit] as Array[BattleUnit], [RulesKit.unit("Enemy", 1, Vector2(25, 18))] as Array[BattleUnit])
	_game.command(unit, Commands.Remove.new("in reserve"))
	unit.positions = PackedVector2Array()
	var effect := RulesKit.effect({"op": "setup", "to": "user"})
	effect.resolve(RulesKit.action(_game, unit), _game)
	assert_eq(unit.positions.size(), unit.model_count())
	assert_eq(_game.set_up_problems(unit, unit.positions, 0.0, null, 0.0), PackedStringArray(), "A coherent spot on the battlefield")


func test_a_set_up_closer_than_the_gap_is_refused() -> void:
	var started := _start({"min_enemy_gap": 6})
	assert_ne(started[0].answer(started[1], _game, started[2], Decision.move_to(_at(20, 16))), "")
	assert_false(_unit.is_on_battlefield())


func test_an_accepted_set_up_clears_the_reserve() -> void:
	_unit.reserve = "in reserve"
	var started := _start()
	started[0].answer(started[1], _game, started[2], Decision.move_to(_at(10, 10)))
	assert_true(_unit.is_on_battlefield())
	assert_eq(_unit.reserve, "")


## The rounds in which the player's or the opponent's Brutes were set up in a seeded AI battle.
func _brutes_set_up_rounds(seed_value: int) -> Array[int]:
	var game := GameController.new(BattleSim.spearhead_battle(seed_value), BattleSim.seeded(seed_value))
	var rounds: Array[int] = []
	game.events.subscribe(BattleEvent.UNIT_SET_UP, func(event: BattleEvent) -> void:
		if event.data.unit.name == "Brutes" and event.data.unit.is_on_battlefield():
			rounds.append(game.state.round_number))
	assert_eq(BattleSim.play_out(game, AiParticipant.new()), "")
	game.dispose()
	return rounds


func test_brutes_in_an_ai_battle_are_only_set_up_from_round_three() -> void:
	var rounds := _brutes_set_up_rounds(1)
	assert_false(rounds.is_empty(), "They came on")
	for round_number in rounds:
		assert_gte(round_number, 3)
