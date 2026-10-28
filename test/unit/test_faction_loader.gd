extends GutTest
## Unit tests for building factions from JSON (scripts/data/faction_loader.gd).
##
## Expectations are read from the fixture JSON, so editing a fixture value doesn't break tests.

const FIXTURES := "res://test/fixtures/factions"


func _dir(fixture: String) -> String:
	return FIXTURES.path_join(fixture)


func _json(fixture: String, file_name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_dir(fixture).path_join(file_name)))


func _load(fixture: String) -> Faction:
	return FactionLoader.new().load_faction(_dir(fixture))


## Returns the loader's errors after loading [param fixture].
func _errors(fixture: String) -> PackedStringArray:
	var loader := FactionLoader.new()
	loader.load_faction(_dir(fixture))
	return loader.errors


func _has_error_naming(errors: PackedStringArray, file_name: String, field: String) -> bool:
	for error in errors:
		if error.begins_with(file_name) and field in error:
			return true
	return false


# Valid fixture

func test_valid_fixture_loads() -> void:
	assert_not_null(_load("valid"))


func test_valid_fixture_has_no_errors() -> void:
	assert_eq(_errors("valid").size(), 0, "\n".join(_errors("valid")))


func test_faction_id_and_name_come_from_file() -> void:
	var data := _json("valid", "faction.json")
	var faction := _load("valid")
	assert_eq([faction.id, faction.name], [data.id, data.name])


func test_grand_alliance_is_parsed_from_id() -> void:
	var data := _json("valid", "faction.json")
	assert_eq(_load("valid").grand_alliance, GrandAlliance.from_id(data.grand_alliance))


func test_faction_without_legends_is_not_legends() -> void:
	assert_false(_json("valid", "faction.json").has("legends"), "fixture faction should omit legends")
	assert_false(_load("valid").legends)


func test_faction_legends_comes_from_file() -> void:
	var data := _json("legends", "faction.json")
	assert_true(data.get("legends", false), "fixture faction should be legends")
	assert_eq(_load("legends").legends, data.legends)


func test_legends_faction_has_no_errors() -> void:
	assert_eq(_errors("legends").size(), 0, "\n".join(_errors("legends")))


func test_battle_trait_fields_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "faction.json").battle_traits[0]
	var trait_: Ability = _load("valid").battle_traits[0]
	assert_eq([trait_.name, trait_.category, trait_.timing, trait_.frequency, trait_.declare, trait_.effect],
			[expected.name, expected.category, expected.timing, expected.frequency, expected.declare, expected.effect])


func test_ability_keywords_are_carried_over() -> void:
	var expected: Dictionary = _json("valid", "faction.json").battle_traits[0]
	assert_eq(_load("valid").battle_traits[0].keywords, PackedStringArray(expected.keywords))


func test_ability_summons_come_from_file() -> void:
	var expected: Array = _json("valid", "faction.json").lores[2].entries[0].summons
	assert_eq(_load("valid").lores[2].entries[0].summons, PackedStringArray(expected))


func test_absent_ability_summons_default_to_empty() -> void:
	assert_eq(_load("valid").battle_traits[0].summons, PackedStringArray())


func test_ability_options_are_carried_over() -> void:
	var expected: Dictionary = _json("valid", "faction.json").battle_traits[0]
	var options := _load("valid").battle_traits[0].options
	assert_eq(options.size(), expected.options.size())
	assert_eq([options[0].name, options[0].text], [expected.options[0].name, expected.options[0].text])


func test_battle_formation_points_are_int() -> void:
	var formation: BattleFormation = _load("valid").battle_formations[0]
	assert_typeof(formation.points, TYPE_INT)
	assert_eq(formation.points, int(_json("valid", "faction.json").battle_formations[0].points))


func test_battle_formation_abilities_are_loaded() -> void:
	var expected: Array = _json("valid", "faction.json").battle_formations[0].abilities
	assert_eq(_load("valid").battle_formations[0].abilities.size(), expected.size())


func test_enhancement_table_fields_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "faction.json").enhancement_tables[0]
	var table: EnhancementTable = _load("valid").enhancement_tables[0]
	assert_eq([table.name, table.group, table.entries.size()], [expected.name, expected.group, expected.entries.size()])


func test_enhancement_table_units_come_from_file() -> void:
	var expected: Dictionary = _json("scourge", "faction.json").enhancement_tables[3]
	assert_eq(_load("scourge").enhancement_tables[3].units, PackedStringArray(expected.units))


func test_enhancement_table_without_units_has_none() -> void:
	assert_eq(_load("valid").enhancement_tables[0].units.size(), 0)


## The scourge fixture loaded with [param scourge] as the battlepack's Scourge.
func _load_with_scourge(scourge: String) -> Faction:
	var loader := FactionLoader.new()
	loader.scourge = scourge
	return loader.load_faction(_dir("scourge"))


func _legends_ids(faction: Faction) -> PackedStringArray:
	var ids := PackedStringArray()
	for warscroll in faction.warscrolls:
		if warscroll.legends:
			ids.append(warscroll.id)
	return ids


func test_warscroll_from_another_scourge_is_legends() -> void:
	assert_eq(_legends_ids(_load_with_scourge("Scourge of Aqshy")), PackedStringArray(["scourge_of_ghyran_unit_one"]))


func test_scourge_marker_is_kept_on_a_legends_warscroll() -> void:
	var warscroll := _load_with_scourge("Scourge of Aqshy").get_warscroll("scourge_of_ghyran_unit_one")
	assert_eq(warscroll.source, "Scourge of Ghyran")


func test_changing_the_scourge_changes_which_warscrolls_are_legends() -> void:
	assert_eq(_legends_ids(_load_with_scourge("Scourge of Ghyran")), PackedStringArray(["scourge_of_aqshy_unit_one"]))


func test_without_a_scourge_no_scourge_warscroll_is_legends() -> void:
	assert_eq(_legends_ids(_load("scourge")).size(), 0)


func test_enhancement_table_from_another_scourge_is_legends() -> void:
	var legends := _load_with_scourge("Scourge of Aqshy").enhancement_tables.map(
			func(t: EnhancementTable) -> bool: return t.legends)
	assert_eq(legends, [false, true, false, false])


func test_lore_from_another_scourge_is_legends() -> void:
	var legends := _load_with_scourge("Scourge of Aqshy").lores.map(func(l: Lore) -> bool: return l.legends)
	assert_eq(legends, [false, true, false])


func test_enhancement_points_are_loaded() -> void:
	var expected: Dictionary = _json("valid", "faction.json").enhancement_tables[0].entries[0]
	assert_eq(_load("valid").enhancement_tables[0].entries[0].points, int(expected.points))


func test_lore_fields_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "faction.json").lores[0]
	var lore: Lore = _load("valid").lores[0]
	assert_eq([lore.name, lore.kind, lore.entries.size()], [expected.name, expected.kind, expected.entries.size()])


func test_lore_points_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "faction.json").lores[0]
	assert_eq(_load("valid").lores[0].points, int(expected.points))


func test_absent_lore_points_default_to_zero() -> void:
	var expected: Dictionary = _json("valid", "faction.json").lores[1]
	assert_false(expected.has("points"), "fixture lore should omit points")
	assert_eq(_load("valid").lores[1].points, 0)


func test_lore_source_comes_from_file() -> void:
	var expected: Dictionary = _json("valid", "faction.json").lores[2]
	assert_eq(_load("valid").lores[2].source, expected.source)


func test_absent_lore_source_defaults_to_empty() -> void:
	var expected: Dictionary = _json("valid", "faction.json").lores[0]
	assert_false(expected.has("source"), "fixture lore should omit source")
	assert_eq(_load("valid").lores[0].source, "")


func test_spell_casting_value_comes_from_file() -> void:
	var expected: Dictionary = _json("valid", "faction.json").lores[0].entries[0]
	assert_eq(_load("valid").lores[0].entries[0].casting_value, int(expected.casting_value))


func test_prayer_chanting_value_comes_from_file() -> void:
	var expected: Dictionary = _json("valid", "faction.json").lores[1].entries[0]
	assert_eq(_load("valid").lores[1].entries[0].chanting_value, int(expected.chanting_value))


func test_absent_casting_value_defaults_to_zero() -> void:
	var expected: Dictionary = _json("valid", "faction.json").lores[1].entries[0]
	assert_false(expected.has("casting_value"), "fixture prayer should omit casting_value")
	assert_eq(_load("valid").lores[1].entries[0].casting_value, 0)


func test_absent_chanting_value_defaults_to_zero() -> void:
	var expected: Dictionary = _json("valid", "faction.json").lores[0].entries[0]
	assert_false(expected.has("chanting_value"), "fixture spell should omit chanting_value")
	assert_eq(_load("valid").lores[0].entries[0].chanting_value, 0)


func test_every_warscroll_is_loaded() -> void:
	assert_eq(_load("valid").warscrolls.size(), _json("valid", "warscrolls.json").warscrolls.size())


func test_warscroll_army_of_renown_comes_from_file() -> void:
	var expected: Dictionary = _json("valid", "warscrolls.json").warscrolls[0]
	assert_false(str(expected.get("army_of_renown", "")).is_empty(), "fixture warscroll should name an Army of Renown")
	assert_eq(_load("valid").warscrolls[0].army_of_renown, expected.army_of_renown)


func test_absent_warscroll_army_of_renown_defaults_to_empty() -> void:
	assert_false(_json("valid", "warscrolls.json").warscrolls[1].has("army_of_renown"), "fixture warscroll should omit army_of_renown")
	assert_eq(_load("valid").warscrolls[1].army_of_renown, "")


func test_warscroll_characteristics_are_ints_from_file() -> void:
	var expected: Dictionary = _json("valid", "warscrolls.json").warscrolls[0]
	var unit: Warscroll = _load("valid").warscrolls[0]
	var actual := [unit.health, unit.save, unit.ward, unit.control]
	for value: Variant in actual:
		assert_typeof(value, TYPE_INT)
	assert_eq(actual, [int(expected.health), int(expected.save), int(expected.ward), int(expected.control)])


func test_warscroll_move_is_string_from_file() -> void:
	var expected: Dictionary = _json("valid", "warscrolls.json").warscrolls[0]
	assert_eq(_load("valid").warscrolls[0].move, expected.move)


func test_warscroll_banishment_is_int_from_file() -> void:
	var expected: Dictionary = _json("valid", "warscrolls.json").warscrolls[2]
	var unit: Warscroll = _load("valid").warscrolls[2]
	assert_typeof(unit.banishment, TYPE_INT)
	assert_eq(unit.banishment, int(expected.banishment))


func test_absent_banishment_defaults_to_zero() -> void:
	var expected: Dictionary = _json("valid", "warscrolls.json").warscrolls[0]
	assert_false(expected.has("banishment"), "fixture warscroll should omit banishment")
	assert_eq(_load("valid").warscrolls[0].banishment, 0)


func test_warscroll_battle_profile_comes_from_file() -> void:
	var expected: Dictionary = _json("valid", "warscrolls.json").warscrolls[0]
	var unit: Warscroll = _load("valid").warscrolls[0]
	assert_eq([unit.points, unit.unit_size, unit.base_size, unit.can_reinforce],
			[int(expected.points), int(expected.unit_size), expected.base_size, expected.can_reinforce])


func test_warscroll_regiment_options_are_carried_over() -> void:
	var expected: Dictionary = _json("valid", "warscrolls.json").warscrolls[0]
	assert_eq(_load("valid").warscrolls[0].regiment_options, PackedStringArray(expected.regiment_options))


func test_warscroll_keywords_are_carried_over() -> void:
	var expected: Dictionary = _json("valid", "warscrolls.json").warscrolls[0]
	assert_eq(_load("valid").warscrolls[0].keywords, PackedStringArray(expected.keywords))


func test_weapon_option_fields_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "warscrolls.json").warscrolls[0].weapon_options[0]
	var option: WeaponOption = _load("valid").warscrolls[0].weapon_options[0]
	assert_eq([option.name, option.replaces, option.max, option.per, option.note],
			[expected.name, expected.replaces, int(expected.max), int(expected.per), expected.note])


func test_weapon_option_choice_loads_without_max_or_per() -> void:
	var expected: Dictionary = _json("valid", "warscrolls.json").warscrolls[0].weapon_options[1]
	assert_false(expected.has("max") or expected.has("per"), "fixture choice should omit max and per")
	var option: WeaponOption = _load("valid").warscrolls[0].weapon_options[1]
	assert_eq([option.name, option.replaces, option.choice], [expected.name, expected.replaces, expected.choice])


func test_weapon_option_per_style_is_not_a_choice() -> void:
	assert_false(_json("valid", "warscrolls.json").warscrolls[0].weapon_options[0].has("choice"))
	assert_false(_load("valid").warscrolls[0].weapon_options[0].choice)


func test_every_weapon_option_is_loaded() -> void:
	var expected: Array = _json("valid", "warscrolls.json").warscrolls[0].weapon_options
	assert_eq(_load("valid").warscrolls[0].weapon_options.size(), expected.size())


func test_warscroll_without_weapon_options_has_none() -> void:
	assert_false(_json("valid", "warscrolls.json").warscrolls[1].has("weapon_options"), "fixture should omit weapon_options")
	assert_eq(_load("valid").warscrolls[1].weapon_options.size(), 0)


func test_warscroll_source_and_legends_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "warscrolls.json").warscrolls[1]
	var unit: Warscroll = _load("valid").warscrolls[1]
	assert_eq([unit.source, unit.legends], [expected.source, expected.legends])


func test_missing_optional_warscroll_fields_use_defaults() -> void:
	var unit: Warscroll = _load("valid").warscrolls[1]
	assert_eq([unit.ward, unit.can_reinforce, unit.base_size, unit.ranged_weapons.size()], [0, false, "", 0])


func test_weapon_dice_expressions_stay_strings() -> void:
	var expected: Dictionary = _json("valid", "warscrolls.json").warscrolls[0].ranged_weapons[0]
	var weapon: Weapon = _load("valid").warscrolls[0].ranged_weapons[0]
	assert_typeof(weapon.attacks, TYPE_STRING)
	assert_typeof(weapon.damage, TYPE_STRING)
	assert_eq([weapon.attacks, weapon.damage], [expected.attacks, expected.damage])


func test_weapon_numbers_are_ints_from_file() -> void:
	var expected: Dictionary = _json("valid", "warscrolls.json").warscrolls[0].ranged_weapons[0]
	var weapon: Weapon = _load("valid").warscrolls[0].ranged_weapons[0]
	assert_eq([weapon.range, weapon.hit, weapon.wound, weapon.rend],
			[int(expected.range), int(expected.hit), int(expected.wound), int(expected.rend)])


func test_weapon_abilities_are_carried_over() -> void:
	var expected: Dictionary = _json("valid", "warscrolls.json").warscrolls[0].ranged_weapons[0]
	assert_eq(_load("valid").warscrolls[0].ranged_weapons[0].abilities, PackedStringArray(expected.abilities))


func test_melee_weapon_without_range_is_melee() -> void:
	assert_true(_load("valid").warscrolls[0].melee_weapons[0].is_melee())


func test_ranged_weapon_is_not_melee() -> void:
	assert_false(_load("valid").warscrolls[0].ranged_weapons[0].is_melee())


func test_get_warscroll_finds_by_id() -> void:
	var id: String = _json("valid", "warscrolls.json").warscrolls[1].id
	assert_eq(_load("valid").get_warscroll(id).id, id)


func test_get_warscroll_returns_null_for_unknown_id() -> void:
	assert_null(_load("valid").get_warscroll("not_a_real_warscroll"))


func test_army_of_renown_fields_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0]
	var army: ArmyOfRenown = _load("valid").armies_of_renown[0]
	assert_eq([army.name, army.source, army.text], [expected.name, expected.source, expected.text])


func test_army_of_renown_rules_are_loaded() -> void:
	var expected: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0]
	var army: ArmyOfRenown = _load("valid").armies_of_renown[0]
	assert_eq([army.battle_traits.size(), army.enhancement_tables.size(), army.lores.size()],
			[expected.battle_traits.size(), expected.enhancement_tables.size(), expected.lores.size()])


## Index of the first army in the valid fixture whose "legends" key is [param present].
func _army_index(present: bool) -> int:
	var armies: Array = _json("valid", "armies_of_renown.json").armies_of_renown
	for i in armies.size():
		if armies[i].has("legends") == present:
			return i
	return -1


func test_army_of_renown_legends_comes_from_file() -> void:
	var index := _army_index(true)
	assert_gt(index, -1, "fixture needs an army of renown with legends")
	var expected: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[index]
	assert_eq(_load("valid").armies_of_renown[index].legends, expected.legends)


func test_army_of_renown_without_legends_is_not_legends() -> void:
	var index := _army_index(false)
	assert_gt(index, -1, "fixture needs an army of renown without legends")
	assert_false(_load("valid").armies_of_renown[index].legends)


func test_army_of_renown_roster_entry_fields_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster.entries[0]
	var entry: RosterEntry = _load("valid").armies_of_renown[0].roster.entries[0]
	assert_eq([entry.unit, entry.required, entry.general, entry.gains_keywords],
			[expected.unit, expected.required, expected.general, PackedStringArray(expected.gains_keywords)])


func test_army_of_renown_roster_keyword_entry_fields_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster.entries[1]
	var entry: RosterEntry = _load("valid").armies_of_renown[0].roster.entries[1]
	assert_eq([entry.keywords, entry.not_keywords, entry.per, entry.max],
			[PackedStringArray(expected.keywords), PackedStringArray(expected.not_keywords), PackedStringArray(expected.per), int(expected.max)])


func test_roster_entry_absent_fields_use_defaults() -> void:
	var expected: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster.entries[1]
	assert_false(expected.has("unit") or expected.has("required") or expected.has("general")
			or expected.has("gains_keywords"), "fixture entry should omit these")
	var entry: RosterEntry = _load("valid").armies_of_renown[0].roster.entries[1]
	assert_eq([entry.unit, entry.required, entry.general, entry.gains_keywords.size()], ["", false, false, 0])


func test_army_of_renown_roster_one_of_entry_fields_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster.entries[2]
	var entry: RosterEntry = _load("valid").armies_of_renown[0].roster.entries[2]
	assert_eq([entry.one_of, entry.unit], [PackedStringArray(expected.one_of), ""])


func test_roster_entry_absent_one_of_is_empty() -> void:
	var entry: RosterEntry = _load("valid").armies_of_renown[0].roster.entries[0]
	assert_eq(entry.one_of.size(), 0)


func test_army_of_renown_roster_has_one_entry_per_file_entry() -> void:
	var expected: Array = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster.entries
	assert_eq(_load("valid").armies_of_renown[0].roster.entries.size(), expected.size())


func test_army_of_renown_roster_explicit_false_is_kept() -> void:
	var expected: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster
	assert_false(expected.regiments_of_renown, "fixture should set regiments_of_renown false")
	assert_false(_load("valid").armies_of_renown[0].roster.regiments_of_renown)


func test_army_of_renown_roster_omitted_boolean_defaults_to_true() -> void:
	var expected: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster
	assert_false(expected.has("faction_terrain"), "fixture roster should omit faction_terrain")
	assert_true(_load("valid").armies_of_renown[0].roster.faction_terrain)


func test_army_of_renown_roster_excluded_units_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster
	assert_eq(_load("valid").armies_of_renown[0].roster.excluded_units, PackedStringArray(expected.excluded_units))


func test_army_of_renown_roster_omitted_excluded_units_is_empty() -> void:
	var path := "res://test/fixtures/factions/roster_without_excluded_units/armies_of_renown.json"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_false(data.armies_of_renown[0].roster.has("excluded_units"), "fixture roster should omit excluded_units")
	assert_eq(_load("roster_without_excluded_units").armies_of_renown[0].roster.excluded_units.size(), 0)


func test_army_of_renown_roster_included_unit_factions_come_from_file() -> void:
	var expected: Array = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster.included_units
	var actual := _load("valid").armies_of_renown[0].roster.included_units.map(func(i: RosterInclusion) -> String: return i.faction)
	assert_eq(actual, expected.map(func(i: Dictionary) -> String: return i.faction))


func test_army_of_renown_roster_included_units_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster.included_units[0]
	assert_eq(_load("valid").armies_of_renown[0].roster.included_units[0].units, PackedStringArray(expected.units))


func test_army_of_renown_roster_inclusion_without_units_has_none_listed() -> void:
	var data: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster.included_units[1]
	assert_false(data.has("units"), "fixture inclusion should omit units")
	assert_eq(_load("valid").armies_of_renown[0].roster.included_units[1].units.size(), 0)


func test_army_of_renown_roster_without_included_units_has_none() -> void:
	var data: Dictionary = _json("roster_without_excluded_units", "armies_of_renown.json").armies_of_renown[0].roster
	assert_false(data.has("included_units"), "fixture roster should omit included_units")
	assert_eq(_load("roster_without_excluded_units").armies_of_renown[0].roster.included_units.size(), 0)


func test_roster_inclusion_without_faction_returns_null() -> void:
	assert_null(_load("roster_inclusion_missing_faction"))


func test_roster_inclusion_without_faction_error_names_file_and_field_path() -> void:
	var errors := _errors("roster_inclusion_missing_faction")
	assert_true(_has_error_naming(errors, "armies_of_renown.json", "roster.included_units[0]"), str(errors))


func test_army_of_renown_roster_paired_leaders_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster
	assert_eq(_load("valid").armies_of_renown[0].roster.paired_leaders, PackedStringArray(expected.paired_leaders))


func test_army_of_renown_roster_omitted_paired_leaders_is_empty() -> void:
	var data: Dictionary = _json("roster_without_excluded_units", "armies_of_renown.json").armies_of_renown[0].roster
	assert_false(data.has("paired_leaders"), "fixture roster should omit paired_leaders")
	assert_eq(_load("roster_without_excluded_units").armies_of_renown[0].roster.paired_leaders.size(), 0)


func test_roster_with_one_paired_leader_keyword_is_an_error_naming_the_field() -> void:
	var errors := _errors("roster_paired_leaders_one_keyword")
	assert_true(_has_error_naming(errors, "armies_of_renown.json", "roster.paired_leaders"), str(errors))


func test_roster_with_one_paired_leader_keyword_returns_null() -> void:
	assert_null(_load("roster_paired_leaders_one_keyword"))


func test_army_of_renown_without_roster_has_null_roster() -> void:
	assert_false(_json("valid", "armies_of_renown.json").armies_of_renown[1].has("roster"), "fixture should omit roster")
	assert_null(_load("valid").armies_of_renown[1].roster)


func test_spearhead_fields_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "spearhead.json").spearheads[0]
	var spearhead: Spearhead = _load("valid").spearheads[0]
	assert_eq([spearhead.name, spearhead.text, spearhead.general], [expected.name, expected.text, expected.general])


func test_spearhead_units_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "spearhead.json").spearheads[0].units[0]
	var unit: SpearheadUnit = _load("valid").spearheads[0].units[0]
	assert_eq([unit.count, unit.name, unit.notes], [int(expected.count), expected.name, expected.notes])


func test_spearhead_ability_lists_are_loaded() -> void:
	var expected: Dictionary = _json("valid", "spearhead.json").spearheads[0]
	var spearhead: Spearhead = _load("valid").spearheads[0]
	assert_eq([spearhead.battle_traits.size(), spearhead.regiment_abilities.size(), spearhead.enhancements.size()],
			[expected.battle_traits.size(), expected.regiment_abilities.size(), expected.enhancements.size()])


func test_spearhead_warscrolls_without_points_are_allowed() -> void:
	var expected: Array = _json("valid", "spearhead.json").spearheads[0].warscrolls
	var warscrolls := _load("valid").spearheads[0].warscrolls
	assert_eq(warscrolls.size(), expected.size())
	assert_eq(warscrolls[0].points, 0)


func test_spearhead_get_warscroll_finds_by_name() -> void:
	var spearhead: Spearhead = _load("valid").spearheads[0]
	assert_eq(spearhead.get_warscroll(spearhead.general).name, spearhead.general)


func test_spearhead_get_warscroll_returns_null_for_unknown_name() -> void:
	assert_null(_load("valid").spearheads[0].get_warscroll("Not A Real Unit"))


func test_path_to_glory_sections_come_from_file() -> void:
	var expected: Array = _json("valid", "path_to_glory.json").sections
	var sections := _load("valid").path_to_glory
	assert_eq(sections.size(), expected.size())
	assert_eq([sections[0].name, sections[0].text], [expected[0].name, expected[0].text])


func test_path_to_glory_warscrolls_without_points_are_allowed() -> void:
	var expected: Array = _json("valid", "path_to_glory.json").sections[1].warscrolls
	assert_eq(_load("valid").path_to_glory[1].warscrolls.size(), expected.size())


# Optional files

func test_faction_with_only_faction_file_loads() -> void:
	assert_not_null(_load("minimal"))


func test_faction_with_only_faction_file_has_no_errors() -> void:
	assert_eq(_errors("minimal").size(), 0)


func test_absent_optional_files_leave_lists_empty() -> void:
	var faction := _load("minimal")
	assert_eq([faction.warscrolls.size(), faction.armies_of_renown.size(), faction.spearheads.size(),
			faction.path_to_glory.size()], [0, 0, 0, 0])


# Broken fixtures

func test_missing_faction_file_returns_null() -> void:
	assert_null(_load("no_faction_file"))


func test_missing_faction_file_error_names_file() -> void:
	assert_true(_has_error_naming(_errors("no_faction_file"), "faction.json", "not found"))


func test_missing_directory_returns_null() -> void:
	assert_null(_load("does_not_exist"))


func test_missing_required_field_returns_null() -> void:
	assert_null(_load("missing_name"))


func test_missing_required_field_error_names_file_and_field() -> void:
	assert_true(_has_error_naming(_errors("missing_name"), "faction.json", "name"), str(_errors("missing_name")))


func test_wrong_type_returns_null() -> void:
	assert_null(_load("wrong_type"))


func test_wrong_type_error_names_file_and_field() -> void:
	assert_true(_has_error_naming(_errors("wrong_type"), "faction.json", "name"), str(_errors("wrong_type")))


func test_bad_json_returns_null() -> void:
	assert_null(_load("bad_json"))


func test_bad_json_error_names_file() -> void:
	assert_true(_has_error_naming(_errors("bad_json"), "faction.json", "JSON"), str(_errors("bad_json")))


func test_unknown_grand_alliance_returns_null() -> void:
	assert_null(_load("unknown_alliance"))


func test_unknown_grand_alliance_error_names_file_and_field() -> void:
	assert_true(_has_error_naming(_errors("unknown_alliance"), "faction.json", "grand_alliance"),
			str(_errors("unknown_alliance")))


func test_fractional_number_returns_null() -> void:
	assert_null(_load("fractional_number"))


func test_fractional_number_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("fractional_number"), "faction.json", "battle_formations[0].points"),
			str(_errors("fractional_number")))


func test_fractional_casting_value_returns_null() -> void:
	assert_null(_load("fractional_casting_value"))


func test_fractional_casting_value_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("fractional_casting_value"), "faction.json",
			"lores[0].entries[0].casting_value"), str(_errors("fractional_casting_value")))


func test_wrong_type_chanting_value_returns_null() -> void:
	assert_null(_load("wrong_type_chanting_value"))


func test_wrong_type_chanting_value_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("wrong_type_chanting_value"), "faction.json",
			"lores[0].entries[0].chanting_value"), str(_errors("wrong_type_chanting_value")))


func test_fractional_lore_points_returns_null() -> void:
	assert_null(_load("fractional_lore_points"))


func test_fractional_lore_points_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("fractional_lore_points"), "faction.json", "lores[0].points"),
			str(_errors("fractional_lore_points")))


func test_fractional_banishment_returns_null() -> void:
	assert_null(_load("fractional_banishment"))


func test_fractional_banishment_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("fractional_banishment"), "warscrolls.json", "warscrolls[0].banishment"),
			str(_errors("fractional_banishment")))


func test_wrong_type_banishment_returns_null() -> void:
	assert_null(_load("wrong_type_banishment"))


func test_wrong_type_banishment_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("wrong_type_banishment"), "warscrolls.json", "warscrolls[0].banishment"),
			str(_errors("wrong_type_banishment")))


func test_wrong_type_move_returns_null() -> void:
	assert_null(_load("wrong_type_move"))


func test_wrong_type_move_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("wrong_type_move"), "warscrolls.json", "warscrolls[0].move"),
			str(_errors("wrong_type_move")))


func test_wrong_type_lore_source_returns_null() -> void:
	assert_null(_load("wrong_type_lore_source"))


func test_wrong_type_lore_source_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("wrong_type_lore_source"), "faction.json", "lores[0].source"),
			str(_errors("wrong_type_lore_source")))


func test_wrong_type_faction_legends_returns_null() -> void:
	assert_null(_load("wrong_type_legends"))


func test_wrong_type_faction_legends_error_names_file_and_field() -> void:
	assert_true(_has_error_naming(_errors("wrong_type_legends"), "faction.json", "legends"),
			str(_errors("wrong_type_legends")))


func test_wrong_type_army_legends_returns_null() -> void:
	assert_null(_load("wrong_type_army_legends"))


func test_wrong_type_army_legends_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("wrong_type_army_legends"), "armies_of_renown.json",
			"armies_of_renown[0].legends"), str(_errors("wrong_type_army_legends")))


func test_main_warscroll_without_points_returns_null() -> void:
	assert_null(_load("bad_warscroll"))


func test_main_warscroll_without_points_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("bad_warscroll"), "warscrolls.json", "warscrolls[0].points"),
			str(_errors("bad_warscroll")))


func test_weapon_option_without_replaces_returns_null() -> void:
	assert_null(_load("weapon_option_missing_replaces"))


func test_weapon_option_without_replaces_error_names_file_and_field_path() -> void:
	var errors := _errors("weapon_option_missing_replaces")
	assert_true(_has_error_naming(errors, "warscrolls.json", "warscrolls[0].weapon_options[0].replaces"), str(errors))


func test_weapon_option_with_zero_per_returns_null() -> void:
	assert_null(_load("weapon_option_zero_per"))


func test_weapon_option_with_zero_per_error_names_file_and_field_path() -> void:
	var errors := _errors("weapon_option_zero_per")
	assert_true(_has_error_naming(errors, "warscrolls.json", "warscrolls[0].weapon_options[0].per"), str(errors))


func test_roster_entry_without_unit_or_keywords_returns_null() -> void:
	assert_null(_load("roster_entry_empty"))


func test_roster_entry_without_unit_or_keywords_error_names_file_and_field_path() -> void:
	var errors := _errors("roster_entry_empty")
	assert_true(_has_error_naming(errors, "armies_of_renown.json", "armies_of_renown[0].roster.entries[0]"), str(errors))


func test_roster_entry_with_unit_and_one_of_returns_null() -> void:
	assert_null(_load("roster_entry_unit_and_one_of"))


func test_roster_entry_with_unit_and_one_of_error_names_file_and_field_path() -> void:
	var errors := _errors("roster_entry_unit_and_one_of")
	assert_true(_has_error_naming(errors, "armies_of_renown.json", "armies_of_renown[0].roster.entries[0]"), str(errors))


func test_wrong_type_roster_faction_terrain_returns_null() -> void:
	assert_null(_load("wrong_type_roster_faction_terrain"))


func test_wrong_type_roster_faction_terrain_error_names_file_and_field_path() -> void:
	var errors := _errors("wrong_type_roster_faction_terrain")
	assert_true(_has_error_naming(errors, "armies_of_renown.json", "armies_of_renown[0].roster.faction_terrain"), str(errors))


func test_errors_reset_between_loads() -> void:
	var loader := FactionLoader.new()
	loader.load_faction(_dir("missing_name"))
	loader.load_faction(_dir("valid"))
	assert_eq(loader.errors.size(), 0)


func test_loader_can_load_valid_faction_after_a_failure() -> void:
	var loader := FactionLoader.new()
	loader.load_faction(_dir("missing_name"))
	assert_not_null(loader.load_faction(_dir("valid")))


func test_loader_does_not_push_errors_itself() -> void:
	_load("missing_name")
	assert_push_error_count(0)


# Shared warscrolls and Armies of Renown

const SHARED_FIXTURES := "res://test/fixtures/shared"


func _shared_json(file_name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SHARED_FIXTURES.path_join(file_name)))


func _shared_loader(shared_dir := SHARED_FIXTURES) -> FactionLoader:
	var loader := FactionLoader.new()
	loader.shared_dir = shared_dir
	return loader


func _load_shared(fixture: String) -> Faction:
	return _shared_loader().load_faction(_dir(fixture))


func _shared_errors(fixture: String, shared_dir := SHARED_FIXTURES) -> PackedStringArray:
	var loader := _shared_loader(shared_dir)
	loader.load_faction(_dir(fixture))
	return loader.errors


func _ability_named(abilities: Array, ability_name: String) -> Variant:
	for ability: Variant in abilities:
		if ability.name == ability_name:
			return ability
	return null


func _ability_names(abilities: Array) -> Array:
	return abilities.map(func(a: Variant) -> String: return a.name)


func test_shared_reference_fixture_has_no_errors() -> void:
	var errors := _shared_errors("shared_refs")
	assert_eq(errors.size(), 0, "\n".join(errors))


func test_shared_reference_takes_id_and_name_from_shared_entry() -> void:
	var expected: Dictionary = _shared_json("warscrolls.json").warscrolls[0]
	var warscroll: Warscroll = _load_shared("shared_refs").warscrolls[0]
	assert_eq([warscroll.id, warscroll.name], [expected.id, expected.name])


func test_shared_reference_takes_characteristics_from_shared_entry() -> void:
	var expected: Dictionary = _shared_json("warscrolls.json").warscrolls[0]
	var warscroll: Warscroll = _load_shared("shared_refs").warscrolls[0]
	assert_eq([warscroll.move, warscroll.health, warscroll.save, warscroll.ward, warscroll.control],
			[expected.move, int(expected.health), int(expected.save), int(expected.ward), int(expected.control)])


func test_shared_reference_takes_weapons_from_shared_entry() -> void:
	var expected: Array = _shared_json("warscrolls.json").warscrolls[0].melee_weapons
	var weapons := _load_shared("shared_refs").warscrolls[0].melee_weapons
	assert_eq(weapons.map(func(w: Weapon) -> String: return w.name), expected.map(func(w: Dictionary) -> String: return w.name))


func test_shared_reference_keeps_shared_fields_it_does_not_set() -> void:
	var reference: Dictionary = _json("shared_refs", "warscrolls.json").warscrolls[0]
	assert_false(reference.has("unit_size"), "fixture reference should not set unit_size")
	var expected: Dictionary = _shared_json("warscrolls.json").warscrolls[0]
	assert_eq(_load_shared("shared_refs").warscrolls[0].unit_size, int(expected.unit_size))


func test_shared_reference_points_replace_shared_points() -> void:
	var reference: Dictionary = _json("shared_refs", "warscrolls.json").warscrolls[0]
	assert_eq(_load_shared("shared_refs").warscrolls[0].points, int(reference.points))


func test_shared_reference_regiment_options_come_from_reference() -> void:
	var reference: Dictionary = _json("shared_refs", "warscrolls.json").warscrolls[0]
	assert_eq(_load_shared("shared_refs").warscrolls[0].regiment_options, PackedStringArray(reference.regiment_options))


func test_shared_reference_keywords_follow_shared_keywords() -> void:
	var shared: Array = _shared_json("warscrolls.json").warscrolls[0].keywords
	var keywords := _load_shared("shared_refs").warscrolls[0].keywords
	assert_eq(Array(keywords).slice(0, shared.size()), shared)


func test_shared_reference_adds_its_own_keywords() -> void:
	var shared: Array = _shared_json("warscrolls.json").warscrolls[0].keywords
	var own: Array = _json("shared_refs", "warscrolls.json").warscrolls[0].keywords.filter(
			func(k: String) -> bool: return not k in shared)
	assert_false(own.is_empty(), "fixture reference should add a keyword")
	var keywords := _load_shared("shared_refs").warscrolls[0].keywords
	for keyword: String in own:
		assert_has(keywords, keyword)


func test_shared_reference_does_not_duplicate_keywords() -> void:
	var keywords := Array(_load_shared("shared_refs").warscrolls[0].keywords)
	for keyword: String in keywords:
		assert_eq(keywords.count(keyword), 1, keyword)


func test_shared_reference_ability_replaces_same_named_shared_ability() -> void:
	var own: Dictionary = _json("shared_refs", "warscrolls.json").warscrolls[0].abilities[0]
	var ability: Ability = _ability_named(_load_shared("shared_refs").warscrolls[0].abilities, own.name)
	assert_eq(ability.effect, own.effect)


func test_shared_reference_replaced_ability_keeps_its_position() -> void:
	var shared: Array = _shared_json("warscrolls.json").warscrolls[0].abilities
	var own_name: String = _json("shared_refs", "warscrolls.json").warscrolls[0].abilities[0].name
	var abilities := _load_shared("shared_refs").warscrolls[0].abilities
	assert_eq(_ability_names(abilities).slice(0, shared.size()), shared.map(func(a: Dictionary) -> String: return a.name))
	assert_ne(_ability_names(shared).find(own_name), -1, "fixture should replace a shared ability")


func test_shared_reference_new_ability_is_appended() -> void:
	var own: Dictionary = _json("shared_refs", "warscrolls.json").warscrolls[0].abilities[1]
	var abilities := _load_shared("shared_refs").warscrolls[0].abilities
	assert_eq([abilities[-1].name, abilities[-1].effect], [own.name, own.effect])


func test_shared_reference_keeps_shared_abilities_it_does_not_replace() -> void:
	var shared: Dictionary = _shared_json("warscrolls.json").warscrolls[0].abilities[0]
	var ability: Ability = _ability_named(_load_shared("shared_refs").warscrolls[0].abilities, shared.name)
	assert_eq(ability.effect, shared.effect)


func test_shared_reference_does_not_leak_into_other_references() -> void:
	var expected: Dictionary = _shared_json("warscrolls.json").warscrolls[0]
	var second: Warscroll = _load_shared("shared_twice").warscrolls[1]
	var first_ability: Ability = _ability_named(second.abilities, expected.abilities[0].name)
	assert_eq([second.keywords, first_ability.effect], [PackedStringArray(expected.keywords), expected.abilities[0].effect])


func test_non_reference_warscroll_loads_unchanged() -> void:
	var expected: Dictionary = _json("shared_refs", "warscrolls.json").warscrolls[1]
	var warscroll: Warscroll = _load_shared("shared_refs").warscrolls[1]
	assert_eq([warscroll.id, warscroll.name, warscroll.points, warscroll.keywords],
			[expected.id, expected.name, int(expected.points), PackedStringArray(expected.keywords)])


func test_shared_army_of_renown_reference_resolves() -> void:
	var expected: Dictionary = _shared_json("armies_of_renown.json").armies_of_renown[0]
	var army: ArmyOfRenown = _load_shared("shared_refs").armies_of_renown[0]
	assert_eq([army.name, army.source, army.legends, army.text], [expected.name, expected.source, expected.legends, expected.text])


func test_shared_army_of_renown_reference_has_shared_battle_traits() -> void:
	var expected: Array = _shared_json("armies_of_renown.json").armies_of_renown[0].battle_traits
	var army: ArmyOfRenown = _load_shared("shared_refs").armies_of_renown[0]
	assert_eq(_ability_names(army.battle_traits), expected.map(func(a: Dictionary) -> String: return a.name))


func test_non_reference_army_of_renown_loads_unchanged() -> void:
	var expected: Dictionary = _json("shared_refs", "armies_of_renown.json").armies_of_renown[1]
	var army: ArmyOfRenown = _load_shared("shared_refs").armies_of_renown[1]
	assert_eq([army.name, army.text], [expected.name, expected.text])


func test_unknown_shared_warscroll_returns_null() -> void:
	assert_null(_load_shared("shared_unknown_id"))


func test_unknown_shared_warscroll_error_names_file_and_shared_field() -> void:
	var errors := _shared_errors("shared_unknown_id")
	assert_true(_has_error_naming(errors, "warscrolls.json", "warscrolls[0].shared"), str(errors))


func test_unknown_shared_warscroll_error_mentions_shared() -> void:
	var errors := _shared_errors("shared_unknown_id")
	assert_true(Array(errors).any(func(e: String) -> bool: return "names no entry in shared" in e), str(errors))


func test_unknown_shared_warscroll_reports_only_the_reference() -> void:
	assert_eq(_shared_errors("shared_unknown_id").size(), 1)


func test_unknown_shared_army_of_renown_returns_null() -> void:
	assert_null(_load_shared("shared_unknown_army"))


func test_unknown_shared_army_of_renown_error_names_file_and_shared_field() -> void:
	var errors := _shared_errors("shared_unknown_army")
	assert_true(_has_error_naming(errors, "armies_of_renown.json", "armies_of_renown[0].shared"), str(errors))


func test_missing_shared_file_returns_null_when_referenced() -> void:
	assert_null(_shared_loader(_dir("no_such_shared_dir")).load_faction(_dir("shared_refs")))


func test_missing_shared_file_error_says_file_not_found() -> void:
	var errors := _shared_errors("shared_refs", _dir("no_such_shared_dir"))
	assert_true(_has_error_naming(errors, "shared/warscrolls.json", "file not found"), str(errors))


func test_faction_without_references_needs_no_shared_dir() -> void:
	assert_not_null(_shared_loader(_dir("no_such_shared_dir")).load_faction(_dir("valid")))


func test_shared_entries_are_read_again_for_each_load() -> void:
	var loader := _shared_loader()
	loader.load_faction(_dir("shared_refs"))
	loader.shared_dir = _dir("no_such_shared_dir")
	assert_null(loader.load_faction(_dir("shared_refs")))


# Ability used_by and command_points

func test_ability_used_by_comes_from_file() -> void:
	var expected: Dictionary = _json("ability_extras", "faction.json").battle_traits[0]
	assert_eq(_load("ability_extras").battle_traits[0].used_by, expected.used_by)


func test_ability_command_points_come_from_file() -> void:
	var expected: Dictionary = _json("ability_extras", "faction.json").battle_traits[0]
	var ability: Ability = _load("ability_extras").battle_traits[0]
	assert_typeof(ability.command_points, TYPE_INT)
	assert_eq(ability.command_points, int(expected.command_points))


func test_absent_used_by_and_command_points_default_to_empty_and_zero() -> void:
	var expected: Dictionary = _json("valid", "faction.json").battle_traits[0]
	assert_false(expected.has("used_by") or expected.has("command_points"), "fixture trait should omit both")
	var trait_: Ability = _load("valid").battle_traits[0]
	assert_eq([trait_.used_by, trait_.command_points], ["", 0])


func test_wrong_type_used_by_returns_null() -> void:
	assert_null(_load("wrong_type_used_by"))


func test_wrong_type_used_by_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("wrong_type_used_by"), "faction.json", "battle_traits[0].used_by"),
			str(_errors("wrong_type_used_by")))


func test_fractional_command_points_returns_null() -> void:
	assert_null(_load("fractional_command_points"))


func test_fractional_command_points_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("fractional_command_points"), "faction.json",
			"battle_traits[0].command_points"), str(_errors("fractional_command_points")))


# Ability type

func test_ability_type_comes_from_file() -> void:
	var expected: Dictionary = _json("ability_type", "faction.json").battle_traits[0]
	assert_eq(_load("ability_type").battle_traits[0].type, expected.type)


func test_ability_type_from_file_is_a_known_type() -> void:
	var expected: Dictionary = _json("ability_type", "faction.json").battle_traits[0]
	assert_has(Ability.TYPES, expected.type)
	assert_eq(_errors("ability_type").size(), 0, "\n".join(_errors("ability_type")))


func test_absent_ability_type_defaults_to_empty() -> void:
	assert_false(_json("valid", "faction.json").battle_traits[0].has("type"), "fixture trait should omit type")
	assert_eq(_load("valid").battle_traits[0].type, "")


func test_invalid_ability_type_returns_null() -> void:
	assert_null(_load("invalid_ability_type"))


func test_invalid_ability_type_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("invalid_ability_type"), "faction.json", "battle_traits[0].type"),
			str(_errors("invalid_ability_type")))


func test_invalid_ability_type_error_lists_the_allowed_types() -> void:
	var errors := "\n".join(_errors("invalid_ability_type"))
	for allowed in Ability.TYPES:
		assert_string_contains(errors, allowed)


func test_wrong_type_ability_type_returns_null() -> void:
	assert_null(_load("wrong_type_ability_type"))


func test_wrong_type_ability_type_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("wrong_type_ability_type"), "faction.json", "battle_traits[0].type"),
			str(_errors("wrong_type_ability_type")))


# Ability colour

func test_ability_colour_comes_from_file() -> void:
	var expected: Dictionary = _json("ability_colour", "faction.json").battle_traits[0]
	assert_eq(_load("ability_colour").battle_traits[0].colour, expected.colour)


func test_ability_colour_from_file_is_a_known_colour() -> void:
	var expected: Dictionary = _json("ability_colour", "faction.json").battle_traits[0]
	assert_has(Ability.COLOURS, expected.colour)
	assert_eq(_errors("ability_colour").size(), 0, "\n".join(_errors("ability_colour")))


func test_absent_ability_colour_defaults_to_empty() -> void:
	assert_false(_json("valid", "faction.json").battle_traits[0].has("colour"), "fixture trait should omit colour")
	assert_eq(_load("valid").battle_traits[0].colour, "")


func test_invalid_ability_colour_returns_null() -> void:
	assert_null(_load("ability_invalid_colour"))


func test_invalid_ability_colour_error_names_file_and_field_path() -> void:
	assert_true(_has_error_naming(_errors("ability_invalid_colour"), "faction.json", "battle_traits[0].colour"),
			str(_errors("ability_invalid_colour")))


func test_invalid_ability_colour_error_lists_the_allowed_colours() -> void:
	var errors := "\n".join(_errors("ability_invalid_colour"))
	for allowed in Ability.COLOURS:
		assert_string_contains(errors, allowed)


# Regiments of Renown

func _regiments(fixture := "valid") -> Array:
	return _json(fixture, "regiments_of_renown.json").regiments_of_renown


func test_regiment_of_renown_fields_come_from_file() -> void:
	var expected: Dictionary = _regiments()[0]
	var regiment: RegimentOfRenown = _load("valid").regiments_of_renown[0]
	assert_eq([regiment.name, regiment.source, regiment.text, regiment.points],
			[expected.name, expected.source, expected.text, int(expected.points)])


func test_regiment_of_renown_has_one_entry_per_file_entry() -> void:
	assert_eq(_load("valid").regiments_of_renown.size(), _regiments().size())


func test_regiment_of_renown_legends_comes_from_file() -> void:
	var index := _regiments().find_custom(func(r: Dictionary) -> bool: return r.has("legends"))
	assert_gt(index, -1, "fixture needs a regiment with legends")
	assert_eq(_load("valid").regiments_of_renown[index].legends, _regiments()[index].legends)


func test_regiment_of_renown_without_legends_is_not_legends() -> void:
	var index := _regiments().find_custom(func(r: Dictionary) -> bool: return not r.has("legends"))
	assert_gt(index, -1, "fixture needs a regiment without legends")
	assert_false(_load("valid").regiments_of_renown[index].legends)


func test_regiment_unit_fields_come_from_file() -> void:
	var expected: Dictionary = _regiments()[0].units[0]
	var unit: RegimentUnit = _load("valid").regiments_of_renown[0].units[0]
	assert_eq([unit.count, unit.name, unit.faction_id, unit.warscroll_id, unit.notes],
			[int(expected.count), expected.name, expected.faction, expected.warscroll, expected.notes])


func test_regiment_unit_absent_faction_and_notes_default_to_empty() -> void:
	var expected: Dictionary = _regiments()[0].units[1]
	assert_false(expected.has("faction") or expected.has("notes"), "fixture unit should omit both")
	var unit: RegimentUnit = _load("valid").regiments_of_renown[0].units[1]
	assert_eq([unit.faction_id, unit.notes], ["", ""])


func test_regiment_has_one_unit_per_file_entry() -> void:
	assert_eq(_load("valid").regiments_of_renown[0].units.size(), _regiments()[0].units.size())


func test_regiment_abilities_are_loaded() -> void:
	var expected: Dictionary = _regiments()[0].abilities[0]
	var abilities := _load("valid").regiments_of_renown[0].abilities
	assert_eq([abilities[0].name, abilities[0].effect], [expected.name, expected.effect])


func test_regiment_own_warscrolls_are_loaded() -> void:
	var expected: Dictionary = _regiments()[0].warscrolls[0]
	var warscroll: Warscroll = _load("valid").regiments_of_renown[0].warscrolls[0]
	assert_eq([warscroll.id, warscroll.name, warscroll.health], [expected.id, expected.name, int(expected.health)])


func test_valid_fixture_with_regiments_has_no_errors() -> void:
	assert_eq(_errors("valid").size(), 0, "\n".join(_errors("valid")))


func test_regiment_get_warscroll_finds_by_id() -> void:
	var regiment: RegimentOfRenown = _load("valid").regiments_of_renown[0]
	var id: String = _regiments()[0].warscrolls[0].id
	assert_eq(regiment.get_warscroll(id).id, id)


func test_regiment_get_warscroll_returns_null_for_unknown_id() -> void:
	assert_null(_load("valid").regiments_of_renown[0].get_warscroll("not_a_real_warscroll"))


func test_regiment_without_warscrolls_has_none() -> void:
	assert_eq(_load("valid").regiments_of_renown[1].warscrolls.size(), 0)


func test_faction_without_regiments_file_has_no_regiments() -> void:
	assert_eq(_load("minimal").regiments_of_renown.size(), 0)


func test_shared_regiment_of_renown_reference_resolves() -> void:
	var expected: Dictionary = _shared_json("regiments_of_renown.json").regiments_of_renown[0]
	var regiment: RegimentOfRenown = _load_shared("shared_refs").regiments_of_renown[0]
	assert_eq([regiment.name, regiment.source, regiment.legends, regiment.points, regiment.text],
			[expected.name, expected.source, expected.legends, int(expected.points), expected.text])


func test_shared_regiment_of_renown_reference_has_shared_units_and_abilities() -> void:
	var expected: Dictionary = _shared_json("regiments_of_renown.json").regiments_of_renown[0]
	var regiment: RegimentOfRenown = _load_shared("shared_refs").regiments_of_renown[0]
	assert_eq([regiment.units[0].warscroll_id, _ability_names(regiment.abilities)],
			[expected.units[0].warscroll, expected.abilities.map(func(a: Dictionary) -> String: return a.name)])


func test_inline_regiment_of_renown_loads_next_to_shared_one() -> void:
	var expected: Dictionary = _regiments("shared_refs")[1]
	var regiment: RegimentOfRenown = _load_shared("shared_refs").regiments_of_renown[1]
	assert_eq([regiment.name, regiment.points], [expected.name, int(expected.points)])


func test_unknown_shared_regiment_returns_null() -> void:
	assert_null(_load_shared("shared_unknown_regiment"))


func test_unknown_shared_regiment_error_names_file_and_shared_field() -> void:
	var errors := _shared_errors("shared_unknown_regiment")
	assert_true(_has_error_naming(errors, "regiments_of_renown.json", "regiments_of_renown[0].shared"), str(errors))


func test_regiment_without_points_returns_null() -> void:
	assert_null(_load("regiment_missing_points"))


func test_regiment_without_points_error_names_file_and_field_path() -> void:
	var errors := _errors("regiment_missing_points")
	assert_true(_has_error_naming(errors, "regiments_of_renown.json", "regiments_of_renown[0].points"), str(errors))


func test_wrong_type_regiment_points_returns_null() -> void:
	assert_null(_load("wrong_type_regiment_points"))


func test_wrong_type_regiment_points_error_names_file_and_field_path() -> void:
	var errors := _errors("wrong_type_regiment_points")
	assert_true(_has_error_naming(errors, "regiments_of_renown.json", "regiments_of_renown[0].points"), str(errors))


func test_wrong_type_regiment_legends_error_names_file_and_field_path() -> void:
	var errors := _errors("wrong_type_regiment_legends")
	assert_true(_has_error_naming(errors, "regiments_of_renown.json", "regiments_of_renown[0].legends"), str(errors))


func test_wrong_type_regiment_units_error_names_file_and_field_path() -> void:
	var errors := _errors("wrong_type_regiment_units")
	assert_true(_has_error_naming(errors, "regiments_of_renown.json", "regiments_of_renown[0].units"), str(errors))


func test_regiment_unit_without_warscroll_returns_null() -> void:
	assert_null(_load("regiment_unit_missing_warscroll"))


func test_regiment_unit_without_warscroll_error_names_file_and_field_path() -> void:
	var errors := _errors("regiment_unit_missing_warscroll")
	assert_true(_has_error_naming(errors, "regiments_of_renown.json", "regiments_of_renown[0].units[0].warscroll"),
			str(errors))


func test_wrong_type_regiment_unit_count_error_names_file_and_field_path() -> void:
	var errors := _errors("wrong_type_regiment_unit_count")
	assert_true(_has_error_naming(errors, "regiments_of_renown.json", "regiments_of_renown[0].units[0].count"),
			str(errors))


func test_army_of_renown_roster_omitted_manifestations_defaults_to_true() -> void:
	var expected: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster
	assert_false(expected.has("manifestations"), "fixture roster should omit manifestations")
	assert_true(_load("valid").armies_of_renown[0].roster.manifestations)


func test_army_of_renown_roster_regiment_option_leaders_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster.regiment_options[0]
	assert_eq(_load("valid").armies_of_renown[0].roster.regiment_options[0].leaders, PackedStringArray(expected.leaders))


func test_army_of_renown_roster_regiment_options_come_from_file() -> void:
	var expected: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster.regiment_options[0]
	assert_eq(_load("valid").armies_of_renown[0].roster.regiment_options[0].options, PackedStringArray(expected.options))


func test_army_of_renown_roster_regiment_options_without_leaders_have_none_listed() -> void:
	var data: Dictionary = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster.regiment_options[1]
	assert_false(data.has("leaders"), "fixture entry should omit leaders")
	assert_eq(_load("valid").armies_of_renown[0].roster.regiment_options[1].leaders.size(), 0)


func test_army_of_renown_roster_regiment_options_are_all_read() -> void:
	var expected: Array = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster.regiment_options
	assert_eq(_load("valid").armies_of_renown[0].roster.regiment_options.size(), expected.size())


func test_army_of_renown_roster_without_regiment_options_has_none() -> void:
	var data: Dictionary = _json("roster_without_excluded_units", "armies_of_renown.json").armies_of_renown[0].roster
	assert_false(data.has("regiment_options"), "fixture roster should omit regiment_options")
	assert_eq(_load("roster_without_excluded_units").armies_of_renown[0].roster.regiment_options.size(), 0)


func test_roster_regiment_options_without_options_returns_null() -> void:
	assert_null(_load("roster_regiment_options_empty"))


func test_roster_regiment_options_without_options_error_names_file_and_field_path() -> void:
	var errors := _errors("roster_regiment_options_empty")
	assert_true(_has_error_naming(errors, "armies_of_renown.json", "roster.regiment_options[0].options"), str(errors))


# Non-Hero general

func test_army_of_renown_roster_non_hero_general_unit_is_read() -> void:
	var expected: String = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster.non_hero_general.unit
	assert_eq(_load("valid").armies_of_renown[0].roster.non_hero_general, expected)


func test_army_of_renown_roster_non_hero_general_unless_is_read() -> void:
	var expected: Array = _json("valid", "armies_of_renown.json").armies_of_renown[0].roster.non_hero_general.unless
	assert_eq(_load("valid").armies_of_renown[0].roster.non_hero_general_unless, PackedStringArray(expected))


func test_army_of_renown_roster_without_non_hero_general_has_none() -> void:
	var data: Dictionary = _json("roster_without_excluded_units", "armies_of_renown.json").armies_of_renown[0].roster
	assert_false(data.has("non_hero_general"), "fixture roster should omit non_hero_general")
	assert_true(_load("roster_without_excluded_units").armies_of_renown[0].roster.non_hero_general.is_empty())


func test_army_of_renown_roster_without_non_hero_general_has_no_blocking_units() -> void:
	assert_eq(_load("roster_without_excluded_units").armies_of_renown[0].roster.non_hero_general_unless.size(), 0)


func test_roster_non_hero_general_without_unit_returns_null() -> void:
	assert_null(_load("roster_non_hero_general_no_unit"))


func test_roster_non_hero_general_without_unit_error_names_file_and_field_path() -> void:
	var errors := _errors("roster_non_hero_general_no_unit")
	assert_true(_has_error_naming(errors, "armies_of_renown.json", "roster.non_hero_general.unit"), str(errors))
	assert_true("is required" in " ".join(errors), str(errors))
