extends GutTest
## Whether a battle tactic's condition is met.

const RulesKit := preload("res://test/support/rules_kit.gd")
const BattleKit := preload("res://test/support/battle_kit.gd")
const SPACE := RulesKit.TEST_PACK

var _game: GameController
var _mine: BattleArmy
var _theirs: BattleArmy


func after_each() -> void:
	_game.dispose()
	RulesKit.forget_abilities()


## A game on the 30" x 22" board, the player's territory in the west and the opponent's in the east.
func _start(mine: Array[BattleUnit], theirs: Array[BattleUnit]) -> void:
	_game = RulesKit.game(mine, theirs)
	_mine = _game.battle.player
	_theirs = _game.battle.opponent


func _far_units() -> void:
	_start([RulesKit.unit("Mine", 1, Vector2(8, 11))] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(22, 11))] as Array[BattleUnit])


func _complete(check: String, extra := {}) -> bool:
	RulesKit.add_tactic("Test Tactic", check, extra)
	return TacticChecks.is_complete(SPACE, "Test Tactic", _mine, _game)


func test_a_tactic_without_data_cannot_be_completed() -> void:
	_far_units()
	assert_false(TacticChecks.is_supported(SPACE, "Test Missing"))
	assert_false(TacticChecks.is_complete(SPACE, "Test Missing", _mine, _game))


func test_a_tactic_with_data_is_supported() -> void:
	_far_units()
	RulesKit.add_tactic("Test Tactic", "attrition")
	assert_true(TacticChecks.is_supported(SPACE, "Test Tactic"))


func test_a_check_the_engine_does_not_know_is_not_completed() -> void:
	_far_units()
	assert_false(_complete("no_such_check"))


func test_attrition_needs_more_destroyed_than_lost() -> void:
	_far_units()
	assert_false(_complete("attrition"), "Nothing destroyed")
	_game.state.count_turn(_mine, &"enemy_destroyed")
	assert_true(_complete("attrition"))
	_game.state.count_turn(_mine, &"own_destroyed")
	assert_false(_complete("attrition"), "As many lost as destroyed")


func test_lost_more_needs_more_lost_than_destroyed() -> void:
	_far_units()
	assert_false(_complete("lost_more"))
	_game.state.count_turn(_mine, &"own_destroyed")
	assert_true(_complete("lost_more"))
	_game.state.count_turn(_mine, &"enemy_destroyed")
	assert_false(_complete("lost_more"))


func test_cutting_off_the_head_needs_the_enemy_general_slain() -> void:
	_far_units()
	assert_false(_complete("cut_head"))
	_game.state.count_turn(_mine, &"general_slain")
	assert_true(_complete("cut_head"))


func test_cutting_off_the_head_counts_a_general_slain_earlier_if_something_was_destroyed() -> void:
	_far_units()
	_game.state.generals_slain[_theirs] = true
	assert_false(_complete("cut_head"), "Nothing destroyed this turn")
	_game.state.count_turn(_mine, &"enemy_destroyed")
	assert_true(_complete("cut_head"))


func test_controlling_a_named_objective() -> void:
	_far_units()
	var objective := BattleKit.feature("Sun Seekers", Vector2(15, 11))
	_game.state.objective_control[objective] = _theirs
	assert_false(_complete("control_named", {"name": "Sun Seekers"}))
	_game.state.objective_control[objective] = _mine
	assert_true(_complete("control_named", {"name": "Sun Seekers"}))
	assert_false(_complete("control_named", {"name": "Golden Lions"}))


func test_a_raid_needs_a_unit_wholly_in_enemy_territory_and_out_of_combat() -> void:
	_start([RulesKit.unit("Mine", 1, Vector2(25, 5))] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(28, 20))] as Array[BattleUnit])
	assert_true(_complete("raid"))


func test_a_raid_is_not_made_from_your_own_territory() -> void:
	_far_units()
	assert_false(_complete("raid"))


func test_a_raid_is_not_made_by_a_unit_in_combat() -> void:
	_start([RulesKit.unit("Mine", 1, Vector2(25, 5))] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(27, 5))] as Array[BattleUnit])
	assert_false(_complete("raid"))


func test_a_raid_needs_the_whole_unit_in_enemy_territory() -> void:
	_start([RulesKit.unit("Mine", 1, Vector2(20.2, 5))] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(28, 20))] as Array[BattleUnit])
	assert_false(_complete("raid"), "Its base is over the edge of the territory")


func test_taking_the_flanks_needs_units_near_both_short_edges() -> void:
	_start([RulesKit.unit("West", 1, Vector2(1.5, 5)), RulesKit.unit("East", 1, Vector2(28.5, 5))] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(15, 20))] as Array[BattleUnit])
	assert_true(_complete("flanks"))


func test_one_flank_is_not_enough() -> void:
	_start([RulesKit.unit("West", 1, Vector2(1.5, 5)), RulesKit.unit("Middle", 1, Vector2(15, 5))] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(15, 20))] as Array[BattleUnit])
	assert_false(_complete("flanks"))


func test_a_unit_near_the_centre_holds_it() -> void:
	_start([RulesKit.unit("Mine", 1, Vector2(15, 11))] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(28, 20))] as Array[BattleUnit])
	assert_true(_complete("centre"))


func test_a_unit_far_from_the_centre_does_not_hold_it() -> void:
	_far_units()
	assert_false(_complete("centre"))


func test_the_centre_can_need_more_than_one_unit() -> void:
	_start([RulesKit.unit("A", 1, Vector2(15, 11)), RulesKit.unit("B", 1, Vector2(15, 14)), RulesKit.unit("C", 1, Vector2(5, 5))] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(28, 20))] as Array[BattleUnit])
	assert_true(_complete("centre", {"count": 2}))
	assert_false(_complete("centre", {"count": 3}), "The third is far away")


func test_the_centre_without_being_in_combat() -> void:
	_start([RulesKit.unit("Mine", 1, Vector2(15, 11))] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(17, 11))] as Array[BattleUnit])
	assert_true(_complete("centre"))
	assert_false(_complete("centre_not_in_combat"))


func test_fighting_without_losses() -> void:
	_far_units()
	assert_false(_complete("fought_no_losses"), "Nothing fought")
	_game.state.count_turn(_mine, &"fought")
	assert_true(_complete("fought_no_losses"))
	_game.state.count_turn(_mine, &"own_destroyed")
	assert_false(_complete("fought_no_losses"))


func test_gaining_an_objective_the_enemy_held() -> void:
	_far_units()
	var objective := BattleKit.feature("Sun Seekers", Vector2(15, 11))
	_game.state.objective_control[objective] = _mine
	_game.state.control_at_turn_start[objective] = _theirs
	assert_true(_complete("gained_count", {"count": 1}))
	assert_false(_complete("gained_count", {"count": 2}))


func test_gaining_an_objective_already_ours_is_not_gaining() -> void:
	_far_units()
	var objective := BattleKit.feature("Sun Seekers", Vector2(15, 11))
	_game.state.objective_control[objective] = _mine
	_game.state.control_at_turn_start[objective] = _mine
	assert_false(_complete("gained_count", {"count": 1}))
