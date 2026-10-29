class_name WarscrollCard
extends PanelContainer
## A unit's or manifestation's warscroll in its own box: its name, characteristics in boxes, a table
## for each kind of weapon, its abilities and keywords. Shown in the info pane and Regiments of
## Renown cards.

## The width of each characteristic column in the weapon tables. Every table uses it, so a melee
## table's Attacks lines up with a ranged table's above it.
const COLUMN_WIDTH := 36

var warscroll: Warscroll


## [param summoned], given an ability, returns the manifestations it sets up
## ([method ArmyCatalog.summoned]); their warscrolls are shown under it.
func _init(unit: Warscroll, summoned := Callable()) -> void:
	warscroll = unit
	theme_type_variation = "WarscrollPanel"
	var content := UIBuilder.vbox([_header(), _characteristics()], 10)
	var damaged := battle_damaged_weapons(unit)
	if not unit.ranged_weapons.is_empty():
		content.add_child(weapon_table(unit.ranged_weapons, true, damaged))
	if not unit.melee_weapons.is_empty():
		content.add_child(weapon_table(unit.melee_weapons, false, damaged))
	for rule in unit.abilities:
		content.add_child(AbilityCard.new(rule))
		if summoned.is_valid():
			for manifestation: Warscroll in summoned.call(rule):
				content.add_child(WarscrollCard.new(manifestation))
	var notes := PackedStringArray()
	if not unit.composition.is_empty():
		notes.append("[b]Unit composition:[/b] %s" % unit.composition.replace("[", "[lb]"))
	if not unit.regiment_options.is_empty():
		notes.append("[b]Regiment options:[/b] %s" % ", ".join(unit.regiment_options).replace("[", "[lb]"))
	if not unit.notes.is_empty():
		notes.append("[b]Notes:[/b] %s" % unit.notes.replace("[", "[lb]"))
	if not notes.is_empty():
		content.add_child(HSeparator.new())
		content.add_child(UIBuilder.rich("\n".join(notes)))
	if not unit.keywords.is_empty():
		content.add_child(UIBuilder.label(" · ".join(unit.keywords).to_upper(), "KeywordsLabel", true))
	add_child(content)


## The characteristics shown in boxes, in warscroll order, as [name, value] pairs. Manifestations
## have a banishment value in place of Control.
static func characteristics(unit: Warscroll) -> Array:
	var result := [["Move", '%s"' % unit.move if unit.move != "0" else "-"], ["Health", str(unit.health)]]
	if unit.banishment == 0:
		result.append(["Control", str(unit.control)])
	result.append(["Save", "%d+" % unit.save])
	if unit.ward > 0:
		result.append(["Ward", "%d+" % unit.ward])
	if unit.banishment > 0:
		result.append(["Banish", "%d+" % unit.banishment])
	return result


## A weapon's characteristics in table order: Range (ranged weapons only), Attacks, Hit, Wound, Rend
## and Damage.
static func weapon_values(weapon: Weapon, ranged: bool) -> PackedStringArray:
	var values := PackedStringArray([weapon.attacks, "%d+" % weapon.hit, "%d+" % weapon.wound,
			str(weapon.rend) if weapon.rend > 0 else "-", weapon.damage])
	if ranged:
		values.insert(0, '%d"' % weapon.range)
	return values


## The names of [param unit]'s weapons that its Battle Damaged ability changes: those its rules
## name, either in full or, for a weapon with several profiles such as "Menhir Club: Crushing Blow",
## by the part before the colon.
static func battle_damaged_weapons(unit: Warscroll) -> PackedStringArray:
	var result := PackedStringArray()
	for rule in unit.abilities:
		if not AbilityCard.is_battle_damaged(rule):
			continue
		var text := " ".join([rule.text, rule.declare, rule.effect]).to_lower()
		for weapon in unit.ranged_weapons + unit.melee_weapons:
			if weapon.name.to_lower() in text or weapon.name.get_slice(":", 0).strip_edges().to_lower() in text:
				result.append(weapon.name)
	return result


## The profiles of [param weapons] in a box, under a header naming the kind of weapon and each column.
## Weapons named in [param damaged] have a skull before their name, linking them to the unit's
## Battle Damaged ability ([method battle_damaged_weapons]).
static func weapon_table(weapons: Array[Weapon], ranged: bool, damaged := PackedStringArray()) -> PanelContainer:
	var columns := PackedStringArray(["ATK", "HIT", "WND", "RND", "DMG"])
	if ranged:
		columns.insert(0, "RNG")
	var icon := _icon("aos/white/weapons/ranged_weapon" if ranged else "aos/white/treasure/weapons", 15)
	var title := UIBuilder.label("RANGED WEAPONS" if ranged else "MELEE WEAPONS", "WeaponTitleLabel")
	var heading := UIBuilder.hbox([icon, title], 6)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var table := UIBuilder.vbox([UIBuilder.panel("WeaponHeaderPanel", _row(heading, columns, "WeaponColumnLabel"))], 0)
	for weapon in weapons:
		var weapon_name: Control = UIBuilder.label(weapon.name, "WeaponNameLabel", true)
		if weapon.name in damaged:
			var skull := _icon(AbilityCard.BATTLE_DAMAGED_ICON, 13)
			skull.tooltip_text = "Changed by Battle Damaged"
			skull.mouse_filter = Control.MOUSE_FILTER_PASS
			skull.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			weapon_name = UIBuilder.hbox([skull, weapon_name], 5)
		var line := UIBuilder.vbox([_row(weapon_name, weapon_values(weapon, ranged), "WeaponValueLabel")], 2)
		if not weapon.abilities.is_empty():
			line.add_child(UIBuilder.label(", ".join(weapon.abilities), "MutedLabel", true))
		table.add_child(UIBuilder.panel("WeaponRowPanel", line))
	return UIBuilder.panel("WeaponTablePanel", table)


## [param icon_name] from assets/2d/icons at [param size] pixels, in the weapon tables' pale text colour.
static func _icon(icon_name: String, size: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = UITheme.icon(icon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(size, size)
	icon.modulate = Color("#D8D2C4")
	return icon


## [param first] followed by [param cells], each centred in a column of [constant COLUMN_WIDTH].
static func _row(first: Control, cells: PackedStringArray, variation: String) -> HBoxContainer:
	first.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIBuilder.hbox([first], 4)
	for text in cells:
		var cell := UIBuilder.label(text, variation)
		cell.custom_minimum_size.x = COLUMN_WIDTH
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(cell)
	return row


func _header() -> HBoxContainer:
	var details := PackedStringArray()
	if warscroll.points > 0:
		details.append("%d pts" % warscroll.points)
	if warscroll.unit_size > 0:
		details.append("%d %s" % [warscroll.unit_size, "model" if warscroll.unit_size == 1 else "models"])
	if not warscroll.base_size.is_empty():
		details.append("%s base" % warscroll.base_size)
	if warscroll.can_reinforce:
		details.append("Can be reinforced")
	var title := UIBuilder.label(warscroll.name, "WarscrollNameLabel", true)
	var subtitle := UIBuilder.hbox([], 6)
	if not details.is_empty():
		subtitle.add_child(UIBuilder.label(" · ".join(details), "MutedLabel", true))
	for tag in UIBuilder.tags(warscroll):
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		subtitle.add_child(tag)
	var names := UIBuilder.vbox([title], 2)
	if subtitle.get_child_count() > 0:
		names.add_child(subtitle)
	else:
		subtitle.free()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	return UIBuilder.hbox([UIBuilder.portrait(warscroll.name), names], 10)


func _characteristics() -> HBoxContainer:
	var row := UIBuilder.hbox([], 6)
	for stat: Array in characteristics(warscroll):
		var value := UIBuilder.label(stat[1], "StatValueLabel")
		var key := UIBuilder.label(stat[0].to_upper(), "StatNameLabel")
		for label in [value, key]:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var box := UIBuilder.panel("StatPanel", UIBuilder.vbox([value, key], 2))
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(box)
	return row
