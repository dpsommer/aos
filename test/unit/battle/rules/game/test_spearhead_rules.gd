extends GutTest
## Spearhead: battle tactic hands, seizing the initiative and scoring.

const RulesKit := preload("res://test/support/rules_kit.gd")
const BattleKit := preload("res://test/support/battle_kit.gd")

var _game: GameController
var _rules: SpearheadRules
var _mine: BattleArmy
var _theirs: BattleArmy


func after_each() -> void:
	_game.dispose()
	RulesKit.forget_abilities()


## A Spearhead game of a battlepack with [param cards] tactic cards, named `Test 1` and so on, each
## with a command when [param with_commands].
func _start(cards := 6, scoring := PackedStringArray(), with_commands := false, seed_value := 1) -> void:
	var pack := SpearheadBattlepack.new()
	pack.name = "Test Pack"
	pack.battle_rounds = 4
	pack.scoring = scoring
	for i in cards:
		var card := SpearheadTacticCard.new()
		card.name = "Test %d" % (i + 1)
		if with_commands:
			var command := BattleKit.ability("Command %d" % (i + 1), PackedStringArray(["COMMAND"]))
			command.timing = "Your Hero Phase"
			command.type = "command"
			card.command = command
		pack.battle_tactic_cards.append(card)
		RulesKit.add_tactic(card.name, "attrition")
	var battle := BattleKit.battle()
	battle.battlepack = pack
	battle.player.units.assign([RulesKit.unit("Mine", 1, Vector2(2, 5))] as Array[BattleUnit])
	battle.opponent.units.assign([RulesKit.unit("Theirs", 1, Vector2(28, 15))] as Array[BattleUnit])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_game = GameController.new(battle, rng)
	_rules = _game.rules
	_mine = battle.player
	_theirs = battle.opponent


func _names(hand: Array) -> Array[String]:
	var result: Array[String] = []
	for card: SpearheadTacticCard in hand:
		result.append(card.name)
	return result


func _begin_round(number: int, first: BattleArmy, last_time: BattleArmy = null) -> void:
	_game.state.round_number = number
	_game.state.first_this_round = first
	_game.state.first_last_round = last_time
	_rules.on_round_started()


# The kind of game

func test_spearhead_has_no_commands_or_magic() -> void:
	_start()
	assert_false(_rules.uses_commands())
	assert_false(_rules.uses_magic())


func test_the_battlepack_sets_the_number_of_rounds() -> void:
	_start()
	assert_eq(_rules.round_count(), _game.battle.battlepack.battle_rounds)


# Hands

func test_each_hand_is_filled_at_the_start_of_the_first_round() -> void:
	_start()
	_begin_round(1, _mine)
	assert_eq(_rules.hand_of(_mine).size(), SpearheadRules.HAND_SIZE)
	assert_eq(_rules.hand_of(_theirs).size(), SpearheadRules.HAND_SIZE)


func test_a_hand_holds_no_card_twice() -> void:
	_start()
	_begin_round(1, _mine)
	var seen := {}
	for card_name in _names(_rules.hand_of(_mine)):
		seen[card_name] = true
	assert_eq(seen.size(), SpearheadRules.HAND_SIZE)


func test_the_same_seed_deals_the_same_hands() -> void:
	_start(6, PackedStringArray(), false, 5)
	_begin_round(1, _mine)
	var first := _names(_rules.hand_of(_mine))
	_game.dispose()
	_start(6, PackedStringArray(), false, 5)
	_begin_round(1, _mine)
	assert_eq(_names(_rules.hand_of(_mine)), first)


func test_a_hand_is_topped_up_to_three_at_the_start_of_the_next_round() -> void:
	_start()
	_begin_round(1, _mine)
	_rules.discard(_mine, _rules.hand_of(_mine)[0])
	_rules.discard(_mine, _rules.hand_of(_mine)[0])
	assert_eq(_rules.hand_of(_mine).size(), 1)
	_begin_round(2, _theirs, _mine)
	assert_eq(_rules.hand_of(_mine).size(), SpearheadRules.HAND_SIZE)


func test_a_full_hand_is_not_added_to() -> void:
	_start()
	_begin_round(1, _mine)
	_begin_round(2, _theirs, _mine)
	assert_eq(_rules.hand_of(_mine).size(), SpearheadRules.HAND_SIZE)


func test_a_hand_cannot_be_filled_from_an_empty_deck() -> void:
	_start(4)
	_begin_round(1, _mine)
	for army in [_mine, _theirs]:
		for card: SpearheadTacticCard in _rules.hand_of(army).duplicate():
			_rules.discard(army, card)
	_begin_round(2, _theirs, _mine)
	assert_eq(_rules.hand_of(_mine).size(), 1, "Only one card left in a deck of four")


func test_discarding_takes_the_card_out_of_the_hand() -> void:
	_start()
	_begin_round(1, _mine)
	var card: SpearheadTacticCard = _rules.hand_of(_mine)[0]
	_rules.discard(_mine, card)
	assert_false(card in _rules.hand_of(_mine))
	assert_eq(_rules.hand_of(_mine).size(), SpearheadRules.HAND_SIZE - 1)


# Seizing the initiative

func test_the_army_that_seizes_the_initiative_does_not_draw() -> void:
	_start()
	_begin_round(1, _mine)
	_rules.discard(_theirs, _rules.hand_of(_theirs)[0])
	_rules.discard(_theirs, _rules.hand_of(_theirs)[0])
	_begin_round(2, _theirs, _mine)
	assert_eq(_rules.hand_of(_theirs).size(), 1)


func test_the_other_army_still_draws_when_the_initiative_is_seized() -> void:
	_start()
	_begin_round(1, _mine)
	_rules.discard(_mine, _rules.hand_of(_mine)[0])
	_begin_round(2, _theirs, _mine)
	assert_eq(_rules.hand_of(_mine).size(), SpearheadRules.HAND_SIZE)


func test_going_first_again_is_not_seizing_so_the_hand_is_filled() -> void:
	_start()
	_begin_round(1, _mine)
	_rules.discard(_mine, _rules.hand_of(_mine)[0])
	_begin_round(2, _mine, _mine)
	assert_eq(_rules.hand_of(_mine).size(), SpearheadRules.HAND_SIZE)


func test_the_underdog_who_seizes_the_initiative_from_far_behind_does_draw() -> void:
	_start()
	_begin_round(1, _mine)
	_rules.discard(_theirs, _rules.hand_of(_theirs)[0])
	_game.state.victory_points[_mine] = SpearheadRules.SEIZE_MARGIN
	_game.state.underdog = _theirs
	_begin_round(2, _theirs, _mine)
	assert_eq(_rules.hand_of(_theirs).size(), SpearheadRules.HAND_SIZE)


func test_the_underdog_who_is_not_far_enough_behind_does_not_draw() -> void:
	_start()
	_begin_round(1, _mine)
	_rules.discard(_theirs, _rules.hand_of(_theirs)[0])
	_game.state.victory_points[_mine] = SpearheadRules.SEIZE_MARGIN - 1
	_game.state.underdog = _theirs
	_begin_round(2, _theirs, _mine)
	assert_eq(_rules.hand_of(_theirs).size(), SpearheadRules.HAND_SIZE - 1)


func test_far_behind_but_not_the_underdog_does_not_count() -> void:
	_start()
	_begin_round(1, _mine)
	_rules.discard(_theirs, _rules.hand_of(_theirs)[0])
	_game.state.victory_points[_mine] = SpearheadRules.SEIZE_MARGIN + 3
	_game.state.underdog = null
	_begin_round(2, _theirs, _mine)
	assert_eq(_rules.hand_of(_theirs).size(), SpearheadRules.HAND_SIZE - 1)


# Cards' commands

func test_each_card_in_hand_gives_its_command_as_an_ability() -> void:
	_start(6, PackedStringArray(), true)
	_begin_round(1, _mine)
	var offered: Array[String] = []
	for entry: AbilityEntry in _game.books[_mine]:
		if entry.card:
			offered.append(entry.ability.name)
	assert_eq(offered.size(), SpearheadRules.HAND_SIZE)
	for card: SpearheadTacticCard in _rules.hand_of(_mine):
		assert_true(card.command.name in offered)


func test_commands_of_cards_not_in_hand_are_not_offered() -> void:
	_start(6, PackedStringArray(), true)
	_begin_round(1, _mine)
	for entry: AbilityEntry in _game.books[_mine]:
		if entry.card:
			assert_true(entry.card in _rules.hand_of(_mine))


func test_using_a_cards_command_discards_the_card() -> void:
	_start(6, PackedStringArray(), true)
	_begin_round(1, _mine)
	var entry: AbilityEntry
	for each: AbilityEntry in _game.books[_mine]:
		if each.card:
			entry = each
			break
	_game.declare_action(Action.create(ActionOption.create(entry, null)))
	assert_false(entry.card in _rules.hand_of(_mine))
	for each: AbilityEntry in _game.books[_mine]:
		assert_ne(each.card, entry.card, "Its command goes too")


# Scoring

func test_a_completed_card_in_hand_is_scored_and_discarded() -> void:
	_start()
	_begin_round(1, _mine)
	var card: SpearheadTacticCard = _rules.hand_of(_mine)[0]
	_game.state.count_turn(_mine, &"enemy_destroyed")
	_rules.score_turn(_mine)
	assert_eq(_game.state.tactics_of(_mine), SpearheadRules.HAND_SIZE, "All the cards are completed by the same thing")
	assert_false(card in _rules.hand_of(_mine))


func test_a_card_not_completed_stays_in_hand() -> void:
	_start()
	_begin_round(1, _mine)
	_rules.score_turn(_mine)
	assert_eq(_rules.hand_of(_mine).size(), SpearheadRules.HAND_SIZE)
	assert_eq(_game.state.tactics_of(_mine), 0)


func test_the_battleplans_scoring_is_scored() -> void:
	_start(6, PackedStringArray(["Score 3 victory points if you control at least 1 objective."]))
	_begin_round(1, _mine)
	_game.state.objective_control[BattleKit.feature("Sun Seekers", Vector2(5, 5))] = _mine
	_rules.score_turn(_mine)
	assert_eq(_game.state.points_of(_mine), 3)


func test_the_battleplans_scoring_comes_after_the_cards_so_it_can_count_them() -> void:
	_start(6, PackedStringArray(["Score 2 victory point for each battle tactic you completed this turn."]))
	_begin_round(1, _mine)
	_game.state.count_turn(_mine, &"enemy_destroyed")
	_rules.score_turn(_mine)
	assert_eq(_game.state.points_of(_mine), 2 * _game.state.tactics_of(_mine))
	assert_gt(_game.state.tactics_of(_mine), 0)


# The result

func test_the_army_with_more_points_wins() -> void:
	_start()
	_game.state.victory_points[_mine] = 9
	_game.state.victory_points[_theirs] = 4
	_rules.decide_result()
	assert_eq(_game.state.winner, _mine)
	assert_ne(_game.state.outcome, GameState.Outcome.UNDECIDED)


func test_the_other_army_can_win() -> void:
	_start()
	_game.state.victory_points[_theirs] = 1
	_rules.decide_result()
	assert_eq(_game.state.winner, _theirs)


func test_level_points_is_a_draw() -> void:
	_start()
	_rules.decide_result()
	assert_eq(_game.state.outcome, GameState.Outcome.DRAW)
	assert_null(_game.state.winner)
