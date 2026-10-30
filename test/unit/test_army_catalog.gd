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


func test_army_of_renown_forbidding_manifestations_has_no_manifestation_lores() -> void:
	var catalog := _catalog()
	catalog.army_of_renown("Horde").roster.manifestations = false
	assert_eq(catalog.lores(_horde_army(), "manifestation"), [])


func test_army_of_renown_forbidding_manifestations_still_has_its_spell_lores() -> void:
	var catalog := _catalog()
	catalog.army_of_renown("Horde").roster.manifestations = false
	assert_not_null(catalog.lore(_horde_army(), "spell", "Horde Spell"))


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


# Summoned manifestations

func _summoning(ids: Array) -> Ability:
	var spell := Kit.ability("Summon Thing")
	spell.summons = PackedStringArray(ids)
	return spell


func _manifestation(id: String) -> Warscroll:
	return Kit.warscroll(id, PackedStringArray(["MANIFESTATION"]))


func _summoned_ids(catalog: ArmyCatalog, ids: Array) -> Array:
	return catalog.summoned(_summoning(ids)).map(func(w: Warscroll) -> String: return w.id)


func test_summoned_finds_the_factions_manifestation() -> void:
	assert_eq(_summoned_ids(_catalog(), ["manifest"]), ["manifest"])


func test_summoned_finds_a_core_manifestation() -> void:
	var core := Kit.core()
	core.manifestations = [_manifestation("core_thing")] as Array[Warscroll]
	assert_eq(_summoned_ids(Kit.catalog(_faction(), core), ["core_thing"]), ["core_thing"])


func test_summoned_prefers_the_faction_warscroll_over_the_core_one() -> void:
	var core := Kit.core()
	core.manifestations = [_manifestation("manifest")] as Array[Warscroll]
	var catalog := Kit.catalog(_faction(), core)
	assert_same(catalog.summoned(_summoning(["manifest"]))[0], catalog.faction.get_warscroll("manifest"))


func test_summoned_skips_a_faction_warscroll_that_is_not_a_manifestation() -> void:
	assert_eq(_summoned_ids(_catalog(), ["unit"]), [])


func test_summoned_uses_the_core_manifestation_when_the_faction_warscroll_is_not_one() -> void:
	var faction := Kit.faction([Kit.warscroll("shared_id")] as Array[Warscroll])
	var core := Kit.core()
	core.manifestations = [_manifestation("shared_id")] as Array[Warscroll]
	assert_eq(_summoned_ids(Kit.catalog(faction, core), ["shared_id"]), ["shared_id"])


func test_summoned_skips_unknown_ids() -> void:
	assert_eq(_summoned_ids(_catalog(), ["nope"]), [])


func test_summoned_keeps_the_order_of_the_ids() -> void:
	var faction := Kit.faction([_manifestation("a"), _manifestation("b")] as Array[Warscroll])
	assert_eq(_summoned_ids(Kit.catalog(faction), ["b", "a"]), ["b", "a"])


func test_summoned_by_an_ability_with_no_summons_is_empty() -> void:
	assert_eq(_summoned_ids(_catalog(), []), [])


func test_summoned_finds_another_factions_manifestation() -> void:
	var wisper_home := Kit.faction([_manifestation("wisper")] as Array[Warscroll], "cities_of_sigmar")
	var asked := PackedStringArray()
	var load_faction := func(faction_id: String) -> Faction:
		asked.append(faction_id)
		return wisper_home
	var catalog := Kit.catalog(_faction(), null, load_faction)
	assert_eq(_summoned_ids(catalog, ["wisper"]), ["wisper"])
	assert_eq(asked.size(), 1)


func test_summoned_does_not_load_another_faction_when_it_has_the_manifestation() -> void:
	var loads := []
	var load_faction := func(faction_id: String) -> Faction:
		loads.append(faction_id)
		return null
	_summoned_ids(Kit.catalog(_faction(), null, load_faction), ["manifest"])
	assert_eq(loads, [])


func test_summoned_skips_a_manifestation_in_a_faction_that_cannot_load() -> void:
	var catalog := Kit.catalog(_faction(), null, func(_id: String) -> Faction: return null)
	assert_eq(_summoned_ids(catalog, ["wisper"]), [])


# Units included from other factions

func _home() -> Faction:
	var scrolls: Array[Warscroll] = [
		Kit.warscroll("sailor"), Kit.hero("captain"),
		Kit.warscroll("home_manifest", PackedStringArray(["MANIFESTATION"])),
		Kit.warscroll("home_terrain", PackedStringArray(["FACTION TERRAIN"])),
		Kit.warscroll("unit"),
	]
	return Kit.faction(scrolls, "home")


## A catalog whose Army of Renown "Horde" includes the given units of the faction "home". Its roster
## allows every unit of both factions, so only the inclusions decide which are offered.
func _including_catalog(inclusions: Array[RosterInclusion]) -> ArmyCatalog:
	var faction := _faction()
	var home := _home()
	faction.armies_of_renown[0].roster = ArmyRoster.new()
	faction.armies_of_renown[0].roster.included_units = inclusions
	for warscroll in faction.warscrolls + home.warscrolls:
		faction.armies_of_renown[0].roster.entries.append(Kit.roster_entry(warscroll.name))
	var loader := func(faction_id: String) -> Faction: return home if faction_id == "home" else null
	return Kit.catalog(faction, null, loader)


func _inclusion(faction_id: String, units := PackedStringArray()) -> RosterInclusion:
	var inclusion := RosterInclusion.new()
	inclusion.faction = faction_id
	inclusion.units = units
	return inclusion


func _unit_ids(catalog: ArmyCatalog, army: Army = null) -> Array:
	return catalog.unit_warscrolls(army).map(func(w: Warscroll) -> String: return w.id)


func test_unit_warscrolls_without_an_army_are_the_factions_own() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	assert_eq(_unit_ids(catalog), ["unit", "hero"])


func test_unit_warscrolls_include_a_whole_faction() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	var ids := _unit_ids(catalog, _horde_army())
	assert_true("sailor" in ids and "captain" in ids, str(ids))


func test_unit_warscrolls_include_only_the_named_units() -> void:
	var catalog := _including_catalog([_inclusion("home", PackedStringArray(["Captain"]))] as Array[RosterInclusion])
	var ids := _unit_ids(catalog, _horde_army())
	assert_true("captain" in ids and not "sailor" in ids, str(ids))


func test_unit_warscrolls_leave_out_included_manifestations_and_terrain() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	var ids := _unit_ids(catalog, _horde_army())
	assert_false("home_manifest" in ids or "home_terrain" in ids, str(ids))


func test_unit_warscrolls_ignore_an_inclusion_of_the_own_faction() -> void:
	var catalog := _including_catalog([_inclusion("test_faction")] as Array[RosterInclusion])
	assert_eq(_unit_ids(catalog, _horde_army()), ["unit", "hero"])


func test_unit_warscrolls_do_not_duplicate_a_warscroll_the_faction_has() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	assert_eq(_unit_ids(catalog, _horde_army()).count("unit"), 1)


func test_unit_warscrolls_do_not_duplicate_across_inclusions() -> void:
	var inclusions: Array[RosterInclusion] = [_inclusion("home"), _inclusion("home", PackedStringArray(["Sailor"]))]
	var catalog := _including_catalog(inclusions)
	assert_eq(_unit_ids(catalog, _horde_army()).count("sailor"), 1)


func test_unit_warscrolls_skip_an_inclusion_of_a_faction_that_cannot_load() -> void:
	var catalog := _including_catalog([_inclusion("nowhere")] as Array[RosterInclusion])
	assert_eq(_unit_ids(catalog, _horde_army()), ["unit", "hero"])


func test_unit_warscrolls_include_nothing_for_an_army_without_an_army_of_renown() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	assert_eq(_unit_ids(catalog, Kit.army()), ["unit", "hero"])


func test_find_warscroll_finds_an_own_unit() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	assert_eq(catalog.find_warscroll(_horde_army(), "hero").id, "hero")


func test_find_warscroll_prefers_the_own_faction_for_a_shared_id() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	assert_same(catalog.find_warscroll(_horde_army(), "unit"), catalog.faction.get_warscroll("unit"))


func test_find_warscroll_finds_an_included_unit() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	assert_eq(catalog.find_warscroll(_horde_army(), "sailor").id, "sailor")


func test_find_warscroll_is_null_for_an_unknown_id() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	assert_null(catalog.find_warscroll(_horde_army(), "gone"))


func test_find_warscroll_is_null_for_a_unit_the_army_of_renown_does_not_include() -> void:
	var catalog := _including_catalog([_inclusion("home", PackedStringArray(["Captain"]))] as Array[RosterInclusion])
	assert_null(catalog.find_warscroll(_horde_army(), "sailor"))


func test_included_faction_id_is_empty_for_an_own_unit() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	assert_eq(catalog.included_faction_id(_horde_army(), "hero"), "")


func test_included_faction_id_is_empty_for_a_shared_id() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	assert_eq(catalog.included_faction_id(_horde_army(), "unit"), "")


func test_included_faction_id_is_the_home_faction_for_an_included_unit() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	assert_eq(catalog.included_faction_id(_horde_army(), "sailor"), "home")


func test_included_faction_id_is_empty_for_an_unknown_id() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	assert_eq(catalog.included_faction_id(_horde_army(), "gone"), "")


func test_included_faction_id_is_empty_without_an_army_of_renown() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	assert_eq(catalog.included_faction_id(Kit.army(), "sailor"), "")


func test_warscroll_of_an_included_auxiliary_unit_comes_from_its_faction() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	var unit := Kit.unit("u1", "sailor")
	unit.faction_id = "home"
	assert_eq(catalog.warscroll(unit).id, "sailor")


func test_warscroll_of_an_included_unit_in_a_built_regiment_comes_from_its_faction() -> void:
	var catalog := _including_catalog([_inclusion("home")] as Array[RosterInclusion])
	var unit := Kit.unit("u1", "sailor")
	unit.faction_id = "home"
	var regiment := Kit.regiment("r1", [unit] as Array[ArmyUnit])
	assert_eq(catalog.warscroll(unit, regiment).id, "sailor")


# Units filtered by an Army of Renown roster

## A catalog whose Army of Renown "Horde" has the given roster entries and excluded unit names, and
## includes all of the faction "home".
## [param home] is the faction the Army of Renown includes units from, [method _home] by default.
func _filtering_catalog(entries: Array[RosterEntry], excluded := PackedStringArray(), home: Faction = null) -> ArmyCatalog:
	var faction := _faction()
	home = home if home else _home()
	var renown := faction.armies_of_renown[0]
	renown.roster = ArmyRoster.new()
	renown.roster.entries = entries
	renown.roster.excluded_units = excluded
	renown.roster.included_units = [_inclusion("home")] as Array[RosterInclusion]
	var loader := func(faction_id: String) -> Faction: return home if faction_id == "home" else null
	return Kit.catalog(faction, null, loader)


func test_unit_warscrolls_leave_out_own_units_matching_no_roster_entry() -> void:
	var catalog := _filtering_catalog([Kit.roster_entry("Hero")] as Array[RosterEntry])
	var ids := _unit_ids(catalog, _horde_army())
	assert_true("hero" in ids and not "unit" in ids, str(ids))


func test_unit_warscrolls_leave_out_excluded_units() -> void:
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero"), Kit.roster_entry("Unit")]
	var catalog := _filtering_catalog(entries, PackedStringArray(["Hero"]))
	var ids := _unit_ids(catalog, _horde_army())
	assert_true("unit" in ids and not "hero" in ids, str(ids))


func test_unit_warscrolls_leave_out_included_units_matching_no_roster_entry() -> void:
	var entries: Array[RosterEntry] = [Kit.roster_entry("Hero"), Kit.roster_entry("Captain")]
	var catalog := _filtering_catalog(entries)
	var ids := _unit_ids(catalog, _horde_army())
	assert_true("captain" in ids and not "sailor" in ids, str(ids))


func test_unit_warscrolls_keep_included_units_matching_a_roster_entry() -> void:
	var catalog := _filtering_catalog([Kit.roster_entry("Sailor")] as Array[RosterEntry])
	assert_eq(_unit_ids(catalog, _horde_army()), ["sailor"])


func test_unit_warscrolls_are_not_filtered_when_the_army_overrides_constraints() -> void:
	var catalog := _filtering_catalog([Kit.roster_entry("Hero")] as Array[RosterEntry], PackedStringArray(["Hero"]))
	var army := _horde_army()
	army.override_constraints = true
	var ids := _unit_ids(catalog, army)
	assert_true("hero" in ids and "unit" in ids and "sailor" in ids and "captain" in ids, str(ids))


func test_unit_warscrolls_are_not_filtered_for_an_army_without_an_army_of_renown() -> void:
	var catalog := _filtering_catalog([Kit.roster_entry("Captain")] as Array[RosterEntry])
	assert_eq(_unit_ids(catalog, Kit.army()), ["unit", "hero"])


func test_unit_warscrolls_without_an_army_are_not_filtered_by_a_roster() -> void:
	var catalog := _filtering_catalog([Kit.roster_entry("Captain")] as Array[RosterEntry])
	assert_eq(_unit_ids(catalog), ["unit", "hero"])


# Units only one Army of Renown can include

## A catalog whose Army of Renown "Horde" has a roster allowing every unit of the faction, whose unit
## "march_unit" can only be included in the Army of Renown "March" (which has no roster).
func _march_catalog() -> ArmyCatalog:
	var faction := _faction()
	faction.warscrolls.append(Kit.warscroll("march_unit"))
	faction.warscrolls[-1].army_of_renown = "March"
	var renown := faction.armies_of_renown[0]
	renown.roster = ArmyRoster.new()
	for warscroll in faction.warscrolls:
		renown.roster.entries.append(Kit.roster_entry(warscroll.name))
	faction.armies_of_renown.append(Kit.army_of_renown("March"))
	faction.armies_of_renown[1].roster = null
	return Kit.catalog(faction)


func _march_army() -> Army:
	var army := Kit.army()
	army.army_of_renown = "March"
	return army


func test_unit_warscrolls_leave_out_an_army_of_renown_unit_for_an_army_without_one() -> void:
	assert_false("march_unit" in _unit_ids(_march_catalog(), Kit.army()))


func test_unit_warscrolls_leave_out_an_army_of_renown_unit_for_another_army_of_renown() -> void:
	assert_false("march_unit" in _unit_ids(_march_catalog(), _horde_army()))


func test_unit_warscrolls_keep_an_army_of_renown_unit_for_its_own_army_of_renown() -> void:
	assert_true("march_unit" in _unit_ids(_march_catalog(), _march_army()))


func test_unit_warscrolls_keep_an_army_of_renown_unit_when_the_army_overrides_constraints() -> void:
	var army := Kit.army()
	army.override_constraints = true
	assert_true("march_unit" in _unit_ids(_march_catalog(), army))


func test_unit_warscrolls_without_an_army_keep_an_army_of_renown_unit() -> void:
	assert_true("march_unit" in _unit_ids(_march_catalog()))


func test_unit_warscrolls_keep_unrestricted_units_for_an_army_without_an_army_of_renown() -> void:
	assert_true("unit" in _unit_ids(_march_catalog(), Kit.army()))


func test_unit_warscrolls_leave_out_an_included_army_of_renown_unit_for_another_army_of_renown() -> void:
	var home := _home()
	home.get_warscroll("sailor").army_of_renown = "March"
	var catalog := _filtering_catalog([Kit.roster_entry("Sailor")] as Array[RosterEntry], PackedStringArray(), home)
	assert_false("sailor" in _unit_ids(catalog, _horde_army()))


# Paired leaders (Big Waaagh!)

func _kragnos(options := PackedStringArray(), id := "kragnos") -> Warscroll:
	return Kit.hero(id, options, PackedStringArray(["IRONJAWZ", "KRULEBOYZ"]))


## A catalog for the Army of Renown "Horde" paired IRONJAWZ/KRULEBOYZ in the faction "test_faction",
## which includes the given factions' units. The own faction has an Ironjawz Kragnos; the faction
## "home" has a Kruleboyz one allowing "Any KRULEBOYZ" and "other" an Ironjawz one.
func _paired_catalog(inclusions: Array[RosterInclusion], paired := PackedStringArray(["IRONJAWZ", "KRULEBOYZ"])) -> ArmyCatalog:
	var own: Array[Warscroll] = [_kragnos(PackedStringArray(["Any IRONJAWZ"])), Kit.hero("boss", PackedStringArray(), PackedStringArray(["IRONJAWZ"]))]
	var faction := Kit.faction(own)
	var home_scrolls: Array[Warscroll] = [_kragnos(PackedStringArray(["Any KRULEBOYZ"]))]
	var other_scrolls: Array[Warscroll] = [_kragnos(PackedStringArray(["Any ORDER"]))]
	var factions := {"home": Kit.faction(home_scrolls, "home"), "other": Kit.faction(other_scrolls, "other")}
	faction.armies_of_renown = [Kit.army_of_renown("Horde")] as Array[ArmyOfRenown]
	faction.armies_of_renown[0].roster.included_units = inclusions
	faction.armies_of_renown[0].roster.paired_leaders = paired
	return Kit.catalog(faction, null, func(faction_id: String) -> Faction: return factions.get(faction_id))


func _version_factions(versions: Array[Warscroll]) -> Array:
	return versions.map(func(w: Warscroll) -> String: return w.regiment_options[0])


func test_leader_versions_of_a_dual_keyword_leader_include_each_included_faction() -> void:
	var catalog := _paired_catalog([_inclusion("home")] as Array[RosterInclusion])
	var versions := catalog.leader_versions(_horde_army(), catalog.faction.get_warscroll("kragnos"))
	assert_eq(_version_factions(versions), ["Any IRONJAWZ", "Any KRULEBOYZ"])


func test_leader_versions_start_with_the_leader_itself() -> void:
	var catalog := _paired_catalog([_inclusion("home")] as Array[RosterInclusion])
	var leader := catalog.faction.get_warscroll("kragnos")
	assert_same(catalog.leader_versions(_horde_army(), leader)[0], leader)


func test_leader_versions_include_every_included_faction() -> void:
	var catalog := _paired_catalog([_inclusion("home"), _inclusion("other")] as Array[RosterInclusion])
	assert_eq(catalog.leader_versions(_horde_army(), catalog.faction.get_warscroll("kragnos")).size(), 3)


func test_leader_versions_of_a_single_keyword_leader_is_just_the_leader() -> void:
	var catalog := _paired_catalog([_inclusion("home")] as Array[RosterInclusion])
	assert_eq(catalog.leader_versions(_horde_army(), catalog.faction.get_warscroll("boss")).size(), 1)


func test_leader_versions_without_paired_leaders_is_just_the_leader() -> void:
	var catalog := _paired_catalog([_inclusion("home")] as Array[RosterInclusion], PackedStringArray())
	assert_eq(catalog.leader_versions(_horde_army(), catalog.faction.get_warscroll("kragnos")).size(), 1)


func test_leader_versions_for_a_faction_army_is_just_the_leader() -> void:
	var catalog := _paired_catalog([_inclusion("home")] as Array[RosterInclusion])
	assert_eq(catalog.leader_versions(Kit.army(), catalog.faction.get_warscroll("kragnos")).size(), 1)


func test_leader_versions_skip_an_inclusion_of_only_some_units() -> void:
	var catalog := _paired_catalog([_inclusion("home", PackedStringArray(["Kragnos"]))] as Array[RosterInclusion])
	assert_eq(catalog.leader_versions(_horde_army(), catalog.faction.get_warscroll("kragnos")).size(), 1)


func test_leader_versions_skip_an_inclusion_of_the_own_faction() -> void:
	var catalog := _paired_catalog([_inclusion("test_faction")] as Array[RosterInclusion])
	assert_eq(catalog.leader_versions(_horde_army(), catalog.faction.get_warscroll("kragnos")).size(), 1)


func test_leader_versions_skip_a_faction_that_cannot_load() -> void:
	var catalog := _paired_catalog([_inclusion("nowhere")] as Array[RosterInclusion])
	assert_eq(catalog.leader_versions(_horde_army(), catalog.faction.get_warscroll("kragnos")).size(), 1)


func test_leader_versions_skip_a_faction_without_the_warscroll() -> void:
	var catalog := _paired_catalog([_inclusion("home")] as Array[RosterInclusion])
	var stranger := _kragnos(PackedStringArray(), "stranger")
	assert_eq(catalog.leader_versions(_horde_army(), stranger).size(), 1)


func _regiment_of(leader: String, others: Array[String] = []) -> ArmyRegiment:
	var units: Array[ArmyUnit] = [Kit.unit("lead", leader)]
	for i in others.size():
		units.append(Kit.unit("u%d" % i, others[i]))
	return Kit.regiment("r", units)


## A catalog where the units are one Ironjawz and one Kruleboyz warscroll, to be fit against the options.
func _paired_units_catalog() -> ArmyCatalog:
	var catalog := _paired_catalog([_inclusion("home")] as Array[RosterInclusion])
	catalog.faction.warscrolls.append(Kit.warscroll("orruk", PackedStringArray(["IRONJAWZ"])))
	catalog.faction.warscrolls.append(Kit.warscroll("gobbo", PackedStringArray(["KRULEBOYZ"])))
	return catalog


func test_regiment_options_of_a_single_version_leader_are_its_own() -> void:
	var catalog := _paired_units_catalog()
	assert_eq(catalog.regiment_options(_horde_army(), _regiment_of("boss")).size(), 0)


func test_regiment_options_of_an_unknown_leader_are_empty() -> void:
	var catalog := _paired_units_catalog()
	assert_eq(catalog.regiment_options(_horde_army(), _regiment_of("gone")).size(), 0)


func test_regiment_options_of_an_empty_multi_version_regiment_are_the_union() -> void:
	var catalog := _paired_units_catalog()
	var options := catalog.regiment_options(_horde_army(), _regiment_of("kragnos"))
	assert_true(options.any(func(o: RegimentOption) -> bool: return o.matches(catalog.faction.get_warscroll("orruk"))))
	assert_true(options.any(func(o: RegimentOption) -> bool: return o.matches(catalog.faction.get_warscroll("gobbo"))))


func test_regiment_options_narrow_to_the_version_the_units_fit() -> void:
	var catalog := _paired_units_catalog()
	var options := catalog.regiment_options(_horde_army(), _regiment_of("kragnos", ["gobbo"]))
	assert_true(options.any(func(o: RegimentOption) -> bool: return o.matches(catalog.faction.get_warscroll("gobbo"))))
	assert_false(options.any(func(o: RegimentOption) -> bool: return o.matches(catalog.faction.get_warscroll("orruk"))))


func test_regiment_options_offer_neither_version_when_the_units_mix_both() -> void:
	var catalog := _paired_units_catalog()
	assert_eq(catalog.regiment_options(_horde_army(), _regiment_of("kragnos", ["gobbo", "orruk"])).size(), 0)


# Army of Renown regiment options

func _scroll_ids(options: Array[RegimentOption], scrolls: Array[Warscroll]) -> Array:
	return scrolls.filter(func(w: Warscroll) -> bool:
		return options.any(func(o: RegimentOption) -> bool: return o.matches(w))).map(func(w: Warscroll) -> String: return w.id)


## A catalog with the Army of Renown "Horde" adding "Any MONSTER" for [param leaders] (empty for all).
## Hero "boss" has "Any INFANTRY" and the keyword WARMASTER; "plain" has no options.
func _added_catalog(leaders: PackedStringArray) -> ArmyCatalog:
	var scrolls: Array[Warscroll] = [
		Kit.hero("boss", PackedStringArray(["Any INFANTRY"]), PackedStringArray(["WARMASTER"])),
		Kit.hero("plain"),
		Kit.warscroll("grunt", PackedStringArray(["INFANTRY"])),
		Kit.warscroll("beast", PackedStringArray(["MONSTER"])),
	]
	var faction := Kit.faction(scrolls)
	faction.armies_of_renown = [Kit.army_of_renown("Horde")] as Array[ArmyOfRenown]
	var added := RosterRegimentOptions.new()
	added.leaders = leaders
	added.options = PackedStringArray(["Any MONSTER"])
	faction.armies_of_renown[0].roster.regiment_options = [added] as Array[RosterRegimentOptions]
	return Kit.catalog(faction)


func _allowed(catalog: ArmyCatalog, army: Army, leader: String) -> Array:
	var options := catalog.leader_options(army, catalog.faction.get_warscroll(leader))
	return _scroll_ids(options, [catalog.faction.get_warscroll("grunt"), catalog.faction.get_warscroll("beast")] as Array[Warscroll])


func test_leader_options_without_an_army_of_renown_are_the_leaders_own() -> void:
	var catalog := _added_catalog(PackedStringArray())
	assert_eq(_allowed(catalog, Kit.army(), "boss"), ["grunt"])


func test_leader_options_with_empty_leaders_apply_to_every_leader() -> void:
	var catalog := _added_catalog(PackedStringArray())
	assert_eq(_allowed(catalog, _horde_army(), "plain"), ["beast"])


func test_leader_options_add_to_the_leaders_own() -> void:
	var catalog := _added_catalog(PackedStringArray())
	assert_eq(_allowed(catalog, _horde_army(), "boss"), ["grunt", "beast"])


func test_leader_options_apply_to_a_leader_matched_by_name() -> void:
	var catalog := _added_catalog(PackedStringArray(["Boss"]))
	assert_eq(_allowed(catalog, _horde_army(), "boss"), ["grunt", "beast"])


func test_leader_options_apply_to_a_leader_matched_by_keyword() -> void:
	var catalog := _added_catalog(PackedStringArray(["WARMASTER"]))
	assert_eq(_allowed(catalog, _horde_army(), "boss"), ["grunt", "beast"])


func test_leader_options_skip_a_non_matching_leader() -> void:
	var catalog := _added_catalog(PackedStringArray(["Boss"]))
	assert_eq(_allowed(catalog, _horde_army(), "plain"), [])


func test_leader_options_do_not_change_the_warscroll() -> void:
	var catalog := _added_catalog(PackedStringArray())
	catalog.leader_options(_horde_army(), catalog.faction.get_warscroll("boss"))
	assert_eq(catalog.faction.get_warscroll("boss").regiment_options.size(), 1)


func test_regiment_options_include_the_army_of_renown_additions() -> void:
	var catalog := _added_catalog(PackedStringArray(["Boss"]))
	var options := catalog.regiment_options(_horde_army(), _regiment_of("boss"))
	assert_eq(_scroll_ids(options, [catalog.faction.get_warscroll("beast")] as Array[Warscroll]), ["beast"])


func test_regiment_options_leave_out_additions_for_a_non_matching_leader() -> void:
	var catalog := _added_catalog(PackedStringArray(["Boss"]))
	assert_eq(catalog.regiment_options(_horde_army(), _regiment_of("plain")).size(), 0)


func test_regiment_options_of_each_paired_version_include_the_additions() -> void:
	var catalog := _paired_units_catalog()
	var added := RosterRegimentOptions.new()
	added.options = PackedStringArray(["Any ORDER"])
	catalog.faction.armies_of_renown[0].roster.regiment_options = [added] as Array[RosterRegimentOptions]
	catalog.faction.warscrolls.append(Kit.warscroll("knight", PackedStringArray(["ORDER"])))
	var options := catalog.regiment_options(_horde_army(), _regiment_of("kragnos"))
	assert_true(options.any(func(o: RegimentOption) -> bool: return o.matches(catalog.faction.get_warscroll("knight"))))


# Non-Hero general

## A faction whose Army of Renown "Crew" lets the Ironclad be the general, unless Brokk is included.
func _crew_catalog(roster_general := "Ironclad") -> ArmyCatalog:
	var ironclad := Kit.warscroll("ironclad", PackedStringArray(["WAR MACHINE"]), 100, "Ironclad")
	var brokk := Kit.hero("brokk")
	brokk.name = "Brokk, Lord-Magnate"
	var faction := Kit.faction([ironclad, brokk, Kit.warscroll("grunt"), Kit.hero("hero")] as Array[Warscroll])
	faction.enhancement_tables = [Kit.table("Heroic Traits", [Kit.ability("Brave")] as Array[Ability]),
			Kit.table("Artefacts of Power", [Kit.ability("Sword")] as Array[Ability]),
			Kit.table("Banners", [Kit.ability("Flag")] as Array[Ability])] as Array[EnhancementTable]
	var crew := Kit.army_of_renown("Crew")
	crew.roster.non_hero_general = roster_general
	crew.roster.non_hero_general_unless = PackedStringArray(["Brokk"])
	crew.enhancement_tables = faction.enhancement_tables
	faction.armies_of_renown = [crew] as Array[ArmyOfRenown]
	return Kit.catalog(faction)


func _crew_army(regiment_units: Array[ArmyUnit] = [], auxiliary: Array[ArmyUnit] = []) -> Army:
	var army := Kit.army()
	army.army_of_renown = "Crew"
	army.regiments.append(Kit.regiment("r1", regiment_units))
	army.auxiliary = auxiliary
	return army


func _scroll(catalog: ArmyCatalog, id: String) -> Warscroll:
	return catalog.faction.get_warscroll(id)


func test_named_unit_can_be_the_non_hero_general() -> void:
	var catalog := _crew_catalog()
	assert_true(catalog.can_be_non_hero_general(_crew_army(), _scroll(catalog, "ironclad")))


func test_unit_the_roster_does_not_name_cannot_be_the_non_hero_general() -> void:
	var catalog := _crew_catalog()
	assert_false(catalog.can_be_non_hero_general(_crew_army(), _scroll(catalog, "grunt")))


func test_hero_cannot_be_a_non_hero_general() -> void:
	var catalog := _crew_catalog("Hero")
	assert_false(catalog.can_be_non_hero_general(_crew_army(), _scroll(catalog, "hero")))


func test_no_unit_can_be_the_non_hero_general_without_a_roster() -> void:
	var catalog := _crew_catalog()
	assert_false(catalog.can_be_non_hero_general(Kit.army(), _scroll(catalog, "ironclad")))


func test_roster_without_a_non_hero_general_names_none() -> void:
	var catalog := _crew_catalog("")
	assert_false(catalog.can_be_non_hero_general(_crew_army(), _scroll(catalog, "ironclad")))


func test_blocker_in_a_regiment_stops_the_non_hero_general() -> void:
	var catalog := _crew_catalog()
	var army := _crew_army([Kit.unit("u1", "brokk")] as Array[ArmyUnit])
	assert_false(catalog.can_be_non_hero_general(army, _scroll(catalog, "ironclad")))


func test_blocker_in_a_regiment_is_named() -> void:
	var army := _crew_army([Kit.unit("u1", "grunt"), Kit.unit("u2", "brokk")] as Array[ArmyUnit])
	assert_eq(_crew_catalog().non_hero_general_blocker(army), "Brokk, Lord-Magnate")


func test_blocker_in_the_auxiliary_is_named() -> void:
	var army := _crew_army([Kit.unit("u1", "grunt")] as Array[ArmyUnit], [Kit.unit("u2", "brokk")] as Array[ArmyUnit])
	assert_eq(_crew_catalog().non_hero_general_blocker(army), "Brokk, Lord-Magnate")


func test_no_blocker_when_the_army_lacks_the_unit() -> void:
	var army := _crew_army([Kit.unit("u1", "grunt")] as Array[ArmyUnit])
	assert_eq(_crew_catalog().non_hero_general_blocker(army), "")


func test_no_blocker_without_a_roster() -> void:
	assert_eq(_crew_catalog().non_hero_general_blocker(Kit.army()), "")


func test_general_that_can_be_a_non_hero_general_is_a_hero() -> void:
	var catalog := _crew_catalog()
	var unit := Kit.unit("u1", "ironclad")
	var army := _crew_army([unit] as Array[ArmyUnit])
	army.general_uid = "u1"
	assert_true(catalog.is_hero(army, unit, _scroll(catalog, "ironclad")))


func test_non_general_that_can_be_a_non_hero_general_is_not_a_hero() -> void:
	var catalog := _crew_catalog()
	var unit := Kit.unit("u1", "ironclad")
	var army := _crew_army([unit] as Array[ArmyUnit])
	army.general_uid = "other"
	assert_false(catalog.is_hero(army, unit, _scroll(catalog, "ironclad")))


func test_blocked_non_hero_general_is_not_a_hero() -> void:
	var catalog := _crew_catalog()
	var unit := Kit.unit("u1", "ironclad")
	var army := _crew_army([unit, Kit.unit("u2", "brokk")] as Array[ArmyUnit])
	army.general_uid = "u1"
	assert_false(catalog.is_hero(army, unit, _scroll(catalog, "ironclad")))


func test_unit_with_the_hero_keyword_is_a_hero() -> void:
	var catalog := _crew_catalog()
	assert_true(catalog.is_hero(_crew_army(), Kit.unit("u1", "hero"), _scroll(catalog, "hero")))


func test_can_take_a_hero_table_when_counted_as_a_hero() -> void:
	var table := Kit.table("Heroic Traits", [] as Array[Ability])
	assert_true(ArmyCatalog.can_take(table, Kit.warscroll("grunt"), true))


func test_cannot_take_a_hero_table_as_a_non_hero_by_default() -> void:
	var table := Kit.table("Heroic Traits", [] as Array[Ability])
	assert_false(ArmyCatalog.can_take(table, Kit.warscroll("grunt")))


func test_non_hero_general_is_offered_hero_enhancements_with_its_unit() -> void:
	var catalog := _crew_catalog()
	var unit := Kit.unit("u1", "ironclad")
	var army := _crew_army([unit] as Array[ArmyUnit])
	army.general_uid = "u1"
	assert_eq(catalog.enhancement_choices(army, _scroll(catalog, "ironclad"), "Heroic Traits", "", unit).size(), 1)


func test_non_hero_general_is_offered_no_hero_enhancements_without_its_unit() -> void:
	var catalog := _crew_catalog()
	var army := _crew_army([Kit.unit("u1", "ironclad")] as Array[ArmyUnit])
	army.general_uid = "u1"
	assert_eq(catalog.enhancement_choices(army, _scroll(catalog, "ironclad"), "Heroic Traits").size(), 0)


func test_non_general_non_hero_is_offered_no_hero_enhancements_with_its_unit() -> void:
	var catalog := _crew_catalog()
	var unit := Kit.unit("u1", "ironclad")
	var army := _crew_army([unit] as Array[ArmyUnit])
	army.general_uid = "other"
	assert_eq(catalog.enhancement_choices(army, _scroll(catalog, "ironclad"), "Artefacts of Power", "", unit).size(), 0)


func test_non_hero_general_is_still_offered_other_enhancement_types() -> void:
	var catalog := _crew_catalog()
	var army := _crew_army([Kit.unit("u1", "ironclad")] as Array[ArmyUnit])
	assert_eq(catalog.enhancement_choices(army, _scroll(catalog, "ironclad"), "Banners").size(), 1)


# Gained keywords

## A catalog with Army of Renown "Horde" (keyword [param keyword]) and the given roster entries; with
## [param roster] false it has no roster at all.
func _keyword_catalog(keyword: String, entries: Array[RosterEntry], roster := true) -> ArmyCatalog:
	var scrolls: Array[Warscroll] = [Kit.warscroll("grunt", PackedStringArray(["INFANTRY"])), Kit.warscroll("beast", PackedStringArray(["MONSTER"]))]
	var faction := Kit.faction(scrolls)
	var renown := Kit.army_of_renown("Horde", entries)
	renown.keyword = keyword
	if not roster:
		renown.roster = null
	faction.armies_of_renown = [renown] as Array[ArmyOfRenown]
	return Kit.catalog(faction)


func _gained(catalog: ArmyCatalog, army: Army, id := "grunt") -> PackedStringArray:
	return catalog.gained_keywords(army, catalog.faction.get_warscroll(id))


func test_gained_keywords_are_empty_without_an_army_of_renown() -> void:
	var catalog := _keyword_catalog("CREW", [Kit.roster_entry("Grunt")] as Array[RosterEntry])
	assert_eq(_gained(catalog, Kit.army()), PackedStringArray())


func test_gained_keywords_include_the_army_of_renown_keyword() -> void:
	var catalog := _keyword_catalog("CREW", [Kit.roster_entry("Grunt")] as Array[RosterEntry])
	assert_eq(_gained(catalog, _horde_army()), PackedStringArray(["CREW"]))


func test_gained_keywords_are_empty_for_a_unit_the_roster_rejects() -> void:
	var catalog := _keyword_catalog("CREW", [Kit.roster_entry("Grunt")] as Array[RosterEntry])
	assert_eq(_gained(catalog, _horde_army(), "beast"), PackedStringArray())


func test_gained_keywords_are_empty_for_an_excluded_unit() -> void:
	var catalog := _keyword_catalog("CREW", [Kit.roster_entry("Grunt")] as Array[RosterEntry])
	catalog.army_of_renown("Horde").roster.excluded_units = PackedStringArray(["Grunt"])
	assert_eq(_gained(catalog, _horde_army()), PackedStringArray())


func test_army_of_renown_without_a_roster_gives_the_keyword_to_every_unit() -> void:
	var catalog := _keyword_catalog("CREW", [] as Array[RosterEntry], false)
	assert_eq([_gained(catalog, _horde_army()), _gained(catalog, _horde_army(), "beast")],
			[PackedStringArray(["CREW"]), PackedStringArray(["CREW"])])


func test_gained_keywords_append_the_roster_entry_gains_after_the_keyword() -> void:
	var entry := Kit.roster_entry("Grunt")
	entry.gains_keywords = PackedStringArray(["WARMASTER"])
	var catalog := _keyword_catalog("CREW", [entry] as Array[RosterEntry])
	assert_eq(_gained(catalog, _horde_army()), PackedStringArray(["CREW", "WARMASTER"]))


func test_gained_keywords_collect_the_gains_of_every_matching_entry() -> void:
	var first := Kit.roster_entry("Grunt")
	first.gains_keywords = PackedStringArray(["ONE"])
	var second := Kit.roster_entry("", PackedStringArray(["INFANTRY"]))
	second.gains_keywords = PackedStringArray(["TWO"])
	var catalog := _keyword_catalog("", [first, second] as Array[RosterEntry])
	assert_eq(_gained(catalog, _horde_army()), PackedStringArray(["ONE", "TWO"]))


func test_gained_keywords_leave_out_the_gains_of_a_non_matching_entry() -> void:
	var other := Kit.roster_entry("Beast")
	other.gains_keywords = PackedStringArray(["NOPE"])
	var catalog := _keyword_catalog("CREW", [Kit.roster_entry("Grunt"), other] as Array[RosterEntry])
	assert_eq(_gained(catalog, _horde_army()), PackedStringArray(["CREW"]))


func test_gained_keywords_skip_an_empty_army_of_renown_keyword() -> void:
	var entry := Kit.roster_entry("Grunt")
	entry.gains_keywords = PackedStringArray(["WARMASTER"])
	var catalog := _keyword_catalog("", [entry] as Array[RosterEntry])
	assert_eq(_gained(catalog, _horde_army()), PackedStringArray(["WARMASTER"]))


func test_gained_keywords_are_empty_with_an_empty_keyword_and_no_gains() -> void:
	var catalog := _keyword_catalog("", [Kit.roster_entry("Grunt")] as Array[RosterEntry])
	assert_eq(_gained(catalog, _horde_army()), PackedStringArray())


# Leader options with gained keywords

func test_leader_options_match_a_leader_by_the_keyword_it_gains() -> void:
	var catalog := _added_catalog(PackedStringArray(["CREW"]))
	catalog.army_of_renown("Horde").keyword = "CREW"
	catalog.army_of_renown("Horde").roster.entries = [Kit.roster_entry("Plain")] as Array[RosterEntry]
	assert_eq(_allowed(catalog, _horde_army(), "plain"), ["beast"])


func test_leader_options_do_not_match_a_gained_keyword_without_the_army_of_renown() -> void:
	var catalog := _added_catalog(PackedStringArray(["CREW"]))
	catalog.army_of_renown("Horde").keyword = "CREW"
	assert_eq(_allowed(catalog, Kit.army(), "plain"), [])


func test_leader_options_pass_heroes_on_to_the_added_options() -> void:
	var catalog := _added_catalog(PackedStringArray())
	catalog.army_of_renown("Horde").roster.regiment_options[0].heroes = true
	var options := catalog.leader_options(_horde_army(), catalog.faction.get_warscroll("plain"))
	assert_eq(options.map(func(o: RegimentOption) -> bool: return o.heroes), [true])


func test_leader_options_do_not_give_the_leaders_own_options_heroes() -> void:
	var catalog := _added_catalog(PackedStringArray())
	catalog.army_of_renown("Horde").roster.regiment_options[0].heroes = true
	var options := catalog.leader_options(_horde_army(), catalog.faction.get_warscroll("boss"))
	assert_eq(options.map(func(o: RegimentOption) -> bool: return o.heroes), [false, true])


func test_regiment_options_fit_a_unit_through_its_gained_keyword() -> void:
	var catalog := _added_catalog(PackedStringArray(["Boss"]))
	catalog.army_of_renown("Horde").roster.regiment_options[0].options = PackedStringArray(["Any CREW"])
	catalog.army_of_renown("Horde").keyword = "CREW"
	catalog.army_of_renown("Horde").roster.entries = [Kit.roster_entry("Boss"), Kit.roster_entry("Beast")] as Array[RosterEntry]
	var army := _horde_army()
	var beast := catalog.faction.get_warscroll("beast")
	var options := catalog.regiment_options(army, _regiment_of("boss"))
	assert_true(options.any(func(o: RegimentOption) -> bool: return o.matches(beast, catalog.gained_keywords(army, beast))))


# Non-Hero leaders

## A faction whose Army of Renown "Mob" lets the given names or keywords lead regiments without being Heroes.
func _mob_catalog(leaders: PackedStringArray, keyword := "") -> ArmyCatalog:
	var scrolls: Array[Warscroll] = [Kit.warscroll("gargant", PackedStringArray(["MONSTER"]), 100, "Gargant"),
			Kit.warscroll("grunt"), Kit.hero("hero")]
	var faction := Kit.faction(scrolls)
	var mob := Kit.army_of_renown("Mob")
	mob.keyword = keyword
	mob.roster.non_hero_leaders = leaders
	mob.roster.entries = [Kit.roster_entry("Grunt"), Kit.roster_entry("Gargant"), Kit.roster_entry("Hero")] as Array[RosterEntry]
	faction.armies_of_renown = [mob] as Array[ArmyOfRenown]
	return Kit.catalog(faction)


func _mob_army() -> Army:
	var army := Kit.army()
	army.army_of_renown = "Mob"
	return army


func test_unit_named_in_non_hero_leaders_is_a_non_hero_leader() -> void:
	var catalog := _mob_catalog(PackedStringArray(["Gargant"]))
	assert_true(catalog.is_non_hero_leader(_mob_army(), _scroll(catalog, "gargant")))


func test_unit_with_a_keyword_in_non_hero_leaders_is_a_non_hero_leader() -> void:
	var catalog := _mob_catalog(PackedStringArray(["MONSTER"]))
	assert_true(catalog.is_non_hero_leader(_mob_army(), _scroll(catalog, "gargant")))


func test_unit_gaining_a_keyword_from_the_army_of_renown_can_be_a_non_hero_leader() -> void:
	var catalog := _mob_catalog(PackedStringArray(["MOB"]), "MOB")
	assert_true(catalog.is_non_hero_leader(_mob_army(), _scroll(catalog, "grunt")))


func test_unit_not_in_non_hero_leaders_is_not_a_non_hero_leader() -> void:
	var catalog := _mob_catalog(PackedStringArray(["Gargant"]))
	assert_false(catalog.is_non_hero_leader(_mob_army(), _scroll(catalog, "grunt")))


func test_hero_is_not_a_non_hero_leader() -> void:
	var catalog := _mob_catalog(PackedStringArray(["Hero"]))
	assert_false(catalog.is_non_hero_leader(_mob_army(), _scroll(catalog, "hero")))


func test_no_unit_is_a_non_hero_leader_without_an_army_of_renown() -> void:
	var catalog := _mob_catalog(PackedStringArray(["Gargant"]))
	assert_false(catalog.is_non_hero_leader(Kit.army(), _scroll(catalog, "gargant")))


func test_no_unit_is_a_non_hero_leader_with_an_empty_list() -> void:
	var catalog := _mob_catalog(PackedStringArray())
	assert_false(catalog.is_non_hero_leader(_mob_army(), _scroll(catalog, "gargant")))


func test_hero_can_lead() -> void:
	var catalog := _mob_catalog(PackedStringArray())
	assert_true(catalog.can_lead(_mob_army(), _scroll(catalog, "hero")))


func test_non_hero_leader_can_lead() -> void:
	var catalog := _mob_catalog(PackedStringArray(["Gargant"]))
	assert_true(catalog.can_lead(_mob_army(), _scroll(catalog, "gargant")))


func test_non_hero_general_can_lead() -> void:
	var catalog := _crew_catalog()
	assert_true(catalog.can_lead(_crew_army(), _scroll(catalog, "ironclad")))


func test_ordinary_unit_cannot_lead() -> void:
	var catalog := _mob_catalog(PackedStringArray(["Gargant"]))
	assert_false(catalog.can_lead(_mob_army(), _scroll(catalog, "grunt")))


func test_non_hero_leader_is_not_a_hero() -> void:
	var catalog := _mob_catalog(PackedStringArray(["Gargant"]))
	var unit := Kit.unit("u1", "gargant")
	var army := _mob_army()
	army.regiments.append(Kit.regiment("r1", [unit] as Array[ArmyUnit]))
	army.general_uid = "u1"
	assert_false(catalog.is_hero(army, unit, _scroll(catalog, "gargant")))


# Enhancement limit

func _limit_catalog(faction_max: int, renown_max := 1) -> ArmyCatalog:
	var faction := _faction()
	faction.enhancement_tables[0].max = faction_max
	faction.armies_of_renown[0].enhancement_tables[0].max = renown_max
	return Kit.catalog(faction)


func test_enhancement_limit_is_one_by_default() -> void:
	assert_eq(_catalog().enhancement_limit(Kit.army(), "Heroic Traits"), 1)


func test_enhancement_limit_is_the_tables_max() -> void:
	assert_eq(_limit_catalog(3).enhancement_limit(Kit.army(), "Heroic Traits"), 3)


func test_enhancement_limit_ignores_other_types_tables() -> void:
	assert_eq(_limit_catalog(3).enhancement_limit(Kit.army(), "Artefacts of Power"), 1)


func test_enhancement_limit_takes_the_largest_max_of_the_type() -> void:
	var faction := _faction()
	var extra := Kit.table("Heroic Traits", [Kit.ability("Other")] as Array[Ability])
	extra.max = 2
	faction.enhancement_tables.append(extra)
	faction.enhancement_tables[0].max = 3
	assert_eq(Kit.catalog(faction).enhancement_limit(Kit.army(), "Heroic Traits"), 3)


func test_enhancement_limit_is_at_least_one() -> void:
	assert_eq(_limit_catalog(0).enhancement_limit(Kit.army(), "Heroic Traits"), 1)


func test_enhancement_limit_is_one_for_an_unknown_type() -> void:
	assert_eq(_limit_catalog(3).enhancement_limit(Kit.army(), "Nonsense"), 1)


func test_army_of_renown_limit_comes_from_its_own_tables() -> void:
	assert_eq(_limit_catalog(3, 2).enhancement_limit(_horde_army(), "Heroic Traits"), 2)


func test_army_of_renown_does_not_inherit_the_factions_limit() -> void:
	assert_eq(_limit_catalog(3, 1).enhancement_limit(_horde_army(), "Heroic Traits"), 1)


# Summoned units

func _faction_with_summoned_unit() -> Faction:
	var summoned_unit := Kit.warscroll("auto")
	summoned_unit.summoned = true
	return Kit.faction([Kit.warscroll("unit"), summoned_unit] as Array[Warscroll])


func test_unit_warscrolls_leave_out_summoned_units() -> void:
	var ids := Kit.catalog(_faction_with_summoned_unit()).unit_warscrolls().map(
			func(w: Warscroll) -> String: return w.id)
	assert_eq(ids, ["unit"])


func test_summoned_finds_the_factions_summoned_unit() -> void:
	assert_eq(_summoned_ids(Kit.catalog(_faction_with_summoned_unit()), ["auto"]), ["auto"])
