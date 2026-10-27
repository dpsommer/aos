extends GutTest
## Unit tests for looking up the rules an army refers to (scripts/army/army_catalog.gd).

const Kit := preload("res://test/support/army_kit.gd")


func _faction() -> Faction:
	var unit := Kit.warscroll("unit")
	var manifestation := Kit.warscroll("manifest", PackedStringArray(["MANIFESTATION"]))
	var terrain := Kit.warscroll("terrain", PackedStringArray(["FACTION TERRAIN"]))
	var faction := Kit.faction([unit, manifestation, terrain, Kit.hero("hero")] as Array[Warscroll])
	faction.enhancement_tables = [Kit.table("Heroic Traits", [Kit.ability("Brave", 10)] as Array[Ability]),
			Kit.table("Artefacts of Power", [Kit.ability("Sword", 20)] as Array[Ability])] as Array[EnhancementTable]
	faction.lores = [Kit.lore("Fire", "spell"), Kit.lore("Hymns", "prayer"), Kit.lore("Own Manifest", "manifestation")] as Array[Lore]
	faction.battle_formations = [Kit.formation("Vanguard", 0)] as Array[BattleFormation]
	faction.regiments_of_renown = [Kit.regiment_of_renown("Band", 150, [] as Array[RegimentUnit])] as Array[RegimentOfRenown]
	var renown := Kit.army_of_renown("Horde")
	renown.enhancement_tables = [Kit.table("Heroic Traits", [Kit.ability("Horde Trait", 5)] as Array[Ability])] as Array[EnhancementTable]
	renown.lores = [Kit.lore("Horde Spell", "spell")] as Array[Lore]
	faction.armies_of_renown = [renown] as Array[ArmyOfRenown]
	return faction


func _catalog() -> ArmyCatalog:
	var universal: Array[Lore] = [Kit.lore("Universal", "manifestation")]
	return Kit.catalog(_faction(), Kit.core(PackedStringArray(["Card A"]), universal))


func _horde_army() -> Army:
	var army := Kit.army()
	army.army_of_renown = "Horde"
	return army


# Army of Renown

func test_army_of_renown_is_found_by_name() -> void:
	assert_eq(_catalog().army_of_renown("Horde").name, "Horde")


func test_unknown_army_of_renown_is_null() -> void:
	assert_null(_catalog().army_of_renown("Nope"))


func test_roster_is_null_for_the_faction_own_rules() -> void:
	assert_null(_catalog().roster(Kit.army()))


func test_roster_comes_from_the_army_of_renown() -> void:
	assert_not_null(_catalog().roster(_horde_army()))


# Enhancements

func test_faction_army_uses_the_faction_enhancement_tables() -> void:
	assert_eq(_catalog().enhancement_types(Kit.army()), PackedStringArray(["Heroic Traits", "Artefacts of Power"]))


func test_army_of_renown_uses_its_own_enhancement_tables() -> void:
	assert_eq(_catalog().enhancement_types(_horde_army()), PackedStringArray(["Heroic Traits"]))


func test_enhancement_types_are_listed_once() -> void:
	var faction := _faction()
	faction.enhancement_tables.append(Kit.table("Heroic Traits", [] as Array[Ability]))
	assert_eq(Kit.catalog(faction).enhancement_types(Kit.army()).count("Heroic Traits"), 1)


func test_enhancement_is_found_by_type_and_name() -> void:
	assert_not_null(_catalog().enhancement(Kit.army(), "Artefacts of Power", "Sword"))


func test_enhancement_under_the_wrong_type_is_null() -> void:
	assert_null(_catalog().enhancement(Kit.army(), "Heroic Traits", "Sword"))


func test_enhancement_table_holding_an_enhancement_is_found() -> void:
	assert_eq(_catalog().enhancement_table(Kit.army(), "Artefacts of Power", "Sword").name, "Artefacts of Power")


func test_enhancement_table_is_null_for_an_unknown_enhancement() -> void:
	assert_null(_catalog().enhancement_table(Kit.army(), "Artefacts of Power", "Nope"))


func _units_table(units: PackedStringArray) -> EnhancementTable:
	var table := Kit.table("Great Works", [Kit.ability("Engine")] as Array[Ability])
	table.units = units
	return table


func test_listed_unit_can_take_a_table_for_certain_units() -> void:
	assert_true(ArmyCatalog.can_take(_units_table(PackedStringArray(["Unit"])), Kit.warscroll("unit")))


func test_unlisted_unit_cannot_take_a_table_for_certain_units() -> void:
	assert_false(ArmyCatalog.can_take(_units_table(PackedStringArray(["Unit"])), Kit.hero("hero")))


func test_non_hero_cannot_take_heroic_traits() -> void:
	var table := Kit.table("Heroic Traits", [] as Array[Ability])
	assert_false(ArmyCatalog.can_take(table, Kit.warscroll("unit")))


func test_any_unit_can_take_an_unrestricted_table_of_another_type() -> void:
	var table := Kit.table("Monstrous Traits", [] as Array[Ability])
	assert_true(ArmyCatalog.can_take(table, Kit.warscroll("unit")))


func _choice_names(tables: Array[EnhancementTable]) -> Array:
	return tables.map(func(t: EnhancementTable) -> String: return t.entries[0].name)


func _faction_with_works() -> Faction:
	var faction := _faction()
	var legends := Kit.table("Great Works", [Kit.ability("Old Engine")] as Array[Ability])
	legends.legends = true
	faction.enhancement_tables.append_array([_units_table(PackedStringArray(["Unit"])), legends])
	return faction


func test_enhancement_choices_leave_out_tables_the_unit_cannot_take() -> void:
	var choices := Kit.catalog(_faction_with_works()).enhancement_choices(Kit.army(), Kit.hero("hero"), "Great Works")
	assert_does_not_have(_choice_names(choices), "Engine")


func test_enhancement_choices_include_tables_the_unit_can_take() -> void:
	var choices := Kit.catalog(_faction_with_works()).enhancement_choices(Kit.army(), Kit.warscroll("unit"), "Great Works")
	assert_has(_choice_names(choices), "Engine")


func test_enhancement_choices_leave_out_legends_tables() -> void:
	var choices := Kit.catalog(_faction_with_works()).enhancement_choices(Kit.army(), Kit.warscroll("unit"), "Great Works")
	assert_does_not_have(_choice_names(choices), "Old Engine")


func test_enhancement_choices_include_legends_tables_when_showing_legends() -> void:
	var army := Kit.army()
	army.show_legends = true
	var choices := Kit.catalog(_faction_with_works()).enhancement_choices(army, Kit.warscroll("unit"), "Great Works")
	assert_has(_choice_names(choices), "Old Engine")


func test_enhancement_choices_keep_the_selected_enhancement_table() -> void:
	var choices := Kit.catalog(_faction_with_works()).enhancement_choices(Kit.army(), Kit.hero("hero"), "Great Works", "Old Engine")
	assert_eq(_choice_names(choices), ["Old Engine"])


func test_faction_enhancement_is_not_available_to_an_army_of_renown() -> void:
	assert_null(_catalog().enhancement(_horde_army(), "Heroic Traits", "Brave"))


# Lores

func test_lores_are_filtered_by_kind() -> void:
	var names := _catalog().lores(Kit.army(), "spell").map(func(l: Lore) -> String: return l.name)
	assert_eq(names, ["Fire"])


func test_manifestation_lores_include_the_universal_ones() -> void:
	var names := _catalog().lores(Kit.army(), "manifestation").map(func(l: Lore) -> String: return l.name)
	assert_has(names, "Own Manifest")
	assert_has(names, "Universal")


func test_spell_lores_do_not_include_universal_manifestation_lores() -> void:
	var names := _catalog().lores(Kit.army(), "spell").map(func(l: Lore) -> String: return l.name)
	assert_does_not_have(names, "Universal")


func test_army_of_renown_uses_its_own_lores_but_keeps_universal_ones() -> void:
	var catalog := _catalog()
	assert_not_null(catalog.lore(_horde_army(), "spell", "Horde Spell"))
	assert_null(catalog.lore(_horde_army(), "spell", "Fire"))
	assert_not_null(catalog.lore(_horde_army(), "manifestation", "Universal"))


func _legends_lore_faction() -> Faction:
	var faction := _faction()
	var old := Kit.lore("Old Fire", "spell")
	old.legends = true
	faction.lores.append(old)
	return faction


func _lore_choice_names(army: Army, selected := "") -> Array:
	return Kit.catalog(_legends_lore_faction()).lore_choices(army, "spell", selected).map(func(l: Lore) -> String: return l.name)


func test_lore_choices_leave_out_legends_lores() -> void:
	assert_eq(_lore_choice_names(Kit.army()), ["Fire"])


func test_lore_choices_include_legends_lores_when_showing_legends() -> void:
	var army := Kit.army()
	army.show_legends = true
	assert_has(_lore_choice_names(army), "Old Fire")


func test_lore_choices_keep_the_picked_legends_lore() -> void:
	assert_has(_lore_choice_names(Kit.army(), "Old Fire"), "Old Fire")


func test_lore_lookup_is_null_for_unknown_name() -> void:
	assert_null(_catalog().lore(Kit.army(), "spell", "Nope"))


func test_lores_work_without_core_rules() -> void:
	var catalog := ArmyCatalog.new(_faction(), null)
	assert_eq(catalog.lores(Kit.army(), "manifestation").size(), 1)


# Formations

func test_formation_is_found_by_name() -> void:
	assert_not_null(_catalog().battle_formation(Kit.army(), "Vanguard"))


func test_army_of_renown_has_no_formations() -> void:
	var catalog := _catalog()
	assert_eq(catalog.battle_formations(_horde_army()).size(), 0)
	assert_null(catalog.battle_formation(_horde_army(), "Vanguard"))


# Warscrolls

func test_unit_warscrolls_exclude_manifestations_and_terrain() -> void:
	var ids := _catalog().unit_warscrolls().map(func(w: Warscroll) -> String: return w.id)
	assert_eq(ids, ["unit", "hero"])


func test_terrain_warscrolls_are_only_faction_terrain() -> void:
	var ids := _catalog().terrain_warscrolls().map(func(w: Warscroll) -> String: return w.id)
	assert_eq(ids, ["terrain"])


func test_warscroll_of_an_auxiliary_unit_comes_from_the_faction() -> void:
	assert_eq(_catalog().warscroll(Kit.unit("u1", "hero")).id, "hero")


func test_warscroll_of_a_missing_unit_is_null() -> void:
	assert_null(_catalog().warscroll(Kit.unit("u1", "gone")))


func test_warscroll_in_a_built_regiment_comes_from_the_faction() -> void:
	var regiment := Kit.regiment("r1", [] as Array[ArmyUnit])
	assert_eq(_catalog().warscroll(Kit.unit("u1", "unit"), regiment).id, "unit")


# Regiments of Renown

func test_regiment_of_renown_is_found_by_name() -> void:
	assert_eq(_catalog().regiment_of_renown("Band").points, 150)


func test_unknown_regiment_of_renown_is_null() -> void:
	assert_null(_catalog().regiment_of_renown("Nope"))


func test_regiments_of_renown_are_available_to_the_faction_army() -> void:
	assert_eq(_catalog().regiments_of_renown(Kit.army()).size(), 1)


func test_regiments_of_renown_are_available_when_the_roster_allows_them() -> void:
	assert_eq(_catalog().regiments_of_renown(_horde_army()).size(), 1)


func test_regiments_of_renown_are_unavailable_when_the_roster_forbids_them() -> void:
	var faction := _faction()
	faction.armies_of_renown[0].roster.regiments_of_renown = false
	assert_eq(Kit.catalog(faction).regiments_of_renown(_horde_army()).size(), 0)


func test_warscroll_of_a_self_defined_renown_unit_comes_from_the_regiment() -> void:
	var faction := _faction()
	var own: Array[Warscroll] = [Kit.warscroll("gotrek")]
	faction.regiments_of_renown[0].warscrolls = own
	var regiment := Kit.ror_regiment("r1", "Band", [] as Array[ArmyUnit])
	assert_eq(Kit.catalog(faction).warscroll(Kit.unit("u1", "gotrek"), regiment).id, "gotrek")


func test_warscroll_of_a_renown_unit_comes_from_its_home_faction() -> void:
	var home := Kit.faction([Kit.warscroll("elsewhere")] as Array[Warscroll], "home")
	var loader := func(faction_id: String) -> Faction: return home if faction_id == "home" else null
	var catalog := Kit.catalog(_faction(), null, loader)
	var unit := Kit.unit("u1", "elsewhere")
	unit.faction_id = "home"
	assert_eq(catalog.warscroll(unit, Kit.ror_regiment("r1", "Band", [] as Array[ArmyUnit])).id, "elsewhere")


func test_warscroll_of_a_renown_unit_is_null_when_its_home_faction_is_unknown() -> void:
	var loader := func(_faction_id: String) -> Faction: return null
	var catalog := Kit.catalog(_faction(), null, loader)
	var unit := Kit.unit("u1", "elsewhere")
	unit.faction_id = "nowhere"
	assert_null(catalog.warscroll(unit, Kit.ror_regiment("r1", "Band", [] as Array[ArmyUnit])))


func test_warscroll_of_a_unit_in_an_unknown_regiment_of_renown_is_null() -> void:
	var regiment := Kit.ror_regiment("r1", "Nope", [] as Array[ArmyUnit])
	assert_null(_catalog().warscroll(Kit.unit("u1", "unit"), regiment))


# Battle tactics

func test_battle_tactic_card_is_found_by_name() -> void:
	assert_not_null(_catalog().battle_tactic_card("Card A"))


func test_unknown_battle_tactic_card_is_null() -> void:
	assert_null(_catalog().battle_tactic_card("Nope"))


func test_battle_tactic_card_is_null_without_core_rules() -> void:
	assert_null(ArmyCatalog.new(_faction(), null).battle_tactic_card("Card A"))
