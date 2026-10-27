extends GutTest
## Unit tests for the Rules tab's section model (scripts/ui/forge/builder/rules_sections.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")


func _abilities(names: Array) -> Array[Ability]:
	var result: Array[Ability] = []
	for ability_name: String in names:
		result.append(Kit.ability(ability_name))
	return result


## A faction with rules of every kind, including a manifestation lore that summons its
## manifestation, and core rules with two battle tactics cards, a universal manifestation lore and
## the manifestation it summons.
func _faction() -> Faction:
	var faction := UIKit.faction()
	faction.battle_traits = _abilities(["Trait Alpha"])
	faction.battle_formations = [Kit.formation("Vanguard", 0), Kit.formation("Siege", 50)] as Array[BattleFormation]
	faction.battle_formations[0].abilities = _abilities(["Charge Plan"])
	faction.battle_formations[1].abilities = _abilities(["Wall Breaker"])
	var table := Kit.table("Artefacts", _abilities(["Sword of Dawn"]))
	table.group = "Heroes"
	faction.enhancement_tables = [table] as Array[EnhancementTable]
	var spells := Kit.lore("Fire Spells", "spell", 0)
	spells.entries = _abilities(["Fireball"])
	var prayers := Kit.lore("Sun Prayers", "prayer", 20)
	prayers.entries = _abilities(["Blessing"])
	var flames := Kit.lore("Flame Lore", "manifestation")
	flames.entries = _abilities(["Summon Flame"])
	flames.entries[0].summons = PackedStringArray(["flame"])
	faction.lores = [spells, prayers, flames] as Array[Lore]
	var manifestation := Kit.warscroll("flame", PackedStringArray(["MANIFESTATION"]))
	faction.warscrolls.append(manifestation)
	return faction


func _core() -> CoreRules:
	var universal := Kit.lore("Universal Lore", "manifestation")
	universal.entries = _abilities(["Summon Core Thing"])
	universal.entries[0].summons = PackedStringArray(["core_thing"])
	var core := Kit.core(PackedStringArray(["Card A", "Card B"]), [universal] as Array[Lore])
	core.manifestations = [Kit.warscroll("core_thing", PackedStringArray(["MANIFESTATION"]))] as Array[Warscroll]
	return core


func _build(army: Army = null, faction: Faction = null) -> Array[RulesSections.Section]:
	var catalog := Kit.catalog(faction if faction else _faction(), _core())
	return RulesSections.build(army if army else Kit.army(), catalog)


func _titles(sections: Array[RulesSections.Section]) -> Array:
	return sections.map(func(s: RulesSections.Section) -> String: return s.title)


func _section(sections: Array[RulesSections.Section], title: String) -> RulesSections.Section:
	for section in sections:
		if section.title == title:
			return section
	return null


func _group_titles(section: RulesSections.Section) -> Array:
	return section.groups.map(func(g: RulesSections.Group) -> String: return g.title)


func _names(abilities: Array[Ability]) -> Array:
	return abilities.map(func(a: Ability) -> String: return a.name)


func _ability_names(section: RulesSections.Section) -> Array:
	var names := []
	for group in section.groups:
		for ability in group.abilities:
			names.append(ability.name)
	return names


# --- build ---

func test_build_lists_sections_in_order() -> void:
	assert_eq(_titles(_build()), ["Battle Traits", "Battle Formations", "Enhancements", "Lores", "Faction Terrain",
			"Battle Tactics"])


func test_build_drops_empty_sections() -> void:
	var faction := _faction()
	faction.battle_formations = [] as Array[BattleFormation]
	faction.enhancement_tables = [] as Array[EnhancementTable]
	var titles := _titles(_build(null, faction))
	assert_does_not_have(titles, "Battle Formations")
	assert_does_not_have(titles, "Enhancements")


func test_build_without_battlepack_has_no_tactics_section() -> void:
	var core := Kit.core()
	core.battlepack = null
	var sections := RulesSections.build(Kit.army(), Kit.catalog(_faction(), core))
	assert_does_not_have(_titles(sections), "Battle Tactics")


func test_battle_traits_come_from_the_faction() -> void:
	assert_eq(_ability_names(_section(_build(), "Battle Traits")), ["Trait Alpha"])


func test_formations_are_groups_with_points() -> void:
	var section := _section(_build(), "Battle Formations")
	assert_eq(_group_titles(section), ["Vanguard", "Siege"])
	assert_eq(section.groups[1].points, 50)


func test_the_armys_formation_is_selected() -> void:
	var army := Kit.army()
	army.formation = "Siege"
	var groups := _section(_build(army), "Battle Formations").groups
	assert_false(groups[0].selected)
	assert_true(groups[1].selected)


func test_enhancement_groups_carry_the_table_group_as_a_note() -> void:
	var group := _section(_build(), "Enhancements").groups[0]
	assert_eq(group.title, "Artefacts")
	assert_eq(group.note, "Heroes")


func test_lores_are_flagged_as_lores() -> void:
	for group in _section(_build(), "Lores").groups:
		assert_true(group.lore, group.title)


func test_lores_include_universal_manifestation_lores_with_a_note() -> void:
	var groups := _section(_build(), "Lores").groups
	var universal: RulesSections.Group = groups.filter(func(g: RulesSections.Group) -> bool: return g.title == "Universal Lore")[0]
	assert_eq(universal.note, "Universal Manifestation Lore")


func test_faction_lores_note_their_kind() -> void:
	var groups := _section(_build(), "Lores").groups
	assert_ne(groups[0].note, groups[1].note)
	assert_ne(groups[0].note, "")


func test_picked_lore_is_selected() -> void:
	var army := Kit.army()
	army.prayer_lore = "Sun Prayers"
	var selected := _section(_build(army), "Lores").groups.filter(func(g: RulesSections.Group) -> bool: return g.selected)
	assert_eq(selected.map(func(g: RulesSections.Group) -> String: return g.title), ["Sun Prayers"])


func test_lore_group_has_the_lores_points() -> void:
	var group: RulesSections.Group = _section(_build(), "Lores").groups.filter(
			func(g: RulesSections.Group) -> bool: return g.title == "Sun Prayers")[0]
	assert_eq(group.points, 20)


func _lore(sections: Array[RulesSections.Section], title: String) -> RulesSections.Group:
	for group in _section(sections, "Lores").groups:
		if group.title == title:
			return group
	return null


func test_a_faction_lore_carries_the_manifestation_it_summons() -> void:
	var group := _lore(_build(), "Flame Lore")
	assert_eq(_ids(group.summons[group.abilities[0]]), ["flame"])


func test_a_universal_lore_carries_the_manifestation_it_summons() -> void:
	var group := _lore(_build(), "Universal Lore")
	assert_eq(_ids(group.summons[group.abilities[0]]), ["core_thing"])


func test_a_summoning_spell_with_several_summons_carries_them_all() -> void:
	var faction := _faction()
	faction.lores[2].entries[0].summons = PackedStringArray(["flame", "ember"])
	faction.warscrolls.append(Kit.warscroll("ember", PackedStringArray(["MANIFESTATION"])))
	var group := _lore(_build(null, faction), "Flame Lore")
	assert_eq(_ids(group.summons[group.abilities[0]]), ["flame", "ember"])


func test_a_spell_named_like_a_manifestation_without_summons_carries_none() -> void:
	var faction := _faction()
	faction.lores[2].entries[0].summons = PackedStringArray()
	assert_true(_lore(_build(null, faction), "Flame Lore").summons.is_empty())


func test_lores_without_summons_carry_no_manifestations() -> void:
	assert_true(_lore(_build(), "Fire Spells").summons.is_empty())


func test_lore_groups_carry_the_lores_source() -> void:
	var faction := _faction()
	faction.lores[0].source = "Scourge of Ghyran"
	assert_eq(_lore(_build(null, faction), "Fire Spells").source, "Scourge of Ghyran")


func test_enhancement_groups_carry_the_tables_source() -> void:
	var faction := _faction()
	faction.enhancement_tables[0].source = "Scourge of Aqshy"
	assert_eq(_section(_build(null, faction), "Enhancements").groups[0].source, "Scourge of Aqshy")


func test_groups_are_keyed_by_title() -> void:
	var section := _section(_build(), "Battle Formations")
	assert_eq(section.groups.map(func(g: RulesSections.Group) -> String: return g.key), ["Vanguard", "Siege"])


func test_groups_with_the_same_title_get_different_keys() -> void:
	var faction := _faction()
	var second := Kit.table("Artefacts", _abilities(["Shield of Dusk"]))
	second.source = "Scourge of Ghyran"
	faction.enhancement_tables.append(second)
	var groups := _section(_build(null, faction), "Enhancements").groups
	assert_eq(groups[0].title, groups[1].title)
	assert_ne(groups[0].key, groups[1].key)


func _faction_with_legends_table() -> Faction:
	var faction := _faction()
	var legends := Kit.table("Old Relics", _abilities(["Ancient Blade"]))
	legends.legends = true
	faction.enhancement_tables.append(legends)
	return faction


func test_legends_enhancement_tables_are_left_out_when_the_army_hides_legends() -> void:
	var army := Kit.army()
	army.show_legends = false
	var section := _section(_build(army, _faction_with_legends_table()), "Enhancements")
	assert_does_not_have(_group_titles(section), "Old Relics")
	assert_has(_group_titles(section), "Artefacts")


func test_legends_enhancement_tables_are_kept_and_flagged_when_the_army_shows_legends() -> void:
	var army := Kit.army()
	army.show_legends = true
	var section := _section(_build(army, _faction_with_legends_table()), "Enhancements")
	var group: RulesSections.Group = section.groups.filter(
			func(g: RulesSections.Group) -> bool: return g.title == "Old Relics")[0]
	assert_true(group.legends)


func test_non_legends_enhancement_groups_are_not_flagged_as_legends() -> void:
	var army := Kit.army()
	army.show_legends = true
	var section := _section(_build(army, _faction_with_legends_table()), "Enhancements")
	assert_false(section.groups[0].legends)


func _faction_with_legends_lore() -> Faction:
	var faction := _faction()
	var legends := Kit.lore("Old Spells", "spell")
	legends.legends = true
	legends.entries = _abilities(["Ancient Bolt"])
	faction.lores.append(legends)
	return faction


func test_legends_lores_are_left_out_when_the_army_hides_legends() -> void:
	var army := Kit.army()
	army.show_legends = false
	var sections := _build(army, _faction_with_legends_lore())
	assert_does_not_have(_group_titles(_section(sections, "Lores")), "Old Spells")
	assert_has(_group_titles(_section(sections, "Lores")), "Fire Spells")


func test_legends_lores_are_kept_and_flagged_when_the_army_shows_legends() -> void:
	var army := Kit.army()
	army.show_legends = true
	var sections := _build(army, _faction_with_legends_lore())
	assert_true(_lore(sections, "Old Spells").legends)
	assert_false(_lore(sections, "Fire Spells").legends)


func test_a_picked_legends_lore_stays_and_is_selected_when_the_army_hides_legends() -> void:
	var army := Kit.army()
	army.show_legends = false
	army.spell_lore = "Old Spells"
	var group := _lore(_build(army, _faction_with_legends_lore()), "Old Spells")
	assert_not_null(group)
	assert_true(group.selected)


func _ids(warscrolls: Array) -> Array:
	return warscrolls.map(func(w: Warscroll) -> String: return w.id)


func test_terrain_section_lists_faction_terrain() -> void:
	var group := _section(_build(), "Faction Terrain").groups[0]
	assert_eq(group.warscrolls.map(func(w: Warscroll) -> String: return w.id), ["terrain"])


func test_tactics_section_lists_battlepack_cards() -> void:
	var group := _section(_build(), "Battle Tactics").groups[0]
	assert_eq(group.cards.map(func(c: BattleTacticCard) -> String: return c.name), ["Card A", "Card B"])


# --- Army of Renown ---

func _faction_with_renown(forbids_terrain := false) -> Faction:
	var faction := _faction()
	var renown := Kit.army_of_renown("Wanderers")
	renown.battle_traits = _abilities(["Wanderer Trait"])
	var table := Kit.table("Relics", _abilities(["Wanderer Relic"]))
	renown.enhancement_tables = [table] as Array[EnhancementTable]
	var lore := Kit.lore("Wander Lore", "spell")
	lore.entries = _abilities(["Roam"])
	renown.lores = [lore] as Array[Lore]
	renown.roster.faction_terrain = not forbids_terrain
	faction.armies_of_renown.append(renown)
	return faction


func _renown_army() -> Army:
	var army := Kit.army()
	army.army_of_renown = "Wanderers"
	return army


func test_army_of_renown_replaces_battle_traits() -> void:
	var sections := _build(_renown_army(), _faction_with_renown())
	assert_eq(_ability_names(_section(sections, "Battle Traits")), ["Wanderer Trait"])


func test_army_of_renown_replaces_enhancements() -> void:
	var sections := _build(_renown_army(), _faction_with_renown())
	assert_eq(_group_titles(_section(sections, "Enhancements")), ["Relics"])


func test_army_of_renown_replaces_faction_lores_but_keeps_universal_ones() -> void:
	var sections := _build(_renown_army(), _faction_with_renown())
	var titles := _group_titles(_section(sections, "Lores"))
	assert_has(titles, "Wander Lore")
	assert_has(titles, "Universal Lore")
	assert_does_not_have(titles, "Fire Spells")


func test_army_of_renown_has_no_battle_formations() -> void:
	assert_does_not_have(_titles(_build(_renown_army(), _faction_with_renown())), "Battle Formations")


func test_terrain_is_hidden_when_the_army_of_renown_forbids_it() -> void:
	var sections := _build(_renown_army(), _faction_with_renown(true))
	assert_does_not_have(_titles(sections), "Faction Terrain")


func test_terrain_is_kept_when_the_army_of_renown_allows_it() -> void:
	assert_has(_titles(_build(_renown_army(), _faction_with_renown(false))), "Faction Terrain")


# --- count ---

func test_count_counts_rules_across_groups() -> void:
	var section := _section(_build(), "Battle Formations")
	assert_eq(section.count(), 2)


func test_lores_count_is_the_number_of_lore_groups() -> void:
	var section := _section(_build(), "Lores")
	assert_eq(section.count(), section.groups.size())


func test_lores_count_ignores_how_many_rules_each_lore_has() -> void:
	var faction := _faction()
	faction.lores[0].entries = _abilities(["A", "B", "C", "D"])
	var section := _section(_build(null, faction), "Lores")
	assert_eq(section.count(), section.groups.size())


func test_group_size_counts_abilities_warscrolls_and_cards() -> void:
	var group := RulesSections.Group.new()
	group.abilities = _abilities(["a"])
	group.warscrolls = [Kit.warscroll("w")] as Array[Warscroll]
	group.cards = [Kit.card("c"), Kit.card("d")] as Array[BattleTacticCard]
	assert_eq(group.size(), 4)


func test_group_copy_keeps_the_title_but_not_the_rules() -> void:
	var group := RulesSections.Group.new()
	group.title = "T"
	group.key = "T#2"
	group.note = "N"
	group.source = "S"
	group.points = 5
	group.selected = true
	group.legends = true
	group.lore = true
	group.abilities = _abilities(["a"])
	var copy := group.copy()
	assert_eq([copy.title, copy.key, copy.note, copy.source, copy.legends, copy.points, copy.selected, copy.lore],
			["T", "T#2", "N", "S", true, 5, true, true])
	assert_eq(copy.size(), 0)


# --- filter ---

func test_filter_with_a_blank_query_returns_everything() -> void:
	var sections := _build()
	assert_eq(RulesSections.filter(sections, "  ").size(), sections.size())


func test_filter_by_section_title_keeps_the_whole_section() -> void:
	var sections := _build()
	var found := RulesSections.filter(sections, "formations")
	assert_eq(_titles(found), ["Battle Formations"])
	assert_eq(found[0].count(), _section(sections, "Battle Formations").count())


func test_filter_by_group_title_keeps_the_whole_group() -> void:
	var found := RulesSections.filter(_build(), "vanguard")
	assert_eq(_titles(found), ["Battle Formations"])
	assert_eq(_group_titles(found[0]), ["Vanguard"])
	assert_eq(found[0].groups[0].abilities.size(), 1)


func test_filter_by_group_note_keeps_the_group() -> void:
	var found := RulesSections.filter(_build(), "heroes")
	assert_eq(_group_titles(_section(found, "Enhancements")), ["Artefacts"])


func test_filter_by_ability_name_keeps_only_that_ability() -> void:
	var found := RulesSections.filter(_build(), "wall breaker")
	assert_eq(_titles(found), ["Battle Formations"])
	assert_eq(_ability_names(found[0]), ["Wall Breaker"])
	assert_eq(_group_titles(found[0]), ["Siege"])


func test_filter_keeps_group_flags_on_partial_matches() -> void:
	var army := Kit.army()
	army.formation = "Siege"
	var found := RulesSections.filter(_build(army), "wall breaker")
	assert_true(found[0].groups[0].selected)
	assert_eq(found[0].groups[0].points, 50)


func test_filter_drops_groups_with_no_match() -> void:
	var found := RulesSections.filter(_build(), "charge plan")
	assert_eq(found[0].groups.size(), 1)


func test_filter_requires_every_word() -> void:
	assert_true(RulesSections.filter(_build(), "wall zzzz").is_empty())


func test_filter_matches_battle_tactic_cards() -> void:
	var found := RulesSections.filter(_build(), "card b")
	assert_eq(found[0].groups[0].cards.map(func(c: BattleTacticCard) -> String: return c.name), ["Card B"])


func test_filter_matches_warscrolls() -> void:
	var found := RulesSections.filter(_build(), "terrain")
	assert_eq(_titles(found), ["Faction Terrain"])
	assert_eq(found[0].groups[0].warscrolls.size(), 1)


func test_filter_by_group_source_keeps_the_group() -> void:
	var faction := _faction()
	faction.enhancement_tables[0].source = "Scourge of Ghyran"
	var found := RulesSections.filter(_build(null, faction), "ghyran")
	assert_eq(_group_titles(_section(found, "Enhancements")), ["Artefacts"])


func test_filter_keeps_a_summoning_spell_whose_manifestation_matches() -> void:
	var core := _core()
	core.manifestations[0].keywords = PackedStringArray(["MANIFESTATION", "GLOWING"])
	var sections := RulesSections.build(Kit.army(), Kit.catalog(_faction(), core))
	var group := _lore(RulesSections.filter(sections, "glowing"), "Universal Lore")
	assert_eq(_names(group.abilities), ["Summon Core Thing"])
	assert_eq(_ids(group.summons[group.abilities[0]]), ["core_thing"])


func test_filter_with_no_match_is_empty() -> void:
	assert_true(RulesSections.filter(_build(), "qqqq").is_empty())


func test_filter_is_case_insensitive() -> void:
	assert_eq(_titles(RulesSections.filter(_build(), "WALL BREAKER")), ["Battle Formations"])


func test_filter_does_not_change_the_input_sections() -> void:
	var sections := _build()
	var before := _section(sections, "Battle Formations").count()
	RulesSections.filter(sections, "wall breaker")
	assert_eq(_section(sections, "Battle Formations").count(), before)
