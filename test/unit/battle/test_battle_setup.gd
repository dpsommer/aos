extends GutTest
## Unit tests for what the player chose in Quick Play (scripts/battle/battle_setup.gd).


func test_every_mode_has_its_own_display_name() -> void:
	var names := {}
	for mode: BattleSetup.Mode in BattleSetup.Mode.values():
		names[BattleSetup.display_name(mode)] = true
	assert_eq(names.size(), BattleSetup.Mode.values().size())


func test_display_names_are_not_empty() -> void:
	for mode: BattleSetup.Mode in BattleSetup.Mode.values():
		assert_false(BattleSetup.display_name(mode).is_empty())


func test_battleplan_is_empty_for_random_by_default() -> void:
	assert_true(BattleSetup.new().battleplan.is_empty())


func test_battlepack_is_empty_for_random_by_default() -> void:
	assert_true(BattleSetup.new().battlepack.is_empty())


func test_realm_is_empty_for_random_by_default() -> void:
	assert_true(BattleSetup.new().realm.is_empty())


func test_battlepack_and_realm_are_independent_of_the_battleplan() -> void:
	var setup := BattleSetup.new()
	setup.battlepack = "Some Pack"
	setup.realm = "Some Realm"
	assert_true(setup.battleplan.is_empty())
