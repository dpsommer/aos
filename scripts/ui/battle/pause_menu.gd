class_name PauseMenu
extends Control
## The game map's menu: the battlefield dimmed behind a panel of Resume, Settings, Surrender and Save
## and Quit. Surrender asks the player to confirm first. Esc resumes. See docs/design/battle.md.

signal resume_pressed
signal settings_pressed
## Surrender, once the player confirms it.
signal surrender_pressed
signal save_and_quit_pressed

## How long the dimming fades in or out, in seconds.
const FADE_SECONDS := 0.2
const DIM := Color(0.02, 0.024, 0.031, 0.6)

var resume_button: Button
var settings_button: Button
var surrender_button: Button
var surrender_dialog: ConfirmationDialog
var save_and_quit_button: Button
var _fade: Tween


func _init() -> void:
	name = "PauseMenu"
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	resume_button = UIBuilder.button("Resume", resume_pressed.emit, "resume", "GoldButton")
	settings_button = UIBuilder.button("Settings", settings_pressed.emit, "settings")
	surrender_button = UIBuilder.button("Surrender", confirm_surrender, "surrender", "DangerButton")
	save_and_quit_button = UIBuilder.button("Save and Quit", save_and_quit_pressed.emit, "save_and_quit")
	var buttons: Array[Button] = [resume_button, settings_button, surrender_button, save_and_quit_button]
	for button in buttons:
		button.custom_minimum_size = Vector2(260, 44)
	var title := UIBuilder.label("Menu", "SectionLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var panel := UIBuilder.panel("CardPanel", UIBuilder.vbox([title] + buttons, 12))
	panel.name = "Panel"
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	add_child(center)
	_build_surrender_dialog()
	hide()


func _build_surrender_dialog() -> void:
	surrender_dialog = ConfirmationDialog.new()
	surrender_dialog.name = "SurrenderDialog"
	surrender_dialog.title = "Are you sure?"
	surrender_dialog.dialog_text = "Surrendering will result in a loss."
	surrender_dialog.ok_button_text = "Surrender"
	surrender_dialog.cancel_button_text = "Cancel"
	UITheme.style_dialog(surrender_dialog, "DialogDangerButton")
	surrender_dialog.confirmed.connect(surrender_pressed.emit)
	surrender_dialog.canceled.connect(surrender_button.grab_focus)
	add_child(surrender_dialog)


## Asks the player to confirm surrendering, with Cancel focused so a stray Enter doesn't surrender.
func confirm_surrender() -> void:
	surrender_dialog.popup_centered()
	surrender_dialog.get_cancel_button().grab_focus()


## Shows the menu, fading the dimming in, with Resume focused.
func open() -> void:
	if not visible:
		modulate.a = 0.0
	show()
	_fade_to(1.0)
	resume_button.grab_focus()


## Hides the menu, fading the dimming out.
func close() -> void:
	_fade_to(0.0).finished.connect(hide)


func _fade_to(alpha: float) -> Tween:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, FADE_SECONDS)
	return _fade


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_pressed.emit()
