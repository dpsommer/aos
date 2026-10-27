class_name MainMenu
extends Control
## Title screen menu. Emits a signal for each option; Quit also closes the game.

signal quick_play_pressed
signal forge_pressed
signal settings_pressed
signal quit_pressed

@onready var quick_play_button: Button = %QuickPlayButton
@onready var forge_button: Button = %ForgeButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	theme = UITheme.get_theme()
	quick_play_button.pressed.connect(_on_quick_play_pressed)
	forge_button.pressed.connect(_on_forge_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	quick_play_button.grab_focus()


func _on_quick_play_pressed() -> void:
	quick_play_pressed.emit()


func _on_forge_pressed() -> void:
	forge_pressed.emit()


func _on_settings_pressed() -> void:
	settings_pressed.emit()


func _on_quit_pressed() -> void:
	quit_pressed.emit()
	_quit()


## Separated from the handler so tests can stub it without closing the runner.
func _quit() -> void:
	get_tree().quit()
