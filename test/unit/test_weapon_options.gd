extends GutTest
## Unit tests for weapon option counts (scripts/army/weapon_options.gd).

const Kit := preload("res://test/support/army_kit.gd")


## A unit of 10 with a "1 per 5 models" option (cap 2, or 4 reinforced) and a choice option.
func _scroll() -> Warscroll:
	var scroll := Kit.warscroll("squad")
	scroll.unit_size = 10
	scroll.weapon_options.append(Kit.weapon_option("Grandhammer", 1, 5))
	scroll.weapon_options.append(Kit.weapon_option("Shield", 0, 0, true))
	return scroll


func _unit(reinforced := false) -> ArmyUnit:
	var unit := Kit.unit("u1", "squad")
	unit.reinforced = reinforced
	return unit


func test_models_is_unit_size() -> void:
	assert_eq(WeaponOptions.models(_scroll(), false), 10)


func test_models_doubles_when_reinforced() -> void:
	assert_eq(WeaponOptions.models(_scroll(), true), 20)


func test_models_is_at_least_one_for_a_unit_without_size() -> void:
	var scroll := Kit.warscroll("hero")
	scroll.unit_size = 0
	assert_eq(WeaponOptions.models(scroll, false), 1)


func test_ratio_option_cap_scales_with_unit_size() -> void:
	var scroll := _scroll()
	assert_eq(WeaponOptions.cap(scroll.weapon_options[0], scroll, false), 2)


func test_ratio_option_cap_doubles_when_reinforced() -> void:
	var scroll := _scroll()
	assert_eq(WeaponOptions.cap(scroll.weapon_options[0], scroll, true), 4)


func test_ratio_option_cap_rounds_down_partial_groups() -> void:
	var scroll := _scroll()
	scroll.unit_size = 9
	assert_eq(WeaponOptions.cap(scroll.weapon_options[0], scroll, false), 1)


func test_choice_option_cap_is_every_model() -> void:
	var scroll := _scroll()
	assert_eq(WeaponOptions.cap(scroll.weapon_options[1], scroll, false), 10)


func test_value_defaults_to_the_cap() -> void:
	var scroll := _scroll()
	assert_eq(WeaponOptions.value(_unit(), scroll.weapon_options[0], scroll), 2)


func test_value_uses_the_units_count() -> void:
	var scroll := _scroll()
	var unit := _unit()
	unit.weapon_options["Grandhammer"] = 1
	assert_eq(WeaponOptions.value(unit, scroll.weapon_options[0], scroll), 1)


func test_value_never_exceeds_the_cap() -> void:
	var scroll := _scroll()
	var unit := _unit()
	unit.weapon_options["Grandhammer"] = 50
	assert_eq(WeaponOptions.value(unit, scroll.weapon_options[0], scroll), 2)


func test_defaults_has_every_option_at_its_cap() -> void:
	var scroll := _scroll()
	var defaults := WeaponOptions.defaults(scroll)
	for option in scroll.weapon_options:
		assert_eq(defaults[option.name], WeaponOptions.cap(option, scroll, false))


func test_defaults_for_a_reinforced_unit_use_reinforced_caps() -> void:
	var scroll := _scroll()
	var option := scroll.weapon_options[0]
	assert_eq(WeaponOptions.defaults(scroll, true)[option.name], WeaponOptions.cap(option, scroll, true))


func test_defaults_is_empty_without_options() -> void:
	assert_true(WeaponOptions.defaults(Kit.warscroll("plain")).is_empty())


func test_reinforcing_moves_an_option_at_its_cap_to_the_new_cap() -> void:
	var scroll := _scroll()
	var unit := _unit()
	unit.weapon_options = WeaponOptions.defaults(scroll)
	WeaponOptions.set_reinforced(unit, scroll, true)
	assert_eq(unit.weapon_options["Grandhammer"], WeaponOptions.cap(scroll.weapon_options[0], scroll, true))


func test_reinforcing_keeps_an_option_below_its_cap() -> void:
	var scroll := _scroll()
	var unit := _unit()
	unit.weapon_options["Grandhammer"] = 1
	WeaponOptions.set_reinforced(unit, scroll, true)
	assert_eq(unit.weapon_options["Grandhammer"], 1)


func test_reinforcing_sets_the_flag() -> void:
	var unit := _unit()
	WeaponOptions.set_reinforced(unit, _scroll(), true)
	assert_true(unit.reinforced)


func test_unreinforcing_moves_an_option_at_its_cap_to_the_new_cap() -> void:
	var scroll := _scroll()
	var unit := _unit(true)
	unit.weapon_options = WeaponOptions.defaults(scroll, true)
	WeaponOptions.set_reinforced(unit, scroll, false)
	assert_eq(unit.weapon_options["Grandhammer"], WeaponOptions.cap(scroll.weapon_options[0], scroll, false))


func test_unreinforcing_reduces_a_count_above_the_new_cap() -> void:
	var scroll := _scroll()
	var unit := _unit(true)
	unit.weapon_options["Grandhammer"] = 3
	WeaponOptions.set_reinforced(unit, scroll, false)
	assert_eq(unit.weapon_options["Grandhammer"], WeaponOptions.cap(scroll.weapon_options[0], scroll, false))


func test_unreinforcing_keeps_a_count_within_the_new_cap() -> void:
	var scroll := _scroll()
	var unit := _unit(true)
	unit.weapon_options["Grandhammer"] = 1
	WeaponOptions.set_reinforced(unit, scroll, false)
	assert_eq(unit.weapon_options["Grandhammer"], 1)


func test_unreinforcing_clears_the_flag() -> void:
	var unit := _unit(true)
	WeaponOptions.set_reinforced(unit, _scroll(), false)
	assert_false(unit.reinforced)
