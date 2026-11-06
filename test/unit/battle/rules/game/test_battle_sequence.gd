extends GutTest
## The battle from round to round, turn to turn and phase to phase.

const RulesKit := preload("res://test/support/rules_kit.gd")
const BattleKit := preload("res://test/support/battle_kit.gd")

var _games: Array[GameController] = []


func after_each() -> void:
	for each in _games:
		each.dispose()
	_games.clear()


func _game(seed_value := 1) -> GameController:
	var game := RulesKit.matched_game([RulesKit.unit("Mine", 1, Vector2(5, 5))] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(25, 15))] as Array[BattleUnit], seed_value)
	_games.append(game)
	return game


func _kinds(game: GameController, kind: StringName) -> Array[BattleEvent]:
	var result: Array[BattleEvent] = []
	for event in game.events.log_entries:
		if event.kind == kind:
			result.append(event)
	return result


func _play(game: GameController, stop: Callable = Callable()) -> DecisionRequest:
	return RulesKit.drive(game, func(request: DecisionRequest) -> Decision:
		if stop.is_valid() and stop.call(request):
			return null
		return RulesKit.pass_on(request), 2000)


func test_the_battle_lasts_the_rounds_the_rules_say() -> void:
	var game := _game()
	_play(game)
	assert_eq(_kinds(game, BattleEvent.ROUND_STARTED).size(), game.rules.round_count())
	assert_eq(_kinds(game, BattleEvent.ROUND_ENDED).size(), game.rules.round_count())


func test_the_end_of_the_battle_is_announced_once_with_the_result() -> void:
	var game := _game()
	_play(game)
	var ended := _kinds(game, BattleEvent.BATTLE_ENDED)
	assert_eq(ended.size(), 1)
	assert_eq(ended[0].data.outcome, game.state.outcome)
	assert_true(game.is_over())


func test_a_battle_with_no_scoring_is_a_draw() -> void:
	var game := _game()
	_play(game)
	assert_eq(game.state.outcome, GameState.Outcome.DRAW)


func test_nothing_more_is_asked_once_the_battle_is_over() -> void:
	var game := _game()
	_play(game)
	assert_null(game.next_decision())
	assert_ne(game.answer(Decision.pass_it()), "")


func test_each_round_has_two_turns_the_first_players_then_the_others() -> void:
	var game := _game()
	_play(game)
	var turns := _kinds(game, BattleEvent.TURN_STARTED)
	assert_eq(turns.size(), game.rules.round_count() * 2)
	for round_index in game.rules.round_count():
		assert_ne(turns[round_index * 2].data.army, turns[round_index * 2 + 1].data.army)
		assert_eq(turns[round_index * 2].data.round, round_index + 1)


func test_the_player_who_goes_first_in_round_one_has_the_first_turn() -> void:
	var game := _game()
	_play(game)
	assert_eq(_kinds(game, BattleEvent.TURN_STARTED)[0].data.army, game.battle.attacker())


func test_each_turn_runs_through_the_phases_in_order() -> void:
	var game := _game()
	_play(game)
	var windows: Array = []
	for event in _kinds(game, BattleEvent.PHASE_STARTED):
		windows.append(event.data.window)
	# The round's start window, then the first turn's phases.
	var turn: Array = AbilityTiming.TURN_WINDOWS
	assert_eq(windows[0], AbilityTiming.Moment.START_OF_ROUND)
	assert_eq(windows.slice(1, 1 + turn.size()), turn)


func test_the_rounds_end_window_comes_after_the_second_turn() -> void:
	var game := _game()
	_play(game)
	var windows: Array = []
	for event in _kinds(game, BattleEvent.PHASE_STARTED):
		windows.append(event.data.window)
	assert_eq(windows[1 + 2 * AbilityTiming.TURN_WINDOWS.size() + 0], AbilityTiming.Moment.END_OF_ROUND)


func test_every_phase_that_starts_ends() -> void:
	var game := _game()
	_play(game)
	assert_eq(_kinds(game, BattleEvent.PHASE_STARTED).size(), _kinds(game, BattleEvent.PHASE_ENDED).size())


func test_the_turn_counter_goes_up_each_turn() -> void:
	var game := _game()
	_play(game)
	assert_eq(game.state.turn_serial, game.rules.round_count() * 2)


func test_turn_statistics_start_again_each_turn() -> void:
	var game := _game()
	game.state.count_turn(game.battle.player, &"enemy_destroyed")
	_play(game, func(request: DecisionRequest) -> bool: return request.kind == DecisionRequest.Kind.FIRST_TURN and game.state.round_number == 2)
	assert_eq(game.state.turn_stat(game.battle.player, &"enemy_destroyed"), 0)


# Round 2 onwards: the priority roll

func _at_round_two(seed_value: int) -> GameController:
	var game := _game(seed_value)
	_play(game, func(request: DecisionRequest) -> bool: return request.kind == DecisionRequest.Kind.FIRST_TURN and game.state.round_number == 2)
	return game


func test_the_higher_priority_roll_chooses_in_later_rounds() -> void:
	var game := _at_round_two(RulesKit.seed_for([6, 1]))
	assert_eq(game.next_decision().army, game.battle.player, "Player 6 against 1")
	var other := _at_round_two(RulesKit.seed_for([1, 6]))
	assert_eq(other.next_decision().army, other.battle.opponent)


func test_a_tied_priority_roll_goes_to_whoever_went_first_last_round() -> void:
	var game := _at_round_two(RulesKit.seed_for([3, 3]))
	assert_eq(game.next_decision().army, game.state.first_last_round)


func test_the_priority_roll_is_in_the_log() -> void:
	var game := _at_round_two(RulesKit.seed_for([6, 1]))
	var rolls := _kinds(game, BattleEvent.ROLL_MADE).filter(func(e: BattleEvent) -> bool: return e.data.name == "priority")
	assert_eq(rolls.size(), 1)


func test_the_army_behind_is_the_underdog_each_round() -> void:
	var game := _game()
	game.state.victory_points[game.battle.opponent] = 4
	game.state.victory_points[game.battle.player] = 1
	game.next_decision()
	game.answer(Decision.choose(0))
	game.next_decision()
	assert_eq(game.state.underdog, game.battle.player)


func test_level_armies_have_no_underdog() -> void:
	var game := _game()
	game.next_decision()
	game.answer(Decision.choose(0))
	game.next_decision()
	assert_null(game.state.underdog)


# Ending a turn

func test_the_active_army_scores_at_the_end_of_its_turn() -> void:
	var game := _game()
	var plan := BattleKit.battleplan("Plan")
	plan.scoring = PackedStringArray(["Score 3 victory points if you control at least 1 objective."])
	game.battle.battleplan = plan
	game.battle.objectives = [BattleKit.feature("Sun Seekers", Vector2(5, 5))] as Array[MapFeature]
	_play(game, func(request: DecisionRequest) -> bool: return request.kind == DecisionRequest.Kind.FIRST_TURN and game.state.round_number == 2)
	assert_eq(game.state.points_of(game.battle.player), 3, "It stands on the objective and had one turn")
	assert_eq(game.state.points_of(game.battle.opponent), 0)


func test_the_end_of_a_turn_works_out_who_controls_objectives() -> void:
	var game := _game()
	var objective := BattleKit.feature("Sun Seekers", Vector2(5, 5))
	game.battle.objectives = [objective] as Array[MapFeature]
	_play(game, func(request: DecisionRequest) -> bool: return request.kind == DecisionRequest.Kind.FIRST_TURN and game.state.round_number == 2)
	assert_eq(game.state.objective_control[objective], game.battle.player)
