extends GutTest
## Unit tests for a regiment on the battlefield (scripts/battle/battle_regiment.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")


func _regiment() -> BattleRegiment:
	var units: Array[BattleUnit] = [BattleKit.unit("A", 1), BattleKit.unit("B", 1)]
	return BattleKit.regiment("R", units)


func test_nothing_is_deployed_to_begin_with() -> void:
	var regiment := _regiment()
	assert_false(regiment.any_deployed())
	assert_false(regiment.all_deployed())


func test_one_deployed_unit_is_any_but_not_all() -> void:
	var regiment := _regiment()
	regiment.units[0].deployed = true
	assert_true(regiment.any_deployed())
	assert_false(regiment.all_deployed())


func test_every_unit_deployed_is_all_deployed() -> void:
	var regiment := _regiment()
	for unit in regiment.units:
		unit.deployed = true
	assert_true(regiment.all_deployed())


func test_a_unit_in_reserve_counts_as_deployed() -> void:
	var regiment := _regiment()
	regiment.units[0].deployed = true
	regiment.units[0].reserve = "in the clouds"
	assert_true(regiment.any_deployed())
