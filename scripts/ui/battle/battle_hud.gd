class_name BattleHud
extends Control
## The game map's overlay, from the design's deployment boards: a header with the battleplan's name,
## who is attacker and defender and the menu's settings gear, and the camera controls in the corner.
## The header slides up out of view while the menu is open. See docs/design/battle.md.

signal menu_pressed

## How long the header takes to slide in or out, in seconds.
const SLIDE_SECONDS := 0.2
const PLAYER_PILL := [Color(0.141, 0.322, 0.494, 0.45), Color("#3D74A8"), Color("#C7DEFA"), Color("#7FB2E8")]
const OPPONENT_PILL := [Color(0.549, 0.165, 0.141, 0.35), Color("#8C2A24"), Color("#FFC8B5"), Color("#E58A80")]

var menu_button: Button
var header: PanelContainer
var title_label: Label
var player_pill: PanelContainer
var opponent_pill: PanelContainer
var controls: Control
var _slide: Tween


func _init(battle: Battle) -> void:
	name = "BattleHud"
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	header = _header(battle)
	add_child(header)
	controls = _controls()
	add_child(controls)


## Slides the header up out of view if [param hidden], or back down if not.
func set_header_hidden(hidden: bool) -> void:
	if _slide:
		_slide.kill()
	_slide = create_tween()
	_slide.tween_property(header, "position:y", -header.size.y if hidden else 0.0, SLIDE_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Shows the keys as currently bound, e.g. after they were rebound in Settings: rebuilds the camera
## controls panel and updates the menu button's tooltip.
func refresh_controls() -> void:
	menu_button.tooltip_text = menu_tooltip()
	menu_button.accessibility_name = menu_button.tooltip_text
	var fresh := _controls()
	controls.replace_by(fresh)
	controls.free()
	controls = fresh


func _header(battle: Battle) -> Control:
	var bar := PanelContainer.new()
	bar.name = "Header"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size.y = 64
	bar.add_theme_stylebox_override("panel", UITheme.box(Color(0.047, 0.051, 0.063, 0.85), Color.TRANSPARENT, 0, 0))
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	menu_button = UIBuilder.icon_button("settings", menu_tooltip(), menu_pressed.emit, "menu")
	menu_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_label = UIBuilder.label(battle.title, "TitleLabel")
	var role := "Attacker" if battle.player_is_attacker else "Defender"
	var other := "Defender" if battle.player_is_attacker else "Attacker"
	player_pill = _pill("You · %s" % role, PLAYER_PILL)
	opponent_pill = _pill("Opponent · %s" % other, OPPONENT_PILL)
	var row := UIBuilder.hbox([UIBuilder.spacer(), title_label, player_pill, opponent_pill, menu_button], 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)
	bar.add_child(margin)
	return bar


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


## The menu button's tooltip, naming the first key bound to Back ([code]ui_cancel[/code]), e.g.
## "Menu (Esc)", or just "Menu" if none is.
static func menu_tooltip() -> String:
	var keys := InputBindings.keys("ui_cancel")
	return "Menu (%s)" % InputBindings.key_name(keys[0]) if not keys.is_empty() else "Menu"


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
