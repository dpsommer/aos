extends GutTest
## Unit tests for turning faction data into BBCode (scripts/ui/rules_formatter.gd).


func _ability(fields := {}) -> Ability:
	var rule := Ability.new()
	rule.name = "Made-up Ability"
	for key: String in fields:
		rule.set(key, fields[key])
	return rule


func _weapon(weapon_name: String, weapon_range := 0) -> Weapon:
	var weapon := Weapon.new()
	weapon.name = weapon_name
	weapon.range = weapon_range
	weapon.attacks = "D6+1"
	weapon.hit = 3
	weapon.wound = 4
	weapon.damage = "D3"
	return weapon


func _warscroll(fields := {}) -> Warscroll:
	var unit := Warscroll.new()
	unit.name = "Made-up Unit"
	unit.move = "5"
	unit.health = 7
	unit.save = 4
	unit.control = 2
	for key: String in fields:
		unit.set(key, fields[key])
	return unit


# ability

func test_ability_contains_name() -> void:
	var rule := _ability()
	assert_string_contains(RulesFormatter.ability(rule), rule.name)


func test_ability_contains_timing() -> void:
	var rule := _ability({timing = "Some Phase"})
	assert_string_contains(RulesFormatter.ability(rule), rule.timing)


func test_ability_contains_frequency() -> void:
	var rule := _ability({frequency = "Once Per Something"})
	assert_string_contains(RulesFormatter.ability(rule), rule.frequency)


func test_ability_contains_declare() -> void:
	var rule := _ability({declare = "Pick a made-up target."})
	assert_string_contains(RulesFormatter.ability(rule), rule.declare)


func test_ability_contains_effect() -> void:
	var rule := _ability({effect = "Something happens."})
	assert_string_contains(RulesFormatter.ability(rule), rule.effect)


func test_ability_contains_text() -> void:
	var rule := _ability({text = "Free-form rules text."})
	assert_string_contains(RulesFormatter.ability(rule), rule.text)


func test_ability_contains_every_option_name_and_text() -> void:
	var options: Array[Dictionary] = [{"name": "First Choice", "text": "First text."},
			{"name": "Second Choice", "text": "Second text."}]
	var output := RulesFormatter.ability(_ability({options = options}))
	for option in options:
		assert_string_contains(output, option.name)
		assert_string_contains(output, option.text)


func test_ability_contains_points_when_set() -> void:
	var rule := _ability({points = 35})
	assert_string_contains(RulesFormatter.ability(rule), str(rule.points))


func test_ability_contains_keywords() -> void:
	var rule := _ability({keywords = PackedStringArray(["FIRSTWORD", "SECONDWORD"])})
	var output := RulesFormatter.ability(rule)
	for keyword in rule.keywords:
		assert_string_contains(output, keyword)


func test_ability_contains_source() -> void:
	var rule := _ability({source = "Made-up Expansion"})
	assert_string_contains(RulesFormatter.ability(rule), rule.source)


func test_ability_with_only_name_is_one_line() -> void:
	assert_eq(RulesFormatter.ability(_ability()).split("\n").size(), 1)


func test_ability_omits_declare_label_when_declare_empty() -> void:
	var with_declare := RulesFormatter.ability(_ability({declare = "x", effect = "y"}))
	var without_declare := RulesFormatter.ability(_ability({effect = "y"}))
	assert_lt(without_declare.split("\n").size(), with_declare.split("\n").size())


func test_ability_omits_points_when_zero() -> void:
	assert_false("pts" in RulesFormatter.ability(_ability({timing = "Some Phase"})))


func test_ability_contains_casting_value_when_set() -> void:
	var rule := _ability({casting_value = 7})
	assert_string_contains(RulesFormatter.ability(rule), "Casting value %d" % rule.casting_value)


func test_ability_omits_casting_value_when_zero() -> void:
	assert_false("Casting value" in RulesFormatter.ability(_ability({timing = "Some Phase"})))


func test_ability_contains_chanting_value_when_set() -> void:
	var rule := _ability({chanting_value = 4})
	assert_string_contains(RulesFormatter.ability(rule), "Chanting value %d" % rule.chanting_value)


func test_ability_omits_chanting_value_when_zero() -> void:
	assert_false("Chanting value" in RulesFormatter.ability(_ability({timing = "Some Phase"})))


func test_ability_escapes_brackets_in_name() -> void:
	var output := RulesFormatter.ability(_ability({name = "[Bracketed]"}))
	assert_string_contains(output, "[lb]Bracketed]")


func test_ability_does_not_leave_raw_bracket_from_effect() -> void:
	var output := RulesFormatter.ability(_ability({effect = "Gains [Crit (Mortal)]."}))
	assert_false("[Crit" in output)


func test_abilities_contains_every_ability() -> void:
	var rules: Array[Ability] = [_ability({name = "Alpha"}), _ability({name = "Beta"})]
	var output := RulesFormatter.abilities(rules)
	for rule in rules:
		assert_string_contains(output, rule.name)


func test_abilities_of_empty_list_is_empty() -> void:
	var rules: Array[Ability] = []
	assert_eq(RulesFormatter.abilities(rules), "")


# warscroll

func test_warscroll_contains_name() -> void:
	var unit := _warscroll()
	assert_string_contains(RulesFormatter.warscroll(unit), unit.name)


func test_warscroll_contains_characteristics() -> void:
	var unit := _warscroll({move = "11", health = 13, save = 5, control = 17})
	var output := RulesFormatter.warscroll(unit)
	for value in [unit.move, unit.health, unit.save, unit.control]:
		assert_string_contains(output, str(value))


func test_warscroll_shows_dice_move_in_inches() -> void:
	var unit := _warscroll({move = "D6+3"})
	assert_string_contains(RulesFormatter.warscroll(unit), '%s"' % unit.move)


func test_warscroll_with_zero_move_shows_dash() -> void:
	assert_string_contains(RulesFormatter.warscroll(_warscroll({move = "0"})), "[cell]-[/cell]")


func test_warscroll_with_zero_move_omits_inches() -> void:
	assert_false('0"' in RulesFormatter.warscroll(_warscroll({move = "0"})))


func test_warscroll_contains_ward_when_positive() -> void:
	var with_ward := RulesFormatter.warscroll(_warscroll({ward = 6}))
	var without_ward := RulesFormatter.warscroll(_warscroll())
	assert_gt(with_ward.count("[cell]"), without_ward.count("[cell]"))


func test_warscroll_ward_value_is_shown() -> void:
	var unit := _warscroll({ward = 6, save = 3})
	assert_string_contains(RulesFormatter.warscroll(unit), "%d+" % unit.ward)


func test_warscroll_with_banishment_shows_banishment_column() -> void:
	assert_string_contains(RulesFormatter.warscroll(_warscroll({banishment = 7})), "Banishment")


func test_warscroll_with_banishment_shows_value_as_roll() -> void:
	var unit := _warscroll({banishment = 7})
	assert_string_contains(RulesFormatter.warscroll(unit), "%d+" % unit.banishment)


func test_warscroll_with_banishment_replaces_control_column() -> void:
	assert_false("Control" in RulesFormatter.warscroll(_warscroll({banishment = 7})))


func test_warscroll_with_banishment_has_same_column_count() -> void:
	var with_banishment := RulesFormatter.warscroll(_warscroll({banishment = 7}))
	assert_eq(with_banishment.count("[cell]"), RulesFormatter.warscroll(_warscroll()).count("[cell]"))


func test_warscroll_without_banishment_shows_control_column() -> void:
	assert_string_contains(RulesFormatter.warscroll(_warscroll()), "Control")


func test_warscroll_without_banishment_omits_banishment_column() -> void:
	assert_false("Banishment" in RulesFormatter.warscroll(_warscroll()))


func test_warscroll_contains_ranged_weapon_name_and_profile() -> void:
	var weapon := _weapon("Made-up Gun", 18)
	var weapons: Array[Weapon] = [weapon]
	var output := RulesFormatter.warscroll(_warscroll({ranged_weapons = weapons}))
	for value in [weapon.name, str(weapon.range), weapon.attacks, weapon.damage]:
		assert_string_contains(output, value)


func test_warscroll_contains_melee_weapon_name() -> void:
	var weapons: Array[Weapon] = [_weapon("Made-up Blade")]
	assert_string_contains(RulesFormatter.warscroll(_warscroll({melee_weapons = weapons})), weapons[0].name)


func test_warscroll_weapon_abilities_are_escaped() -> void:
	var weapon := _weapon("Made-up Blade")
	weapon.abilities = PackedStringArray(["Anti-Thing"])
	var weapons: Array[Weapon] = [weapon]
	var output := RulesFormatter.warscroll(_warscroll({melee_weapons = weapons}))
	assert_string_contains(output, "[lb]Anti-Thing]")


func test_warscroll_without_weapons_has_only_characteristics_table() -> void:
	assert_eq(RulesFormatter.warscroll(_warscroll()).count("[table="), 1)


func test_warscroll_contains_ability_names() -> void:
	var abilities: Array[Ability] = [_ability({name = "Unit Trick"})]
	assert_string_contains(RulesFormatter.warscroll(_warscroll({abilities = abilities})), abilities[0].name)


func test_warscroll_contains_points_when_it_has_a_profile() -> void:
	var unit := _warscroll({points = 145, unit_size = 3})
	assert_string_contains(RulesFormatter.warscroll(unit), str(unit.points))


func test_warscroll_without_profile_omits_points() -> void:
	assert_false("pts" in RulesFormatter.warscroll(_warscroll()))


func test_warscroll_contains_keywords() -> void:
	var unit := _warscroll({keywords = PackedStringArray(["ONEWORD", "TWOWORD"])})
	var output := RulesFormatter.warscroll(unit)
	for keyword in unit.keywords:
		assert_string_contains(output, keyword)


func test_warscroll_contains_regiment_options() -> void:
	var unit := _warscroll({regiment_options = PackedStringArray(["Any MADEUP"])})
	assert_string_contains(RulesFormatter.warscroll(unit), unit.regiment_options[0])


func test_warscroll_contains_composition() -> void:
	var unit := _warscroll({composition = "Made-up models"})
	assert_string_contains(RulesFormatter.warscroll(unit), unit.composition)


func test_warscroll_omits_empty_keywords() -> void:
	assert_false("Keywords" in RulesFormatter.warscroll(_warscroll()))


func test_warscroll_contains_source() -> void:
	var unit := _warscroll({source = "Made-up Expansion"})
	assert_string_contains(RulesFormatter.warscroll(unit), unit.source)


# other sections

func test_heading_escapes_brackets() -> void:
	assert_string_contains(RulesFormatter.heading("A [B]"), "A [lb]B]")


func test_enhancement_table_contains_name_group_and_entries() -> void:
	var table := EnhancementTable.new()
	table.name = "Made-up Traits"
	table.group = "Made-up Group"
	table.entries = [_ability({name = "Entry One"})]
	var output := RulesFormatter.enhancement_table(table)
	for value in [table.name, table.group, table.entries[0].name]:
		assert_string_contains(output, value)


func test_lore_contains_name_and_entries() -> void:
	var lore := Lore.new()
	lore.name = "Made-up Lore"
	lore.entries = [_ability({name = "Made-up Spell"})]
	var output := RulesFormatter.lore(lore)
	assert_string_contains(output, lore.name)
	assert_string_contains(output, lore.entries[0].name)


func test_lore_contains_points_when_set() -> void:
	var lore := Lore.new()
	lore.name = "Made-up Lore"
	lore.points = 30
	assert_string_contains(RulesFormatter.lore(lore), "%d pts" % lore.points)


func test_lore_omits_points_when_zero() -> void:
	var lore := Lore.new()
	lore.name = "Made-up Lore"
	assert_false("pts" in RulesFormatter.lore(lore))


func test_lore_contains_source_when_set() -> void:
	var lore := Lore.new()
	lore.name = "Made-up Lore"
	lore.source = "Made-up Expansion"
	assert_string_contains(RulesFormatter.lore(lore), lore.source)


func test_lore_omits_source_when_empty() -> void:
	var lore := Lore.new()
	lore.name = "Made-up Lore"
	assert_false("()" in RulesFormatter.lore(lore))


func test_battle_formation_contains_name_points_and_abilities() -> void:
	var formation := BattleFormation.new()
	formation.name = "Made-up Formation"
	formation.points = 40
	formation.abilities = [_ability({name = "Formation Trick"})]
	var output := RulesFormatter.battle_formation(formation)
	for value in [formation.name, str(formation.points), formation.abilities[0].name]:
		assert_string_contains(output, value)


func test_faction_rules_contains_every_section() -> void:
	var faction := Faction.new()
	faction.battle_traits = [_ability({name = "Faction Trait"})]
	var formation := BattleFormation.new()
	formation.name = "Faction Formation"
	faction.battle_formations = [formation]
	var lore := Lore.new()
	lore.name = "Faction Lore"
	faction.lores = [lore]
	var output := RulesFormatter.faction_rules(faction)
	for value in [faction.battle_traits[0].name, formation.name, lore.name]:
		assert_string_contains(output, value)


func test_faction_rules_of_empty_faction_is_empty() -> void:
	assert_eq(RulesFormatter.faction_rules(Faction.new()), "")


func _faction_with_trait(legends: bool) -> Faction:
	var faction := Faction.new()
	faction.battle_traits = [_ability({name = "Faction Trait"})]
	faction.legends = legends
	return faction


func test_faction_rules_marks_legends() -> void:
	assert_string_contains(RulesFormatter.faction_rules(_faction_with_trait(true)), "Legends")


func test_faction_rules_omits_legends_mark_when_not_legends() -> void:
	assert_false(RulesFormatter.faction_rules(_faction_with_trait(false)).contains("Legends"))


func test_faction_rules_legends_mark_comes_before_battle_traits() -> void:
	var faction := _faction_with_trait(true)
	var output := RulesFormatter.faction_rules(faction)
	assert_lt(output.find("Legends"), output.find(faction.battle_traits[0].name), output)


func test_faction_rules_of_empty_legends_faction_is_only_the_mark() -> void:
	var faction := Faction.new()
	faction.legends = true
	var output := RulesFormatter.faction_rules(faction)
	assert_string_contains(output, "Legends")
	assert_false(output.contains("\n"), output)


func test_army_of_renown_contains_name_text_and_traits() -> void:
	var army := ArmyOfRenown.new()
	army.name = "Made-up Army"
	army.text = "Roster limits."
	army.battle_traits = [_ability({name = "Army Trait"})]
	var output := RulesFormatter.army_of_renown(army)
	for value in [army.name, army.text, army.battle_traits[0].name]:
		assert_string_contains(output, value)


func _army(legends: bool) -> ArmyOfRenown:
	var army := ArmyOfRenown.new()
	army.name = "Made-up Army"
	army.source = "Made-up Book"
	army.text = "Roster limits."
	army.legends = legends
	return army


func test_army_of_renown_marks_legends() -> void:
	assert_string_contains(RulesFormatter.army_of_renown(_army(true)), "Legends")


func test_army_of_renown_omits_legends_mark_when_not_legends() -> void:
	assert_false(RulesFormatter.army_of_renown(_army(false)).contains("Legends"))


func test_army_of_renown_legends_mark_comes_between_source_and_text() -> void:
	var army := _army(true)
	var output := RulesFormatter.army_of_renown(army)
	var legends := output.find("Legends")
	assert_true(output.find(army.source) < legends and legends < output.find(army.text), output)


func test_army_of_renown_legends_mark_adds_a_line() -> void:
	var lines := func(army: ArmyOfRenown) -> int: return RulesFormatter.army_of_renown(army).count("\n")
	assert_gt(lines.call(_army(true)), lines.call(_army(false)))


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


func test_regiment_of_renown_contains_name_and_points() -> void:
	var regiment := _regiment()
	var output := RulesFormatter.regiment_of_renown(regiment)
	assert_string_contains(output, regiment.name)
	assert_string_contains(output, str(regiment.points))


func test_regiment_of_renown_contains_source_and_text() -> void:
	var regiment := _regiment({source = "Made-up Book", text = "Regiment restrictions."})
	var output := RulesFormatter.regiment_of_renown(regiment)
	assert_string_contains(output, regiment.source)
	assert_string_contains(output, regiment.text)


func test_regiment_of_renown_marks_legends() -> void:
	assert_string_contains(RulesFormatter.regiment_of_renown(_regiment({legends = true})), "Legends")


func test_regiment_of_renown_omits_legends_mark_when_not_legends() -> void:
	assert_false(RulesFormatter.regiment_of_renown(_regiment()).contains("Legends"))


func test_regiment_of_renown_omits_source_when_empty() -> void:
	assert_false(RulesFormatter.regiment_of_renown(_regiment()).contains("Source"))


func test_regiment_of_renown_lists_units_with_counts_and_notes() -> void:
	var regiment := _regiment({units = [_regiment_unit(3, "Made-up Troops", "incl. Banner"), _regiment_unit(1, "Made-up Lord")]})
	var output := RulesFormatter.regiment_of_renown(regiment)
	for value in ["3", "Made-up Troops", "incl. Banner", "1", "Made-up Lord"]:
		assert_string_contains(output, value)


func test_regiment_of_renown_unit_without_notes_has_no_empty_brackets() -> void:
	var output := RulesFormatter.regiment_of_renown(_regiment({units = [_regiment_unit(1, "Made-up Lord")]}))
	assert_false(output.contains("()"), output)


func test_regiment_of_renown_omits_units_section_without_units() -> void:
	assert_false(RulesFormatter.regiment_of_renown(_regiment()).contains("Units"))


func test_regiment_of_renown_contains_abilities() -> void:
	var regiment := _regiment({abilities = [_ability({name = "Regiment Ability"})] as Array[Ability]})
	assert_string_contains(RulesFormatter.regiment_of_renown(regiment), "Regiment Ability")


func test_regiment_of_renown_contains_its_warscrolls() -> void:
	var regiment := _regiment({warscrolls = [_warscroll({name = "Regiment Hero"})] as Array[Warscroll]})
	assert_string_contains(RulesFormatter.regiment_of_renown(regiment), "Regiment Hero")


func test_regiment_of_renown_escapes_bbcode_in_text() -> void:
	var output := RulesFormatter.regiment_of_renown(_regiment({text = "Take [b]bold[/b] steps."}))
	assert_false(output.contains("Take [b]bold"), output)


func test_regiment_of_renown_escapes_bbcode_in_unit_names() -> void:
	var regiment := _regiment({units = [_regiment_unit(1, "[url]Evil[/url]")]})
	assert_false(RulesFormatter.regiment_of_renown(regiment).contains("[url]Evil"))


func test_spearhead_contains_general_and_units() -> void:
	var army := Spearhead.new()
	army.name = "Made-up Spearhead"
	army.general = "Made-up General"
	var unit := SpearheadUnit.new()
	unit.count = 4
	unit.name = "Made-up Troops"
	unit.notes = "incl. Banner"
	army.units = [unit]
	var output := RulesFormatter.spearhead(army)
	for value in [army.general, unit.name, str(unit.count), unit.notes]:
		assert_string_contains(output, value)


func test_spearhead_contains_its_warscrolls() -> void:
	var army := Spearhead.new()
	army.name = "Made-up Spearhead"
	army.warscrolls = [_warscroll({name = "Spearhead Unit"})]
	assert_string_contains(RulesFormatter.spearhead(army), army.warscrolls[0].name)


func test_spearhead_omits_empty_ability_sections() -> void:
	var army := Spearhead.new()
	army.name = "Made-up Spearhead"
	var with_traits := Spearhead.new()
	with_traits.name = army.name
	with_traits.battle_traits = [_ability()]
	assert_lt(RulesFormatter.spearhead(army).count("[font_size="),
			RulesFormatter.spearhead(with_traits).count("[font_size="))


func test_rules_section_contains_name_text_and_warscrolls() -> void:
	var section := RulesSection.new()
	section.name = "Made-up Section"
	section.text = "Section body."
	section.warscrolls = [_warscroll({name = "Section Unit"})]
	var output := RulesFormatter.rules_section(section)
	for value in [section.name, section.text, section.warscrolls[0].name]:
		assert_string_contains(output, value)


func test_warscroll_heading_can_be_left_out() -> void:
	var unit := _warscroll()
	assert_string_contains(RulesFormatter.warscroll(unit), RulesFormatter.heading(unit.name))
	assert_false(RulesFormatter.warscroll(unit, false).contains(RulesFormatter.heading(unit.name)))


func test_warscroll_without_heading_keeps_the_characteristics() -> void:
	var unit := _warscroll({move = "11", health = 13})
	var output := RulesFormatter.warscroll(unit, false)
	assert_string_contains(output, "11")
	assert_string_contains(output, "13")


# ability_body

func test_ability_body_omits_name_timing_and_source() -> void:
	var rule := _ability({timing = "Some Phase", source = "Some Book", text = "Body text."})
	var body := RulesFormatter.ability_body(rule)
	assert_false(body.contains(rule.name))
	assert_false(body.contains(rule.timing))
	assert_false(body.contains(rule.source))


func test_ability_body_includes_text_declare_and_effect() -> void:
	var rule := _ability({text = "Plain text.", declare = "Pick a unit.", effect = "It gets stronger."})
	var body := RulesFormatter.ability_body(rule)
	assert_string_contains(body, rule.text)
	assert_string_contains(body, rule.declare)
	assert_string_contains(body, rule.effect)


func test_ability_body_of_an_empty_ability_is_empty() -> void:
	assert_eq(RulesFormatter.ability_body(_ability()), "")


func test_ability_includes_the_body() -> void:
	var rule := _ability({declare = "Pick a unit."})
	assert_string_contains(RulesFormatter.ability(rule), RulesFormatter.ability_body(rule))
