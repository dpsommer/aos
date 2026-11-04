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


func _escape_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func test_quit_button_opens_quit_dialog() -> void:
	var menu := _make_menu()
	menu.quit_button.pressed.emit()
	assert_true(menu.quit_dialog.visible)


func test_quit_button_alone_does_not_quit_the_game() -> void:
	var menu := _make_menu()
	menu.quit_button.pressed.emit()
	assert_not_called(menu, "_quit")


func test_quit_button_alone_does_not_emit_quit_pressed() -> void:
	var menu := _make_menu()
	menu.quit_button.pressed.emit()
	assert_signal_not_emitted(menu, "quit_pressed")


func test_escape_opens_quit_dialog() -> void:
	var menu := _make_menu()
	menu._unhandled_input(_escape_event())
	assert_true(menu.quit_dialog.visible)


func test_escape_alone_does_not_quit_the_game() -> void:
	var menu := _make_menu()
	menu._unhandled_input(_escape_event())
	assert_not_called(menu, "_quit")
	assert_signal_not_emitted(menu, "quit_pressed")


func test_quit_dialog_is_hidden_on_ready() -> void:
	var menu := _make_menu()
	assert_false(menu.quit_dialog.visible)


func test_cancel_button_is_focused_when_quit_dialog_opens() -> void:
	var menu := _make_menu()
	menu.request_quit()
	assert_true(menu.quit_dialog.get_cancel_button().has_focus())


func test_confirming_quit_dialog_quits_the_game() -> void:
	var menu := _make_menu()
	menu.request_quit()
	menu.quit_dialog.confirmed.emit()
	assert_called(menu, "_quit")


func test_confirming_quit_dialog_emits_quit_pressed() -> void:
	var menu := _make_menu()
	menu.request_quit()
	menu.quit_dialog.confirmed.emit()
	assert_signal_emitted(menu, "quit_pressed")


func test_cancelling_quit_dialog_does_not_quit_the_game() -> void:
	var menu := _make_menu()
	menu.request_quit()
	menu.quit_dialog.canceled.emit()
	assert_not_called(menu, "_quit")


func test_cancelling_quit_dialog_does_not_emit_quit_pressed() -> void:
	var menu := _make_menu()
	menu.request_quit()
	menu.quit_dialog.canceled.emit()
	assert_signal_not_emitted(menu, "quit_pressed")


func test_option_buttons_do_not_quit_the_game() -> void:
	var menu := _make_menu()
	menu.quick_play_button.pressed.emit()
	menu.forge_button.pressed.emit()
	menu.settings_button.pressed.emit()
	assert_not_called(menu, "_quit")


func test_quick_play_button_has_focus_on_ready() -> void:
	var menu := _make_menu()
	assert_true(menu.quick_play_button.has_focus())


func test_quit_dialog_ok_uses_the_gold_dialog_variation() -> void:
	var menu := _make_menu()
	var ok_variation := menu.quit_dialog.get_ok_button().theme_type_variation
	assert_ne(ok_variation, menu.quit_dialog.get_cancel_button().theme_type_variation)
	assert_eq(UITheme.get_theme().get_type_variation_base(ok_variation), &"GoldButton")


func test_quit_dialog_cancel_uses_the_plain_dialog_variation() -> void:
	var menu := _make_menu()
	var variation := menu.quit_dialog.get_cancel_button().theme_type_variation
	assert_eq(UITheme.get_theme().get_type_variation_base(variation), &"Button")
