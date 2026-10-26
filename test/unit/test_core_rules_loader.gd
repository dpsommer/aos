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


func _pack() -> Battlepack:
	return _load("valid").battlepack


func _card() -> BattleTacticCard:
	return _pack().battle_tactic_cards[0]


func _plan() -> Battleplan:
	return _pack().battleplans[0]


func test_battlepack_name_and_rounds_come_from_file() -> void:
	var expected := _json("valid", "battlepack.json")
	assert_eq([_pack().name, _pack().battle_rounds], [expected.name, int(expected.battle_rounds)])


func test_battlefield_size_comes_from_file() -> void:
	var expected: Dictionary = _json("valid", "battlepack.json").battlefield
	assert_eq(_pack().battlefield_size, Vector2(expected.width, expected.depth))


func test_battlepack_sections_come_from_file() -> void:
	var expected: Array = _json("valid", "battlepack.json").sections
	assert_eq(_pack().sections.size(), expected.size())
	assert_eq([_pack().sections[0].name, _pack().sections[0].text], [expected[0].name, expected[0].text])


func test_battleplan_tables_come_from_file() -> void:
	var expected: Array = _json("valid", "battlepack.json").battleplan_tables
	var tables := _pack().battleplan_tables
	assert_eq(tables.size(), expected.size())
	assert_eq(Array(tables[0]), expected[0])
	assert_eq(Array(tables[1]), expected[1])


func test_season_rules_come_from_file() -> void:
	var expected: Array = _json("valid", "battlepack.json").season_rules
	assert_eq(_pack().season_rules.size(), expected.size())
	assert_eq(_pack().season_rules[0].name, expected[0].name)


func test_battlepack_faqs_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "battlepack.json").faqs[0]
	assert_eq(_pack().faqs[0], {"about": expected.about, "question": expected.question, "answer": expected.answer})


func test_battle_tactic_rules_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "battle_tactics.json").sections[0]
	assert_eq([_pack().battle_tactic_rules[0].name, _pack().battle_tactic_rules[0].text],
			[expected.name, expected.text])


func test_card_number_name_and_text_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "battle_tactics.json").cards[0]
	assert_eq([_card().number, _card().name, _card().text], [int(expected.number), expected.name, expected.text])


func test_card_tactics_keep_file_order() -> void:
	var expected: Array = _json("valid", "battle_tactics.json").cards[0].tactics
	var names: Array = []
	for tactic in _card().tactics:
		names.append(tactic.name)
	assert_eq(names, expected.map(func(t): return t.name))


func test_tactic_kind_condition_and_points_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "battle_tactics.json").cards[0].tactics[1]
	var tactic := _card().tactics[1]
	assert_eq([tactic.kind, tactic.condition, tactic.victory_points],
			[expected.kind, expected.condition, int(expected.victory_points)])


func test_card_faqs_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "battle_tactics.json").cards[0].faqs[0]
	assert_eq(_card().faqs[0].question, expected.question)


func test_battleplan_rules_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "battleplans.json").sections[0]
	assert_eq(_pack().battleplan_rules[0].name, expected.name)


func test_battleplan_identity_comes_from_file() -> void:
	var expected: Dictionary = _json("valid", "battleplans.json").battleplans[0]
	assert_eq([_plan().number, _plan().table, _plan().name],
			[int(expected.number), int(expected.table), expected.name])


func test_battleplan_text_and_twist_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "battleplans.json").battleplans[0]
	assert_eq([_plan().text, _plan().twist], [expected.text, expected.twist])


func test_battleplan_abilities_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "battleplans.json").battleplans[0]
	assert_eq(_plan().abilities.size(), expected.abilities.size())
	assert_eq(_plan().abilities[0].name, expected.abilities[0].name)


func test_battleplan_scoring_comes_from_file() -> void:
	var expected: Array = _json("valid", "battleplans.json").battleplans[0].scoring
	assert_eq(Array(_plan().scoring), expected)


func test_objective_type_and_position_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "battleplans.json").battleplans[0].objectives[0]
	var objective := _plan().objectives[0]
	assert_eq([objective.type, objective.position], [expected.type, Vector2(expected.x, expected.y)])


func test_objective_position_keeps_fractions() -> void:
	var expected: Dictionary = _json("valid", "battleplans.json").battleplans[0].objectives[0]
	assert_almost_eq(_plan().objectives[0].position.x, float(expected.x), 0.0001)


func test_objective_has_no_size() -> void:
	assert_eq(_plan().objectives[0].size, "")


func test_terrain_type_size_and_position_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "battleplans.json").battleplans[0].terrain[0]
	var terrain := _plan().terrain[0]
	assert_eq([terrain.type, terrain.size, terrain.position],
			[expected.type, expected.size, Vector2(expected.x, expected.y)])


func test_attacker_territory_comes_from_file() -> void:
	var expected: Dictionary = _json("valid", "battleplans.json").battleplans[0].attacker_territory[0]
	assert_eq(_plan().attacker_territory[0], Rect2(expected.x, expected.y, expected.width, expected.depth))


func test_defender_territory_keeps_every_rect() -> void:
	var expected: Array = _json("valid", "battleplans.json").battleplans[0].defender_territory
	assert_eq(_plan().defender_territory.size(), expected.size())
	assert_eq(_plan().defender_territory[1],
			Rect2(expected[1].x, expected[1].y, expected[1].width, expected[1].depth))


func test_battleplan_faq_without_about_has_empty_about() -> void:
	var expected: Dictionary = _json("valid", "battleplans.json").battleplans[0].faqs[0]
	assert_eq(_plan().faqs[0], {"about": "", "question": expected.question, "answer": expected.answer})


func test_get_battleplan_finds_by_name() -> void:
	var plan_name: String = _json("valid", "battleplans.json").battleplans[0].name
	assert_eq(_pack().get_battleplan(plan_name).name, plan_name)


func test_get_battleplan_returns_null_for_unknown_name() -> void:
	assert_null(_pack().get_battleplan("Not A Real Battleplan"))


func test_get_battle_tactic_card_finds_by_name() -> void:
	var card_name: String = _json("valid", "battle_tactics.json").cards[0].name
	assert_eq(_pack().get_battle_tactic_card(card_name).name, card_name)


func test_get_battle_tactic_card_returns_null_for_unknown_name() -> void:
	assert_null(_pack().get_battle_tactic_card("Not A Real Card"))


func test_missing_battlepack_file_returns_null() -> void:
	assert_null(_load("no_battlepack"))


func test_missing_battlepack_file_error_names_file() -> void:
	assert_true(_has_error_naming(_errors("no_battlepack"), "battlepack.json", "not found"), str(_errors("no_battlepack")))


func test_missing_battle_tactics_file_returns_null() -> void:
	assert_null(_load("no_battle_tactics"))


func test_missing_battle_tactics_file_error_names_file() -> void:
	assert_true(_has_error_naming(_errors("no_battle_tactics"), "battle_tactics.json", "not found"),
			str(_errors("no_battle_tactics")))


func test_missing_battleplans_file_returns_null() -> void:
	assert_null(_load("no_battleplans"))


func test_missing_battleplans_file_error_names_file() -> void:
	assert_true(_has_error_naming(_errors("no_battleplans"), "battleplans.json", "not found"),
			str(_errors("no_battleplans")))


func test_bad_tactic_kind_returns_null() -> void:
	assert_null(_load("bad_tactic_kind"))


func test_bad_tactic_kind_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("bad_tactic_kind"), "battle_tactics.json", "cards[0].tactics[1].kind"),
			str(_errors("bad_tactic_kind")))


func test_bad_objective_type_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("bad_objective_type"), "battleplans.json", "battleplans[0].objectives[0].type"),
			str(_errors("bad_objective_type")))


func test_bad_terrain_type_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("bad_terrain_type"), "battleplans.json", "battleplans[0].terrain[0].type"),
			str(_errors("bad_terrain_type")))


func test_bad_terrain_size_returns_null() -> void:
	assert_null(_load("bad_terrain_size"))


func test_bad_terrain_size_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("bad_terrain_size"), "battleplans.json", "battleplans[0].terrain[0].size"),
			str(_errors("bad_terrain_size")))


func test_non_numeric_position_returns_null() -> void:
	assert_null(_load("bad_position"))


func test_non_numeric_position_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("bad_position"), "battleplans.json", "battleplans[0].objectives[0].x"),
			str(_errors("bad_position")))


func test_non_string_battleplan_table_entry_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("bad_battleplan_table"), "battlepack.json", "battleplan_tables[1][0]"),
			str(_errors("bad_battleplan_table")))


func test_faq_without_answer_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("bad_faq"), "battlepack.json", "faqs[0].answer"), str(_errors("bad_faq")))
