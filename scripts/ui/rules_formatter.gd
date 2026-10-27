class_name RulesFormatter
extends RefCounted
## Turns faction data into BBCode for display in a [RichTextLabel].


static func ability(rule: Ability) -> String:
	var header := PackedStringArray()
	for part in [rule.frequency, rule.timing]:
		if not part.is_empty():
			header.append(part)
	if rule.casting_value > 0:
		header.append("Casting value %d" % rule.casting_value)
	if rule.chanting_value > 0:
		header.append("Chanting value %d" % rule.chanting_value)
	if rule.points > 0:
		header.append("%d pts" % rule.points)
	var lines := PackedStringArray(["[b]%s[/b]" % _escape(rule.name)])
	if not header.is_empty():
		lines.append("[i]%s[/i]" % _escape(", ".join(header)))
	if not rule.text.is_empty():
		lines.append(_escape(rule.text))
	if not rule.declare.is_empty():
		lines.append("[b]Declare:[/b] %s" % _escape(rule.declare))
	if not rule.effect.is_empty():
		lines.append("[b]Effect:[/b] %s" % _escape(rule.effect))
	for option in rule.options:
		lines.append("[indent][b]%s:[/b] %s[/indent]" % [_escape(option.name), _escape(option.text)])
	if not rule.keywords.is_empty():
		lines.append("[b]Keywords:[/b] %s" % _escape(", ".join(rule.keywords)))
	if not rule.source.is_empty():
		lines.append("[i]Source: %s[/i]" % _escape(rule.source))
	return "\n".join(lines)


static func abilities(rules: Array[Ability]) -> String:
	var parts := PackedStringArray()
	for rule in rules:
		parts.append(ability(rule))
	return "\n\n".join(parts)


static func enhancement_table(table: EnhancementTable) -> String:
	var title := table.name if table.group.is_empty() else "%s: %s" % [table.name, table.group]
	if not table.source.is_empty():
		title += " (%s)" % table.source
	return "%s\n\n%s" % [heading(title), abilities(table.entries)]


static func lore(rules: Lore) -> String:
	var title := rules.name if rules.points == 0 else "%s (%d pts)" % [rules.name, rules.points]
	if not rules.source.is_empty():
		title += " (%s)" % rules.source
	return "%s\n\n%s" % [heading(title), abilities(rules.entries)]


static func battle_formation(formation: BattleFormation) -> String:
	return "%s\n\n%s" % [heading("%s (%d pts)" % [formation.name, formation.points]), abilities(formation.abilities)]


## [param with_heading] is false where the unit's name is already shown, e.g. in a roster card.
static func warscroll(unit: Warscroll, with_heading := true) -> String:
	var lines := PackedStringArray([heading(unit.name)] if with_heading else [])
	var tags := PackedStringArray()
	if not unit.source.is_empty():
		tags.append(unit.source)
	if unit.legends:
		tags.append("Legends")
	if not tags.is_empty():
		lines.append("[i]%s[/i]" % _escape(", ".join(tags)))
	if unit.unit_size > 0:
		var profile := "%d pts, %d %s" % [unit.points, unit.unit_size, "model" if unit.unit_size == 1 else "models"]
		if not unit.base_size.is_empty():
			profile += ", %s base" % unit.base_size
		if unit.can_reinforce:
			profile += ", can be reinforced"
		lines.append(_escape(profile))
	lines.append("")
	lines.append(_characteristics(unit))
	if not unit.ranged_weapons.is_empty():
		lines.append("")
		lines.append(_weapon_table("Ranged Weapons", unit.ranged_weapons, true))
	if not unit.melee_weapons.is_empty():
		lines.append("")
		lines.append(_weapon_table("Melee Weapons", unit.melee_weapons, false))
	if not unit.abilities.is_empty():
		lines.append("")
		lines.append(abilities(unit.abilities))
	if not unit.composition.is_empty():
		lines.append("")
		lines.append("[b]Unit composition:[/b] %s" % _escape(unit.composition))
	if not unit.regiment_options.is_empty():
		lines.append("[b]Regiment options:[/b] %s" % _escape(", ".join(unit.regiment_options)))
	if not unit.notes.is_empty():
		lines.append("[b]Notes:[/b] %s" % _escape(unit.notes))
	if not unit.keywords.is_empty():
		lines.append("")
		lines.append("[b]Keywords:[/b] %s" % _escape(", ".join(unit.keywords)))
	return "\n".join(lines)


static func faction_rules(faction: Faction) -> String:
	var parts := PackedStringArray()
	if faction.legends:
		parts.append("[i]Legends[/i]")
	if not faction.battle_traits.is_empty():
		parts.append("%s\n\n%s" % [heading("Battle Traits"), abilities(faction.battle_traits)])
	for formation in faction.battle_formations:
		parts.append(battle_formation(formation))
	for table in faction.enhancement_tables:
		parts.append(enhancement_table(table))
	for rules in faction.lores:
		parts.append(lore(rules))
	return "\n\n".join(parts)


static func army_of_renown(army: ArmyOfRenown) -> String:
	var parts := PackedStringArray([heading(army.name)])
	if not army.source.is_empty():
		parts.append("[i]Source: %s[/i]" % _escape(army.source))
	if army.legends:
		parts.append("[i]Legends[/i]")
	if not army.text.is_empty():
		parts.append(_escape(army.text))
	if not army.battle_traits.is_empty():
		parts.append("%s\n\n%s" % [heading("Battle Traits"), abilities(army.battle_traits)])
	for table in army.enhancement_tables:
		parts.append(enhancement_table(table))
	for rules in army.lores:
		parts.append(lore(rules))
	return "\n\n".join(parts)


static func regiment_of_renown(regiment: RegimentOfRenown) -> String:
	var parts := PackedStringArray([heading("%s (%d pts)" % [regiment.name, regiment.points])])
	if not regiment.source.is_empty():
		parts.append("[i]Source: %s[/i]" % _escape(regiment.source))
	if regiment.legends:
		parts.append("[i]Legends[/i]")
	if not regiment.text.is_empty():
		parts.append(_escape(regiment.text))
	var roster := PackedStringArray()
	for unit in regiment.units:
		var line := "%d %s" % [unit.count, unit.name]
		if not unit.notes.is_empty():
			line += " (%s)" % unit.notes
		roster.append("[indent]%s[/indent]" % _escape(line))
	if not roster.is_empty():
		parts.append("[b]Units:[/b]\n%s" % "\n".join(roster))
	if not regiment.abilities.is_empty():
		parts.append(abilities(regiment.abilities))
	for unit in regiment.warscrolls:
		parts.append(warscroll(unit))
	return "\n\n".join(parts)


static func spearhead(army: Spearhead) -> String:
	var parts := PackedStringArray([heading(army.name)])
	if not army.text.is_empty():
		parts.append(_escape(army.text))
	var roster := PackedStringArray(["[b]General:[/b] %s" % _escape(army.general)])
	for unit in army.units:
		var line := "%d %s" % [unit.count, unit.name]
		if not unit.notes.is_empty():
			line += " (%s)" % unit.notes
		roster.append("[indent]%s[/indent]" % _escape(line))
	parts.append("\n".join(roster))
	for section: Array in [
		["Battle Traits", army.battle_traits],
		["Regiment Abilities", army.regiment_abilities],
		["Enhancements", army.enhancements],
	]:
		if not section[1].is_empty():
			parts.append("%s\n\n%s" % [heading(section[0]), abilities(section[1])])
	for unit in army.warscrolls:
		parts.append(warscroll(unit))
	return "\n\n".join(parts)


static func rules_section(section: RulesSection) -> String:
	var parts := PackedStringArray([heading(section.name)])
	if not section.text.is_empty():
		parts.append(_escape(section.text))
	for unit in section.warscrolls:
		parts.append(warscroll(unit))
	return "\n\n".join(parts)


static func heading(title: String) -> String:
	return "[font_size=24][b]%s[/b][/font_size]" % _escape(title)


static func _characteristics(unit: Warscroll) -> String:
	# Manifestations have a banishment value in place of Control.
	var headers := ["Move", "Health", "Save", "Banishment" if unit.banishment > 0 else "Control"]
	var values := ['%s"' % unit.move if unit.move != "0" else "-", str(unit.health), "%d+" % unit.save,
			"%d+" % unit.banishment if unit.banishment > 0 else str(unit.control)]
	if unit.ward > 0:
		headers.append("Ward")
		values.append("%d+" % unit.ward)
	return _table(headers, [values])


static func _weapon_table(title: String, weapons: Array[Weapon], ranged: bool) -> String:
	var headers := [title, "Atk", "Hit", "Wnd", "Rnd", "Dmg"]
	if ranged:
		headers.insert(1, "Rng")
	var rows := []
	for weapon in weapons:
		var label := weapon.name
		if not weapon.abilities.is_empty():
			label += " [%s]" % ", ".join(weapon.abilities)
		var row := [label, weapon.attacks, "%d+" % weapon.hit, "%d+" % weapon.wound,
				str(weapon.rend) if weapon.rend > 0 else "-", weapon.damage]
		if ranged:
			row.insert(1, '%d"' % weapon.range)
		rows.append(row)
	return _table(headers, rows)


static func _table(headers: Array, rows: Array) -> String:
	var cells := PackedStringArray()
	for header in headers:
		cells.append("[cell][b]%s[/b][/cell]" % _escape(header))
	for row: Array in rows:
		for value in row:
			cells.append("[cell]%s[/cell]" % _escape(value))
	return "[table=%d]%s[/table]" % [headers.size(), "".join(cells)]


## Stops rules text such as "[Shoot in Combat]" being read as BBCode.
static func _escape(value: String) -> String:
	return value.replace("[", "[lb]")
