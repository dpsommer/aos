class_name UnitRow
extends PanelContainer
## One unit in the army list, with buttons for its choices and an expandable options panel.

var builder: ArmyBuilder
var unit: ArmyUnit
var regiment: ArmyRegiment
var warscroll: Warscroll


static func create(army_builder: ArmyBuilder, army_unit: ArmyUnit, army_regiment: ArmyRegiment) -> UnitRow:
	var row: UnitRow = load("res://scenes/ui/forge/builder/unit_row.tscn").instantiate()
	row._fill(army_builder, army_unit, army_regiment)
	return row


func _fill(army_builder: ArmyBuilder, army_unit: ArmyUnit, army_regiment: ArmyRegiment) -> void:
	builder = army_builder
	unit = army_unit
	regiment = army_regiment
	warscroll = builder.catalog.warscroll(unit, regiment)
	set_meta(&"uid", unit.uid)
	_fill_summary()
	if builder.expanded.has(unit.uid) and has_options():
		%Content.add_child(_options())
	if not _in_renown():
		BuilderDragDrop.pass_mouse(self)


## The line under a unit's name: whether it leads its regiment or is the General, its warscroll's
## name if it has been renamed, its model count, its enhancements and its weapon options, e.g.
## "General · 1 model · Sword of Judgement".
static func subtext(army_unit: ArmyUnit, army_regiment: ArmyRegiment, army: Army, unit_warscroll: Warscroll) -> String:
	var parts := PackedStringArray()
	if army_unit.uid == army.general_uid:
		parts.append("General")
	elif army_regiment and army_regiment.leader() == army_unit:
		parts.append("Leader")
	if not army_unit.label.is_empty():
		parts.append(unit_warscroll.name if unit_warscroll else army_unit.warscroll_id)
	if unit_warscroll == null:
		parts.append("No longer in the faction data")
		return " · ".join(parts)
	var models := WeaponOptions.models(unit_warscroll, army_unit.reinforced)
	parts.append("%d %s" % [models, "model" if models == 1 else "models"])
	for type: String in army_unit.enhancements:
		if not army_unit.enhancements[type].is_empty():
			parts.append(army_unit.enhancements[type])
	for option in unit_warscroll.weapon_options:
		var count := WeaponOptions.value(army_unit, option, unit_warscroll)
		if count > 0:
			parts.append("%d × %s" % [count, option.name])
	return " · ".join(parts)


func _in_renown() -> bool:
	return regiment != null and regiment.is_regiment_of_renown()


## The units this row is listed with: its regiment's, or the auxiliary units.
func _list() -> Array[ArmyUnit]:
	return regiment.units if regiment else builder.editor.army.auxiliary


## Whether the unit can be dragged and reordered: not a Hero leader, which stays first.
func movable() -> bool:
	if _in_renown():
		return false
	return regiment == null or regiment.units[0] != unit or builder.editor.insertion_index(regiment, 0) == 0


## Whether the options panel has anything to choose: an enhancement or a weapon option.
func has_options() -> bool:
	if warscroll == null or _in_renown():
		return false
	return not warscroll.weapon_options.is_empty() or not _enhancement_types().is_empty()


## The enhancement types the unit can take.
func _enhancement_types() -> PackedStringArray:
	var result := PackedStringArray()
	if warscroll.has_keyword("UNIQUE"):
		return result
	var army := builder.editor.army
	for type in builder.catalog.enhancement_types(army):
		if not builder.catalog.enhancement_choices(army, warscroll, type, unit.enhancements.get(type, ""), unit).is_empty():
			result.append(type)
	return result


## Where a unit dropped at [param at] goes in this row's list.
func drop_index(at: Vector2) -> int:
	var index := _list().find(unit) + (1 if at.y > size.y / 2 else 0)
	return builder.editor.insertion_index(regiment, index) if regiment else index


func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if not data is Dictionary or _in_renown() or not builder.drag.accepts_unit(data, regiment):
		return false
	var rows := get_parent().get_children().filter(func(n: Node) -> bool: return n is UnitRow)
	builder.drag.show_line_in(self, rows, drop_index(at), self)
	return true


func _drop_data(at: Vector2, data: Variant) -> void:
	builder.drag.place_unit(data, regiment, drop_index(at))


## Up and Down on the grip move the unit within its list.
func _on_grip_input(event: InputEvent, grip: Button) -> void:
	var step := -1 if event.is_action_pressed("ui_up", true) else 1 if event.is_action_pressed("ui_down", true) else 0
	if step == 0:
		return
	grip.accept_event()
	var list := _list()
	var to := list.find(unit) + step
	var first := builder.editor.insertion_index(regiment, 0) if regiment else 0
	if to >= first and to < list.size():
		builder.editor.move_unit(unit.uid, regiment.id if regiment else "", to + (1 if step > 0 else 0))


## Fills in the unit's line from the scene's controls, removing those it doesn't have.
func _fill_summary() -> void:
	var editor := builder.editor
	var army := editor.army
	var renown := _in_renown()
	var title := warscroll.name if warscroll else unit.warscroll_id
	var shown := unit.label if not unit.label.is_empty() else title
	var key := unit.uid + ":"
	var names: VBoxContainer = %Names
	if builder.renaming == unit.uid:
		%NameLine.free()
		var edit := _name_edit()
		names.add_child(edit)
		names.move_child(edit, 0)
	else:
		var heading: Label = %Heading
		heading.text = shown
		heading.tooltip_text = shown
		var rename: Button = %Rename
		if renown:
			rename.free()
		else:
			_key(rename, key + "rename")
			rename.pressed.connect(builder.start_renaming.bind(unit.uid))
	var detail: Label = %Detail
	detail.text = subtext(unit, regiment, army, warscroll)
	detail.tooltip_text = detail.text
	if warscroll:
		for tag in UIBuilder.tags(warscroll):
			%SubLine.add_child(tag)

	var portrait: Control
	if renown:
		portrait = UIBuilder.portrait(title, builder.info_pane.show_regiment_of_renown.bind(regiment.regiment_of_renown),
				"Show %s in Regiments of Renown" % regiment.regiment_of_renown)
	elif warscroll and builder.catalog.find_warscroll(army, warscroll.id) == warscroll:
		portrait = UIBuilder.portrait(title, builder.info_pane.show_unit.bind(warscroll), "Show %s in the Roster" % warscroll.name)
	else:
		portrait = UIBuilder.portrait(title)
	var row: HBoxContainer = %Summary
	row.add_child(portrait)
	row.move_child(portrait, names.get_index())
	# The General's crown takes the grip's place on the left, so a Hero leader lines up with the
	# grips of the units below it.
	var crown: Button = %Crown
	if regiment and regiment.leader() == unit:
		var general := unit.uid == army.general_uid
		crown.button_pressed = general
		crown.tooltip_text = "Remove as general" if general else "Make general"
		crown.accessibility_name = crown.tooltip_text
		_key(crown, key + "general")
		crown.toggled.connect(func(_on: bool) -> void: editor.set_general(unit.uid))
		# Before the grip, as the crown went to the front first.
		row.move_child(crown, 0)
	else:
		crown.free()
	var grip: Button = %Grip
	var gap: Control = %Gap
	if movable():
		_key(grip, key + "grip")
		grip.gui_input.connect(_on_grip_input.bind(grip))
		builder.drag.source(grip, {"kind": "unit", "uid": unit.uid}, shown, self)
		row.move_child(grip, 0)
		gap.free()
	elif renown:
		# Regiment of Renown units can't be reordered, so a gap the width of a grip (a square icon
		# button) lines them up with the units of other regiments.
		gap.custom_minimum_size.x = UITheme.icon_button_width("GripButton")
		row.move_child(gap, 0)
		grip.free()
	else:
		grip.free()
		gap.free()
	if renown:
		%Points.free()
	else:
		_fill_points()
	var reinforce: Button = %Reinforce
	if warscroll and warscroll.can_reinforce and not renown:
		reinforce.button_pressed = unit.reinforced
		reinforce.tooltip_text = "Unreinforce unit" if unit.reinforced else "Reinforce unit"
		reinforce.accessibility_name = reinforce.tooltip_text
		_key(reinforce, key + "reinforce")
		reinforce.toggled.connect(func(on: bool) -> void: editor.set_reinforced(unit.uid, on))
	else:
		reinforce.free()
	var options: Button = %Options
	if warscroll and not renown:
		options.button_pressed = builder.expanded.has(unit.uid) and has_options()
		_key(options, key + "options")
		options.toggled.connect(func(_on: bool) -> void: builder.toggle_expanded(unit.uid))
		if not has_options():
			options.disabled = true
			options.tooltip_text = "This unit has no options"
	else:
		options.free()
	var copy: Button = %Copy
	var remove: Button = %Remove
	if renown:
		copy.free()
		remove.free()
	else:
		_key(copy, key + "copy")
		copy.pressed.connect(func() -> void: editor.duplicate_unit(unit.uid))
		_key(remove, key + "remove")
		remove.pressed.connect(func() -> void: editor.remove_unit(unit.uid))


static func _key(control: Control, key: String) -> void:
	control.set_meta(&"focus_key", key)


## The unit's points, followed by a tag with any points its enhancements add, e.g. "150 pts +20".
func _fill_points() -> void:
	var army := builder.editor.army
	var extra := ArmyPoints.enhancement_points(unit, regiment, army, builder.catalog)
	var base := ArmyPoints.unit_points(unit, regiment, army, builder.catalog) - extra
	(%BasePoints as Label).text = "%d pts" % base
	var box: HBoxContainer = %Points
	if extra > 0:
		var tag: PanelContainer = load("res://scenes/ui/forge/builder/enhancement_points_tag.tscn").instantiate()
		tag.add_theme_stylebox_override("panel", UITheme.chip_style("gold"))
		var label: Label = tag.get_node(^"%Label")
		label.text = "+%d" % extra
		label.add_theme_color_override("font_color", UITheme.chip_text_colour("gold"))
		tag.tooltip_text = "+%d points from enhancements" % extra
		tag.set_meta(&"enhancement_points", extra)
		box.add_child(tag)


## The field that replaces the unit's name while it's renamed. A blank name goes back to the
## warscroll's.
func _name_edit() -> LineEdit:
	var edit := LineEdit.new()
	edit.text = unit.label
	edit.placeholder_text = warscroll.name if warscroll else unit.warscroll_id
	edit.tooltip_text = "Unit name"
	edit.accessibility_name = "Unit name"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.set_meta(&"focus_key", unit.uid + ":label")
	edit.text_submitted.connect(finish_renaming)
	edit.focus_exited.connect(func() -> void: finish_renaming(edit.text))
	return edit


## Names the unit [param text] if it's being renamed, and stops renaming.
func finish_renaming(text: String) -> void:
	if builder.renaming != unit.uid:
		return
	builder.renaming = ""
	if text.strip_edges() != unit.label:
		builder.editor.set_label(unit.uid, text)
	else:
		builder.redraw()


func _options() -> VBoxContainer:
	var editor := builder.editor
	var army := editor.army
	var key := unit.uid + ":"
	var box := UIBuilder.vbox([], 8)

	for type in _enhancement_types():
		var section := UIBuilder.vbox([UIBuilder.label(type, "SectionLabel")], 8)
		section.set_meta(&"enhancement_type", type)
		var picked: String = unit.enhancements.get(type, "")
		var tables := builder.catalog.enhancement_choices(army, warscroll, type, picked, unit)
		for i in tables.size():
			var table := tables[i]
			# A rule between sources, e.g. the battletome's tables and a Scourge's.
			if i > 0 and table.source != tables[i - 1].source:
				section.add_child(HSeparator.new())
			for entry in table.entries:
				section.add_child(_enhancement_card(type, table, entry, entry.name == picked))
		box.add_child(section)

	for option in warscroll.weapon_options:
		var option_row: HBoxContainer = load("res://scenes/ui/forge/builder/weapon_option_row.tscn").instantiate()
		var spin: SpinBox = option_row.get_node(^"%Count")
		spin.max_value = WeaponOptions.cap(option, warscroll, unit.reinforced)
		spin.value = WeaponOptions.value(unit, option, warscroll)
		spin.tooltip_text = "Models with a %s" % option.name
		spin.set_meta(&"focus_key", key + "wopt:" + option.name)
		spin.value_changed.connect(func(value: float) -> void: editor.set_weapon_option(unit.uid, option.name, int(value)))
		var note := "Instead of %s" % option.replaces if option.choice \
				else "Replaces %s · %d per %d models" % [option.replaces, option.max_models, option.per]
		if not option.note.is_empty():
			note += " · " + option.note
		(option_row.get_node(^"%Name") as Label).text = option.name
		(option_row.get_node(^"%Note") as Label).text = note
		box.add_child(option_row)
	return box


## A card for [param entry] of [param table], showing its points, table group, Scourge and Legends
## tags in its header, folded until its chevron unfolds it. Pressing it gives the unit the
## enhancement, or takes it away if [param picked].
func _enhancement_card(type: String, table: EnhancementTable, entry: Ability, picked: bool) -> AbilityChoiceCard:
	var key := "%s:enh:%s:%s" % [unit.uid, type, entry.name]
	var fold_key := key + ":fold"
	var card := AbilityChoiceCard.create(entry, builder.expanded.has(fold_key), fold_key)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.set_meta(&"focus_key", key)
	card.set_meta(&"enhancement", entry.name)
	if not table.group.is_empty():
		card.add_header_control(UITheme.chip(table.group))
	var scourge := UIBuilder.scourge_tag(table.source)
	if scourge:
		card.add_header_control(scourge)
	if table.legends:
		card.add_header_control(UITheme.chip("Legends", "legends"))
	card.selected = picked
	# The chevron folds the card in place, so the row isn't redrawn.
	card.fold_toggled.connect(func(on: bool) -> void:
		if on:
			builder.expanded[fold_key] = true
		else:
			builder.expanded.erase(fold_key))
	card.pressed.connect(func() -> void:
		builder.editor.set_enhancement(unit.uid, type, "" if picked else entry.name))
	return card
