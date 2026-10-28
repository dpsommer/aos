extends GutTest
## Unit tests for turning faction data into controls (scripts/ui/forge/rules_view.gd).

const UIKit := preload("res://test/support/ui_kit.gd")
const Kit := preload("res://test/support/army_kit.gd")


func after_each() -> void:
	await get_tree().process_frame


func _ability(ability_name := "Made-up Ability") -> Ability:
	return Kit.ability(ability_name)


func _warscroll(unit_name := "Made-up Unit") -> Warscroll:
	var unit := Warscroll.new()
	unit.name = unit_name
	unit.id = unit_name.to_snake_case()
	return unit


## Frees [param node] after the test and returns it.
func _keep(node: Node) -> Node:
	autofree(node)
	return node


## All the text shown under [param node], from its labels and rich text labels.
func _text(node: Node) -> String:
	var parts := PackedStringArray()
	for found in UIKit.find_all(node, func(n: Node) -> bool: return n is Label or n is RichTextLabel):
		parts.append(found.text)
	if node is Label or node is RichTextLabel:
		parts.append(node.text)
	return "\n".join(parts)


func _headings(node: Node) -> PackedStringArray:
	var result := PackedStringArray()
	for label in UIKit.labels_with_variation(node, "SectionLabel"):
		result.append(label.text)
	return result


func _ability_names(node: Node) -> Array:
	return UIKit.find_all(node, func(n: Node) -> bool: return n is AbilityCard).map(
			func(c: AbilityCard) -> String: return c.ability.name)


func _warscroll_names(node: Node) -> Array:
	return UIKit.find_all(node, func(n: Node) -> bool: return n is WarscrollCard).map(
			func(c: WarscrollCard) -> String: return c.warscroll.name)


## Gives [param found] to the first ability of [param rules] only.
func _summoning(rules: Array[Ability], found: Array[Warscroll]) -> Callable:
	return func(rule: Ability) -> Array[Warscroll]: return found if rule == rules[0] else []


# abilities

func test_abilities_have_a_card_for_each_ability() -> void:
	var rules: Array[Ability] = [_ability("Alpha"), _ability("Beta")]
	assert_eq(_ability_names(_keep(RulesView.abilities(rules))), ["Alpha", "Beta"])


func test_abilities_of_empty_list_is_empty() -> void:
	var rules: Array[Ability] = []
	assert_eq(_keep(RulesView.abilities(rules)).get_child_count(), 0)


func test_abilities_show_a_summoned_manifestations_warscroll_after_the_ability() -> void:
	var rules: Array[Ability] = [_ability("Alpha")]
	var found: Array[Warscroll] = [_warscroll("Spooky Cloud")]
	var box := _keep(RulesView.abilities(rules, _summoning(rules, found)))
	assert_eq(box.get_child_count(), 2)
	assert_true(box.get_child(0) is AbilityCard)
	assert_eq((box.get_child(1) as WarscrollCard).warscroll.name, "Spooky Cloud")


func test_abilities_show_every_summoned_manifestation() -> void:
	var rules: Array[Ability] = [_ability("Alpha")]
	var found: Array[Warscroll] = [_warscroll("Spooky Cloud"), _warscroll("Wobbly Wall")]
	var box := _keep(RulesView.abilities(rules, _summoning(rules, found)))
	assert_eq(_warscroll_names(box), ["Spooky Cloud", "Wobbly Wall"])


func test_abilities_without_a_summoned_callable_show_no_warscrolls() -> void:
	var rules: Array[Ability] = [_ability("Alpha")]
	assert_eq(_warscroll_names(_keep(RulesView.abilities(rules))), [])


func test_abilities_without_summoned_manifestations_show_only_cards() -> void:
	var rules: Array[Ability] = [_ability("Alpha"), _ability("Beta")]
	var none: Array[Warscroll] = []
	var box := _keep(RulesView.abilities(rules, _summoning(rules, none)))
	assert_eq(box.get_child_count(), rules.size())


func test_abilities_only_show_warscrolls_after_the_summoning_ability() -> void:
	var rules: Array[Ability] = [_ability("Alpha"), _ability("Beta")]
	var found: Array[Warscroll] = [_warscroll("Spooky Cloud")]
	var box := _keep(RulesView.abilities(rules, _summoning(rules, found)))
	assert_eq(box.get_child_count(), 3)
	assert_true(box.get_child(2) is AbilityCard)
	assert_eq((box.get_child(2) as AbilityCard).ability.name, "Beta")


# warscroll

func test_warscroll_is_a_card_for_that_unit() -> void:
	var unit := _warscroll()
	assert_same((_keep(RulesView.warscroll(unit)) as WarscrollCard).warscroll, unit)


func test_warscroll_shows_the_manifestations_its_abilities_summon() -> void:
	var rules: Array[Ability] = [_ability("Alpha")]
	var found: Array[Warscroll] = [_warscroll("Spooky Cloud")]
	var unit := _warscroll()
	unit.abilities = rules
	var card := _keep(RulesView.warscroll(unit, _summoning(rules, found)))
	assert_eq(_warscroll_names(card), ["Spooky Cloud"])


func test_warscroll_without_a_summoned_callable_has_no_nested_warscroll() -> void:
	var rules: Array[Ability] = [_ability("Alpha")]
	var unit := _warscroll()
	unit.abilities = rules
	assert_eq(_warscroll_names(_keep(RulesView.warscroll(unit))), [])


# headings and enhancements

func test_heading_is_a_section_label_with_the_title() -> void:
	var label := RulesView.heading("A [B]")
	autofree(label)
	assert_eq(label.theme_type_variation, &"SectionLabel")
	assert_eq(label.text, "A [B]")


func _table() -> EnhancementTable:
	var table := EnhancementTable.new()
	table.name = "Made-up Traits"
	table.group = "Made-up Group"
	table.entries = [_ability("Entry One")]
	return table


func test_enhancement_table_shows_name_group_and_entries() -> void:
	var table := _table()
	var box := _keep(RulesView.enhancement_table(table))
	assert_string_contains(_headings(box)[0], table.name)
	assert_string_contains(_headings(box)[0], table.group)
	assert_eq(_ability_names(box), ["Entry One"])


func test_enhancement_table_shows_its_source() -> void:
	var table := _table()
	table.source = "Made-up Expansion"
	assert_string_contains(_headings(_keep(RulesView.enhancement_table(table)))[0], table.source)


func test_enhancement_table_without_group_or_source_is_just_its_name() -> void:
	var table := _table()
	table.group = ""
	assert_eq(_headings(_keep(RulesView.enhancement_table(table)))[0], table.name)


func test_battle_formation_shows_name_points_and_abilities() -> void:
	var formation := BattleFormation.new()
	formation.name = "Made-up Formation"
	formation.points = 40
	formation.abilities = [_ability("Formation Trick")]
	var box := _keep(RulesView.battle_formation(formation))
	assert_string_contains(_headings(box)[0], formation.name)
	assert_string_contains(_headings(box)[0], str(formation.points))
	assert_eq(_ability_names(box), ["Formation Trick"])


# faction rules

func _faction_with_trait(legends: bool) -> Faction:
	var faction := Faction.new()
	faction.battle_traits = [_ability("Faction Trait")]
	faction.legends = legends
	return faction


func test_faction_rules_show_every_section() -> void:
	var faction := _faction_with_trait(false)
	var formation := Kit.formation("Faction Formation")
	formation.abilities = [_ability("Formation Trick")]
	faction.battle_formations = [formation]
	var table := _table()
	faction.enhancement_tables = [table]
	var lore := Kit.lore("Faction Lore", "spell")
	lore.entries = [_ability("Faction Spell")]
	faction.lores = [lore]
	var page := _keep(RulesView.faction_rules(faction))
	var headings := _headings(page)
	assert_true(headings.has("Battle Traits"))
	assert_true(Array(headings).any(func(h: String) -> bool: return h.contains(formation.name)))
	assert_true(Array(headings).any(func(h: String) -> bool: return h.contains(table.name)))
	assert_string_contains(_text(page), lore.name)
	assert_eq(_ability_names(page), ["Faction Trait", "Formation Trick", "Entry One", "Faction Spell"])


func test_faction_rules_show_lores_as_full_lore_cards() -> void:
	var faction := Faction.new()
	var lore := Kit.lore("Faction Lore", "spell")
	lore.entries = [_ability("Faction Spell")]
	faction.lores = [lore]
	var cards := UIKit.find_all(_keep(RulesView.faction_rules(faction)), func(n: Node) -> bool: return n is LoreCard)
	assert_eq(cards.size(), 1)
	assert_eq(_ability_names(cards[0]), ["Faction Spell"])


func test_faction_rules_show_a_lores_summoned_manifestations() -> void:
	var faction := Faction.new()
	var lore := Kit.lore("Faction Lore", "manifestation")
	lore.entries = [_ability("Summon Cloud")]
	faction.lores = [lore]
	var found: Array[Warscroll] = [_warscroll("Spooky Cloud")]
	var page := _keep(RulesView.faction_rules(faction, _summoning(lore.entries, found)))
	assert_eq(_warscroll_names(page), ["Spooky Cloud"])


func test_faction_rules_of_empty_faction_is_empty() -> void:
	assert_eq(_keep(RulesView.faction_rules(Faction.new())).get_child_count(), 0)


func test_faction_rules_mark_legends() -> void:
	assert_string_contains(_text(_keep(RulesView.faction_rules(_faction_with_trait(true)))), "Legends")


func test_faction_rules_omit_legends_mark_when_not_legends() -> void:
	assert_false(_text(_keep(RulesView.faction_rules(_faction_with_trait(false)))).contains("Legends"))


func test_faction_rules_legends_mark_comes_before_battle_traits() -> void:
	var page := _keep(RulesView.faction_rules(_faction_with_trait(true)))
	var mark: Node = UIKit.find_all(page, func(n: Node) -> bool: return n is RichTextLabel and n.text.contains("Legends"))[0]
	var card: Node = UIKit.find_all(page, func(n: Node) -> bool: return n is AbilityCard)[0]
	assert_lt(_top_level_index(page, mark), _top_level_index(page, card))


func test_faction_rules_of_empty_legends_faction_is_only_the_mark() -> void:
	var faction := Faction.new()
	faction.legends = true
	var page := _keep(RulesView.faction_rules(faction))
	assert_eq(page.get_child_count(), 1)
	assert_string_contains(_text(page), "Legends")


## The index of the child of [param page] that is or contains [param node].
func _top_level_index(page: Node, node: Node) -> int:
	while node.get_parent() != page:
		node = node.get_parent()
	return node.get_index()


# armies of renown

func _army(legends := false) -> ArmyOfRenown:
	var army := ArmyOfRenown.new()
	army.name = "Made-up Army"
	army.source = "Made-up Book"
	army.text = "Roster limits."
	army.legends = legends
	return army


func test_army_of_renown_shows_name_text_and_traits() -> void:
	var army := _army()
	army.battle_traits = [_ability("Army Trait")]
	var page := _keep(RulesView.army_of_renown(army))
	assert_has(_headings(page), army.name)
	assert_string_contains(_text(page), army.text)
	assert_eq(_ability_names(page), ["Army Trait"])


func test_army_of_renown_shows_its_source() -> void:
	assert_string_contains(_text(_keep(RulesView.army_of_renown(_army()))), "Made-up Book")


func test_army_of_renown_shows_its_enhancements_and_lores() -> void:
	var army := _army()
	army.enhancement_tables = [_table()]
	var lore := Kit.lore("Army Lore", "spell")
	lore.entries = [_ability("Army Spell")]
	army.lores = [lore]
	assert_eq(_ability_names(_keep(RulesView.army_of_renown(army))), ["Entry One", "Army Spell"])


func test_army_of_renown_marks_legends() -> void:
	assert_string_contains(_text(_keep(RulesView.army_of_renown(_army(true)))), "Legends")


func test_army_of_renown_omits_legends_mark_when_not_legends() -> void:
	assert_false(_text(_keep(RulesView.army_of_renown(_army(false)))).contains("Legends"))


func test_army_of_renown_legends_mark_comes_between_source_and_text() -> void:
	var page := _keep(RulesView.army_of_renown(_army(true)))
	var texts: Array = UIKit.find_all(page, func(n: Node) -> bool: return n is RichTextLabel).map(
			func(r: RichTextLabel) -> String: return r.text)
	assert_eq(texts.size(), 3)
	assert_string_contains(texts[0], "Made-up Book")
	assert_string_contains(texts[1], "Legends")
	assert_string_contains(texts[2], "Roster limits.")


# regiments of renown

func _regiment(fields := {}) -> RegimentOfRenown:
	var regiment := RegimentOfRenown.new()
	regiment.name = "Made-up Regiment"
	regiment.points = 275
	for key: String in fields:
		if fields[key] is Array:
			regiment.get(key).assign(fields[key])
		else:
			regiment.set(key, fields[key])
	return regiment


func _regiment_unit(count: int, unit_name: String, notes := "") -> RegimentUnit:
	var unit := RegimentUnit.new()
	unit.count = count
	unit.name = unit_name
	unit.notes = notes
	return unit


func test_regiment_of_renown_shows_name_and_points() -> void:
	var regiment := _regiment()
	var heading := _headings(_keep(RulesView.regiment_of_renown(regiment)))[0]
	assert_string_contains(heading, regiment.name)
	assert_string_contains(heading, str(regiment.points))


func test_regiment_of_renown_shows_source_and_text() -> void:
	var regiment := _regiment({source = "Made-up Book", text = "Regiment restrictions."})
	var text := _text(_keep(RulesView.regiment_of_renown(regiment)))
	assert_string_contains(text, regiment.source)
	assert_string_contains(text, regiment.text)


func test_regiment_of_renown_marks_legends() -> void:
	assert_string_contains(_text(_keep(RulesView.regiment_of_renown(_regiment({legends = true})))), "Legends")


func test_regiment_of_renown_omits_legends_mark_when_not_legends() -> void:
	assert_false(_text(_keep(RulesView.regiment_of_renown(_regiment()))).contains("Legends"))


func test_regiment_of_renown_omits_source_when_empty() -> void:
	assert_false(_text(_keep(RulesView.regiment_of_renown(_regiment()))).contains("Source"))


func test_regiment_of_renown_lists_units_with_counts_and_notes() -> void:
	var regiment := _regiment({units = [_regiment_unit(3, "Made-up Troops", "incl. Banner"), _regiment_unit(1, "Made-up Lord")]})
	var text := _text(_keep(RulesView.regiment_of_renown(regiment)))
	for value in ["3", "Made-up Troops", "incl. Banner", "1", "Made-up Lord"]:
		assert_string_contains(text, value)


func test_regiment_of_renown_unit_without_notes_has_no_empty_brackets() -> void:
	var regiment := _regiment({units = [_regiment_unit(1, "Made-up Lord")]})
	assert_false(_text(_keep(RulesView.regiment_of_renown(regiment))).contains("()"))


func test_regiment_of_renown_omits_units_section_without_units() -> void:
	assert_false(_text(_keep(RulesView.regiment_of_renown(_regiment()))).contains("Units"))


func test_regiment_of_renown_shows_its_abilities_as_cards() -> void:
	var regiment := _regiment({abilities = [_ability("Regiment Ability")] as Array[Ability]})
	assert_eq(_ability_names(_keep(RulesView.regiment_of_renown(regiment))), ["Regiment Ability"])


func test_regiment_of_renown_shows_its_warscrolls() -> void:
	var regiment := _regiment({warscrolls = [_warscroll("Regiment Hero")] as Array[Warscroll]})
	assert_eq(_warscroll_names(_keep(RulesView.regiment_of_renown(regiment))), ["Regiment Hero"])


func test_regiment_of_renown_shows_manifestations_summoned_by_its_abilities() -> void:
	var rules: Array[Ability] = [_ability("Summon Cloud")]
	var found: Array[Warscroll] = [_warscroll("Spooky Cloud")]
	var regiment := _regiment({abilities = rules})
	var page := _keep(RulesView.regiment_of_renown(regiment, _summoning(rules, found)))
	assert_eq(_warscroll_names(page), ["Spooky Cloud"])


func test_regiment_of_renown_escapes_bbcode_in_text() -> void:
	var text := _text(_keep(RulesView.regiment_of_renown(_regiment({text = "Take [b]bold[/b] steps."}))))
	assert_false(text.contains("Take [b]bold"), text)


func test_regiment_of_renown_escapes_bbcode_in_unit_names() -> void:
	var regiment := _regiment({units = [_regiment_unit(1, "[url]Evil[/url]")]})
	assert_false(_text(_keep(RulesView.regiment_of_renown(regiment))).contains("[url]Evil"))


# spearheads and other sections

func _spearhead() -> Spearhead:
	var army := Spearhead.new()
	army.name = "Made-up Spearhead"
	return army


func test_spearhead_shows_general_and_units() -> void:
	var army := _spearhead()
	army.general = "Made-up General"
	var unit := SpearheadUnit.new()
	unit.count = 4
	unit.name = "Made-up Troops"
	unit.notes = "incl. Banner"
	army.units = [unit]
	var text := _text(_keep(RulesView.spearhead(army)))
	for value in [army.name, army.general, unit.name, str(unit.count), unit.notes]:
		assert_string_contains(text, value)


func test_spearhead_shows_its_warscrolls() -> void:
	var army := _spearhead()
	army.warscrolls = [_warscroll("Spearhead Unit")]
	assert_eq(_warscroll_names(_keep(RulesView.spearhead(army))), ["Spearhead Unit"])


func test_spearhead_shows_each_kind_of_ability_as_cards() -> void:
	var army := _spearhead()
	army.battle_traits = [_ability("Trait")]
	army.regiment_abilities = [_ability("Regiment Rule")]
	army.enhancements = [_ability("Enhancement")]
	var page := _keep(RulesView.spearhead(army))
	assert_eq(_ability_names(page), ["Trait", "Regiment Rule", "Enhancement"])
	assert_eq(_headings(page), PackedStringArray([army.name, "Battle Traits", "Regiment Abilities", "Enhancements"]))


func test_spearhead_omits_empty_ability_sections() -> void:
	var with_traits := _spearhead()
	with_traits.battle_traits = [_ability()]
	assert_lt(_headings(_keep(RulesView.spearhead(_spearhead()))).size(),
			_headings(_keep(RulesView.spearhead(with_traits))).size())


func test_spearhead_shows_manifestations_summoned_by_its_warscrolls() -> void:
	var rules: Array[Ability] = [_ability("Summon Cloud")]
	var found: Array[Warscroll] = [_warscroll("Spooky Cloud")]
	var unit := _warscroll("Spearhead Unit")
	unit.abilities = rules
	var army := _spearhead()
	army.warscrolls = [unit]
	assert_has(_warscroll_names(_keep(RulesView.spearhead(army, _summoning(rules, found)))), "Spooky Cloud")


func test_rules_section_shows_name_text_and_warscrolls() -> void:
	var section := RulesSection.new()
	section.name = "Made-up Section"
	section.text = "Section body."
	section.warscrolls = [_warscroll("Section Unit")]
	var page := _keep(RulesView.rules_section(section))
	assert_has(_headings(page), section.name)
	assert_string_contains(_text(page), section.text)
	assert_eq(_warscroll_names(page), ["Section Unit"])


func test_rules_section_without_text_shows_only_its_heading() -> void:
	var section := RulesSection.new()
	section.name = "Made-up Section"
	assert_eq(_keep(RulesView.rules_section(section)).get_child_count(), 1)
