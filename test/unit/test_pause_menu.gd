extends GutTest
## Unit tests for the game map's menu (scripts/ui/battle/pause_menu.gd).


func _menu() -> PauseMenu:
	var menu := PauseMenu.create()
	add_child_autofree(menu)
	return menu


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _escape() -> InputEventAction:
	return _action("ui_cancel")


## Waits until [param done] is true, or a little longer than a fade takes.
func _await_fade(done: Callable) -> void:
	await wait_until(done, PauseMenu.FADE_SECONDS + 0.5)


## Waits for a whole fade, for checks that something didn't happen once it ended.
func _await_whole_fade() -> void:
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
	await _await_fade(func() -> bool: return is_equal_approx(menu.modulate.a, 1.0))
	assert_almost_eq(menu.modulate.a, 1.0, 0.01)


func test_close_hides_the_menu_after_the_fade() -> void:
	var menu := _menu()
	menu.open()
	menu.close()
	await _await_fade(func() -> bool: return not menu.visible)
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
	await _await_whole_fade()
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


func test_surrender_dialog_is_hidden_initially() -> void:
	assert_false(_menu().surrender_dialog.visible)


func test_surrender_button_opens_the_dialog() -> void:
	var menu := _menu()
	menu.surrender_button.pressed.emit()
	assert_true(menu.surrender_dialog.visible)


func test_surrender_button_alone_does_not_emit_surrender_pressed() -> void:
	var menu := _menu()
	watch_signals(menu)
	menu.surrender_button.pressed.emit()
	assert_signal_not_emitted(menu, "surrender_pressed")


func test_surrender_dialog_focuses_cancel() -> void:
	var menu := _menu()
	menu.confirm_surrender()
	assert_true(menu.surrender_dialog.get_cancel_button().has_focus())


func test_confirming_surrender_dialog_emits_surrender_pressed() -> void:
	var menu := _menu()
	menu.confirm_surrender()
	watch_signals(menu)
	menu.surrender_dialog.confirmed.emit()
	assert_signal_emitted(menu, "surrender_pressed")


func test_cancelling_surrender_dialog_does_not_emit_surrender_pressed() -> void:
	var menu := _menu()
	menu.confirm_surrender()
	watch_signals(menu)
	menu.surrender_dialog.canceled.emit()
	assert_signal_not_emitted(menu, "surrender_pressed")


func test_cancelling_surrender_dialog_refocuses_the_surrender_button() -> void:
	var menu := _menu()
	menu.confirm_surrender()
	menu.surrender_dialog.canceled.emit()
	assert_true(menu.surrender_button.has_focus())


func test_save_and_quit_button_emits_save_and_quit_pressed() -> void:
	var menu := _menu()
	watch_signals(menu)
	menu.save_and_quit_button.pressed.emit()
	assert_signal_emitted(menu, "save_and_quit_pressed")


func test_a_button_emits_only_its_own_signal() -> void:
	var menu := _menu()
	watch_signals(menu)
	menu.settings_button.pressed.emit()
	assert_signal_not_emitted(menu, "resume_pressed")
	assert_signal_not_emitted(menu, "surrender_pressed")
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
	watch_signals(menu)
	menu._unhandled_input(_action("ui_accept"))
	assert_signal_not_emitted(menu, "resume_pressed")


func test_menu_blocks_the_mouse() -> void:
	assert_eq(_menu().mouse_filter, Control.MOUSE_FILTER_STOP)
