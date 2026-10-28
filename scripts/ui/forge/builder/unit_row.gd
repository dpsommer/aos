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
	if builder.expanded.has(unit.uid) and has_options():
		content.add_child(_options())
	add_child(content)
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
		if not builder.catalog.enhancement_choices(army, warscroll, type, unit.enhancements.get(type, "")).is_empty():
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


func _summary() -> HBoxContainer:
	var editor := builder.editor
	var army := editor.army
	var renown := _in_renown()
	var title := warscroll.name if warscroll else unit.warscroll_id
	var shown := unit.label if not unit.label.is_empty() else title
	var key := unit.uid + ":"
	var name_line: Control
	if builder.renaming == unit.uid:
		name_line = _name_edit()
	else:
		var heading := UIBuilder.label(shown)
		heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		heading.tooltip_text = shown
		heading.mouse_filter = Control.MOUSE_FILTER_PASS
		name_line = InlineLine.new()
		name_line.add_child(heading)
		if not renown:
			name_line.add_child(UIBuilder.icon_button("rename", "Rename unit", builder.start_renaming.bind(unit.uid),
					key + "rename", "SmallIconButton"))
	var detail := UIBuilder.label(subtext(unit, regiment, army, warscroll), "MutedLabel")
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.tooltip_text = detail.text
	detail.mouse_filter = Control.MOUSE_FILTER_PASS
	var sub := InlineLine.new(6)
	sub.add_child(detail)
	if warscroll:
		for tag in UIBuilder.tags(warscroll):
			sub.add_child(tag)
	var names := UIBuilder.vbox([name_line, sub], 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var portrait: Control
	if renown:
		portrait = UIBuilder.portrait(title, builder.info_pane.show_regiment_of_renown.bind(regiment.regiment_of_renown),
				"Show %s in Regiments of Renown" % regiment.regiment_of_renown)
	elif warscroll and builder.catalog.find_warscroll(army, warscroll.id) == warscroll:
		portrait = UIBuilder.portrait(title, builder.info_pane.show_unit.bind(warscroll), "Show %s in the Roster" % warscroll.name)
	else:
		portrait = UIBuilder.portrait(title)
	var row := UIBuilder.hbox([portrait, names], 10)
	# The General's crown takes the grip's place on the left, so a Hero leader lines up with the
	# grips of the units below it.
	if regiment and regiment.leader() == unit:
		var general := unit.uid == army.general_uid
		var crown := UIBuilder.icon_toggle("crown", "Remove as general" if general else "Make general", general,
				func(_on: bool) -> void: editor.set_general(unit.uid), key + "general")
		row.add_child(crown)
		row.move_child(crown, 0)
	if movable():
		var grip := UIBuilder.icon_button("grip", "Reorder unit: drag, or use the arrow keys", func() -> void: pass,
				key + "grip", "GripButton")
		grip.mouse_default_cursor_shape = Control.CURSOR_MOVE
		grip.gui_input.connect(_on_grip_input.bind(grip))
		builder.drag.source(grip, {"kind": "unit", "uid": unit.uid}, shown, self)
		row.add_child(grip)
		row.move_child(grip, 0)
	elif renown:
		# Regiment of Renown units can't be reordered, so a gap the width of a grip (a square icon
		# button) lines them up with the units of other regiments.
		var gap := Control.new()
		gap.custom_minimum_size.x = UITheme.icon_button_width("GripButton")
		row.add_child(gap)
		row.move_child(gap, 0)
	if not renown:
		row.add_child(_points())
	if warscroll and warscroll.can_reinforce and not renown:
		row.add_child(UIBuilder.icon_toggle("reinforce", "Unreinforce unit" if unit.reinforced else "Reinforce unit",
				unit.reinforced, func(on: bool) -> void: editor.set_reinforced(unit.uid, on), key + "reinforce"))
	if warscroll and not renown:
		var options := UIBuilder.icon_toggle("options", "Unit options", builder.expanded.has(unit.uid) and has_options(),
				func(_on: bool) -> void: builder.toggle_expanded(unit.uid), key + "options")
		if not has_options():
			options.disabled = true
			options.tooltip_text = "This unit has no options"
		row.add_child(options)
	if not renown:
		row.add_child(UIBuilder.icon_button("copy", "Duplicate unit", func() -> void: editor.duplicate_unit(unit.uid), key + "copy"))
		row.add_child(UIBuilder.icon_button("delete", "Remove unit", func() -> void: editor.remove_unit(unit.uid), key + "remove",
				"DangerIconButton"))
	return row


## The unit's points, followed by a tag with any points its enhancements add, e.g. "150 pts +20".
func _points() -> HBoxContainer:
	var army := builder.editor.army
	var extra := ArmyPoints.enhancement_points(unit, regiment, army, builder.catalog)
	var base := ArmyPoints.unit_points(unit, regiment, army, builder.catalog) - extra
	var box := UIBuilder.hbox([UIBuilder.label("%d pts" % base, "MutedLabel")], 6)
	if extra > 0:
		var tag := UITheme.chip("+%d" % extra, "gold")
		var label := tag.get_child(0)
		tag.remove_child(label)
		var icon := TextureRect.new()
		icon.texture = UITheme.icon("enhancement")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(11, 11)
		icon.modulate = UITheme.WARNING
		tag.add_child(UIBuilder.hbox([label, icon], 4))
		tag.tooltip_text = "+%d points from enhancements" % extra
		tag.mouse_filter = Control.MOUSE_FILTER_PASS
		tag.set_meta(&"enhancement_points", extra)
		box.add_child(tag)
	return box


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
		for table in builder.catalog.enhancement_choices(army, warscroll, type, picked):
			for entry in table.entries:
				section.add_child(_enhancement_card(type, table, entry, entry.name == picked))
		box.add_child(section)

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


## A card for [param entry] of [param table], showing its points, table group, Scourge and Legends
## tags and rules. Pressing it gives the unit the enhancement, or takes it away if [param picked].
func _enhancement_card(type: String, table: EnhancementTable, entry: Ability, picked: bool) -> OptionCard:
	var card := OptionCard.new()
	card.toggle_mode = true
	card.button_pressed = picked
	card.accessibility_name = entry.name
	card.tooltip_text = ("Remove %s" if picked else "Give the unit %s") % entry.name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.set_meta(&"focus_key", "%s:enh:%s:%s" % [unit.uid, type, entry.name])
	card.set_meta(&"enhancement", entry.name)
	# The points are in the ability card's header.
	var top := UIBuilder.hbox([], 6)
	if not table.group.is_empty():
		top.add_child(UITheme.chip(table.group))
	var scourge := UIBuilder.scourge_tag(table.source)
	if scourge:
		top.add_child(scourge)
	if table.legends:
		top.add_child(UITheme.chip("Legends", "legends"))
	top.add_child(UIBuilder.spacer())
	if picked:
		top.add_child(UIBuilder.check_badge())
	if top.get_child_count() > 1:
		card.add(top)
	else:
		top.free()
	card.add(AbilityCard.new(entry))
	card.toggled.connect(func(on: bool) -> void:
		builder.editor.set_enhancement(unit.uid, type, entry.name if on else ""))
	return card


## A label with controls right after its text, such as a unit's name and its rename button, or
## its details and their tags. The label is cut short with an ellipsis when there isn't room for
## all of them.
class InlineLine extends Container:
	var separation: int

	func _init(gap := 4) -> void:
		separation = gap

	func _get_minimum_size() -> Vector2:
		var result := Vector2.ZERO
		for child: Control in get_children():
			result.y = maxf(result.y, child.get_combined_minimum_size().y)
		for child in _trailing():
			result.x += child.get_combined_minimum_size().x + separation
		return result

	func _notification(what: int) -> void:
		if what != NOTIFICATION_SORT_CHILDREN:
			return
		var heading := get_child(0) as Label
		var room := size.x
		for child in _trailing():
			room -= child.get_combined_minimum_size().x + separation
		var text_width := heading.get_theme_font("font").get_string_size(heading.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				heading.get_theme_font_size("font_size")).x + 1
		var x := clampf(text_width, 0, maxf(room, 0))
		fit_child_in_rect(heading, Rect2(0, 0, x, size.y))
		for child in _trailing():
			var child_size := child.get_combined_minimum_size()
			x += separation
			fit_child_in_rect(child, Rect2(x, (size.y - child_size.y) / 2, child_size.x, child_size.y))
			x += child_size.x

	func _trailing() -> Array[Control]:
		var result: Array[Control] = []
		for child in get_children().slice(1):
			result.append(child as Control)
		return result
