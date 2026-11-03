class_name RegimentPanel
extends PanelContainer
## A regiment in the army list: its name, points and units, and buttons to change them.

var builder: ArmyBuilder
var regiment: ArmyRegiment
var _header_row: HBoxContainer


static func create(army_builder: ArmyBuilder, army_regiment: ArmyRegiment) -> RegimentPanel:
	var panel: RegimentPanel = load("res://scenes/ui/forge/builder/regiment_panel.tscn").instantiate()
	panel._fill(army_builder, army_regiment)
	return panel


func _fill(army_builder: ArmyBuilder, army_regiment: ArmyRegiment) -> void:
	builder = army_builder
	regiment = army_regiment
	var renown := regiment.is_regiment_of_renown()
	if renown:
		theme_type_variation = "RenownRegimentPanel"
	set_meta(&"regiment_id", regiment.id)
	_header_row = %Header
	_fill_header()
	var content: VBoxContainer = %Content
	if not builder.collapsed.has(regiment.id):
		if regiment.leaderless:
			content.add_child(_leader_button())
		for unit in regiment.units:
			content.add_child(UnitRow.create(builder, unit, regiment))
		var add := _add_button() if not renown else null
		if add:
			content.add_child(add)
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


func _fill_header() -> void:
	var editor := builder.editor
	var key := regiment.id + ":"
	var row := _header_row
	var open := not builder.collapsed.has(regiment.id)
	var grip: Button = %Grip
	grip.set_meta(&"focus_key", key + "grip")
	grip.gui_input.connect(_on_grip_input.bind(grip))
	builder.drag.source(grip, {"kind": "reg", "regiment_id": regiment.id}, regiment.name, self)
	var collapse: Button = %Collapse
	if not open:
		collapse.icon = UITheme.icon("chevron_right")
	collapse.tooltip_text = "Collapse regiment" if open else "Expand regiment"
	collapse.accessibility_name = collapse.tooltip_text
	collapse.set_meta(&"focus_key", key + "collapse")
	collapse.pressed.connect(builder.toggle_collapsed.bind(regiment.id))
	var title: Label = %Title
	if builder.renaming == regiment.id:
		var edit := LineEdit.new()
		edit.text = regiment.name
		edit.tooltip_text = "Regiment name"
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.set_meta(&"focus_key", key + "name")
		edit.text_submitted.connect(func(text: String) -> void: builder.finish_renaming(regiment.id, text))
		edit.focus_exited.connect(func() -> void: builder.finish_renaming(regiment.id, edit.text))
		row.add_child(edit)
		row.move_child(edit, title.get_index())
		title.free()
	else:
		title.text = regiment.name
		if regiment.is_regiment_of_renown():
			var chip := UITheme.chip("Regiment of Renown", "gold")
			row.add_child(chip)
			row.move_child(chip, title.get_index() + 1)
	var points := ArmyPoints.regiment_points(regiment, editor.army, builder.catalog)
	var points_label: Label = %Points
	if regiment.is_regiment_of_renown() or regiment.units.is_empty():
		points_label.text = "%d pts" % points
	else:
		var capacity := ArmyValidator.regiment_capacity(regiment, editor.army)
		points_label.text = "%d/%d units · %d pts" % [regiment.followers().size(), capacity, points]
	var rename: Button = %Rename
	if regiment.is_regiment_of_renown():
		rename.free()
	else:
		rename.set_meta(&"focus_key", key + "rename")
		rename.pressed.connect(builder.start_renaming.bind(regiment.id))
	var delete: Button = %Delete
	delete.set_meta(&"focus_key", key + "delete")
	delete.pressed.connect(editor.remove_regiment.bind(regiment.id))


## The button that fills the regiment's empty leader's slot.
func _leader_button() -> Button:
	return UIBuilder.button("Choose a leader", func() -> void: builder.pick_leader(regiment.id), regiment.id + ":leader",
			"GhostButton")


## The button to choose the regiment's leader or add a unit, or null when the regiment is full or
## its leader's slot is empty, as its units come from the leader's regiment options.
func _add_button() -> Button:
	var key := regiment.id + ":add"
	if regiment.units.is_empty():
		return UIBuilder.button("Choose a leader", func() -> void: builder.pick_leader(regiment.id), key, "GhostButton")
	if not builder.editor.has_room(regiment) or (regiment.leaderless and not builder.editor.army.override_constraints):
		return null
	return UIBuilder.button("Add unit", func() -> void: builder.pick_unit(regiment.id), key, "GhostButton")
