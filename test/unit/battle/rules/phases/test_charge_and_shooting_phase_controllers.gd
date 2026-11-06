extends GutTest
## Who can still charge or shoot.

const RulesKit := preload("res://test/support/rules_kit.gd")
const M := AbilityTiming.Moment

var _game: GameController


func after_each() -> void:
	_game.dispose()


func _start(mine: Array[BattleUnit], theirs: Array[BattleUnit], window: M) -> void:
	_game = RulesKit.matched_game(mine, theirs)
	_game.state.active = _game.battle.player
	_game.state.window = window


func _shooter(at: Vector2, with_gun := true) -> BattleUnit:
	var weapons: Array[Weapon] = []
	if with_gun:
		weapons.append(RulesKit.weapon("1", 2, 2, 0, "1", PackedStringArray(), 24))
	return RulesKit.unit("Shooter", 1, at, PackedStringArray(), 1, 0, weapons)


func _can_shoot() -> Array[BattleUnit]:
	return ShootingPhaseController.new(M.SHOOTING).units_that_can_shoot(_game, _game.battle.player)


func _can_charge() -> Array[BattleUnit]:
	return ChargePhaseController.new(M.CHARGE).units_that_can_charge(_game, _game.battle.player)


func test_a_unit_with_a_target_in_range_can_shoot() -> void:
	var unit := _shooter(Vector2(5, 5))
	_start([unit] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(15, 5))] as Array[BattleUnit], M.SHOOTING)
	assert_eq(_can_shoot(), [unit] as Array[BattleUnit])


func test_a_unit_with_no_target_in_range_cannot_shoot() -> void:
	var unit := _shooter(Vector2(5, 5))
	_start([unit] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(29, 20))] as Array[BattleUnit], M.SHOOTING)
	assert_true(_can_shoot().is_empty())


func test_a_unit_without_ranged_weapons_cannot_shoot() -> void:
	var unit := _shooter(Vector2(5, 5), false)
	_start([unit] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(15, 5))] as Array[BattleUnit], M.SHOOTING)
	assert_true(_can_shoot().is_empty())


func test_a_unit_that_ran_cannot_shoot() -> void:
	var unit := _shooter(Vector2(5, 5))
	_start([unit] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(15, 5))] as Array[BattleUnit], M.SHOOTING)
	_game.controller_of(unit).ran = true
	assert_true(_can_shoot().is_empty())


func test_a_unit_that_ran_can_shoot_if_something_permits_it() -> void:
	var unit := _shooter(Vector2(5, 5))
	_start([unit] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(15, 5))] as Array[BattleUnit], M.SHOOTING)
	_game.controller_of(unit).ran = true
	RulesKit.give(_game, unit, RulesKit.modifier(&"shoot_after_run", 0, _game.battle.player, Modifier.Op.PERMIT))
	assert_eq(_can_shoot(), [unit] as Array[BattleUnit])


func test_a_unit_that_retreated_cannot_shoot() -> void:
	var unit := _shooter(Vector2(5, 5))
	_start([unit] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(15, 5))] as Array[BattleUnit], M.SHOOTING)
	_game.controller_of(unit).retreated = true
	assert_true(_can_shoot().is_empty())


func test_a_unit_near_an_enemy_can_charge() -> void:
	var unit := RulesKit.unit("Charger", 1, Vector2(5, 5))
	_start([unit] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(15, 5))] as Array[BattleUnit], M.CHARGE)
	assert_eq(_can_charge(), [unit] as Array[BattleUnit])


func test_a_unit_far_from_every_enemy_cannot_charge() -> void:
	var unit := RulesKit.unit("Charger", 1, Vector2(2, 2))
	_start([unit] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(29, 20))] as Array[BattleUnit], M.CHARGE)
	assert_true(_can_charge().is_empty())


func test_a_unit_already_in_combat_cannot_charge() -> void:
	var unit := RulesKit.unit("Charger", 1, Vector2(5, 5))
	_start([unit] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(7, 5))] as Array[BattleUnit], M.CHARGE)
	assert_true(_can_charge().is_empty())


func test_a_unit_that_ran_cannot_charge_unless_something_permits_it() -> void:
	var unit := RulesKit.unit("Charger", 1, Vector2(5, 5))
	_start([unit] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(15, 5))] as Array[BattleUnit], M.CHARGE)
	_game.controller_of(unit).ran = true
	assert_true(_can_charge().is_empty())
	RulesKit.give(_game, unit, RulesKit.modifier(&"charge_after_run", 0, _game.battle.player, Modifier.Op.PERMIT))
	assert_eq(_can_charge(), [unit] as Array[BattleUnit])


func test_each_unit_is_listed_once() -> void:
	var unit := RulesKit.unit("Charger", 1, Vector2(5, 5))
	_start([unit] as Array[BattleUnit], [RulesKit.unit("Theirs", 1, Vector2(15, 5))] as Array[BattleUnit], M.CHARGE)
	assert_eq(_can_charge().size(), 1)
