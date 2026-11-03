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


static func create(battle: Battle) -> BattleHud:
	var hud: BattleHud = load("res://scenes/ui/battle/battle_hud.tscn").instantiate()
	hud._battle = battle
	hud.title_label.text = battle.title
	hud.refresh_roles()
	hud.refresh_controls()
	return hud


func _init() -> void:
	theme = UITheme.get_theme()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		header = %Header
		menu_button = %Menu
		phase_badge = %PhaseBadge
		phase_label = %Phase
		steps_row = %Steps
		title_label = %Title
		player_pill = %PlayerPill
		opponent_pill = %OpponentPill
		player_pill_label = %PlayerLabel
		opponent_pill_label = %OpponentLabel
		controls = %Controls


func _on_menu_pressed() -> void:
	menu_pressed.emit()


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


## Shows the keys as currently bound, e.g. after they were rebound in Settings: in the camera
## controls panel, with any extra lines, and in the menu button's tooltip.
func refresh_controls() -> void:
	menu_button.tooltip_text = menu_tooltip()
	menu_button.accessibility_name = menu_button.tooltip_text
	(%Move as Label).text = "RMB / %s  move camera" % move_keys()
	(%Rotate as Label).text = "MMB / %s  rotate camera" % turn_keys()
	var lines: VBoxContainer = %Lines
	for extra in lines.get_children().slice(3):
		lines.remove_child(extra)
		extra.queue_free()
	for line in _extra_controls:
		lines.add_child(UIBuilder.label(line, "MutedLabel"))


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
