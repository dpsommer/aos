extends GutTest
## Unit tests for building the core rules from JSON (scripts/data/core_rules_loader.gd, core_rules.gd).
##
## Expectations are read from the fixture JSON, so editing a fixture value doesn't break tests.

const FIXTURES := "res://test/fixtures/core"


func _dir(fixture: String) -> String:
	return FIXTURES.path_join(fixture)


func _json(fixture: String, file_name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_dir(fixture).path_join(file_name)))


func _load(fixture: String) -> CoreRules:
	return CoreRulesLoader.new().load_core_rules(_dir(fixture))


func _errors(fixture: String) -> PackedStringArray:
	var loader := CoreRulesLoader.new()
	loader.load_core_rules(_dir(fixture))
	return loader.errors


func _has_error_naming(errors: PackedStringArray, file_name: String, field: String) -> bool:
	for error in errors:
		if error.begins_with(file_name) and field in error:
			return true
	return false


func test_valid_dir_loads_without_errors() -> void:
	assert_not_null(_load("valid"))
	assert_eq(_errors("valid").size(), 0, "\n".join(_errors("valid")))


func test_abilities_come_from_file() -> void:
	var expected: Array = _json("valid", "abilities.json").abilities
	var rules := _load("valid")
	assert_eq(rules.abilities.size(), expected.size())
	assert_eq(rules.abilities[0].name, expected[0].name)


func test_weapon_and_terrain_abilities_come_from_file() -> void:
	var data := _json("valid", "abilities.json")
	var rules := _load("valid")
	assert_eq([rules.weapon_abilities[0].name, rules.terrain_abilities[0].name],
			[data.weapon_abilities[0].name, data.terrain_abilities[0].name])


func test_command_points_and_used_by_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "abilities.json").abilities[1]
	var ability := _load("valid").abilities[1]
	assert_eq([ability.command_points, ability.used_by], [int(expected.command_points), expected.used_by])


func test_lores_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "manifestation_lores.json").lores[0]
	var lore := _load("valid").manifestation_lores[0]
	assert_eq([lore.name, lore.kind, lore.points, lore.entries.size()],
			[expected.name, expected.kind, int(expected.points), expected.entries.size()])


func test_manifestation_warscrolls_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "manifestation_lores.json").warscrolls[0]
	var unit := _load("valid").manifestations[0]
	assert_eq([unit.id, unit.name, unit.banishment], [expected.id, expected.name, int(expected.banishment)])


func test_get_ability_finds_by_name() -> void:
	var ability_name: String = _json("valid", "abilities.json").abilities[1].name
	assert_eq(_load("valid").get_ability(ability_name).name, ability_name)


func test_get_ability_returns_null_for_unknown_name() -> void:
	assert_null(_load("valid").get_ability("Not A Real Ability"))


func test_get_manifestation_finds_by_id() -> void:
	var id: String = _json("valid", "manifestation_lores.json").warscrolls[0].id
	assert_eq(_load("valid").get_manifestation(id).id, id)


func test_get_manifestation_returns_null_for_unknown_id() -> void:
	assert_null(_load("valid").get_manifestation("not_a_real_manifestation"))


func test_missing_abilities_file_returns_null() -> void:
	assert_null(_load("no_abilities"))


func test_missing_abilities_file_error_names_file() -> void:
	assert_true(_has_error_naming(_errors("no_abilities"), "abilities.json", "not found"), str(_errors("no_abilities")))


func test_missing_lores_file_returns_null() -> void:
	assert_null(_load("no_lores"))


func test_missing_lores_file_error_names_file() -> void:
	assert_true(_has_error_naming(_errors("no_lores"), "manifestation_lores.json", "not found"), str(_errors("no_lores")))


func test_missing_directory_returns_null() -> void:
	assert_null(_load("does_not_exist"))


func test_wrong_type_returns_null() -> void:
	assert_null(_load("wrong_type"))


func test_wrong_type_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("wrong_type"), "manifestation_lores.json", "lores[0].points"),
			str(_errors("wrong_type")))


func test_errors_are_reset_between_calls() -> void:
	var loader := CoreRulesLoader.new()
	loader.load_core_rules(_dir("no_abilities"))
	assert_gt(loader.errors.size(), 0)
	assert_not_null(loader.load_core_rules(_dir("valid")))
	assert_eq(loader.errors.size(), 0)
