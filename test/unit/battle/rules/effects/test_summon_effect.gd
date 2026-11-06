extends GutTest
## Summoning a manifestation.

const RulesKit := preload("res://test/support/rules_kit.gd")

var _game: GameController
var _caster: BattleUnit
var _id := ""


func before_each() -> void:
	_caster = RulesKit.unit("Caster", 1, Vector2(10, 10), PackedStringArray(["WIZARD (1)"]))
	_game = RulesKit.matched_game([_caster] as Array[BattleUnit], [RulesKit.unit("Enemy", 1, Vector2(25, 18))] as Array[BattleUnit])
	for lore in _game.core.manifestation_lores:
		for entry in lore.entries:
			if _id.is_empty() and not entry.summons.is_empty():
				_id = entry.summons[0]


func after_each() -> void:
	_game.dispose()


func _start(extra := {}) -> Array:
	var effect := RulesKit.effect(extra.merged({"op": "summon"}))
	var action := RulesKit.action(_game, _caster, [] as Array[BattleUnit], "Summon")
	action.entry.ability.summons = PackedStringArray([_id])
	return [effect, action, effect.resolve(action, _game)]


func test_summoning_asks_where_to_set_the_manifestation_up() -> void:
	var request: DecisionRequest = _start()[2]
	assert_eq(request.kind, DecisionRequest.Kind.SET_UP)
	assert_false(request.can_pass)
	assert_true(request.unit in _game.battle.player.units)
	assert_eq(request.unit.warscroll.id, _id)


func test_a_legal_spot_sets_it_up() -> void:
	var started := _start()
	var at := PackedVector2Array([Vector2(14, 10)])
	assert_eq(started[0].answer(started[1], _game, started[2], Decision.move_to(at)), "")
	assert_true(started[2].unit.is_on_battlefield())


func test_it_cannot_be_declined() -> void:
	var started := _start()
	assert_ne(started[0].answer(started[1], _game, started[2], Decision.pass_it()), "")
	assert_false(started[2].unit.is_on_battlefield())


func test_a_spot_near_an_enemy_is_refused() -> void:
	var started := _start()
	assert_ne(started[0].answer(started[1], _game, started[2], Decision.move_to(PackedVector2Array([Vector2(25, 16)]))), "")


func test_it_can_have_to_be_near_the_caster() -> void:
	var started := _start({"near_user": 8})
	assert_eq(started[2].near_unit, _caster)
	assert_ne(started[0].answer(started[1], _game, started[2], Decision.move_to(PackedVector2Array([Vector2(25, 4)]))), "", "Too far from the caster")
	assert_eq(started[0].answer(started[1], _game, started[2], Decision.move_to(PackedVector2Array([Vector2(14, 10)]))), "")


func test_once_set_up_it_asks_nothing_more() -> void:
	var started := _start()
	started[0].answer(started[1], _game, started[2], Decision.move_to(PackedVector2Array([Vector2(14, 10)])))
	assert_null(started[0].resolve(started[1], _game))


func test_an_ability_that_summons_nothing_asks_nothing() -> void:
	var effect := RulesKit.effect({"op": "summon"})
	assert_null(effect.resolve(RulesKit.action(_game, _caster), _game))


func test_a_manifestation_already_on_the_battlefield_is_not_summoned_again() -> void:
	var started := _start()
	started[0].answer(started[1], _game, started[2], Decision.move_to(PackedVector2Array([Vector2(14, 10)])))
	assert_null(_start()[2])
