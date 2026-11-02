extends GutTest
## Unit tests for the game map's menu (scripts/ui/battle/pause_menu.gd).


func _menu() -> PauseMenu:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	return menu


func _escape() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func _wait_for_fade() -> void:
	await wait_seconds(PauseMenu.FADE_SECONDS + 0.1)


func test_starts_hidden() -> void:
	assert_false(_menu().visible)


func test_open_shows_the_menu() -> void:
	var menu := _menu()
	menu.open()
	assert_true(menu.visible)


func test_open_focuses_resume() -> void:
	var menu := _menu()
	menu.open()
	assert_true(menu.resume_button.has_focus())


func test_open_fades_the_menu_in() -> void:
	var menu := _menu()
	menu.open()
	await _wait_for_fade()
	assert_almost_eq(menu.modulate.a, 1.0, 0.01)


func test_close_hides_the_menu_after_the_fade() -> void:
	var menu := _menu()
	menu.open()
	menu.close()
	await _wait_for_fade()
	assert_false(menu.visible)


func test_close_keeps_the_menu_shown_while_fading() -> void:
	var menu := _menu()
	menu.open()
	menu.close()
	assert_true(menu.visible)


func test_reopening_while_closing_keeps_the_menu_shown() -> void:
	var menu := _menu()
	menu.open()
	menu.close()
	menu.open()
	await _wait_for_fade()
	assert_true(menu.visible)


func test_resume_button_emits_resume_pressed() -> void:
	var menu := _menu()
	watch_signals(menu)
	menu.resume_button.pressed.emit()
	assert_signal_emitted(menu, "resume_pressed")


func test_settings_button_emits_settings_pressed() -> void:
	var menu := _menu()
	watch_signals(menu)
	menu.settings_button.pressed.emit()
	assert_signal_emitted(menu, "settings_pressed")


func test_give_up_button_emits_give_up_pressed() -> void:
	var menu := _menu()
	watch_signals(menu)
	menu.give_up_button.pressed.emit()
	assert_signal_emitted(menu, "give_up_pressed")


func test_save_and_quit_button_emits_save_and_quit_pressed() -> void:
	var menu := _menu()
	watch_signals(menu)
	menu.save_and_quit_button.pressed.emit()
	assert_signal_emitted(menu, "save_and_quit_pressed")


func test_a_button_emits_only_its_own_signal() -> void:
	var menu := _menu()
	watch_signals(menu)
	menu.give_up_button.pressed.emit()
	assert_signal_not_emitted(menu, "resume_pressed")
	assert_signal_not_emitted(menu, "save_and_quit_pressed")


func test_escape_resumes_while_open() -> void:
	var menu := _menu()
	menu.open()
	watch_signals(menu)
	menu._unhandled_input(_escape())
	assert_signal_emitted(menu, "resume_pressed")


func test_escape_does_nothing_while_hidden() -> void:
	var menu := _menu()
	watch_signals(menu)
	menu._unhandled_input(_escape())
	assert_signal_not_emitted(menu, "resume_pressed")


func test_other_input_does_not_resume() -> void:
	var menu := _menu()
	menu.open()
	var event := _escape()
	event.action = "ui_accept"
	watch_signals(menu)
	menu._unhandled_input(event)
	assert_signal_not_emitted(menu, "resume_pressed")


func test_menu_blocks_the_mouse() -> void:
	assert_eq(_menu().mouse_filter, Control.MOUSE_FILTER_STOP)
