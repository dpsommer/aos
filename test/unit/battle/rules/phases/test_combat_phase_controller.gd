extends GutTest
## The combat phase: who picks the next unit to fight, and strike order.

const RulesKit := preload("res://test/support/rules_kit.gd")
const PICK := "Pick a unit to fight."

var _games: Array[GameController] = []


func after_each() -> void:
	for each in _games:
		each.dispose()
	_games.clear()


func _fighter(unit_name: String, at: Vector2, keywords := PackedStringArray()) -> BattleUnit:
	var weapon := RulesKit.weapon("1", 2, 2, 0, "1")
	return RulesKit.unit(unit_name, 1, at, keywords, 100, 0, [weapon] as Array[Weapon])


## A Matched Play game with the units all in combat, in a block: the player's are in the west.
func _game(mine: Array[BattleUnit], theirs: Array[BattleUnit]) -> GameController:
	var game := RulesKit.matched_game(mine, theirs)
	_games.append(game)
	return game


func _block(player_keywords: Array = [], opponent_keywords: Array = []) -> GameController:
	var mine: Array[BattleUnit] = [
		_fighter("P1", Vector2(5, 5), PackedStringArray(player_keywords[0] if player_keywords.size() > 0 else [])),
		_fighter("P2", Vector2(5, 8), PackedStringArray(player_keywords[1] if player_keywords.size() > 1 else [])),
	]
	var theirs: Array[BattleUnit] = [
		_fighter("O1", Vector2(6.5, 5), PackedStringArray(opponent_keywords[0] if opponent_keywords.size() > 0 else [])),
		_fighter("O2", Vector2(6.5, 8), PackedStringArray(opponent_keywords[1] if opponent_keywords.size() > 1 else [])),
	]
	return _game(mine, theirs)


## Plays to the combat phase and through it. Returns each pick as "side:unit", and what was offered
## at the first as the units' names.
func _fights(game: GameController, first_offer: Array[String] = []) -> Array[String]:
	var ai := AiParticipant.new()
	var picks: Array[String] = []
	var handler := func(request: DecisionRequest) -> Decision:
		if request.prompt == PICK:
			if picks.is_empty():
				first_offer.assign(request.options.map(func(o: ActionOption) -> String: return o.user.name))
			var option := request.options[0]
			picks.append("%s:%s" % ["player" if request.army == game.battle.player else "opponent", option.user.name])
			return Decision.use(option)
		if request.kind == DecisionRequest.Kind.FIRST_TURN:
			return Decision.choose(0)
		if request.kind == DecisionRequest.Kind.ACTION:
			return Decision.pass_it()
		return ai.decide(request, game)
	# Only the first combat phase.
	var seen := [0]
	RulesKit.drive(game, func(request: DecisionRequest) -> Decision:
		if request.prompt == PICK:
			seen[0] += 1
		if seen[0] > 0 and request.kind == DecisionRequest.Kind.ACTION and request.prompt != PICK:
			return null
		return handler.call(request), 300)
	return picks


## Whose each of [param picks] from [method _fights] was, or which unit's with [param part] 1.
func _pick_parts(picks: Array[String], part := 0) -> Array:
	return picks.map(func(pick: String) -> String: return pick.get_slice(":", part))


## Plays to the first time a player is asked to pick a unit to fight.
func _at_first_pick(game: GameController) -> DecisionRequest:
	return RulesKit.drive(game, func(r: DecisionRequest) -> Decision: return null if r.prompt == PICK else (Decision.choose(0) if r.kind == DecisionRequest.Kind.FIRST_TURN else Decision.pass_it()))


func test_the_players_alternate_picking_a_unit_to_fight() -> void:
	var picks := _fights(_block())
	assert_eq(_pick_parts(picks), ["player", "opponent", "player", "opponent"], "Each unit fights once")


func test_the_active_player_picks_first() -> void:
	var picks := _fights(_block())
	assert_true(picks[0].begins_with("player"))


func test_each_unit_fights_once() -> void:
	var units := _pick_parts(_fights(_block()), 1)
	units.sort()
	assert_eq(units, ["O1", "O2", "P1", "P2"])


func test_a_player_with_nothing_left_to_fight_with_lets_the_other_go_on() -> void:
	var mine: Array[BattleUnit] = [_fighter("P1", Vector2(5, 5)), _fighter("P2", Vector2(5, 8))]
	var theirs: Array[BattleUnit] = [_fighter("O1", Vector2(6.5, 5))]
	assert_eq(_pick_parts(_fights(_game(mine, theirs))), ["player", "opponent", "player"])


func test_a_strike_first_unit_fights_before_the_active_players_units() -> void:
	var offer: Array[String] = []
	var picks := _fights(_block([], [["STRIKE-FIRST"]]), offer)
	assert_eq(offer, ["O1"], "Only the strike-first unit can be picked")
	assert_eq(picks[0], "opponent:O1")


func test_strike_first_units_all_fight_before_the_rest() -> void:
	var picks := _fights(_block([["STRIKE-FIRST"]], [["STRIKE-FIRST"]]))
	var firsts := _pick_parts(picks.slice(0, 2), 1)
	firsts.sort()
	assert_eq(firsts, ["O1", "P1"])


func test_a_strike_last_unit_fights_after_everyone_else() -> void:
	var picks := _fights(_block([["STRIKE-LAST"]]))
	assert_eq(picks[picks.size() - 1], "player:P1")
	assert_eq(picks.size(), 4)


func test_strike_first_and_strike_last_cancel_out() -> void:
	var offer: Array[String] = []
	_fights(_block([], [["STRIKE-FIRST", "STRIKE-LAST"]]), offer)
	assert_eq(offer.size(), 2, "No priority: the active player's units")
	assert_true("P1" in offer)


func test_a_unit_that_has_to_fight_cannot_pass() -> void:
	var game := _block()
	var at_pick := _at_first_pick(game)
	assert_not_null(at_pick)
	assert_ne(game.answer(Decision.pass_it()), "")
	assert_eq(game.next_decision(), at_pick)


func test_a_unit_that_is_not_on_offer_cannot_be_picked() -> void:
	var game := _block()
	var at_pick := _at_first_pick(game)
	var elsewhere := ActionOption.create(at_pick.options[0].entry, game.battle.opponent.units[0])
	assert_ne(game.answer(Decision.use(elsewhere)), "")


# STRIKE-FIRST only counts for units in combat when the phase began

func _opened(game: GameController) -> CombatPhaseController:
	game.state.active = game.battle.player
	var phase := CombatPhaseController.new(AbilityTiming.Moment.COMBAT)
	phase.advance(game)
	return phase


func test_strike_first_works_for_a_unit_that_began_the_phase_in_combat() -> void:
	var game := _block([], [["STRIKE-FIRST"]])
	var phase := _opened(game)
	assert_true(phase.strikes_first(game, game.battle.opponent.units[0]))


func test_strike_first_does_nothing_for_a_unit_not_in_combat_when_the_phase_began() -> void:
	var game := _block([], [["STRIKE-FIRST"]])
	var phase := _opened(game)
	var late := _fighter("Late", Vector2(25, 15), PackedStringArray(["STRIKE-FIRST"]))
	assert_false(phase.strikes_first(game, late))


func test_strike_first_does_nothing_for_a_unit_without_the_keyword() -> void:
	var game := _block([], [["STRIKE-FIRST"]])
	var phase := _opened(game)
	assert_false(phase.strikes_first(game, game.battle.opponent.units[1]))


func test_a_unit_that_came_into_combat_after_the_phase_began_does_not_strike_first() -> void:
	var mine: Array[BattleUnit] = [_fighter("P1", Vector2(5, 5))]
	var theirs: Array[BattleUnit] = [_fighter("Far", Vector2(25, 15), PackedStringArray(["STRIKE-FIRST"]))]
	var game := _game(mine, theirs)
	var phase := _opened(game)
	theirs[0].positions = PackedVector2Array([Vector2(6.5, 5)])
	assert_true(game.in_combat(theirs[0]))
	assert_false(phase.strikes_first(game, theirs[0]))


func test_both_keywords_mean_neither() -> void:
	var game := _block([], [["STRIKE-FIRST", "STRIKE-LAST"]])
	var phase := _opened(game)
	assert_false(phase.strikes_first(game, game.battle.opponent.units[0]))
	assert_false(phase.strikes_last(game, game.battle.opponent.units[0]))


func test_strike_last_is_for_the_keyword_alone() -> void:
	var game := _block([], [["STRIKE-LAST"]])
	var phase := _opened(game)
	assert_true(phase.strikes_last(game, game.battle.opponent.units[0]))
	assert_false(phase.strikes_last(game, game.battle.opponent.units[1]))
