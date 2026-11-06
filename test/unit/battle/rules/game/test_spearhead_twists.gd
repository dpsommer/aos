extends GutTest
## Spearhead twist cards: what they ask for, apply and score.

const RulesKit := preload("res://test/support/rules_kit.gd")
const BattleKit := preload("res://test/support/battle_kit.gd")

var _game: GameController
var _mine: BattleArmy
var _theirs: BattleArmy


func before_each() -> void:
	var battle := BattleKit.battle()
	battle.player.units.assign([RulesKit.unit("Mine", 1, Vector2(2, 5)), RulesKit.unit("Mine Too", 1, Vector2(2, 9))] as Array[BattleUnit])
	battle.opponent.units.assign([RulesKit.unit("Theirs", 1, Vector2(28, 15))] as Array[BattleUnit])
	_game = GameController.new(battle, RandomNumberGenerator.new())
	_mine = battle.player
	_theirs = battle.opponent


func after_each() -> void:
	_game.dispose()


func _twist(twist_name: String) -> TwistCard:
	var card := TwistCard.new()
	card.name = twist_name
	return card


func test_the_twists_the_engine_applies_are_known() -> void:
	assert_true(SpearheadTwists.is_supported(_twist("Let the Blood Flow")))
	assert_true(SpearheadTwists.is_supported(_twist("Bloodmarked")))


func test_a_twist_the_engine_does_not_apply_is_not_supported() -> void:
	assert_false(SpearheadTwists.is_supported(_twist("A Twist Nobody Wrote")))
	assert_false(SpearheadTwists.is_supported(null))


# Let the Blood Flow

func test_let_the_blood_flow_asks_the_underdog_to_pick_a_friendly_unit() -> void:
	_game.state.underdog = _theirs
	_game.push(SpearheadTwists.new(_twist("Let the Blood Flow")))
	var request := _game.next_decision()
	assert_eq(request.kind, DecisionRequest.Kind.TARGETS)
	assert_eq(request.army, _theirs)
	assert_eq(request.units, _game.on_battlefield(_theirs))


func test_let_the_blood_flow_gives_the_picked_unit_a_bonus_to_hit_in_melee_for_the_round() -> void:
	_game.state.underdog = _mine
	_game.push(SpearheadTwists.new(_twist("Let the Blood Flow")))
	var request := _game.next_decision()
	var picked: BattleUnit = request.units[1]
	assert_eq(_game.answer(Decision.pick([picked] as Array[BattleUnit])), "")
	var modifier: Modifier = _game.controller_of(picked).modifiers.modifiers[0]
	assert_eq(modifier.stat, &"hit")
	assert_gt(modifier.value, 0)
	assert_eq(modifier.weapons, "melee")
	assert_eq(modifier.until, Modifier.Until.END_OF_ROUND)
	assert_eq(_game.controller_of(request.units[0]).modifiers.modifiers.size(), 0, "Only the picked unit")


func test_let_the_blood_flow_refuses_a_unit_that_is_not_on_offer() -> void:
	_game.state.underdog = _mine
	_game.push(SpearheadTwists.new(_twist("Let the Blood Flow")))
	_game.next_decision()
	assert_ne(_game.answer(Decision.pick([_theirs.units[0]] as Array[BattleUnit])), "")
	assert_ne(_game.answer(Decision.pick([] as Array[BattleUnit])), "")


func test_let_the_blood_flow_asks_nothing_without_an_underdog() -> void:
	_game.state.underdog = null
	var frame := SpearheadTwists.new(_twist("Let the Blood Flow"))
	assert_null(frame.advance(_game))
	assert_true(frame.finished)


func test_let_the_blood_flow_scores_for_each_enemy_unit_destroyed_this_turn() -> void:
	_game.state.count_turn(_mine, &"enemy_destroyed", 2)
	SpearheadTwists.on_scored(_twist("Let the Blood Flow"), _mine, _game)
	assert_eq(_game.state.points_of(_mine), 2)
	assert_eq(_game.state.points_of(_theirs), 0)


func test_let_the_blood_flow_scores_nothing_if_nothing_was_destroyed() -> void:
	SpearheadTwists.on_scored(_twist("Let the Blood Flow"), _mine, _game)
	assert_eq(_game.state.points_of(_mine), 0)


# Bloodmarked

func test_a_marked_unit_destroyed_scores_for_who_marked_it_when_the_round_ends() -> void:
	var marked := _theirs.units[0]
	_game.twist_picks = {"marks": {marked: _mine}}
	_game.command(marked, Commands.Destroy.new(_mine))
	SpearheadTwists.on_round_ended(_twist("Bloodmarked"), _game)
	assert_eq(_game.state.points_of(_mine), 1)


func test_a_marked_unit_that_survives_scores_nothing() -> void:
	_game.twist_picks = {"marks": {_theirs.units[0]: _mine}}
	SpearheadTwists.on_round_ended(_twist("Bloodmarked"), _game)
	assert_eq(_game.state.points_of(_mine), 0)


func test_another_twists_round_end_scores_nothing() -> void:
	var marked := _theirs.units[0]
	_game.twist_picks = {"marks": {marked: _mine}}
	_game.command(marked, Commands.Destroy.new(_mine))
	SpearheadTwists.on_round_ended(_twist("Let the Blood Flow"), _game)
	assert_eq(_game.state.points_of(_mine), 0)


func test_no_twist_scores_nothing() -> void:
	SpearheadTwists.on_scored(null, _mine, _game)
	SpearheadTwists.on_round_ended(null, _game)
	assert_eq(_game.state.points_of(_mine), 0)


# Ring of Fire

func test_ring_of_fire_takes_the_picked_objective_out_of_play() -> void:
	var objective := BattleKit.feature("Sun Seekers", Vector2(15, 11))
	_game.battle.objectives = [objective] as Array[MapFeature]
	_game.state.objective_control[objective] = _mine
	_game.state.underdog = _mine
	_game.push(SpearheadTwists.new(_twist("Ring of Fire")))
	var request := _game.next_decision()
	assert_eq(request.kind, DecisionRequest.Kind.CHOICE)
	assert_eq(_game.answer(Decision.choose(0)), "")
	assert_true(_game.state.objectives_out_of_play.has(objective))
	assert_false(_game.state.objective_control.has(objective))


# Reclaiming objectives

func test_reclaim_scores_for_each_picked_objective_held() -> void:
	var first := BattleKit.feature("A", Vector2(10, 11))
	var second := BattleKit.feature("B", Vector2(20, 11))
	_game.twist_picks = {"objectives": [first, second]}
	_game.state.objective_control[first] = _mine
	_game.state.objective_control[second] = _theirs
	SpearheadTwists.on_scored(_twist("Reclaim Aqshy"), _mine, _game)
	assert_eq(_game.state.points_of(_mine), 1)
