class_name WarscrollCard
extends PanelContainer
## A unit's or manifestation's warscroll in its own box: its name, characteristics in boxes, a table
## for each kind of weapon, its abilities and keywords. Shown in the info pane and Regiments of
## Renown cards.

## The width of each characteristic column in the weapon tables. Every table uses it, so a melee
## table's Attacks lines up with a ranged table's above it.
const COLUMN_WIDTH := 36

var warscroll: Warscroll


## [param summoned], given an ability, returns the manifestations and units it sets up
## ([method ArmyCatalog.summoned]); they are shown under it ([method summoned_card]), and
## [param show_summoned], given a summoned unit, shows its full warscroll.
static func create(unit: Warscroll, summoned := Callable(), show_summoned := Callable()) -> WarscrollCard:
	var card: WarscrollCard = load("res://scenes/ui/cards/warscroll_card.tscn").instantiate()
	card._fill(unit, summoned, show_summoned)
	return card


func _fill(unit: Warscroll, summoned: Callable, show_summoned: Callable) -> void:
	warscroll = unit
	_fill_header()
	fill_characteristics(%Characteristics, unit)
	var content: VBoxContainer = %Content
	var damaged := battle_damaged_weapons(unit)
	if not unit.ranged_weapons.is_empty():
		content.add_child(weapon_table(unit.ranged_weapons, true, damaged))
	if not unit.melee_weapons.is_empty():
		content.add_child(weapon_table(unit.melee_weapons, false, damaged))
	for rule in unit.abilities:
		content.add_child(AbilityCard.create(rule))
		if summoned.is_valid():
			for summoned_unit: Warscroll in summoned.call(rule):
				content.add_child(summoned_card(summoned_unit, show_summoned))
	var notes := PackedStringArray()
	if not unit.composition.is_empty():
		notes.append("[b]Unit composition:[/b] %s" % UIBuilder.escape_bbcode(unit.composition))
	if not unit.regiment_options.is_empty():
		notes.append("[b]Regiment options:[/b] %s" % UIBuilder.escape_bbcode(", ".join(unit.regiment_options)))
	if not unit.notes.is_empty():
		notes.append("[b]Notes:[/b] %s" % UIBuilder.escape_bbcode(unit.notes))
	if not notes.is_empty():
		content.add_child(HSeparator.new())
		content.add_child(UIBuilder.rich("\n".join(notes)))
	if not unit.keywords.is_empty():
		content.add_child(UIBuilder.label(" · ".join(unit.keywords).to_upper(), "KeywordsLabel", true))


## What an ability that sets up [param unit] shows under its card: a manifestation's full warscroll,
## or a [SummonedUnitCard] for a unit ([member Warscroll.summoned]), which calls [param on_show], if
## valid, with the unit when pressed.
static func summoned_card(unit: Warscroll, on_show := Callable()) -> Control:
	if not unit.summoned:
		return WarscrollCard.create(unit)
	var card := SummonedUnitCard.create(unit)
	if on_show.is_valid():
		card.make_pressable("Show the %s warscroll" % unit.name)
		card.pressed.connect(on_show.bind(unit))
	return card


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
		values.insert(0, '%d"' % weapon.range_inches)
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
	var table: PanelContainer = load("res://scenes/ui/cards/weapon_table.tscn").instantiate()
	var columns := PackedStringArray(["ATK", "HIT", "WND", "RND", "DMG"])
	if ranged:
		columns.insert(0, "RNG")
		(table.get_node(^"%Icon") as TextureRect).texture = UITheme.icon("aos/white/weapons/ranged_weapon")
		(table.get_node(^"%Title") as Label).text = "RANGED WEAPONS"
	_add_cells(table.get_node(^"%HeaderRow"), columns, "WeaponColumnLabel")
	var rows: VBoxContainer = table.get_node(^"%Rows")
	for weapon in weapons:
		var line: PanelContainer = load("res://scenes/ui/cards/weapon_row.tscn").instantiate()
		(line.get_node(^"%WeaponName") as Label).text = weapon.name
		if not weapon.name in damaged:
			line.get_node(^"%Skull").free()
		_add_cells(line.get_node(^"%Row"), weapon_values(weapon, ranged), "WeaponValueLabel")
		if not weapon.abilities.is_empty():
			var abilities: Label = line.get_node(^"%Abilities")
			abilities.text = ", ".join(weapon.abilities)
			abilities.visible = true
		rows.add_child(line)
	return table


## Adds [param cells] to [param row], each centred in a column of [constant COLUMN_WIDTH].
static func _add_cells(row: HBoxContainer, cells: PackedStringArray, variation: String) -> void:
	for text in cells:
		var cell := UIBuilder.label(text, variation)
		cell.custom_minimum_size.x = COLUMN_WIDTH
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(cell)


func _fill_header() -> void:
	var details := PackedStringArray()
	if warscroll.points > 0:
		details.append("%d pts" % warscroll.points)
	if warscroll.unit_size > 0:
		details.append("%d %s" % [warscroll.unit_size, "model" if warscroll.unit_size == 1 else "models"])
	if warscroll.base_size:
		details.append("%s base" % warscroll.base_size.text())
	if warscroll.can_reinforce:
		details.append("Can be reinforced")
	(%Name as Label).text = warscroll.name
	var subtitle: HBoxContainer = %Subtitle
	if not details.is_empty():
		var label: Label = %Details
		label.text = " · ".join(details)
		label.visible = true
	for tag in UIBuilder.tags(warscroll):
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		subtitle.add_child(tag)
	subtitle.visible = not details.is_empty() or subtitle.get_child_count() > 1
	var header: HBoxContainer = %Header
	var portrait := UIBuilder.portrait(warscroll.name)
	header.add_child(portrait)
	header.move_child(portrait, 0)


## Adds a box to [param row] for each of [param unit]'s [method characteristics].
static func fill_characteristics(row: HBoxContainer, unit: Warscroll) -> void:
	for stat: Array in characteristics(unit):
		var box: PanelContainer = load("res://scenes/ui/cards/stat_box.tscn").instantiate()
		(box.get_node(^"%Value") as Label).text = stat[1]
		(box.get_node(^"%Name") as Label).text = stat[0].to_upper()
		row.add_child(box)
