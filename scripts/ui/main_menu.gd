class_name MainMenu
extends Control
## Title screen menu. Emits a signal for each option; Quit (or Escape) asks for confirmation,
## then closes the game.

signal quick_play_pressed
signal forge_pressed
signal settings_pressed
signal quit_pressed

@onready var quick_play_button: Button = %QuickPlayButton
@onready var forge_button: Button = %ForgeButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var quit_dialog: ConfirmationDialog = %QuitDialog


func _ready() -> void:
	theme = UITheme.get_theme()
	quick_play_button.pressed.connect(_on_quick_play_pressed)
	forge_button.pressed.connect(_on_forge_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(request_quit)
	UITheme.style_dialog(quit_dialog, "DialogGoldButton")
	quit_dialog.confirmed.connect(_on_quit_confirmed)
	quick_play_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		request_quit()


## Asks the player to confirm quitting, with Cancel focused so a stray Enter doesn't quit.
func request_quit() -> void:
	quit_dialog.popup_centered()
	quit_dialog.get_cancel_button().grab_focus()


func _on_quick_play_pressed() -> void:
	quick_play_pressed.emit()


func _on_forge_pressed() -> void:
	forge_pressed.emit()


func _on_settings_pressed() -> void:
	settings_pressed.emit()


func _on_quit_confirmed() -> void:
	quit_pressed.emit()
	_quit()


## Separated from the handler so tests can stub it without closing the runner.
func _quit() -> void:
	get_tree().quit()
