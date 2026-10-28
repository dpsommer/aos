class_name RulesView
extends RefCounted
## Builds the faction browser's rules as controls: headings, rules text, [AbilityCard]s,
## [WarscrollCard]s and [LoreCard]s, so they look as they do in the army builder.


## [param summoned], given an ability, returns the manifestations it sets up
## ([method ArmyCatalog.summoned]); their warscrolls are shown under it.
static func abilities(rules: Array[Ability], summoned := Callable()) -> VBoxContainer:
	var box := UIBuilder.vbox([], 10)
	for rule in rules:
		box.add_child(AbilityCard.new(rule))
		if summoned.is_valid():
			for manifestation: Warscroll in summoned.call(rule):
				box.add_child(WarscrollCard.new(manifestation))
	return box


static func enhancement_table(table: EnhancementTable) -> VBoxContainer:
	var title := table.name if table.group.is_empty() else "%s: %s" % [table.name, table.group]
	if not table.source.is_empty():
		title += " (%s)" % table.source
	return _section(title, abilities(table.entries))


static func battle_formation(formation: BattleFormation) -> VBoxContainer:
	return _section("%s (%d pts)" % [formation.name, formation.points], abilities(formation.abilities))


static func warscroll(unit: Warscroll, summoned := Callable()) -> WarscrollCard:
	return WarscrollCard.new(unit, summoned)


static func faction_rules(faction: Faction, summoned := Callable()) -> VBoxContainer:
	var parts := _page()
	if faction.legends:
		parts.add_child(_text("[i]Legends[/i]"))
	if not faction.battle_traits.is_empty():
		parts.add_child(_section("Battle Traits", abilities(faction.battle_traits)))
	for formation in faction.battle_formations:
		parts.add_child(battle_formation(formation))
	for table in faction.enhancement_tables:
		parts.add_child(enhancement_table(table))
	for rules in faction.lores:
		parts.add_child(LoreCard.new(rules, true, "", null, summoned))
	return parts


static func army_of_renown(army: ArmyOfRenown, summoned := Callable()) -> VBoxContainer:
	var parts := _page([heading(army.name)])
	_add_details(parts, army.source, army.legends, army.text)
	if not army.battle_traits.is_empty():
		parts.add_child(_section("Battle Traits", abilities(army.battle_traits)))
	for table in army.enhancement_tables:
		parts.add_child(enhancement_table(table))
	for rules in army.lores:
		parts.add_child(LoreCard.new(rules, true, "", null, summoned))
	return parts


static func regiment_of_renown(regiment: RegimentOfRenown, summoned := Callable()) -> VBoxContainer:
	var parts := _page([heading("%s (%d pts)" % [regiment.name, regiment.points])])
	_add_details(parts, regiment.source, regiment.legends, regiment.text)
	var roster := PackedStringArray()
	for unit in regiment.units:
		roster.append(_roster_line(unit))
	if not roster.is_empty():
		parts.add_child(_text("[b]Units:[/b]\n%s" % "\n".join(roster)))
	if not regiment.abilities.is_empty():
		parts.add_child(abilities(regiment.abilities, summoned))
	for unit in regiment.warscrolls:
		parts.add_child(WarscrollCard.new(unit, summoned))
	return parts


static func spearhead(army: Spearhead, summoned := Callable()) -> VBoxContainer:
	var parts := _page([heading(army.name)])
	if not army.text.is_empty():
		parts.add_child(_text(_escape(army.text)))
	var roster := PackedStringArray(["[b]General:[/b] %s" % _escape(army.general)])
	for unit in army.units:
		roster.append(_roster_line(unit))
	parts.add_child(_text("\n".join(roster)))
	for section: Array in [
		["Battle Traits", army.battle_traits],
		["Regiment Abilities", army.regiment_abilities],
		["Enhancements", army.enhancements],
	]:
		if not section[1].is_empty():
			parts.add_child(_section(section[0], abilities(section[1])))
	for unit in army.warscrolls:
		parts.add_child(WarscrollCard.new(unit, summoned))
	return parts


static func rules_section(section: RulesSection) -> VBoxContainer:
	var parts := _page([heading(section.name)])
	if not section.text.is_empty():
		parts.add_child(_text(_escape(section.text)))
	for unit in section.warscrolls:
		parts.add_child(WarscrollCard.new(unit))
	return parts


static func heading(title: String) -> Label:
	return UIBuilder.label(title, "SectionLabel", true)


## [param title] over [param content].
static func _section(title: String, content: Control) -> VBoxContainer:
	return UIBuilder.vbox([heading(title), content], 10)


## A page of rules, its parts spaced apart.
static func _page(children: Array = []) -> VBoxContainer:
	return UIBuilder.vbox(children, 20)


static func _add_details(parts: VBoxContainer, source: String, legends: bool, text: String) -> void:
	if not source.is_empty():
		parts.add_child(_text("[i]Source: %s[/i]" % _escape(source)))
	if legends:
		parts.add_child(_text("[i]Legends[/i]"))
	if not text.is_empty():
		parts.add_child(_text(_escape(text)))


## A [RegimentUnit] or [SpearheadUnit] in a roster, e.g. "3 Liberators (Reinforced)", indented.
static func _roster_line(unit: Variant) -> String:
	var line := "%d %s" % [unit.count, unit.name]
	if not unit.notes.is_empty():
		line += " (%s)" % unit.notes
	return "[indent]%s[/indent]" % _escape(line)


static func _text(bbcode: String) -> RichTextLabel:
	var label := UIBuilder.rich(bbcode)
	label.selection_enabled = true
	return label


## Stops rules text such as "[Shoot in Combat]" being read as BBCode.
static func _escape(value: String) -> String:
	return value.replace("[", "[lb]")
