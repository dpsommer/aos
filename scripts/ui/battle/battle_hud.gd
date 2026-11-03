class_name BattleHud
extends Control
## The game map's overlay, from the design's deployment boards: a header with the phase (PRE-BATTLE
## or DEPLOYMENT) and its steps, the battleplan's name, who is attacker and defender (once the
## roll-off has decided) with how many units each has left to deploy, and the menu's settings gear;
## and the camera controls in the corner. The header slides up out of view while the menu is open.
## See docs/design/battle.md.

signal menu_pressed

## How long the header takes to slide in or out, in seconds.
const SLIDE_SECONDS := 0.2
const PLAYER_PILL := [Color(0.141, 0.322, 0.494, 0.45), Color("#3D74A8"), Color("#C7DEFA"), Color("#7FB2E8")]
const OPPONENT_PILL := [Color(0.549, 0.165, 0.141, 0.35), Color("#8C2A24"), Color("#FFC8B5"), Color("#E58A80")]

var menu_button: Button
var header: PanelContainer
var phase_badge: PanelContainer
var phase_label: Label
## The phase's steps, e.g. Faction terrain › Armies › Abilities.
var steps_row: HBoxContainer
var title_label: Label
var player_pill: PanelContainer
var opponent_pill: PanelContainer
var player_pill_label: Label
var opponent_pill_label: Label
var controls: Control
var _slide: Tween
var _battle: Battle
## Units (and terrain) each side has left to deploy, or -1 to leave them out.
var _player_left := -1
var _opponent_left := -1
## Extra lines for the controls panel, e.g. the placement keys while placing.
var _extra_controls := PackedStringArray()


func _init(battle: Battle) -> void:
	_battle = battle
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


## Shows the phase in the badge, e.g. "DEPLOYMENT", and its [param steps] with [param current]
## highlighted, the ones before it ticked. No steps hides the step list.
func set_phase(phase: String, steps: PackedStringArray = [], current := -1) -> void:
	phase_label.text = phase
	for child in steps_row.get_children():
		steps_row.remove_child(child)
		child.queue_free()
	for i in steps.size():
		if i > 0:
			var line := ColorRect.new()
			line.color = UITheme.CONTROL_BORDER
			line.custom_minimum_size = Vector2(28, 1)
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			steps_row.add_child(line)
		var step := UIBuilder.label(("✓ " if i < current else "%d · " % (i + 1)) + steps[i])
		step.add_theme_font_size_override("font_size", 13)
		var colour := UITheme.GOOD if i < current else (Color("#F8DFA2") if i == current else UITheme.MUTED)
		step.add_theme_color_override("font_color", colour)
		step.accessibility_name = "%s, %s" % [steps[i], "done" if i < current else ("current step" if i == current else "to come")]
		steps_row.add_child(step)
	steps_row.visible = not steps.is_empty()


## Shows [param text] as the battle's name in the header, e.g. the realm battlefield side once the
## defender picks it.
func set_title(text: String) -> void:
	title_label.text = text


## Updates the pills: roles once the roll-off has decided them, and how many units each side has
## left to deploy ([param player_left] and [param opponent_left]; -1 leaves them out).
func refresh_roles(player_left := -1, opponent_left := -1) -> void:
	_player_left = player_left
	_opponent_left = opponent_left
	player_pill_label.text = _pill_text("You", _battle.player_is_attacker, _player_left)
	opponent_pill_label.text = _pill_text("Opponent", not _battle.player_is_attacker, _opponent_left)


func _pill_text(who: String, attacker: bool, left: int) -> String:
	var parts := PackedStringArray([who])
	if _battle.roles_assigned:
		parts.append("Attacker" if attacker else "Defender")
	if left >= 0:
		parts.append("%d left" % left)
	return " · ".join(parts)


## Adds [param lines] to the camera controls panel, e.g. the placement keys; none to remove them.
func set_extra_controls(lines: PackedStringArray) -> void:
	_extra_controls = lines
	refresh_controls()


## Moves the controls panel up by [param offset] pixels, e.g. above the deployment tray.
func set_controls_bottom(offset: float) -> void:
	controls.position.y = -20 - offset
	controls.set_meta(&"bottom", offset)


## Shows the keys as currently bound, e.g. after they were rebound in Settings: rebuilds the camera
## controls panel and updates the menu button's tooltip.
func refresh_controls() -> void:
	menu_button.tooltip_text = menu_tooltip()
	menu_button.accessibility_name = menu_button.tooltip_text
	var fresh := _controls()
	var bottom: float = controls.get_meta(&"bottom", 0.0)
	var index := controls.get_index()
	remove_child(controls)
	controls.free()
	add_child(fresh)
	move_child(fresh, index)
	controls = fresh
	if bottom > 0.0:
		set_controls_bottom(bottom)


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
	player_pill = _pill(_pill_text("You", battle.player_is_attacker, -1), PLAYER_PILL)
	opponent_pill = _pill(_pill_text("Opponent", not battle.player_is_attacker, -1), OPPONENT_PILL)
	player_pill_label = player_pill.get_meta(&"label")
	opponent_pill_label = opponent_pill.get_meta(&"label")
	phase_label = UIBuilder.label("PRE-BATTLE")
	phase_label.add_theme_font_size_override("font_size", 12)
	phase_label.add_theme_color_override("font_color", Color("#C9CCD3"))
	phase_badge = PanelContainer.new()
	phase_badge.name = "PhaseBadge"
	var badge_style := UITheme.box(Color("#2A2F38"), Color.TRANSPARENT, 4, 0)
	badge_style.content_margin_left = 10
	badge_style.content_margin_right = 10
	badge_style.content_margin_top = 4
	badge_style.content_margin_bottom = 4
	phase_badge.add_theme_stylebox_override("panel", badge_style)
	phase_badge.add_child(phase_label)
	phase_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	steps_row = UIBuilder.hbox([], 8)
	steps_row.name = "Steps"
	steps_row.visible = false
	var row := UIBuilder.hbox([phase_badge, steps_row, UIBuilder.spacer(), title_label, player_pill, opponent_pill, menu_button], 16)
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
	pill.set_meta(&"label", label)
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
	var lines: Array = [
		UIBuilder.label("RMB / %s  move camera" % move_keys(), "MutedLabel"),
		UIBuilder.label("MMB / %s  rotate camera" % turn_keys(), "MutedLabel"),
		UIBuilder.label("Wheel  zoom", "MutedLabel"),
	]
	for line in _extra_controls:
		lines.append(UIBuilder.label(line, "MutedLabel"))
	panel.add_child(UIBuilder.vbox(lines, 6))
	return panel


## The menu button's tooltip, naming the first key bound to Back ([code]ui_cancel[/code]), e.g.
## "Menu (Esc)", or just "Menu" if none is.
static func menu_tooltip() -> String:
	var keys := InputBindings.keys("ui_cancel")
	return "Menu (%s)" % InputBindings.key_name(keys[0]) if not keys.is_empty() else "Menu"


## The camera's move keys as currently bound, e.g. "WASD", or "None" if unbound.
static func move_keys() -> String:
	return _keys(["camera_forward", "camera_left", "camera_back", "camera_right"], "")


## The first key bound to [param action], e.g. "R", or "None".
static func key_for(action: String) -> String:
	var keys := InputBindings.keys(action)
	return InputBindings.key_name(keys[0]) if not keys.is_empty() else "None"


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
