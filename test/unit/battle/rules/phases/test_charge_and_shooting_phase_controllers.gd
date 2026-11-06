extends GutTest
## Who can still charge or shoot.

const RulesKit := preload("res://test/support/rules_kit.gd")
const M := AbilityTiming.Moment

var _game: GameController


func after_each() -> void:
	_game.dispose()


## A game in [param window] of [param unit], of the active player, against an enemy at [param enemy_at].
func _start(unit: BattleUnit, enemy_at: Vector2, window: M) -> void:
	_game = RulesKit.matched_game([unit] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, enemy_at)] as Array[BattleUnit])
	_game.state.active = _game.battle.player
	_game.state.window = window


## A unit at (5, 5) with a 24" gun, in the shooting phase against an enemy at [param enemy_at].
func _start_shooter(enemy_at := Vector2(15, 5)) -> BattleUnit:
	var gun := RulesKit.weapon("1", 2, 2, 0, "1", PackedStringArray(), 24)
	var unit := RulesKit.unit("Shooter", 1, Vector2(5, 5), PackedStringArray(), 1, 0, [gun] as Array[Weapon])
	_start(unit, enemy_at, M.SHOOTING)
	return unit


## A unit at [param at] in the charge phase against an enemy at [param enemy_at].
func _start_charger(at := Vector2(5, 5), enemy_at := Vector2(15, 5)) -> BattleUnit:
	var unit := RulesKit.unit("Charger", 1, at)
	_start(unit, enemy_at, M.CHARGE)
	return unit


func _can_shoot() -> Array[BattleUnit]:
	return ShootingPhaseController.new(M.SHOOTING).units_that_can_shoot(_game, _game.battle.player)


func _can_charge() -> Array[BattleUnit]:
	return ChargePhaseController.new(M.CHARGE).units_that_can_charge(_game, _game.battle.player)


func test_a_unit_with_a_target_in_range_can_shoot() -> void:
	var unit := _start_shooter()
	assert_eq(_can_shoot(), [unit] as Array[BattleUnit])


func test_a_unit_with_no_target_in_range_cannot_shoot() -> void:
	_start_shooter(Vector2(29, 20))
	assert_true(_can_shoot().is_empty())


func test_a_unit_without_ranged_weapons_cannot_shoot() -> void:
	_start(RulesKit.unit("Unarmed", 1, Vector2(5, 5)), Vector2(15, 5), M.SHOOTING)
	assert_true(_can_shoot().is_empty())


func test_a_unit_that_ran_cannot_shoot() -> void:
	var unit := _start_shooter()
	_game.controller_of(unit).ran = true
	assert_true(_can_shoot().is_empty())


func test_a_unit_that_ran_can_shoot_if_something_permits_it() -> void:
	var unit := _start_shooter()
	_game.controller_of(unit).ran = true
	RulesKit.give(_game, unit, RulesKit.modifier(&"shoot_after_run", 0, _game.battle.player, Modifier.Op.PERMIT))
	assert_eq(_can_shoot(), [unit] as Array[BattleUnit])


func test_a_unit_that_retreated_cannot_shoot() -> void:
	var unit := _start_shooter()
	_game.controller_of(unit).retreated = true
	assert_true(_can_shoot().is_empty())


func test_a_unit_near_an_enemy_can_charge() -> void:
	var unit := _start_charger()
	assert_eq(_can_charge(), [unit] as Array[BattleUnit])


func test_a_unit_far_from_every_enemy_cannot_charge() -> void:
	_start_charger(Vector2(2, 2), Vector2(29, 20))
	assert_true(_can_charge().is_empty())


func test_a_unit_already_in_combat_cannot_charge() -> void:
	_start_charger(Vector2(5, 5), Vector2(7, 5))
	assert_true(_can_charge().is_empty())


func test_a_unit_that_ran_cannot_charge() -> void:
	var unit := _start_charger()
	_game.controller_of(unit).ran = true
	assert_true(_can_charge().is_empty())


func test_a_unit_that_ran_can_charge_if_something_permits_it() -> void:
	var unit := _start_charger()
	_game.controller_of(unit).ran = true
	RulesKit.give(_game, unit, RulesKit.modifier(&"charge_after_run", 0, _game.battle.player, Modifier.Op.PERMIT))
	assert_eq(_can_charge(), [unit] as Array[BattleUnit])


func test_each_unit_is_listed_once() -> void:
	_start_charger()
	assert_eq(_can_charge().size(), 1)
