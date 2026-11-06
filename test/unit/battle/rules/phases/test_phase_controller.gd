extends GutTest
## A phase: the active player uses abilities, then the other, and each unit's use is remembered.

const RulesKit := preload("res://test/support/rules_kit.gd")
const M := AbilityTiming.Moment

var _games: Array[GameController] = []


func after_each() -> void:
	for each in _games:
		each.dispose()
	_games.clear()
	RulesKit.forget_abilities()


func _game(mine: Array[BattleUnit] = [], theirs: Array[BattleUnit] = []) -> GameController:
	if mine.is_empty():
		mine = [RulesKit.unit("Mine", 1, Vector2(2, 3))] as Array[BattleUnit]
	if theirs.is_empty():
		theirs = [RulesKit.unit("Theirs", 1, Vector2(28, 15))] as Array[BattleUnit]
	var game := RulesKit.matched_game(mine, theirs)
	_games.append(game)
	return game


func test_each_window_has_its_own_kind_of_phase() -> void:
	var cases := {M.HERO: HeroPhaseController, M.MOVEMENT: MovementPhaseController, M.SHOOTING: ShootingPhaseController,
			M.CHARGE: ChargePhaseController, M.COMBAT: CombatPhaseController, M.END_OF_TURN: EndOfTurnController}
	for window: M in cases:
		assert_true(is_instance_of(PhaseController.for_window(window), cases[window]), str(window))


func test_other_windows_get_the_plain_phase() -> void:
	var phase := PhaseController.for_window(M.START_OF_ROUND)
	assert_eq(phase.get_script(), PhaseController)
	assert_eq(phase.window, M.START_OF_ROUND)


func test_opening_a_phase_sets_the_window_and_counts_it() -> void:
	var game := _game()
	game.state.active = game.battle.player
	var serial := game.state.window_serial
	var phase := PhaseController.new(M.SHOOTING)
	phase.advance(game)
	assert_eq(game.state.window, M.SHOOTING)
	assert_eq(game.state.window_serial, serial + 1)


func test_a_phase_with_nothing_to_use_runs_straight_through() -> void:
	var game := _game()
	game.state.active = game.battle.player
	var phase := PhaseController.new(M.SHOOTING)
	assert_null(phase.advance(game))
	assert_true(phase.finished)


func test_a_phase_announces_its_start_and_end() -> void:
	var game := _game()
	game.state.active = game.battle.player
	PhaseController.new(M.SHOOTING).advance(game)
	var kinds := game.events.log_entries.map(func(e: BattleEvent) -> StringName: return e.kind)
	assert_eq(kinds.count(BattleEvent.PHASE_STARTED), 1)
	assert_eq(kinds.count(BattleEvent.PHASE_ENDED), 1)
	assert_lt(kinds.find(BattleEvent.PHASE_STARTED), kinds.find(BattleEvent.PHASE_ENDED))


func test_an_ability_that_fits_the_phase_is_asked_about() -> void:
	var unit := RulesKit.unit("Mine", 1, Vector2(2, 3))
	RulesKit.add_ability(unit, RulesKit.ability("Trick", "Your Hero Phase"), {"do": [{"op": "heal", "to": "user"}]})
	var game := _game([unit] as Array[BattleUnit])
	game.state.active = game.battle.player
	var request := PhaseController.new(M.HERO).advance(game)
	assert_eq(request.kind, DecisionRequest.Kind.ACTION)
	assert_eq(request.army, game.battle.player)
	assert_true(request.can_pass)
	assert_true(request.options.any(func(o: ActionOption) -> bool: return o.ability_name() == "Trick"))


func test_the_other_player_is_asked_after_the_active_player_passes() -> void:
	var mine := RulesKit.unit("Mine", 1, Vector2(2, 3))
	var theirs := RulesKit.unit("Theirs", 1, Vector2(28, 15))
	var timing := "Any Hero Phase"
	RulesKit.add_ability(mine, RulesKit.ability("Mine Trick", timing), {"do": [{"op": "heal", "to": "user"}]})
	RulesKit.add_ability(theirs, RulesKit.ability("Their Trick", timing), {"do": [{"op": "heal", "to": "user"}]})
	var game := _game([mine] as Array[BattleUnit], [theirs] as Array[BattleUnit])
	game.state.active = game.battle.player
	var phase := PhaseController.new(M.HERO)
	var first := phase.advance(game)
	assert_eq(first.army, game.battle.player)
	assert_eq(phase.answer(game, first, Decision.pass_it()), "")
	var second := phase.advance(game)
	assert_eq(second.army, game.battle.opponent)


func test_a_ability_for_the_enemys_turn_is_not_offered_in_yours() -> void:
	var unit := RulesKit.unit("Mine", 1, Vector2(2, 3))
	RulesKit.add_ability(unit, RulesKit.ability("Trick", "Enemy Hero Phase"), {"do": [{"op": "heal", "to": "user"}]})
	var game := _game([unit] as Array[BattleUnit])
	game.state.active = game.battle.player
	assert_null(PhaseController.new(M.HERO).advance(game))


func test_a_unit_that_has_used_an_ability_is_remembered() -> void:
	var game := _game()
	var phase := PhaseController.new(M.HERO)
	var unit := game.battle.player.units[0]
	assert_false(phase.has_used(unit))
	phase.record_use(RulesKit.action(game, unit, [] as Array[BattleUnit], "Trick"))
	assert_true(phase.has_used(unit))
	assert_true(phase.has_used(unit, "Trick"))
	assert_false(phase.has_used(unit, "Other"))


func test_the_player_using_an_ability_is_not_recorded_against_a_unit() -> void:
	var game := _game()
	var phase := PhaseController.new(M.HERO)
	var action := RulesKit.action(game, game.battle.player.units[0])
	action.user = null
	phase.record_use(action)
	assert_false(phase.has_used(game.battle.player.units[0]))


func test_an_answer_for_an_unavailable_ability_is_refused() -> void:
	var unit := RulesKit.unit("Mine", 1, Vector2(2, 3))
	var ability := RulesKit.ability("Costly", "Your Hero Phase", "command")
	ability.command_points = 9
	RulesKit.add_ability(unit, ability, {"do": [{"op": "heal", "to": "user"}]})
	var game := _game([unit] as Array[BattleUnit])
	game.state.active = game.battle.player
	var phase := PhaseController.new(M.HERO)
	var option: ActionOption
	for entry: AbilityEntry in game.books[game.battle.player]:
		if entry.ability.name == "Costly":
			option = ActionOption.create(entry, unit)
	var request := DecisionRequest.create(DecisionRequest.Kind.ACTION, game.battle.player)
	request.options = [option] as Array[ActionOption]
	assert_ne(phase.answer(game, request, Decision.use(option)), "")


func test_an_answer_that_was_not_offered_is_refused() -> void:
	var unit := RulesKit.unit("Mine", 1, Vector2(2, 3))
	RulesKit.add_ability(unit, RulesKit.ability("Free", "Your Hero Phase"), {"do": [{"op": "heal", "to": "user"}]})
	var game := _game([unit] as Array[BattleUnit])
	game.state.active = game.battle.player
	var phase := PhaseController.new(M.HERO)
	var option: ActionOption
	for entry: AbilityEntry in game.books[game.battle.player]:
		if entry.ability.name == "Free":
			option = ActionOption.create(entry, unit)
	var request := DecisionRequest.create(DecisionRequest.Kind.ACTION, game.battle.opponent)
	assert_ne(phase.answer(game, request, Decision.use(option)), "")
