extends GutTest
## Reading a battleplan's scoring sentences, and what they score.

const RulesKit := preload("res://test/support/rules_kit.gd")
const BattleKit := preload("res://test/support/battle_kit.gd")

var _game: GameController
var _mine: BattleArmy
var _theirs: BattleArmy


func before_each() -> void:
	_game = RulesKit.matched_game([RulesKit.unit("Mine", 1, Vector2(2, 5))] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(28, 15))] as Array[BattleUnit])
	_mine = _game.battle.player
	_theirs = _game.battle.opponent
	_game.state.round_number = 2


func after_each() -> void:
	_game.dispose()


func _holds(army: BattleArmy, objective_type: String, count := 1) -> void:
	for i in count:
		_game.state.objective_control[BattleKit.feature(objective_type, Vector2(5 + i, 5))] = army


func _points(sentence: String, army: BattleArmy = _mine) -> int:
	return ScoringRules.points_for(sentence, army, _game)


# Reading a sentence

func test_numbers_become_n_in_the_shape() -> void:
	assert_eq(ScoringRules.shape_of("Score 3 victory points if you control at least 2 objective."),
			"Score N victory points if you control at least N objective.")


func test_number_words_become_n_too() -> void:
	assert_eq(ScoringRules.shape_of("Score two victory points if you control one objective."), "Score N victory points if you control N objective.")


func test_a_sentence_without_numbers_is_its_own_shape() -> void:
	assert_eq(ScoringRules.shape_of("Hold the line"), "Hold the line")


func test_numbers_are_listed_in_order() -> void:
	assert_eq(ScoringRules.numbers_in("Score 5 victory points if you control at least 2 objective."), PackedInt32Array([5, 2]))


func test_number_words_are_read_as_numbers() -> void:
	assert_eq(ScoringRules.numbers_in("Score three victory points if you control two objectives."), PackedInt32Array([3, 2]))


func test_a_sentence_with_no_numbers_has_none() -> void:
	assert_true(ScoringRules.numbers_in("Hold the line").is_empty())


func test_a_known_shape_has_rules_and_an_unknown_one_none() -> void:
	assert_false(ScoringRules.rule_for("Score 3 victory points if you control at least 2 objective.").is_empty())
	assert_true(ScoringRules.rule_for("Score 3 victory points if you dance.").is_empty())


func test_sentences_without_rules_are_unsupported() -> void:
	var sentences := PackedStringArray(["Score 3 victory points if you control at least 2 objective.", "Score 3 victory points if you dance."])
	assert_eq(ScoringRules.unsupported(sentences), PackedStringArray(["Score 3 victory points if you dance."]))


# What they score

func test_control_at_least_scores_when_enough_are_held() -> void:
	_holds(_mine, "Sun Seekers", 2)
	assert_eq(_points("Score 3 victory points if you control at least 2 objective."), 3)


func test_control_at_least_scores_nothing_when_too_few_are_held() -> void:
	_holds(_mine, "Sun Seekers", 1)
	assert_eq(_points("Score 3 victory points if you control at least 2 objective."), 0)


func test_objectives_held_by_the_enemy_do_not_count() -> void:
	_holds(_theirs, "Sun Seekers", 2)
	assert_eq(_points("Score 3 victory points if you control at least 2 objective."), 0)


func test_control_more_needs_more_than_the_enemy() -> void:
	var sentence := "Score 4 victory points if you control more objectives than your opponent."
	_holds(_mine, "A", 1)
	_holds(_theirs, "B", 1)
	assert_eq(_points(sentence), 0, "Level")
	_holds(_mine, "C", 1)
	assert_eq(_points(sentence), 4)


func test_the_first_round_sentence_only_scores_in_round_one() -> void:
	var sentence := "In the first battle round, score 4 victory points if you control 1 or more objectives."
	_holds(_mine, "A", 1)
	_game.state.round_number = 1
	assert_eq(_points(sentence), 4)
	_game.state.round_number = 2
	assert_eq(_points(sentence), 0)


func test_the_from_the_second_round_sentence_waits_for_round_two() -> void:
	var sentence := "From the second battle round onwards, score 3 victory points if you control an objective that was controlled by your opponent at the start of the turn."
	var objective := BattleKit.feature("A", Vector2(5, 5))
	_game.state.objective_control[objective] = _mine
	_game.state.control_at_turn_start[objective] = _theirs
	_game.state.round_number = 1
	assert_eq(_points(sentence), 0)
	_game.state.round_number = 2
	assert_eq(_points(sentence), 3)


func test_taking_an_objective_from_the_enemy_needs_it_to_have_been_theirs() -> void:
	var sentence := "From the second battle round onwards, score 3 victory points if you control an objective that was controlled by your opponent at the start of the turn."
	var objective := BattleKit.feature("A", Vector2(5, 5))
	_game.state.objective_control[objective] = _mine
	_game.state.control_at_turn_start[objective] = _mine
	assert_eq(_points(sentence), 0)


func test_a_named_objective_scores_only_for_that_one() -> void:
	var sentence := "Score 3 victory points if you control the Sun Seekers objective."
	_holds(_mine, "Golden Lions")
	assert_eq(_points(sentence), 0)
	_holds(_mine, "Sun Seekers")
	assert_eq(_points(sentence), 3)


func test_a_pair_of_objectives_is_two_of_one_type() -> void:
	var sentence := "Score 3 victory points if you control any pairs of objectives."
	_holds(_mine, "A")
	_holds(_mine, "B")
	assert_eq(_points(sentence), 0, "Two of different types")
	_game.state.objective_control[BattleKit.feature("A", Vector2(9, 9))] = _mine
	assert_eq(_points(sentence), 3)


func test_each_tactic_completed_this_turn_scores() -> void:
	var sentence := "Score 2 victory point for each battle tactic you completed this turn."
	assert_eq(_points(sentence), 0)
	_game.state.count_turn(_mine, &"tactics", 2)
	assert_eq(_points(sentence), 4)


func test_a_sentence_without_data_scores_nothing() -> void:
	_holds(_mine, "A", 3)
	assert_eq(_points("Score 3 victory points if you dance."), 0)


func test_the_enemy_scores_for_what_it_controls() -> void:
	_holds(_theirs, "A", 2)
	assert_eq(_points("Score 3 victory points if you control at least 2 objective.", _theirs), 3)
