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

var resume_button: Button
var settings_button: Button
var surrender_button: Button
var surrender_dialog: ConfirmationDialog
var save_and_quit_button: Button
var _fade: Tween


static func create() -> PauseMenu:
	return load("res://scenes/ui/battle/pause_menu.tscn").instantiate()


func _init() -> void:
	theme = UITheme.get_theme()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		resume_button = %Resume
		settings_button = %Settings
		surrender_button = %Surrender
		save_and_quit_button = %SaveAndQuit
		surrender_dialog = %SurrenderDialog
		UITheme.style_dialog(surrender_dialog, "DialogDangerButton")


func _on_resume_pressed() -> void:
	resume_pressed.emit()


func _on_settings_pressed() -> void:
	settings_pressed.emit()


func _on_save_and_quit_pressed() -> void:
	save_and_quit_pressed.emit()


func _on_surrender_confirmed() -> void:
	surrender_pressed.emit()


func _on_surrender_canceled() -> void:
	surrender_button.grab_focus()


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
