extends GutTest
## Contesting and controlling objectives.

const RulesKit := preload("res://test/support/rules_kit.gd")
const BattleKit := preload("res://test/support/battle_kit.gd")

var _game: GameController


func after_each() -> void:
	_game.dispose()


## A game with an objective at (15, 11), the player's [param mine] models and the opponent's
## [param theirs] models standing on it.
func _on_objective(mine: int, theirs: int, control := 1) -> MapFeature:
	var objective := BattleKit.feature("Sun Seekers", Vector2(15, 11))
	var friends := RulesKit.unit("Mine", maxi(mine, 1), Vector2(14.5, 11) if mine > 0 else Vector2(2, 2))
	var foes := RulesKit.unit("Theirs", maxi(theirs, 1), Vector2(14.5, 12.5) if theirs > 0 else Vector2(28, 20))
	friends.warscroll.control = control
	foes.warscroll.control = control
	var battle := BattleKit.battle()
	battle.mode = BattleSetup.Mode.MATCHED_PLAY
	battle.player.units.assign([friends] as Array[BattleUnit])
	battle.opponent.units.assign([foes] as Array[BattleUnit])
	battle.objectives = [objective] as Array[MapFeature]
	_game = GameController.new(battle, RandomNumberGenerator.new())
	return objective


func _mine() -> BattleUnit:
	return _game.battle.player.units[0]


func test_a_model_on_the_objective_contests_it() -> void:
	var objective := _on_objective(1, 0)
	assert_eq(_game.objectives.models_contesting(_mine(), objective), 1)


func test_a_model_far_away_does_not() -> void:
	var objective := _on_objective(0, 0)
	assert_eq(_game.objectives.models_contesting(_mine(), objective), 0)
	assert_false(_game.objectives.contests_any(_mine()))


func test_each_model_that_reaches_is_counted() -> void:
	var objective := _on_objective(3, 0)
	assert_eq(_game.objectives.models_contesting(_mine(), objective), 3)


func test_contesting_can_be_forbidden() -> void:
	var objective := _on_objective(1, 0)
	RulesKit.give(_game, _mine(), RulesKit.modifier(&"contest", 0, _game.battle.opponent, Modifier.Op.FORBID))
	assert_eq(_game.objectives.models_contesting(_mine(), objective), 0)


func test_an_objective_out_of_play_is_not_contested() -> void:
	var objective := _on_objective(1, 0)
	_game.state.objectives_out_of_play[objective] = true
	assert_eq(_game.objectives.models_contesting(_mine(), objective), 0)


func test_contesting_a_named_objective() -> void:
	_on_objective(1, 0)
	assert_true(_game.objectives.contests_named(_mine(), "Sun Seekers"))
	assert_false(_game.objectives.contests_named(_mine(), "Golden Lions"))


func test_the_control_score_is_the_control_of_each_model_contesting() -> void:
	var objective := _on_objective(3, 0, 2)
	assert_eq(_game.objectives.control_score(_mine(), objective), 6)


func test_the_control_score_is_at_least_one_for_a_unit_contesting() -> void:
	var objective := _on_objective(1, 0, 0)
	assert_eq(_game.objectives.control_score(_mine(), objective), 1)


func test_the_control_score_is_nothing_when_not_contesting() -> void:
	var objective := _on_objective(0, 0)
	assert_eq(_game.objectives.control_score(_mine(), objective), 0)


func test_the_army_with_the_higher_score_takes_control() -> void:
	var objective := _on_objective(3, 1)
	_game.objectives.update()
	assert_eq(_game.state.objective_control[objective], _game.battle.player)


func test_the_enemy_can_take_control() -> void:
	var objective := _on_objective(1, 3)
	_game.objectives.update()
	assert_eq(_game.state.objective_control[objective], _game.battle.opponent)


func test_a_tie_leaves_control_where_it_was() -> void:
	var objective := _on_objective(2, 2)
	_game.state.objective_control[objective] = _game.battle.opponent
	_game.objectives.update()
	assert_eq(_game.state.objective_control[objective], _game.battle.opponent)


func test_a_tie_with_nobody_in_control_leaves_it_uncontrolled() -> void:
	var objective := _on_objective(2, 2)
	_game.objectives.update()
	assert_false(_game.state.objective_control.has(objective))


func test_an_objective_nobody_is_near_keeps_its_owner() -> void:
	var objective := _on_objective(0, 0)
	_game.state.objective_control[objective] = _game.battle.player
	_game.objectives.update()
	assert_eq(_game.state.objective_control[objective], _game.battle.player)


func test_an_objective_out_of_play_has_no_controller() -> void:
	var objective := _on_objective(3, 0)
	_game.state.objectives_out_of_play[objective] = true
	_game.state.objective_control[objective] = _game.battle.player
	_game.objectives.update()
	assert_false(_game.state.objective_control.has(objective))


func test_a_change_of_control_is_announced() -> void:
	_on_objective(3, 0)
	_game.objectives.update()
	var kinds := _game.events.log_entries.map(func(e: BattleEvent) -> StringName: return e.kind)
	assert_true(BattleEvent.OBJECTIVE_CHANGED in kinds)


func test_keeping_control_is_not_announced_again() -> void:
	_on_objective(3, 0)
	_game.objectives.update()
	var before := _game.events.log_entries.size()
	_game.objectives.update()
	assert_eq(_game.events.log_entries.size(), before)
