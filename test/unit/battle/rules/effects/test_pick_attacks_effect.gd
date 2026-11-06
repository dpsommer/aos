extends GutTest
## Picking each weapon's target.

const RulesKit := preload("res://test/support/rules_kit.gd")

var _game: GameController
var _attacker: BattleUnit
var _near: BattleUnit
var _far: BattleUnit
var _axe: Weapon
var _spear: Weapon
var _bow: Weapon


func before_each() -> void:
	_axe = RulesKit.weapon("1", 2)
	_axe.name = "Axe"
	_spear = RulesKit.weapon("1", 2)
	_spear.name = "Spear"
	_bow = RulesKit.weapon("1", 2, 2, 0, "1", PackedStringArray(), 24)
	_bow.name = "Bow"
	_attacker = RulesKit.unit("Attacker", 1, Vector2(5, 5), PackedStringArray(), 1, 0, [_axe, _spear, _bow] as Array[Weapon])
	_near = RulesKit.unit("Near", 1, Vector2(6.5, 5))
	_far = RulesKit.unit("Far", 1, Vector2(25, 18))
	_game = RulesKit.game([_attacker] as Array[BattleUnit], [_near, _far] as Array[BattleUnit])


func after_each() -> void:
	_game.dispose()


func _pick(type := "melee") -> Array:
	var effect := RulesKit.effect({"op": "pick_attacks", "type": type})
	var action := RulesKit.action(_game, _attacker)
	return [effect, action, effect.resolve(action, _game)]


func test_it_asks_for_a_target_for_each_weapon_that_has_one() -> void:
	var request: DecisionRequest = _pick()[2]
	assert_eq(request.kind, DecisionRequest.Kind.ATTACK_TARGETS)
	assert_eq(request.attacker, _attacker)
	assert_eq(request.weapons, [_axe, _spear] as Array[Weapon])


func test_each_weapons_eligible_targets_are_listed() -> void:
	var request: DecisionRequest = _pick()[2]
	assert_eq(request.weapon_targets[_axe], [_near] as Array[BattleUnit])


func test_shooting_asks_about_ranged_weapons() -> void:
	_near.positions = PackedVector2Array([Vector2(15, 5)])
	var request: DecisionRequest = _pick("shooting")[2]
	assert_eq(request.weapons, [_bow] as Array[Weapon])


func test_a_unit_in_combat_has_no_shooting_to_pick() -> void:
	assert_null(_pick("shooting")[2])


func test_with_nothing_to_attack_it_asks_nothing() -> void:
	_near.positions = PackedVector2Array([Vector2(25, 5)])
	assert_null(_pick()[2])


func test_a_target_for_every_weapon_is_accepted() -> void:
	var picked := _pick()
	var answer := Decision.attack({_axe: _near, _spear: _near})
	assert_eq(picked[0].answer(picked[1], _game, picked[2], answer), "")
	assert_eq(picked[1].attack_targets, {_axe: _near, _spear: _near})


func test_the_targets_become_the_actions_targets() -> void:
	var picked := _pick()
	picked[0].answer(picked[1], _game, picked[2], Decision.attack({_axe: _near, _spear: _near}))
	assert_eq(picked[1].targets, [_near] as Array[BattleUnit])


func test_a_unit_attacked_by_two_weapons_is_one_target() -> void:
	var picked := _pick()
	picked[0].answer(picked[1], _game, picked[2], Decision.attack({_axe: _near, _spear: _near}))
	assert_eq(picked[1].targets.size(), 1)


func test_no_answer_is_refused() -> void:
	var picked := _pick()
	assert_ne(picked[0].answer(picked[1], _game, picked[2], Decision.attack({})), "")


func test_a_weapon_left_without_a_target_is_refused() -> void:
	var picked := _pick()
	assert_ne(picked[0].answer(picked[1], _game, picked[2], Decision.attack({_axe: _near})), "")
	assert_true(picked[1].attack_targets.is_empty())


func test_a_target_a_weapon_cannot_reach_is_refused() -> void:
	var picked := _pick()
	assert_ne(picked[0].answer(picked[1], _game, picked[2], Decision.attack({_axe: _far, _spear: _near})), "")


func test_once_picked_it_asks_nothing_more() -> void:
	var picked := _pick()
	picked[0].answer(picked[1], _game, picked[2], Decision.attack({_axe: _near, _spear: _near}))
	assert_null(picked[0].resolve(picked[1], _game))
