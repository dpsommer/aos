extends GutTest
## The decision loop, command points, reactions and summoning.

const RulesKit := preload("res://test/support/rules_kit.gd")
const BattleKit := preload("res://test/support/battle_kit.gd")
const M := AbilityTiming.Moment

var _games: Array[GameController] = []


func after_each() -> void:
	for each in _games:
		each.dispose()
	_games.clear()
	RulesKit.forget_abilities()


func _matched(player_units: Array[BattleUnit] = [], opponent_units: Array[BattleUnit] = []) -> GameController:
	if player_units.is_empty():
		player_units = [RulesKit.unit("Mine", 1, Vector2(2, 5))] as Array[BattleUnit]
	if opponent_units.is_empty():
		opponent_units = [RulesKit.unit("Theirs", 1, Vector2(28, 15))] as Array[BattleUnit]
	var game := RulesKit.matched_game(player_units, opponent_units)
	_games.append(game)
	return game


func _entry(game: GameController, army: BattleArmy, ability_name: String) -> AbilityEntry:
	for entry: AbilityEntry in game.books[army]:
		if entry.ability.name == ability_name:
			return entry
	return null


func _heal_for(unit: BattleUnit, ability_name: String, timing: String, type := "active", keywords := PackedStringArray(), points := 0) -> Ability:
	var ability := RulesKit.ability(ability_name, timing, type, keywords)
	ability.command_points = points
	RulesKit.add_ability(unit, ability, {"do": [{"op": "heal", "to": "user", "amount": "1"}]})
	return ability


# The decision loop

func test_the_first_decision_is_who_takes_the_first_turn() -> void:
	var game := _matched()
	var request := game.next_decision()
	assert_eq(request.kind, DecisionRequest.Kind.FIRST_TURN)
	assert_eq(request.army, game.battle.attacker(), "The attacker chooses in round 1")


func test_the_same_decision_is_asked_until_it_is_answered() -> void:
	var game := _matched()
	assert_eq(game.next_decision(), game.next_decision())


func test_nothing_can_be_answered_when_nothing_is_asked() -> void:
	var game := _matched()
	assert_ne(game.answer(Decision.pass_it()), "")


func test_going_first_makes_the_chooser_first() -> void:
	var game := _matched()
	var chooser := game.next_decision().army
	assert_eq(game.answer(Decision.choose(0)), "")
	assert_eq(game.state.first_this_round, chooser)


func test_going_second_makes_the_other_army_first() -> void:
	var game := _matched()
	var chooser := game.next_decision().army
	game.answer(Decision.choose(1))
	assert_eq(game.state.first_this_round, game.battle.enemy_of(chooser))


func test_the_first_turn_is_the_first_armys_after_the_choice() -> void:
	var game := _matched()
	game.next_decision()
	game.answer(Decision.choose(1))
	var request := RulesKit.drive(game, func(r: DecisionRequest) -> Decision: return null if r.kind == DecisionRequest.Kind.ACTION else RulesKit.pass_on(r))
	assert_not_null(request)
	assert_eq(game.state.active, game.state.first_this_round)
	assert_eq(request.army, game.state.first_this_round)


func test_a_battle_with_nothing_to_do_plays_to_the_end() -> void:
	var game := _matched()
	RulesKit.drive(game, RulesKit.pass_on, 2000)
	assert_true(game.is_over())
	assert_eq(game.state.round_number, game.rules.round_count())


# Command points

func test_each_army_gets_command_points_at_the_start_of_a_round() -> void:
	var game := _matched()
	game.rules.on_round_started()
	for army in game.armies():
		assert_gt(game.state.commands_of(army), 0)


func test_the_underdog_gets_one_more_command_point() -> void:
	var game := _matched()
	game.state.underdog = game.battle.player
	game.rules.on_round_started()
	assert_eq(game.state.commands_of(game.battle.player), game.state.commands_of(game.battle.opponent) + 1)


func test_command_points_are_set_each_round_not_added() -> void:
	var game := _matched()
	game.rules.on_round_started()
	var first := game.state.commands_of(game.battle.player)
	game.rules.on_round_started()
	assert_eq(game.state.commands_of(game.battle.player), first)


func test_unspent_command_points_are_lost_when_the_round_ends() -> void:
	var game := _matched()
	game.next_decision()
	game.answer(Decision.choose(0))
	game.next_decision()
	game.state.command_points[game.battle.player] = 3
	var round_two := RulesKit.drive(game, func(r: DecisionRequest) -> Decision: return null if r.kind == DecisionRequest.Kind.FIRST_TURN and game.state.round_number == 2 else RulesKit.pass_on(r))
	assert_not_null(round_two)
	assert_eq(game.state.round_number, 2)
	assert_eq(game.state.commands_of(game.battle.player), 0)
	assert_eq(game.state.commands_of(game.battle.opponent), 0)


## A unit with [code]Costly[/code], a command that costs 2 command points.
func _costly_unit() -> BattleUnit:
	var unit := RulesKit.unit("Mine", 1, Vector2(2, 5))
	_heal_for(unit, "Costly", "Your Hero Phase", "command", PackedStringArray(), 2)
	return unit


func test_a_command_is_refused_without_enough_command_points() -> void:
	var unit := _costly_unit()
	var game := _matched([unit] as Array[BattleUnit])
	game.state.command_points[game.battle.player] = 1
	var entry := _entry(game, game.battle.player, "Costly")
	assert_ne(game.reason_unavailable(entry, unit), "")


func test_a_command_is_available_with_enough_command_points() -> void:
	var unit := _costly_unit()
	var game := _matched([unit] as Array[BattleUnit])
	game.state.command_points[game.battle.player] = 2
	assert_eq(game.reason_unavailable(_entry(game, game.battle.player, "Costly"), unit), "")


func test_using_a_command_spends_its_command_points() -> void:
	var unit := _costly_unit()
	var game := _matched([unit] as Array[BattleUnit])
	game.state.command_points[game.battle.player] = 4
	var action := Action.create(ActionOption.create(_entry(game, game.battle.player, "Costly"), unit))
	game.declare_action(action)
	assert_eq(game.state.commands_of(game.battle.player), 2)


func test_a_command_that_costs_too_much_is_not_offered_in_its_phase() -> void:
	var game := _matched([_costly_unit()] as Array[BattleUnit])
	game.state.active = game.battle.player
	game.state.command_points[game.battle.player] = 1
	assert_false("Costly" in _offered(game))


func test_a_command_that_can_be_paid_for_is_offered_in_its_phase() -> void:
	var game := _matched([_costly_unit()] as Array[BattleUnit])
	game.state.active = game.battle.player
	game.state.command_points[game.battle.player] = 2
	assert_true("Costly" in _offered(game))


func test_a_phase_refuses_a_command_chosen_without_the_points() -> void:
	var unit := _costly_unit()
	var game := _matched([unit] as Array[BattleUnit])
	var in_hero := RulesKit.drive(game, func(r: DecisionRequest) -> Decision: return null if r.kind == DecisionRequest.Kind.ACTION and r.prompt.begins_with("Hero") else RulesKit.pass_on(r))
	assert_not_null(in_hero)
	game.state.command_points[game.battle.player] = 0
	var option := ActionOption.create(_entry(game, game.battle.player, "Costly"), unit)
	assert_ne(game.answer(Decision.use(option)), "")
	assert_eq(game.next_decision(), in_hero, "Still asking")


func test_spearhead_commands_do_not_cost_command_points() -> void:
	var unit := _costly_unit()
	var game := RulesKit.game([unit] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(28, 15))] as Array[BattleUnit])
	_games.append(game)
	assert_eq(game.reason_unavailable(_entry(game, game.battle.player, "Costly"), unit), "")


# Reactions

## A game where the player's Test Strike has a reaction on each side: [code]Mine Reacts[/code] on
## the player's other unit and [code]Theirs Reacts[/code] on the opponent's.
func _reacting_game() -> GameController:
	var striker := RulesKit.unit("Striker", 1, Vector2(2, 5))
	var friend := RulesKit.unit("Friend", 1, Vector2(2, 9))
	var enemy := RulesKit.unit("Enemy", 1, Vector2(28, 15))
	_heal_for(striker, "Test Strike", "Your Hero Phase", "active", PackedStringArray(["TEST"]))
	_heal_for(friend, "Mine Reacts", "Reaction: You declared a TEST ability")
	_heal_for(enemy, "Theirs Reacts", "Reaction: Opponent declared a TEST ability")
	var game := RulesKit.matched_game([striker, friend] as Array[BattleUnit], [enemy] as Array[BattleUnit])
	_games.append(game)
	return game


## Plays Test Strike and answers each reaction request with [param plans]' next entry, each a
## ability name to use or "" to pass. Returns who was asked, as "player" or "opponent".
func _play_strike(game: GameController, plans: Array[String]) -> Array[String]:
	var asked: Array[String] = []
	var struck := [false]
	var handler := func(request: DecisionRequest) -> Decision:
		if request.kind == DecisionRequest.Kind.REACTION:
			asked.append("player" if request.army == game.battle.player else "opponent")
			var plan: String = plans.pop_front() if not plans.is_empty() else ""
			for option in request.options:
				if option.ability_name() == plan:
					return Decision.use(option)
			return Decision.pass_it()
		if request.kind == DecisionRequest.Kind.ACTION:
			for option in request.options:
				if option.ability_name() == "Test Strike" and not struck[0]:
					struck[0] = true
					return Decision.use(option)
		return RulesKit.pass_on(request)
	RulesKit.drive(game, handler, 60)
	return asked


func test_reactions_start_with_the_player_using_the_ability_then_the_other() -> void:
	var game := _reacting_game()
	assert_eq(_play_strike(game, [] as Array[String]), ["player", "opponent"] as Array[String])


func test_a_reaction_hands_the_window_to_the_other_player() -> void:
	var game := _reacting_game()
	var asked := _play_strike(game, ["Mine Reacts"] as Array[String])
	assert_eq(asked, ["player", "opponent"] as Array[String], "Their pass, and then neither has a reaction left")


func test_reactions_go_on_until_both_pass_in_a_row() -> void:
	var game := _reacting_game()
	var asked := _play_strike(game, ["", "Theirs Reacts"] as Array[String])
	assert_eq(asked, ["player", "opponent", "player"] as Array[String], "The player passes, the opponent reacts, the player may react again")


## A game where the player's Test Strike has [param keyword], and only the opponent can react, to a
## TEST ability.
func _strike_game(keyword: String) -> GameController:
	var striker := RulesKit.unit("Striker", 1, Vector2(2, 5))
	_heal_for(striker, "Test Strike", "Your Hero Phase", "active", PackedStringArray([keyword]))
	var enemy := RulesKit.unit("Enemy", 1, Vector2(28, 15))
	_heal_for(enemy, "Theirs Reacts", "Reaction: Opponent declared a TEST ability")
	return _matched([striker] as Array[BattleUnit], [enemy] as Array[BattleUnit])


func test_a_player_with_no_reaction_is_not_asked() -> void:
	assert_eq(_play_strike(_strike_game("TEST"), [] as Array[String]), ["opponent"] as Array[String])


func test_a_reaction_to_something_else_is_not_offered() -> void:
	assert_true(_play_strike(_strike_game("OTHER"), [] as Array[String]).is_empty())


func test_a_reaction_can_only_be_used_once_a_phase_by_its_unit() -> void:
	var game := _reacting_game()
	var asked := _play_strike(game, ["Mine Reacts", "", "Mine Reacts"] as Array[String])
	assert_eq(asked.count("player"), 1, "Used, so not asked again")


# Summoning

func _summoner_game() -> GameController:
	var summoner := RulesKit.unit("Summoner", 1, Vector2(10, 10), PackedStringArray(["WIZARD (1)"]))
	var game := RulesKit.matched_game([summoner] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(28, 15))] as Array[BattleUnit])
	_games.append(game)
	return game


func _any_manifestation(game: GameController) -> String:
	for lore in game.core.manifestation_lores:
		for entry in lore.entries:
			if not entry.summons.is_empty():
				return entry.summons[0]
	return ""


func test_summoning_makes_a_unit_in_the_army_off_the_battlefield() -> void:
	var game := _summoner_game()
	var id := _any_manifestation(game)
	assert_ne(id, "", "The core data has a manifestation to summon")
	var summoned := game.summon(id, game.battle.player, game.battle.player.units[0])
	assert_not_null(summoned)
	assert_true(summoned in game.battle.player.units)
	assert_not_null(game.controller_of(summoned))
	assert_eq(summoned.bases.size(), summoned.positions.size())


func test_a_manifestation_already_on_the_battlefield_is_not_summoned_again() -> void:
	var game := _summoner_game()
	var id := _any_manifestation(game)
	var first := game.summon(id, game.battle.player, game.battle.player.units[0])
	game.command(first, Commands.SetUp.new(first.positions))
	assert_null(game.summon(id, game.battle.player, game.battle.player.units[0]))


func test_a_manifestation_is_destroyed_with_its_summoner() -> void:
	var game := _summoner_game()
	var summoner := game.battle.player.units[0]
	var summoned := game.summon(_any_manifestation(game), game.battle.player, summoner)
	game.command(summoned, Commands.SetUp.new(summoned.positions))
	game.command(summoner, Commands.Destroy.new(game.battle.opponent))
	assert_true(summoned.destroyed)


func test_a_manifestation_stays_while_its_summoner_lives() -> void:
	var game := _summoner_game()
	var summoner := game.battle.player.units[0]
	var summoned := game.summon(_any_manifestation(game), game.battle.player, summoner)
	game.command(summoned, Commands.SetUp.new(summoned.positions))
	game.command(game.battle.opponent.units[0], Commands.Destroy.new(game.battle.player))
	assert_false(summoned.destroyed)


func test_power_level_comes_from_the_keyword() -> void:
	var game := _summoner_game()
	var wizard := game.battle.player.units[0]
	assert_eq(game.power_level(wizard), 1)
	assert_eq(game.power_level(game.battle.opponent.units[0]), 0)


# Who is where

func test_enemies_on_the_battlefield_leave_out_the_destroyed_and_the_unplaced() -> void:
	var near := RulesKit.unit("Near", 1, Vector2(20, 5))
	var gone := RulesKit.unit("Gone", 1, Vector2(22, 5))
	var reserve := RulesKit.unit("Reserve", 1, Vector2(24, 5))
	var game := _matched([RulesKit.unit("Mine", 1, Vector2(2, 5))] as Array[BattleUnit], [near, gone, reserve] as Array[BattleUnit])
	game.command(gone, Commands.Destroy.new(game.battle.player))
	game.command(reserve, Commands.Remove.new("in reserve"))
	assert_eq(game.enemies_on_battlefield(game.battle.player), [near] as Array[BattleUnit])


func test_in_combat_is_within_three_inches_of_an_enemy() -> void:
	var game := _matched([RulesKit.unit("Mine", 1, Vector2(5, 5))] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(8, 5))] as Array[BattleUnit])
	assert_true(game.in_combat(game.battle.player.units[0]))
	game.battle.opponent.units[0].positions = PackedVector2Array([Vector2(12, 5)])
	assert_false(game.in_combat(game.battle.player.units[0]))


func test_a_manifestation_is_laid_out_not_stacked() -> void:
	var game := _summoner_game()
	var scroll := BattleKit.warscroll("Swarm", 4)
	scroll.id = "test_swarm"
	scroll.unit_size = 4
	game.core.manifestations.append(scroll)
	var summoned := game.summon(scroll.id, game.battle.player, game.battle.player.units[0])
	game.core.manifestations.erase(scroll)
	assert_eq(summoned.model_count(), 4)
	assert_eq(_distinct_spots(summoned.positions), summoned.model_count())


func _distinct_spots(positions: PackedVector2Array) -> int:
	var spots := {}
	for spot in positions:
		spots[spot] = true
	return spots.size()


# Units that start in reserve

## A game in which a Brutes unit in reserve has an ability only it can use in round 3 or later.
func _reserve_game(unit_name := "Brutes") -> GameController:
	var brutes := RulesKit.unit(unit_name, 2, Vector2(5, 5))
	brutes.start_in_reserve()
	var ability := RulesKit.ability("Arrive", "Your Hero Phase")
	var descriptor := {
		"user": {"from": "reserve", "names": ["Brutes"], "when": [{"round_at_least": 3}]},
		"do": [{"op": "setup", "to": "user"}],
	}
	RulesKit.add_ability(brutes, ability, descriptor)
	var game := _matched([brutes] as Array[BattleUnit])
	game.state.active = game.battle.player
	game.state.round_number = 3
	return game


## What's offered to the player in the hero phase, by name.
func _offered(game: GameController) -> Array:
	return game.options_in(M.HERO, game.battle.player).map(func(o: ActionOption) -> String: return o.ability_name())


func test_a_unit_in_reserve_is_offered_its_reserve_ability() -> void:
	assert_true("Arrive" in _offered(_reserve_game()))


func test_a_reserve_ability_is_not_offered_before_its_round() -> void:
	var game := _reserve_game()
	game.state.round_number = 2
	assert_false("Arrive" in _offered(game))


func test_a_reserve_ability_is_not_offered_to_a_unit_that_is_not_named() -> void:
	assert_false("Arrive" in _offered(_reserve_game("Other")))


func test_a_reserve_ability_is_not_offered_to_a_destroyed_unit() -> void:
	var game := _reserve_game()
	game.battle.player.units[0].destroyed = true
	assert_false("Arrive" in _offered(game))


func test_a_reserve_ability_is_not_offered_once_the_unit_is_on_the_battlefield() -> void:
	var game := _reserve_game()
	var brutes := game.battle.player.units[0]
	game.command(brutes, Commands.SetUp.new(brutes.positions))
	assert_false("Arrive" in _offered(game))
