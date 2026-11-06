extends GutTest
## Summoning a manifestation.

const RulesKit := preload("res://test/support/rules_kit.gd")

var _game: GameController
var _caster: BattleUnit
var _effect: Effect
var _action: Action


func before_each() -> void:
	_caster = RulesKit.unit("Caster", 1, Vector2(10, 10), PackedStringArray(["WIZARD (1)"]))
	_game = RulesKit.matched_game([_caster] as Array[BattleUnit], [RulesKit.unit("Enemy", 1, Vector2(25, 18))] as Array[BattleUnit])


func after_each() -> void:
	_game.dispose()


## The id of a manifestation in the core rules.
func _manifestation_id() -> String:
	for lore in _game.core.manifestation_lores:
		for entry in lore.entries:
			if not entry.summons.is_empty():
				return entry.summons[0]
	return ""


## Starts a summon, and returns what it asks.
func _start(extra := {}) -> DecisionRequest:
	_effect = RulesKit.effect(extra.merged({"op": "summon"}))
	_action = RulesKit.action(_game, _caster, [] as Array[BattleUnit], "Summon")
	_action.entry.ability.summons = PackedStringArray([_manifestation_id()])
	return _effect.resolve(_action, _game)


func _answer(request: DecisionRequest, decision: Decision) -> String:
	return _effect.answer(_action, _game, request, decision)


func _at(x: float, y: float) -> Decision:
	return Decision.move_to(PackedVector2Array([Vector2(x, y)]))


func test_summoning_asks_where_to_set_the_manifestation_up() -> void:
	var request := _start()
	assert_eq(request.kind, DecisionRequest.Kind.SET_UP)
	assert_false(request.can_pass)
	assert_true(request.unit in _game.battle.player.units)
	assert_eq(request.unit.warscroll.id, _manifestation_id())


func test_a_legal_spot_sets_it_up() -> void:
	var request := _start()
	assert_eq(_answer(request, _at(14, 10)), "")
	assert_true(request.unit.is_on_battlefield())


func test_it_cannot_be_declined() -> void:
	var request := _start()
	assert_ne(_answer(request, Decision.pass_it()), "")
	assert_false(request.unit.is_on_battlefield())


func test_a_spot_near_an_enemy_is_refused() -> void:
	assert_ne(_answer(_start(), _at(25, 16)), "")


func test_it_can_have_to_be_near_the_caster() -> void:
	var request := _start({"near_user": 8})
	assert_eq(request.near_unit, _caster)
	assert_ne(_answer(request, _at(25, 4)), "", "Too far from the caster")
	assert_eq(_answer(request, _at(14, 10)), "")


func test_once_set_up_it_asks_nothing_more() -> void:
	_answer(_start(), _at(14, 10))
	assert_null(_effect.resolve(_action, _game))


func test_an_ability_that_summons_nothing_asks_nothing() -> void:
	var effect := RulesKit.effect({"op": "summon"})
	assert_null(effect.resolve(RulesKit.action(_game, _caster), _game))


func test_a_manifestation_already_on_the_battlefield_is_not_summoned_again() -> void:
	_answer(_start(), _at(14, 10))
	assert_null(_start())
