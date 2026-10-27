class_name UnitRow
extends PanelContainer
## One unit in the army list, with buttons for its choices and an expandable options panel.

var builder: ArmyBuilder
var unit: ArmyUnit
var regiment: ArmyRegiment
var warscroll: Warscroll


func _init(army_builder: ArmyBuilder, army_unit: ArmyUnit, army_regiment: ArmyRegiment) -> void:
	builder = army_builder
	unit = army_unit
	regiment = army_regiment
	warscroll = builder.catalog.warscroll(unit, regiment)
	theme_type_variation = "RowPanel"
	set_meta(&"uid", unit.uid)
	var content := UIBuilder.vbox([_summary()], 8)
	if builder.expanded.has(unit.uid) and warscroll:
		content.add_child(_options())
	add_child(content)
	if not _in_renown():
		BuilderDragDrop.pass_mouse(self)


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


func _summary() -> HBoxContainer:
	var editor := builder.editor
	var army := editor.army
	var title := warscroll.name if warscroll else unit.warscroll_id
	var heading := UIBuilder.label(unit.label if not unit.label.is_empty() else title)
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.tooltip_text = heading.text
	heading.mouse_filter = Control.MOUSE_FILTER_PASS
	var names := UIBuilder.vbox([heading], 2)
	var details := PackedStringArray()
	if not unit.label.is_empty():
		details.append(title)
	if warscroll and warscroll.unit_size > 1:
		details.append("%d models" % WeaponOptions.models(warscroll, unit.reinforced))
	if warscroll == null:
		details.append("No longer in the faction data")
	var detail := UIBuilder.label(" · ".join(details), "MutedLabel")
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var sub := HFlowContainer.new()
	sub.add_child(detail)
	if warscroll:
		for tag in UIBuilder.tags(warscroll):
			sub.add_child(tag)
	for type: String in unit.enhancements:
		sub.add_child(UITheme.chip(unit.enhancements[type], "gold"))
	names.add_child(sub)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var renown := regiment != null and regiment.is_regiment_of_renown()
	var portrait: Control
	if renown:
		portrait = UIBuilder.portrait(title, builder.info_pane.show_regiment_of_renown.bind(regiment.regiment_of_renown),
				"Show %s in Regiments of Renown" % regiment.regiment_of_renown)
	elif warscroll and warscroll in builder.catalog.faction.warscrolls:
		portrait = UIBuilder.portrait(title, builder.info_pane.show_unit.bind(warscroll), "Show %s in the Roster" % warscroll.name)
	else:
		portrait = UIBuilder.portrait(title)
	var row := UIBuilder.hbox([portrait, names], 10)
	if movable():
		var grip := UIBuilder.icon_button("grip", "Reorder unit: drag, or use the arrow keys", func() -> void: pass,
				unit.uid + ":grip", "GripButton")
		grip.mouse_default_cursor_shape = Control.CURSOR_MOVE
		grip.gui_input.connect(_on_grip_input.bind(grip))
		builder.drag.source(grip, {"kind": "unit", "uid": unit.uid}, heading.text, self)
		row.add_child(grip)
		row.move_child(grip, 0)
	if not renown:
		row.add_child(UIBuilder.label("%d pts" % ArmyPoints.unit_points(unit, regiment, army, builder.catalog), "MutedLabel"))
	var key := unit.uid + ":"
	if regiment and regiment.leader() == unit:
		var general := unit.uid == army.general_uid
		row.add_child(UIBuilder.icon_toggle("crown", "Remove as general" if general else "Make general", general,
				func(_on: bool) -> void: editor.set_general(unit.uid), key + "general"))
	if warscroll and warscroll.can_reinforce and not renown:
		row.add_child(UIBuilder.icon_toggle("reinforce", "Unreinforce unit" if unit.reinforced else "Reinforce unit",
				unit.reinforced, func(on: bool) -> void: editor.set_reinforced(unit.uid, on), key + "reinforce"))
	if warscroll and not renown:
		row.add_child(UIBuilder.icon_toggle("options", "Unit options", builder.expanded.has(unit.uid),
				func(_on: bool) -> void: builder.toggle_expanded(unit.uid), key + "options"))
	if not renown:
		row.add_child(UIBuilder.icon_button("copy", "Duplicate unit", func() -> void: editor.duplicate_unit(unit.uid), key + "copy"))
		row.add_child(UIBuilder.icon_button("delete", "Remove unit", func() -> void: editor.remove_unit(unit.uid), key + "remove",
				"DangerIconButton"))
	return row


func _options() -> VBoxContainer:
	var editor := builder.editor
	var army := editor.army
	var key := unit.uid + ":"
	var box := UIBuilder.vbox([], 8)

	var name_edit := LineEdit.new()
	name_edit.placeholder_text = warscroll.name
	name_edit.text = unit.label
	name_edit.tooltip_text = "Unit name"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.set_meta(&"focus_key", key + "label")
	var commit := func(_text := "") -> void:
		if name_edit.text != unit.label:
			editor.set_label(unit.uid, name_edit.text)
	name_edit.text_submitted.connect(commit)
	name_edit.focus_exited.connect(commit)
	box.add_child(UIBuilder.hbox([UIBuilder.label("Name", "MutedLabel"), name_edit]))

	if not warscroll.has_keyword("UNIQUE"):
		for type in builder.catalog.enhancement_types(army):
			var tables := builder.catalog.enhancement_choices(army, warscroll, type, unit.enhancements.get(type, ""))
			if tables.is_empty():
				continue
			var items := [["None", ""]]
			for table in tables:
				for entry in table.entries:
					var group := " (%s)" % table.group if not table.group.is_empty() else ""
					var legends := " (Legends)" if table.legends else ""
					items.append(["%s%s%s%s" % [entry.name, " · %d pts" % entry.points if entry.points else "", group, legends], entry.name])
			var picker := UIBuilder.select(items, unit.enhancements.get(type, ""),
					func(value: String) -> void: editor.set_enhancement(unit.uid, type, value), key + "enh:" + type, type)
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_child(UIBuilder.hbox([UIBuilder.label(type, "MutedLabel"), picker]))

	for option in warscroll.weapon_options:
		var spin := SpinBox.new()
		spin.max_value = WeaponOptions.cap(option, warscroll, unit.reinforced)
		spin.value = WeaponOptions.value(unit, option, warscroll)
		spin.tooltip_text = "Models with a %s" % option.name
		spin.set_meta(&"focus_key", key + "wopt:" + option.name)
		spin.value_changed.connect(func(value: float) -> void: editor.set_weapon_option(unit.uid, option.name, int(value)))
		var note := "Instead of %s" % option.replaces if option.choice \
				else "Replaces %s · %d per %d models" % [option.replaces, option.max, option.per]
		if not option.note.is_empty():
			note += " · " + option.note
		var text := UIBuilder.vbox([UIBuilder.label(option.name), UIBuilder.label(note, "MutedLabel", true)], 2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(UIBuilder.hbox([text, spin]))
	return box
