extends GutTest
## Matched Play: command points, who wins and scoring battle tactics.

const RulesKit := preload("res://test/support/rules_kit.gd")
const BattleKit := preload("res://test/support/battle_kit.gd")

var _game: GameController
var _rules: MatchedPlayRules
var _mine: BattleArmy
var _theirs: BattleArmy


func before_each() -> void:
	_game = _make_game()
	_rules = _game.rules
	_mine = _game.battle.player
	_theirs = _game.battle.opponent


func after_each() -> void:
	_game.dispose()
	RulesKit.forget_abilities()


## A game whose core rules have one battle tactics card, `Test Card`, of the tactics [param tactics]
## (name and victory points).
func _make_game(tactics := [["Test One", 4], ["Test Two", 2]]) -> GameController:
	var core := BattleKit.core([] as Array[Battleplan])
	var card := BattleTacticCard.new()
	card.name = "Test Card"
	for entry: Array in tactics:
		var tactic := BattleTactic.new()
		tactic.name = entry[0]
		tactic.victory_points = entry[1]
		card.tactics.append(tactic)
		RulesKit.add_tactic(entry[0], "attrition", {}, MatchedPlayRules.PACK_SPACE)
	core.battlepack.battle_tactic_cards = [card] as Array[BattleTacticCard]
	var battle := BattleKit.battle()
	battle.mode = BattleSetup.Mode.MATCHED_PLAY
	battle.player.units.assign([RulesKit.unit("Mine", 1, Vector2(2, 5))] as Array[BattleUnit])
	battle.opponent.units.assign([RulesKit.unit("Theirs", 1, Vector2(28, 15))] as Array[BattleUnit])
	battle.player.tactics = PackedStringArray(["Test Card"])
	battle.opponent.tactics = PackedStringArray(["Test Card"])
	return GameController.new(battle, RandomNumberGenerator.new(), core)


func _score(army: BattleArmy, points: int) -> void:
	_game.state.victory_points[army] = points


func _win_a_fight(army: BattleArmy) -> void:
	_game.state.count_turn(army, &"enemy_destroyed")


# The kind of game

func test_matched_play_uses_commands_and_magic() -> void:
	assert_true(_rules.uses_commands())
	assert_true(_rules.uses_magic())


func test_the_attacker_chooses_the_first_turn_without_a_deployment_record() -> void:
	assert_eq(_rules.first_turn_chooser(), _game.battle.attacker())


# Command points

func test_each_army_starts_a_round_with_command_points() -> void:
	_rules.on_round_started()
	assert_gt(_game.state.commands_of(_mine), 0)
	assert_eq(_game.state.commands_of(_mine), _game.state.commands_of(_theirs))


func test_the_underdog_gets_one_more() -> void:
	_game.state.underdog = _theirs
	_rules.on_round_started()
	assert_eq(_game.state.commands_of(_theirs), _game.state.commands_of(_mine) + 1)


func test_no_underdog_means_no_extra() -> void:
	_game.state.underdog = null
	_rules.on_round_started()
	assert_eq(_game.state.commands_of(_theirs), _game.state.commands_of(_mine))


# Who wins

func test_a_big_lead_is_a_major_victory() -> void:
	_score(_mine, 12)
	_score(_theirs, 5)
	_rules.decide_result()
	assert_eq(_game.state.outcome, GameState.Outcome.MAJOR_VICTORY)
	assert_eq(_game.state.winner, _mine)


func test_a_small_lead_is_a_minor_victory() -> void:
	_score(_mine, 12)
	_score(_theirs, 10)
	_rules.decide_result()
	assert_eq(_game.state.outcome, GameState.Outcome.MINOR_VICTORY)
	assert_eq(_game.state.winner, _mine)


func test_the_enemy_can_win() -> void:
	_score(_mine, 3)
	_score(_theirs, 20)
	_rules.decide_result()
	assert_eq(_game.state.winner, _theirs)
	assert_eq(_game.state.outcome, GameState.Outcome.MAJOR_VICTORY)


func test_the_margin_that_makes_a_major_victory_is_the_same_either_way_round() -> void:
	# Each margin and whether it's major, as the rules set it: just under, at and over.
	var margin := MatchedPlayRules.MAJOR_MARGIN
	for ahead in [-(margin + 1), -margin, -(margin - 1), margin - 1, margin, margin + 1]:
		var game := _make_game()
		game.state.victory_points[game.battle.player] = 10 + ahead
		game.state.victory_points[game.battle.opponent] = 10
		game.rules.decide_result()
		var expected := GameState.Outcome.MAJOR_VICTORY if absi(ahead) >= margin else GameState.Outcome.MINOR_VICTORY
		assert_eq(game.state.outcome, expected, "Ahead by %d" % ahead)
		game.dispose()


func test_a_tie_goes_to_the_army_with_more_battle_tactics() -> void:
	_score(_mine, 10)
	_score(_theirs, 10)
	_game.state.tactics_completed[_theirs] = 2
	_game.state.tactics_completed[_mine] = 1
	_rules.decide_result()
	assert_eq(_game.state.winner, _theirs)
	assert_eq(_game.state.outcome, GameState.Outcome.MINOR_VICTORY)


func test_a_tie_in_points_and_tactics_is_a_draw() -> void:
	_score(_mine, 10)
	_score(_theirs, 10)
	_game.state.tactics_completed[_mine] = 2
	_game.state.tactics_completed[_theirs] = 2
	_rules.decide_result()
	assert_eq(_game.state.outcome, GameState.Outcome.DRAW)
	assert_null(_game.state.winner)


func test_tactics_do_not_matter_when_the_points_differ() -> void:
	_score(_mine, 11)
	_score(_theirs, 10)
	_game.state.tactics_completed[_theirs] = 5
	_rules.decide_result()
	assert_eq(_game.state.winner, _mine)


# Battle tactics

func test_a_completed_battle_tactic_scores_its_points() -> void:
	_win_a_fight(_mine)
	_rules.score_turn(_mine)
	assert_eq(_game.state.points_of(_mine), 4)
	assert_eq(_game.state.tactics_of(_mine), 1)


func test_a_battle_tactic_not_completed_scores_nothing() -> void:
	_rules.score_turn(_mine)
	assert_eq(_game.state.points_of(_mine), 0)
	assert_eq(_game.state.tactics_of(_mine), 0)


func test_only_one_tactic_of_a_card_is_scored_each_turn() -> void:
	_win_a_fight(_mine)
	_rules.score_turn(_mine)
	assert_eq(_game.state.tactics_of(_mine), 1, "Both would be complete")


func test_the_next_tactic_of_the_card_is_scored_next() -> void:
	_win_a_fight(_mine)
	_rules.score_turn(_mine)
	_rules.score_turn(_mine)
	assert_eq(_game.state.points_of(_mine), 6, "4 for the first, 2 for the second")


func test_a_card_that_is_finished_scores_no_more() -> void:
	_win_a_fight(_mine)
	for _i in 4:
		_rules.score_turn(_mine)
	assert_eq(_game.state.tactics_of(_mine), 2)


func test_an_army_that_seized_the_initiative_scores_no_tactics() -> void:
	_game.state.round_number = 2
	_game.state.first_this_round = _mine
	_game.state.first_last_round = _theirs
	_win_a_fight(_mine)
	_rules.score_turn(_mine)
	assert_eq(_game.state.tactics_of(_mine), 0)


func test_an_army_that_seized_the_initiative_from_far_behind_does_score() -> void:
	_game.state.round_number = 2
	_game.state.first_this_round = _mine
	_game.state.first_last_round = _theirs
	_score(_theirs, MatchedPlayRules.SEIZE_LIMIT)
	_win_a_fight(_mine)
	_rules.score_turn(_mine)
	assert_eq(_game.state.tactics_of(_mine), 1)


func test_going_first_again_is_not_seizing_the_initiative() -> void:
	_game.state.round_number = 2
	_game.state.first_this_round = _mine
	_game.state.first_last_round = _mine
	_win_a_fight(_mine)
	_rules.score_turn(_mine)
	assert_eq(_game.state.tactics_of(_mine), 1)


func test_going_first_in_the_first_round_is_not_seizing_it() -> void:
	_game.state.round_number = 1
	_game.state.first_this_round = _mine
	_win_a_fight(_mine)
	_rules.score_turn(_mine)
	assert_eq(_game.state.tactics_of(_mine), 1)


func test_the_army_going_second_still_scores_tactics_in_a_later_round() -> void:
	_game.state.round_number = 2
	_game.state.first_this_round = _theirs
	_game.state.first_last_round = _mine
	_win_a_fight(_mine)
	_rules.score_turn(_mine)
	assert_eq(_game.state.tactics_of(_mine), 1)


func test_a_card_the_army_did_not_take_is_not_scored() -> void:
	_mine.tactics = PackedStringArray()
	_win_a_fight(_mine)
	_rules.score_turn(_mine)
	assert_eq(_game.state.tactics_of(_mine), 0)
