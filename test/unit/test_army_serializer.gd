extends GutTest
## Unit tests for saving and loading armies (scripts/army/army_serializer.gd).

const Kit := preload("res://test/support/army_kit.gd")


func _army() -> Army:
	var army := Kit.army()
	army.name = "Saved Army"
	army.army_of_renown = "Horde"
	army.formation = "Vanguard"
	army.points_limit = 1500
	army.show_legends = true
	army.override_constraints = true
	var leader := Kit.unit("u1", "hero_a")
	leader.label = "Boss"
	leader.enhancements = {"Heroic Traits": "Brave"}
	var grunt := Kit.unit("u2", "grunt")
	grunt.reinforced = true
	grunt.weapon_options = {"Hammer": 3}
	var renown_unit := Kit.unit("u3", "ror_grunt")
	renown_unit.faction_id = "home"
	army.regiments.append(Kit.regiment("r1", [leader, grunt] as Array[ArmyUnit], "Alpha"))
	army.regiments.append(Kit.ror_regiment("r2", "Band", [renown_unit] as Array[ArmyUnit]))
	army.auxiliary.append(Kit.unit("u4", "plain"))
	army.general_uid = "u1"
	army.tactics = PackedStringArray(["Card A", "Card B"])
	army.spell_lore = "Fire"
	army.prayer_lore = "Hymns"
	army.manifestation_lore = "Universal"
	army.faction_terrain = "terrain"
	return army


## Saves and reloads through JSON text, as a file would.
func _round_trip(army: Army) -> Army:
	var text := JSON.stringify(ArmySerializer.to_dict(army))
	return ArmySerializer.new().from_dict(JSON.parse_string(text))


func _valid() -> Dictionary:
	return ArmySerializer.to_dict(_army())


# Round trip

func test_round_trip_keeps_the_army_settings() -> void:
	var original := _army()
	var loaded := _round_trip(original)
	assert_eq([loaded.faction_id, loaded.name, loaded.army_of_renown, loaded.formation, loaded.points_limit,
			loaded.show_legends, loaded.override_constraints, loaded.general_uid, loaded.faction_terrain],
			[original.faction_id, original.name, original.army_of_renown, original.formation, original.points_limit,
			original.show_legends, original.override_constraints, original.general_uid, original.faction_terrain])


func test_round_trip_keeps_the_id() -> void:
	var original := _army()
	original.id = "abc123"
	assert_eq(_round_trip(original).id, "abc123")


func test_round_trip_of_an_army_without_an_id_has_none() -> void:
	assert_eq(_round_trip(_army()).id, "")


func test_missing_id_loads_without_error() -> void:
	var data := _valid()
	data.erase("id")
	var serializer := ArmySerializer.new()
	assert_not_null(serializer.from_dict(data))
	assert_eq(serializer.errors.size(), 0)


func test_id_of_the_wrong_type_is_reported() -> void:
	var data := _valid()
	data.id = 5
	var serializer := ArmySerializer.new()
	serializer.from_dict(data)
	assert_gt(serializer.errors.size(), 0)


func test_round_trip_keeps_tactics_and_lores() -> void:
	var original := _army()
	var loaded := _round_trip(original)
	assert_eq(loaded.tactics, original.tactics)
	assert_eq([loaded.spell_lore, loaded.prayer_lore, loaded.manifestation_lore],
			[original.spell_lore, original.prayer_lore, original.manifestation_lore])


func test_round_trip_keeps_regiments_in_order() -> void:
	var loaded := _round_trip(_army())
	assert_eq(loaded.regiments.map(func(r: ArmyRegiment) -> String: return r.id), ["r1", "r2"])
	assert_eq(loaded.regiments[0].name, "Alpha")


func test_round_trip_keeps_the_regiment_of_renown_name() -> void:
	var loaded := _round_trip(_army())
	assert_true(loaded.regiments[1].is_regiment_of_renown())
	assert_false(loaded.regiments[0].is_regiment_of_renown())


func test_round_trip_keeps_unit_choices() -> void:
	var original := _army()
	var loaded := _round_trip(original)
	var leader := loaded.find_unit("u1")
	var grunt := loaded.find_unit("u2")
	assert_eq([leader.warscroll_id, leader.label, leader.enhancements], ["hero_a", "Boss", {"Heroic Traits": "Brave"}])
	assert_eq([grunt.reinforced, grunt.weapon_options], [true, {"Hammer": 3}])


func test_round_trip_keeps_a_units_home_faction() -> void:
	assert_eq(_round_trip(_army()).find_unit("u3").faction_id, "home")


func test_round_trip_keeps_auxiliary_units() -> void:
	assert_eq(_round_trip(_army()).auxiliary.map(func(u: ArmyUnit) -> String: return u.uid), ["u4"])


func test_round_trip_weapon_option_counts_are_integers() -> void:
	var count: Variant = _round_trip(_army()).find_unit("u2").weapon_options["Hammer"]
	assert_typeof(count, TYPE_INT)


func test_round_trip_of_a_default_army_has_no_errors() -> void:
	var serializer := ArmySerializer.new()
	assert_not_null(serializer.from_dict(ArmySerializer.to_dict(Kit.army())))
	assert_eq(serializer.errors.size(), 0)


func test_to_dict_omits_empty_unit_fields() -> void:
	var dict := ArmySerializer.to_dict(_army())
	var plain: Dictionary = dict.auxiliary[0]
	for key in ["label", "reinforced", "enhancements", "weapon_options", "faction"]:
		assert_false(plain.has(key), key)


func test_to_dict_survives_json_encoding() -> void:
	assert_not_null(JSON.parse_string(JSON.stringify(_valid())))


# Version

func test_to_dict_records_the_version() -> void:
	assert_eq(_valid().version, ArmySerializer.VERSION)


func test_missing_version_is_rejected_with_an_error() -> void:
	var data := _valid()
	data.erase("version")
	var serializer := ArmySerializer.new()
	assert_null(serializer.from_dict(data))
	assert_gt(serializer.errors.size(), 0)


func test_newer_version_is_rejected() -> void:
	var data := _valid()
	data.version = ArmySerializer.VERSION + 1
	assert_null(ArmySerializer.new().from_dict(data))


func test_version_zero_is_rejected() -> void:
	var data := _valid()
	data.version = 0
	assert_null(ArmySerializer.new().from_dict(data))


func test_non_numeric_version_is_rejected() -> void:
	var data := _valid()
	data.version = "1"
	assert_null(ArmySerializer.new().from_dict(data))


func test_version_error_names_the_field() -> void:
	var data := _valid()
	data.version = 99
	var serializer := ArmySerializer.new()
	serializer.from_dict(data)
	assert_string_contains(serializer.errors[0], "version")


func test_missing_faction_is_rejected() -> void:
	var data := _valid()
	data.erase("faction")
	var serializer := ArmySerializer.new()
	assert_null(serializer.from_dict(data))
	assert_string_contains(serializer.errors[0], "faction")


# Wrong types

func _errors_after(mutate: Callable) -> PackedStringArray:
	var data := _valid()
	mutate.call(data)
	var serializer := ArmySerializer.new()
	serializer.from_dict(data)
	return serializer.errors


func _has_error_naming(errors: PackedStringArray, field: String) -> bool:
	for error in errors:
		if field in error:
			return true
	return false


func test_string_field_of_the_wrong_type_is_reported() -> void:
	var errors := _errors_after(func(d: Dictionary) -> void: d.name = 5)
	assert_true(_has_error_naming(errors, "name"), str(errors))


func test_bool_field_of_the_wrong_type_is_reported() -> void:
	var errors := _errors_after(func(d: Dictionary) -> void: d.show_legends = "yes")
	assert_true(_has_error_naming(errors, "show_legends"), str(errors))


func test_number_field_of_the_wrong_type_is_reported() -> void:
	var errors := _errors_after(func(d: Dictionary) -> void: d.points_limit = "lots")
	assert_true(_has_error_naming(errors, "points_limit"), str(errors))


func test_list_field_of_the_wrong_type_is_reported() -> void:
	var errors := _errors_after(func(d: Dictionary) -> void: d.regiments = "none")
	assert_true(_has_error_naming(errors, "regiments"), str(errors))


func test_wrongly_typed_field_falls_back_to_its_default() -> void:
	var data := _valid()
	data.points_limit = "lots"
	var serializer := ArmySerializer.new()
	assert_eq(serializer.from_dict(data).points_limit, Army.DEFAULT_POINTS_LIMIT)


func test_missing_points_limit_uses_the_default_without_error() -> void:
	var data := _valid()
	data.erase("points_limit")
	var serializer := ArmySerializer.new()
	assert_eq(serializer.from_dict(data).points_limit, Army.DEFAULT_POINTS_LIMIT)
	assert_eq(serializer.errors.size(), 0)


func test_regiment_that_is_not_an_object_is_skipped_and_reported() -> void:
	var data := _valid()
	data.regiments[0] = "oops"
	var serializer := ArmySerializer.new()
	var army := serializer.from_dict(data)
	assert_eq(army.regiments.size(), 1)
	assert_true(_has_error_naming(serializer.errors, "regiments[0]"), str(serializer.errors))


func test_unit_that_is_not_an_object_is_skipped_and_reported() -> void:
	var data := _valid()
	data.regiments[0].units[1] = 7
	var serializer := ArmySerializer.new()
	var army := serializer.from_dict(data)
	assert_null(army.find_unit("u2"))
	assert_gt(serializer.errors.size(), 0)


func test_unit_without_a_warscroll_is_skipped_and_reported() -> void:
	var data := _valid()
	data.regiments[0].units[1].erase("warscroll")
	var serializer := ArmySerializer.new()
	var army := serializer.from_dict(data)
	assert_null(army.find_unit("u2"))
	assert_gt(serializer.errors.size(), 0)


func test_unit_without_a_uid_is_skipped_and_reported() -> void:
	var data := _valid()
	data.auxiliary[0].erase("uid")
	var serializer := ArmySerializer.new()
	assert_eq(serializer.from_dict(data).auxiliary.size(), 0)
	assert_gt(serializer.errors.size(), 0)


func test_tactic_that_is_not_a_string_becomes_an_empty_slot() -> void:
	var data := _valid()
	data.tactics = ["Card A", 3]
	assert_eq(ArmySerializer.new().from_dict(data).tactics, PackedStringArray(["Card A", ""]))


func test_lore_of_the_wrong_type_is_reported() -> void:
	var data := _valid()
	data.lores.spell = 9
	var serializer := ArmySerializer.new()
	assert_eq(serializer.from_dict(data).spell_lore, "")
	assert_true(_has_error_naming(serializer.errors, "spell"), str(serializer.errors))


func test_enhancement_entries_of_the_wrong_type_are_dropped() -> void:
	var data := _valid()
	data.regiments[0].units[0].enhancements = {"Heroic Traits": 4, "Artefacts of Power": "Sword"}
	var army := ArmySerializer.new().from_dict(data)
	assert_eq(army.find_unit("u1").enhancements, {"Artefacts of Power": "Sword"})


func test_weapon_option_entries_of_the_wrong_type_are_dropped() -> void:
	var data := _valid()
	data.regiments[0].units[1].weapon_options = {"Hammer": "lots", "Axe": 2}
	var army := ArmySerializer.new().from_dict(data)
	assert_eq(army.find_unit("u2").weapon_options, {"Axe": 2})


func test_errors_reset_on_each_load() -> void:
	var serializer := ArmySerializer.new()
	var bad := _valid()
	bad.name = 5
	serializer.from_dict(bad)
	serializer.from_dict(_valid())
	assert_eq(serializer.errors.size(), 0)


# Leaderless regiments

func test_round_trip_keeps_a_leaderless_regiment() -> void:
	var original := _army()
	original.regiments[0].leaderless = true
	assert_true(_round_trip(original).regiments[0].leaderless)


func test_leaderless_is_not_written_for_a_regiment_with_a_leader() -> void:
	assert_false(ArmySerializer.to_dict(_army()).regiments[0].has("leaderless"))


func test_leaderless_is_ignored_for_a_regiment_without_units() -> void:
	var data := _valid()
	data.regiments[0].units = []
	data.regiments[0].leaderless = true
	assert_false(ArmySerializer.new().from_dict(data).regiments[0].leaderless)
