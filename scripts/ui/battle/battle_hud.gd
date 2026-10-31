class_name BattleHud
extends Control
## The game map's overlay, from the design's deployment boards: a header with Menu, the
## battleplan's name and who is attacker and defender, and the camera controls in the corner. See
## docs/design/battle.md.

signal menu_pressed

const PLAYER_PILL := [Color(0.141, 0.322, 0.494, 0.45), Color("#3D74A8"), Color("#C7DEFA"), Color("#7FB2E8")]
const OPPONENT_PILL := [Color(0.549, 0.165, 0.141, 0.35), Color("#8C2A24"), Color("#FFC8B5"), Color("#E58A80")]

var menu_button: Button
var title_label: Label
var player_pill: PanelContainer
var opponent_pill: PanelContainer


func _init(battle: Battle) -> void:
	name = "BattleHud"
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header(battle))
	add_child(_controls())


func _header(battle: Battle) -> Control:
	var header := PanelContainer.new()
	header.name = "Header"
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.custom_minimum_size.y = 64
	header.add_theme_stylebox_override("panel", UITheme.box(Color(0.047, 0.051, 0.063, 0.85), Color.TRANSPARENT, 0, 0))
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	menu_button = UIBuilder.button("Menu", menu_pressed.emit, "menu", "GhostButton", "Back to the main menu (Esc)")
	title_label = UIBuilder.label(battle.title, "TitleLabel")
	var role := "Attacker" if battle.player_is_attacker else "Defender"
	var other := "Defender" if battle.player_is_attacker else "Attacker"
	player_pill = _pill("You · %s" % role, PLAYER_PILL)
	opponent_pill = _pill("Opponent · %s" % other, OPPONENT_PILL)
	var row := UIBuilder.hbox([menu_button, UIBuilder.spacer(), title_label, player_pill, opponent_pill], 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)
	header.add_child(margin)
	return header


func _pill(text: String, colours: Array) -> PanelContainer:
	var pill := PanelContainer.new()
	var style := UITheme.box(colours[0], colours[1], 999, 0)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", style)
	var dot := ColorRect.new()
	dot.color = colours[3]
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := UIBuilder.label(text)
	label.add_theme_color_override("font_color", colours[2])
	label.add_theme_font_size_override("font_size", 13)
	pill.add_child(UIBuilder.hbox([dot, label], 8))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return pill


## The camera controls, with the keys as currently bound.
func _controls() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Controls"
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.09, 0.102, 0.122, 0.9), UITheme.BORDER, 8, 12))
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(20, -20)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.add_child(UIBuilder.vbox([
		UIBuilder.label("RMB / %s  move camera" % move_keys(), "MutedLabel"),
		UIBuilder.label("MMB / %s  rotate camera" % turn_keys(), "MutedLabel"),
		UIBuilder.label("Wheel  zoom", "MutedLabel"),
	], 6))
	return panel


## The camera's move keys as currently bound, e.g. "WASD", or "None" if unbound.
static func move_keys() -> String:
	return _keys(["camera_forward", "camera_left", "camera_back", "camera_right"], "")


## The camera's turn keys as currently bound, e.g. "Q/E".
static func turn_keys() -> String:
	return _keys(["camera_rotate_left", "camera_rotate_right"], "/")


static func _keys(actions: Array, joiner: String) -> String:
	var names := PackedStringArray()
	for action: String in actions:
		var keys := InputBindings.keys(action)
		if not keys.is_empty():
			names.append(InputBindings.key_name(keys[0]))
	for key_name in names:
		if key_name.length() > 1:
			joiner = "/"
	return joiner.join(names) if not names.is_empty() else "None"
