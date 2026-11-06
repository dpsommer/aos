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
var _effect: Effect
var _action: Action


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


## Starts picking attacks of [param type], and returns what it asks.
func _pick(type := "melee") -> DecisionRequest:
	_effect = RulesKit.effect({"op": "pick_attacks", "type": type})
	_action = RulesKit.action(_game, _attacker)
	return _effect.resolve(_action, _game)


## Starts picking melee attacks and answers with [param targets], giving the reason it's refused.
func _pick_targets(targets: Dictionary) -> String:
	var request := _pick()
	return _effect.answer(_action, _game, request, Decision.attack(targets))


func test_it_asks_for_a_target_for_each_weapon_that_has_one() -> void:
	var request := _pick()
	assert_eq(request.kind, DecisionRequest.Kind.ATTACK_TARGETS)
	assert_eq(request.attacker, _attacker)
	assert_eq(request.weapons, [_axe, _spear] as Array[Weapon])


func test_each_weapons_eligible_targets_are_listed() -> void:
	assert_eq(_pick().weapon_targets[_axe], [_near] as Array[BattleUnit])


func test_shooting_asks_about_ranged_weapons() -> void:
	_near.positions = PackedVector2Array([Vector2(15, 5)])
	assert_eq(_pick("shooting").weapons, [_bow] as Array[Weapon])


func test_a_unit_in_combat_has_no_shooting_to_pick() -> void:
	assert_null(_pick("shooting"))


func test_with_nothing_to_attack_it_asks_nothing() -> void:
	_near.positions = PackedVector2Array([Vector2(25, 5)])
	assert_null(_pick())


func test_a_target_for_every_weapon_is_accepted() -> void:
	assert_eq(_pick_targets({_axe: _near, _spear: _near}), "")
	assert_eq(_action.attack_targets, {_axe: _near, _spear: _near})


func test_the_targets_become_the_actions_targets() -> void:
	_pick_targets({_axe: _near, _spear: _near})
	assert_eq(_action.targets, [_near] as Array[BattleUnit])


func test_a_unit_attacked_by_two_weapons_is_one_target() -> void:
	_pick_targets({_axe: _near, _spear: _near})
	assert_eq(_action.targets.size(), 1)


func test_no_answer_is_refused() -> void:
	assert_ne(_pick_targets({}), "")


func test_a_weapon_left_without_a_target_is_refused() -> void:
	assert_ne(_pick_targets({_axe: _near}), "")
	assert_true(_action.attack_targets.is_empty())


func test_a_target_a_weapon_cannot_reach_is_refused() -> void:
	assert_ne(_pick_targets({_axe: _far, _spear: _near}), "")


func test_once_picked_it_asks_nothing_more() -> void:
	_pick_targets({_axe: _near, _spear: _near})
	assert_null(_effect.resolve(_action, _game))
