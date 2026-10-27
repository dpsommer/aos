class_name RegimentPanel
extends PanelContainer
## A regiment in the army list: its name, points and units, and buttons to change them.

var builder: ArmyBuilder
var regiment: ArmyRegiment
var _header_row: HBoxContainer


func _init(army_builder: ArmyBuilder, army_regiment: ArmyRegiment) -> void:
	builder = army_builder
	regiment = army_regiment
	var renown := regiment.is_regiment_of_renown()
	theme_type_variation = "RenownRegimentPanel" if renown else "RegimentPanel"
	set_meta(&"regiment_id", regiment.id)
	_header_row = _header()
	var content := BuilderUI.vbox([_header_row], 8)
	if not builder.collapsed.has(regiment.id):
		for unit in regiment.units:
			content.add_child(UnitRow.new(builder, unit, regiment))
		if not renown:
			content.add_child(_add_button())
	add_child(content)
	BuilderDragDrop.pass_mouse(self)


## Regiments take dragged regiments before or after them, and units at their end.
func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var drag := builder.drag
	if data.get("kind") == "reg":
		if data.get("regiment_id") == regiment.id:
			return false
		drag.show_line(self, get_global_rect(), at.y > size.y / 2, 6)
		return true
	if drag.accepts_unit(data, regiment):
		var rows := _header_row.get_parent().get_children().filter(func(n: Node) -> bool: return n is UnitRow)
		drag.show_line_in(self, rows, rows.size(), _header_row)
		return true
	return false


func _drop_data(at: Vector2, data: Variant) -> void:
	if data.get("kind") == "reg":
		var index := builder.editor.army.regiments.find(regiment) + (1 if at.y > size.y / 2 else 0)
		builder.editor.move_regiment(data.regiment_id, index)
	else:
		builder.drag.place_unit(data, regiment, regiment.units.size())


## Up and Down on the grip move the regiment in the army list.
func _on_grip_input(event: InputEvent, grip: Button) -> void:
	var step := -1 if event.is_action_pressed("ui_up", true) else 1 if event.is_action_pressed("ui_down", true) else 0
	if step == 0:
		return
	grip.accept_event()
	var regiments := builder.editor.army.regiments
	var to := regiments.find(regiment) + step
	if to >= 0 and to < regiments.size():
		builder.editor.move_regiment(regiment.id, to + (1 if step > 0 else 0))


func _header() -> HBoxContainer:
	var editor := builder.editor
	var key := regiment.id + ":"
	var row := BuilderUI.hbox([], 8)
	var open := not builder.collapsed.has(regiment.id)
	var grip := BuilderUI.icon_button("grip", "Reorder regiment: drag, or use the arrow keys", func() -> void: pass,
			key + "grip", "GripButton")
	grip.mouse_default_cursor_shape = Control.CURSOR_MOVE
	grip.gui_input.connect(_on_grip_input.bind(grip))
	builder.drag.source(grip, {"kind": "reg", "regiment_id": regiment.id}, regiment.name, self)
	row.add_child(grip)
	row.add_child(BuilderUI.icon_button("chevron_down" if open else "chevron_right",
			"Collapse regiment" if open else "Expand regiment", builder.toggle_collapsed.bind(regiment.id), key + "collapse"))
	if builder.renaming == regiment.id:
		var edit := LineEdit.new()
		edit.text = regiment.name
		edit.tooltip_text = "Regiment name"
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.set_meta(&"focus_key", key + "name")
		edit.text_submitted.connect(func(text: String) -> void: builder.finish_renaming(regiment.id, text))
		edit.focus_exited.connect(func() -> void: builder.finish_renaming(regiment.id, edit.text))
		row.add_child(edit)
	else:
		var title := BuilderUI.label(regiment.name, "SectionLabel")
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		if regiment.is_regiment_of_renown():
			row.add_child(ForgeTheme.chip("Regiment of Renown", "gold"))
	var points := ArmyPoints.regiment_points(regiment, editor.army, builder.catalog)
	if regiment.is_regiment_of_renown() or regiment.units.is_empty():
		row.add_child(BuilderUI.label("%d pts" % points, "MutedLabel"))
	else:
		var capacity := ArmyValidator.regiment_capacity(regiment, editor.army)
		row.add_child(BuilderUI.label("%d/%d units · %d pts" % [regiment.units.size() - 1, capacity, points], "MutedLabel"))
	if not regiment.is_regiment_of_renown():
		row.add_child(BuilderUI.icon_button("rename", "Rename regiment", builder.start_renaming.bind(regiment.id), key + "rename"))
	row.add_child(BuilderUI.icon_button("delete", "Delete regiment", editor.remove_regiment.bind(regiment.id), key + "delete",
			"DangerIconButton"))
	return row


func _add_button() -> Button:
	var editor := builder.editor
	var key := regiment.id + ":add"
	if regiment.units.is_empty():
		return BuilderUI.button("Choose a leader", func() -> void: builder.pick_leader(regiment.id), key, "GhostButton")
	var add := BuilderUI.button("Add unit", func() -> void: builder.pick_unit(regiment.id), key, "GhostButton")
	if not editor.has_room(regiment):
		add.disabled = true
		add.tooltip_text = "This regiment is full"
	return add
