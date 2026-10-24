extends GutTest
## Unit tests for the title screen menu (scripts/ui/main_menu.gd).

const MainMenuScene := preload("res://scenes/ui/main_menu.tscn")


## Returns a menu instance added to the tree with _quit stubbed out, so
## pressing Quit can never close the test runner.
func _make_menu() -> MainMenu:
	var menu: MainMenu = partial_double(MainMenuScene).instantiate()
	stub(menu, "_quit").to_do_nothing()
	add_child_autofree(menu)
	watch_signals(menu)
	return menu


func test_quick_play_button_emits_quick_play_pressed() -> void:
	var menu := _make_menu()
	menu.quick_play_button.pressed.emit()
	assert_signal_emitted(menu, "quick_play_pressed")


func test_forge_button_emits_forge_pressed() -> void:
	var menu := _make_menu()
	menu.forge_button.pressed.emit()
	assert_signal_emitted(menu, "forge_pressed")


func test_settings_button_emits_settings_pressed() -> void:
	var menu := _make_menu()
	menu.settings_button.pressed.emit()
	assert_signal_emitted(menu, "settings_pressed")


func test_quit_button_emits_quit_pressed() -> void:
	var menu := _make_menu()
	menu.quit_button.pressed.emit()
	assert_signal_emitted(menu, "quit_pressed")


func test_quit_button_quits_the_game() -> void:
	var menu := _make_menu()
	menu.quit_button.pressed.emit()
	assert_called(menu, "_quit")


func test_option_buttons_do_not_quit_the_game() -> void:
	var menu := _make_menu()
	menu.quick_play_button.pressed.emit()
	menu.forge_button.pressed.emit()
	menu.settings_button.pressed.emit()
	assert_not_called(menu, "_quit")


func test_quick_play_button_has_focus_on_ready() -> void:
	var menu := _make_menu()
	assert_true(menu.quick_play_button.has_focus())
