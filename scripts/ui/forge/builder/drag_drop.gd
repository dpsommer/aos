class_name BuilderDragDrop
extends RefCounted
## Drag and drop in the army builder. A drag carries a Dictionary:
## [codeblock]
## {kind = "roster", warscroll_id = ...}  # a Roster card: adds a unit
## {kind = "unit", uid = ...}             # a unit in the army: moves it
## {kind = "reg", regiment_id = ...}      # a regiment: reorders it
## {kind = "ror", name = ...}             # a Regiments of Renown card: adds it
## [/codeblock]
## A gold line shows where a drop will go. See docs/design/forge.md.

## How close to the army list's top or bottom a drag scrolls it, and how fast.
const SCROLL_EDGE := 48.0
const SCROLL_SPEED := 700.0

var builder: ArmyBuilder
var line: ColorRect
## The control being dragged, dimmed until the drag ends.
var lifted: Control
## The drop target showing the line.
var _line_owner: Control
## Controls highlighted for the drag, with their variations to restore.
var _highlighted := {}


func _init(army_builder: ArmyBuilder) -> void:
	builder = army_builder
	line = ColorRect.new()
	line.color = UITheme.GOLD
	line.top_level = true
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.z_index = 10
	line.hide()
	builder.add_child(line)


## Lets [param control] be dragged, carrying [param payload]. The drag preview shows
## [param label], and [param lift] (or the control) is dimmed while dragging.
func source(control: Control, payload: Dictionary, label: String, lift: Control = null) -> void:
	var begin := func(_at: Vector2) -> Variant:
		var preview := UIBuilder.panel("RowPanel", UIBuilder.label(label))
		preview.theme = UITheme.get_theme()
		builder.set_drag_preview(preview)
		lifted = lift if lift else control
		lifted.modulate.a = 0.45
		return payload
	control.set_drag_forwarding(begin, Callable(), Callable())


## Makes [param control] a drop target: [param can_drop] and [param drop] take the position in the
## control and the payload.
func target(control: Control, can_drop: Callable, drop: Callable) -> void:
	var can := func(at: Vector2, data: Variant) -> bool:
		return data is Dictionary and can_drop.call(at, data)
	control.set_drag_forwarding(Callable(), can, drop)
	pass_mouse(control)


## Lets drags over [param node]'s controls reach it and the targets around it: a control that
## stops the mouse also stops a drop from reaching its parents. Nested targets (with a
## [code]drop_target[/code] meta) keep their own.
static func pass_mouse(node: Node) -> void:
	node.set_meta(&"drop_target", true)
	_pass_mouse(node)


static func _pass_mouse(node: Node) -> void:
	if node is Control and node.mouse_filter == Control.MOUSE_FILTER_STOP:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		if not child.has_meta(&"drop_target"):
			_pass_mouse(child)


## Whether the dragged unit can go in [param regiment], or the auxiliary units when it's null.
func accepts_unit(data: Dictionary, regiment: ArmyRegiment) -> bool:
	var editor := builder.editor
	match data.get("kind"):
		"roster":
			return regiment == null or editor.has_room(regiment)
		"unit":
			var from := editor.army.regiment_of(data.get("uid", ""))
			if editor.army.find_unit(data.get("uid", "")) == null or (from and from.is_regiment_of_renown()):
				return false
			return regiment == null or (not regiment.is_regiment_of_renown() and (from == regiment or editor.has_room(regiment)))
	return false


## Adds or moves the dragged unit to [param index] in [param regiment], or the auxiliary units.
func place_unit(data: Dictionary, regiment: ArmyRegiment, index: int) -> void:
	var editor := builder.editor
	if data.get("kind") == "roster":
		if regiment:
			editor.add_unit(regiment.id, data.warscroll_id, index)
		else:
			editor.add_auxiliary(data.warscroll_id, index)
	else:
		editor.move_unit(data.uid, regiment.id if regiment else "", index)


## Shows the line for [param owner] before [param index] in [param rows], or after the last row,
## or below [param fallback] if there are no rows.
func show_line_in(owner: Control, rows: Array, index: int, fallback: Control) -> void:
	if rows.is_empty():
		show_line(owner, fallback.get_global_rect(), true)
	elif index < rows.size():
		show_line(owner, rows[index].get_global_rect(), false)
	else:
		show_line(owner, rows[-1].get_global_rect(), true)


## Shows the line above [param rect], or below it when [param after], for [param owner].
func show_line(owner: Control, rect: Rect2, after: bool, gap := 4.0) -> void:
	line.global_position = Vector2(rect.position.x, (rect.end.y + gap if after else rect.position.y - gap) - 1)
	line.size = Vector2(rect.size.x, 2)
	line.show()
	_line_owner = owner


func hide_line() -> void:
	line.hide()
	_line_owner = null


## Highlights [param control] with [param variation] until the drag ends.
func highlight(control: Control, variation: String) -> void:
	if not _highlighted.has(control):
		_highlighted[control] = control.theme_type_variation
	control.theme_type_variation = variation


func unhighlight(control: Variant) -> void:
	if _highlighted.has(control):
		if is_instance_valid(control):
			control.theme_type_variation = _highlighted[control]
		_highlighted.erase(control)


## Called by the builder when any drag starts.
func begin(data: Variant) -> void:
	if not data is Dictionary:
		return
	for panel in _find(builder.builder_list, func(n: Node) -> bool: return n is RegimentPanel):
		if accepts_unit(data, panel.regiment):
			highlight(panel, "DropRegimentPanel")
	if accepts_unit(data, null) and builder.auxiliary_box:
		highlight(builder.auxiliary_box, "DropRegimentPanel")
	builder.remove_overlay.visible = data.get("kind") == "unit"
	builder.set_process(true)


## Called by the builder when any drag ends, dropped or not.
func end() -> void:
	hide_line()
	for control in _highlighted.keys():
		unhighlight(control)
	builder.remove_overlay.hide()
	if is_instance_valid(lifted):
		lifted.modulate.a = 1.0
	lifted = null
	builder.set_process(false)


## Called every frame during a drag: hides the line once the pointer leaves its target, and
## scrolls the army list near its edges.
func process(delta: float) -> void:
	var hovered := builder.get_viewport().gui_get_hovered_control()
	if line.visible and (not is_instance_valid(_line_owner) or hovered == null
			or not (hovered == _line_owner or _line_owner.is_ancestor_of(hovered))):
		hide_line()
	var overlay := builder.remove_overlay
	if overlay.visible and _highlighted.has(overlay) and not (hovered == overlay or overlay.is_ancestor_of(hovered)):
		unhighlight(overlay)
	var scroll := builder.builder_scroll
	var at := scroll.get_local_mouse_position()
	if at.x < 0 or at.x > scroll.size.x:
		return
	if at.y < SCROLL_EDGE:
		scroll.scroll_vertical -= int(SCROLL_SPEED * delta)
	elif at.y > scroll.size.y - SCROLL_EDGE:
		scroll.scroll_vertical += int(SCROLL_SPEED * delta)


static func _find(node: Node, matches: Callable) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		if matches.call(child):
			result.append(child)
		result.append_array(_find(child, matches))
	return result
