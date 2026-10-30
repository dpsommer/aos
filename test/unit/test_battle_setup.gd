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
