extends GutTest
## Unit tests for the Settings screen (scripts/ui/settings_screen.gd).

const SettingsScene := preload("res://scenes/ui/settings_screen.tscn")
const Sandbox := preload("res://test/support/sandbox.gd")
const UIKit := preload("res://test/support/ui_kit.gd")

const ACTION := "ui_accept"
const OTHER := "ui_cancel"


## The screen remaps keys and sets volumes as it saves, so the sandbox puts them back.
func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	await get_tree().process_frame
	Sandbox.end()


## A screen in the tree with _apply_graphics and _read_window stubbed out, so it neither changes nor
## reads the test runner's window. Graphics changes aren't saved because of that stub; tests read them
## from GameSettings.current().
func _make_screen() -> SettingsScreen:
	var screen: SettingsScreen = partial_double(SettingsScene).instantiate()
	stub(screen, "_apply_graphics").to_do_nothing()
	stub(screen, "_read_window").to_do_nothing()
	add_child_autofree(screen)
	watch_signals(screen)
	return screen


func _key(keycode: Key, modifiers := 0) -> InputEventKey:
	return InputBindings.decode([keycode | modifiers])[0]


## A key press as the engine sends it.
func _press(keycode: Key, modifiers := 0) -> InputEventKey:
	var event := _key(keycode, modifiers)
	event.pressed = true
	return event


func _codes(action: String) -> Array[int]:
	return InputBindings.encode(InputBindings.keys(action))


func _saved() -> GameSettings:
	return GameSettings.load_from(GameSettings.path)


func _toggle(screen: SettingsScreen, key: String) -> CheckButton:
	return UIKit.keyed(screen, key) as CheckButton


# --- Layout ---


func test_has_four_tabs() -> void:
	assert_eq(_make_screen().tabs.get_tab_count(), 4)


func test_tabs_are_titled_for_their_pages() -> void:
	var screen := _make_screen()
	for page: Control in [screen.general, screen.graphics, screen.sound, screen.input]:
		assert_eq(screen.tabs.get_tab_title(page.get_parent().get_index()), String(page.name))


func test_every_tab_has_settings() -> void:
	var screen := _make_screen()
	for page: Control in [screen.general, screen.graphics, screen.sound, screen.input]:
		assert_gt(page.get_child_count(), 0, page.name)


func test_back_button_emits_back_pressed() -> void:
	var screen := _make_screen()
	screen.back_button.pressed.emit()
	assert_signal_emitted(screen, "back_pressed")


func test_escape_emits_back_pressed() -> void:
	var screen := _make_screen()
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	screen._unhandled_input(event)
	assert_signal_emitted(screen, "back_pressed")


func test_other_actions_do_not_emit_back_pressed() -> void:
	var screen := _make_screen()
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	screen._unhandled_input(event)
	assert_signal_not_emitted(screen, "back_pressed")


func test_screen_shows_the_current_settings() -> void:
	GameSettings.current().show_legends = false
	var screen := _make_screen()
	assert_false(_toggle(screen, "settings:show_legends").button_pressed)


# --- General ---


func test_show_legends_switch_changes_the_setting() -> void:
	var screen := _make_screen()
	_toggle(screen, "settings:show_legends").button_pressed = false
	assert_false(GameSettings.current().show_legends)


func test_show_legends_switch_is_saved() -> void:
	var screen := _make_screen()
	_toggle(screen, "settings:show_legends").button_pressed = false
	assert_false(_saved().show_legends)


# --- Graphics ---


func test_fullscreen_switch_changes_the_setting() -> void:
	var screen := _make_screen()
	var check := _toggle(screen, "settings:fullscreen")
	check.button_pressed = not check.button_pressed
	assert_eq(GameSettings.current().fullscreen, check.button_pressed)


func test_graphics_switch_applies_graphics() -> void:
	var screen := _make_screen()
	_toggle(screen, "settings:vsync").button_pressed = not GameSettings.current().vsync
	assert_called(screen, "_apply_graphics")


func test_vsync_switch_changes_the_setting() -> void:
	var screen := _make_screen()
	var before := GameSettings.current().vsync
	_toggle(screen, "settings:vsync").button_pressed = not before
	assert_eq(GameSettings.current().vsync, not before)


func test_window_resizing_switch_changes_the_setting() -> void:
	var screen := _make_screen()
	var before := GameSettings.current().window_resizable
	_toggle(screen, "settings:window_resizable").button_pressed = not before
	assert_eq(GameSettings.current().window_resizable, not before)


func test_render_scale_slider_changes_the_setting() -> void:
	var screen := _make_screen()
	(UIKit.keyed(screen, "settings:render_scale") as HSlider).value = 0.75
	assert_almost_eq(GameSettings.current().render_scale, 0.75, 0.001)


func test_render_scale_drag_applies_only_when_it_ends() -> void:
	var screen := _make_screen()
	var slider := UIKit.keyed(screen, "settings:render_scale") as HSlider
	var before := GameSettings.current().render_scale
	slider.drag_started.emit()
	slider.value = 0.75
	assert_almost_eq(GameSettings.current().render_scale, before, 0.001)
	slider.drag_ended.emit(true)
	assert_almost_eq(GameSettings.current().render_scale, 0.75, 0.001)


func test_render_scale_drag_end_applies_the_graphics() -> void:
	var screen := _make_screen()
	var slider := UIKit.keyed(screen, "settings:render_scale") as HSlider
	slider.drag_started.emit()
	slider.value = 0.75
	assert_not_called(screen, "_apply_graphics")
	slider.drag_ended.emit(true)
	assert_called(screen, "_apply_graphics")


func test_volume_drag_applies_while_dragging() -> void:
	var screen := _make_screen()
	var slider := UIKit.keyed(screen, "settings:master_volume") as HSlider
	slider.drag_started.emit()
	slider.value = 0.5
	assert_almost_eq(GameSettings.current().master_volume, 0.5, 0.001)


func test_reads_the_window_on_ready() -> void:
	var screen := _make_screen()
	assert_called(screen, "_read_window")


func test_render_scale_slider_stays_within_the_allowed_range() -> void:
	var screen := _make_screen()
	var slider := UIKit.keyed(screen, "settings:render_scale") as HSlider
	assert_eq(slider.min_value, GameSettings.RENDER_SCALE_MIN)
	assert_eq(slider.max_value, GameSettings.RENDER_SCALE_MAX)


func test_render_scale_text_gives_a_percentage() -> void:
	var screen := _make_screen()
	assert_true(screen.render_scale_text(0.5).begins_with("50%"))


func test_render_scale_text_includes_the_resulting_resolution() -> void:
	var screen := _make_screen()
	var expected := GameSettings.render_size(0.5, screen.get_window())
	assert_string_contains(screen.render_scale_text(0.5), "%d × %d" % [expected.x, expected.y])


func test_fps_limit_select_changes_the_setting() -> void:
	var screen := _make_screen()
	var select := UIKit.keyed(screen, "settings:fps_limit") as OptionButton
	var limit: int = GameSettings.FPS_LIMITS[1]
	for i in select.item_count:
		if select.get_item_metadata(i) == limit:
			select.select(i)
			select.item_selected.emit(i)
	assert_eq(GameSettings.current().fps_limit, limit)


func test_fps_limit_select_offers_every_limit() -> void:
	var screen := _make_screen()
	var select := UIKit.keyed(screen, "settings:fps_limit") as OptionButton
	var offered := []
	for i in select.item_count:
		offered.append(select.get_item_metadata(i))
	for limit in GameSettings.FPS_LIMITS:
		assert_has(offered, limit)


func test_fps_limit_select_shows_a_saved_limit_it_does_not_list() -> void:
	GameSettings.current().fps_limit = 77
	var select := UIKit.keyed(_make_screen(), "settings:fps_limit") as OptionButton
	assert_eq(select.get_item_metadata(select.selected), 77)


func test_display_select_is_selected_on_the_current_display() -> void:
	var select := UIKit.keyed(_make_screen(), "settings:display") as OptionButton
	assert_eq(select.get_item_metadata(select.selected), GameSettings.current().display)


func test_display_select_is_disabled_with_a_single_display() -> void:
	var select := UIKit.keyed(_make_screen(), "settings:display") as OptionButton
	assert_eq(select.disabled, select.item_count < 2)


# --- Sound ---


func test_volume_slider_changes_the_setting() -> void:
	var screen := _make_screen()
	(UIKit.keyed(screen, "settings:bgm_volume") as HSlider).value = 0.3
	assert_almost_eq(GameSettings.current().bgm_volume, 0.3, 0.001)


func test_volume_slider_is_saved() -> void:
	var screen := _make_screen()
	(UIKit.keyed(screen, "settings:sfx_volume") as HSlider).value = 0.4
	assert_almost_eq(_saved().sfx_volume, 0.4, 0.001)


func test_volume_slider_changes_the_audio_bus() -> void:
	var screen := _make_screen()
	(UIKit.keyed(screen, "settings:master_volume") as HSlider).value = 0.5
	assert_almost_eq(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(&"Master")), 0.5, 0.01)


func test_each_volume_has_its_own_slider() -> void:
	var screen := _make_screen()
	for volume: Array in SettingsScreen.VOLUMES:
		assert_not_null(UIKit.keyed(screen, "settings:" + volume[0]), volume[0])


func test_volume_text_is_a_percentage() -> void:
	assert_eq(SettingsScreen.percent_text(0.5), "50%")


func test_mute_in_background_switch_changes_the_setting() -> void:
	var screen := _make_screen()
	_toggle(screen, "settings:mute_in_background").button_pressed = false
	assert_false(GameSettings.current().mute_in_background)


func test_mute_in_background_switch_is_saved() -> void:
	var screen := _make_screen()
	_toggle(screen, "settings:mute_in_background").button_pressed = false
	assert_false(_saved().mute_in_background)


# --- Input: listening ---


func test_listen_waits_for_a_key_for_the_action() -> void:
	var screen := _make_screen()
	screen.listen(ACTION, null)
	assert_eq(screen.listening_action, ACTION)


func test_listening_to_change_a_key_shows_press_a_key_on_it() -> void:
	var screen := _make_screen()
	screen.listen(ACTION, InputBindings.keys(ACTION)[0])
	assert_not_null(UIKit.button(screen.input, "Press a key…"))


func test_listening_to_add_a_key_replaces_add_key_with_press_a_key() -> void:
	var screen := _make_screen()
	screen.listen(ACTION, null)
	assert_not_null(UIKit.keyed(screen.input, "add:" + ACTION))
	assert_eq((UIKit.keyed(screen.input, "add:" + ACTION) as Button).text, "Press a key…")


func test_key_buttons_listen_to_change_that_key() -> void:
	var screen := _make_screen()
	var key := InputBindings.keys(ACTION)[0]
	(UIKit.keyed(screen.input, "key:%s:%d" % [ACTION, InputBindings.key_code(key)]) as Button).pressed.emit()
	assert_eq(screen.listening_action, ACTION)
	assert_eq(_codes(ACTION), InputBindings.encode(InputBindings.default_keys(ACTION)))


func test_add_key_button_listens() -> void:
	var screen := _make_screen()
	(UIKit.keyed(screen.input, "add:" + ACTION) as Button).pressed.emit()
	assert_eq(screen.listening_action, ACTION)


func test_input_does_nothing_when_not_listening() -> void:
	var screen := _make_screen()
	var before := _codes(ACTION)
	screen._input(_press(KEY_Q))
	assert_eq(_codes(ACTION), before)
	assert_eq(screen.listening_action, "")


func test_pressed_key_replaces_the_key_being_changed() -> void:
	var screen := _make_screen()
	var key := InputBindings.keys(ACTION)[0]
	screen.listen(ACTION, key)
	screen._input(_press(KEY_Q))
	assert_has(_codes(ACTION), KEY_Q)
	assert_does_not_have(_codes(ACTION), InputBindings.key_code(key))


func test_pressed_key_is_added_when_adding() -> void:
	var screen := _make_screen()
	var before := _codes(ACTION)
	screen.listen(ACTION, null)
	screen._input(_press(KEY_Q))
	assert_eq(_codes(ACTION), before + [KEY_Q] as Array[int])


func test_pressed_key_keeps_its_modifiers() -> void:
	var screen := _make_screen()
	screen.listen(ACTION, null)
	screen._input(_press(KEY_Q, KEY_MASK_SHIFT))
	assert_has(_codes(ACTION), KEY_Q | KEY_MASK_SHIFT)


func test_pressed_key_stops_listening() -> void:
	var screen := _make_screen()
	screen.listen(ACTION, null)
	screen._input(_press(KEY_Q))
	assert_eq(screen.listening_action, "")


func test_pressed_key_is_saved() -> void:
	var screen := _make_screen()
	screen.listen(ACTION, null)
	screen._input(_press(KEY_Q))
	assert_true(_saved().key_bindings.has(ACTION))


func test_escape_cancels_listening_without_binding() -> void:
	var screen := _make_screen()
	var before := _codes(ACTION)
	screen.listen(ACTION, null)
	screen._input(_press(KEY_ESCAPE))
	assert_eq(screen.listening_action, "")
	assert_eq(_codes(ACTION), before)


func test_escape_with_a_modifier_can_be_bound() -> void:
	var screen := _make_screen()
	screen.listen(ACTION, null)
	screen._input(_press(KEY_ESCAPE, KEY_MASK_SHIFT))
	assert_has(_codes(ACTION), KEY_ESCAPE | KEY_MASK_SHIFT)


func test_mouse_click_cancels_listening() -> void:
	var screen := _make_screen()
	var before := _codes(ACTION)
	screen.listen(ACTION, null)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	screen._input(click)
	assert_eq(screen.listening_action, "")
	assert_eq(_codes(ACTION), before)


func test_lone_modifier_is_ignored() -> void:
	var screen := _make_screen()
	var before := _codes(ACTION)
	screen.listen(ACTION, null)
	for modifier in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		screen._input(_press(modifier))
	assert_eq(screen.listening_action, ACTION)
	assert_eq(_codes(ACTION), before)


func test_key_release_is_ignored() -> void:
	var screen := _make_screen()
	screen.listen(ACTION, null)
	var release := _key(KEY_Q)
	release.pressed = false
	screen._input(release)
	assert_eq(screen.listening_action, ACTION)


func test_key_echo_is_ignored() -> void:
	var screen := _make_screen()
	screen.listen(ACTION, null)
	var echo := _press(KEY_Q)
	echo.echo = true
	screen._input(echo)
	assert_eq(screen.listening_action, ACTION)


# --- Input: binding, removing and resetting ---


func test_bind_key_takes_the_key_from_another_action() -> void:
	var screen := _make_screen()
	InputBindings.set_keys(OTHER, [_key(KEY_Q)])
	screen.listen(ACTION, null)
	screen.bind_key(_key(KEY_Q))
	assert_does_not_have(_codes(OTHER), KEY_Q)
	assert_has(_codes(ACTION), KEY_Q)


func test_bind_key_notes_which_action_lost_the_key() -> void:
	var screen := _make_screen()
	InputBindings.set_keys(OTHER, [_key(KEY_Q)])
	screen.listen(ACTION, null)
	screen.bind_key(_key(KEY_Q))
	var expected := "%s was removed from %s." % [InputBindings.key_name(_key(KEY_Q)), InputBindings.display_name(OTHER)]
	assert_true(UIKit.has_label_containing(screen.input, expected), expected)


func test_bind_key_names_every_action_that_lost_the_key() -> void:
	var screen := _make_screen()
	InputBindings.set_keys(OTHER, [_key(KEY_Q)])
	InputBindings.set_keys("ui_up", [_key(KEY_Q)])
	screen.listen(ACTION, null)
	screen.bind_key(_key(KEY_Q))
	assert_true(UIKit.has_label_containing(screen.input, InputBindings.display_name(OTHER)))
	assert_true(UIKit.has_label_containing(screen.input, InputBindings.display_name("ui_up")))


func test_bind_key_without_a_conflict_has_no_note() -> void:
	var screen := _make_screen()
	screen.listen(ACTION, null)
	screen.bind_key(_key(KEY_Q))
	assert_false(UIKit.has_label_containing(screen.input, "was removed from"))


func test_note_is_cleared_by_the_next_change() -> void:
	var screen := _make_screen()
	InputBindings.set_keys(OTHER, [_key(KEY_Q)])
	screen.listen(ACTION, null)
	screen.bind_key(_key(KEY_Q))
	screen.reset_keys(ACTION)
	assert_false(UIKit.has_label_containing(screen.input, "was removed from"))


func test_note_survives_rebuilding_the_tab() -> void:
	var screen := _make_screen()
	InputBindings.set_keys(OTHER, [_key(KEY_Q)])
	screen.listen(ACTION, null)
	screen.bind_key(_key(KEY_Q))
	screen.build_input()
	assert_true(UIKit.has_label_containing(screen.input, "was removed from"))


func test_remove_key_removes_it_from_the_action() -> void:
	var screen := _make_screen()
	var key := InputBindings.keys(ACTION)[0]
	screen.remove_key(ACTION, key)
	assert_does_not_have(_codes(ACTION), InputBindings.key_code(key))


func test_remove_button_removes_its_key() -> void:
	var screen := _make_screen()
	var key := InputBindings.keys(ACTION)[0]
	(UIKit.keyed(screen.input, "remove:%s:%d" % [ACTION, InputBindings.key_code(key)]) as Button).pressed.emit()
	assert_does_not_have(_codes(ACTION), InputBindings.key_code(key))


func test_remove_key_is_saved() -> void:
	var screen := _make_screen()
	screen.remove_key(ACTION, InputBindings.keys(ACTION)[0])
	assert_true(_saved().key_bindings.has(ACTION))


func test_reset_keys_restores_the_default_keys() -> void:
	var screen := _make_screen()
	InputBindings.set_keys(ACTION, [_key(KEY_Q)])
	screen.reset_keys(ACTION)
	assert_true(InputBindings.is_default(ACTION))


func test_reset_keys_leaves_other_actions_alone() -> void:
	var screen := _make_screen()
	InputBindings.set_keys(OTHER, [_key(KEY_Q)])
	screen.reset_keys(ACTION)
	assert_eq(_codes(OTHER), [KEY_Q] as Array[int])


func test_reset_keys_is_saved_as_default() -> void:
	var screen := _make_screen()
	screen.remove_key(ACTION, InputBindings.keys(ACTION)[0])
	screen.reset_keys(ACTION)
	assert_false(_saved().key_bindings.has(ACTION))


func test_reset_all_keys_restores_every_action() -> void:
	var screen := _make_screen()
	InputBindings.set_keys(ACTION, [_key(KEY_Q)])
	InputBindings.set_keys(OTHER, [_key(KEY_W)])
	screen.reset_all_keys()
	for action in InputBindings.actions():
		assert_true(InputBindings.is_default(action), action)


func test_reset_all_button_resets_every_action() -> void:
	var screen := _make_screen()
	InputBindings.set_keys(ACTION, [_key(KEY_Q)])
	screen.build_input()
	(UIKit.keyed(screen.input, "settings:reset_all") as Button).pressed.emit()
	assert_true(InputBindings.is_default(ACTION))


func test_reset_is_disabled_for_an_action_on_its_defaults() -> void:
	var screen := _make_screen()
	assert_true((UIKit.keyed(screen.input, "reset:" + ACTION) as Button).disabled)


func test_reset_is_enabled_for_a_remapped_action() -> void:
	var screen := _make_screen()
	screen.listen(ACTION, null)
	screen.bind_key(_key(KEY_Q))
	assert_false((UIKit.keyed(screen.input, "reset:" + ACTION) as Button).disabled)


func test_reset_all_is_disabled_when_every_action_is_default() -> void:
	var screen := _make_screen()
	assert_true((UIKit.keyed(screen.input, "settings:reset_all") as Button).disabled)


func test_reset_all_is_enabled_once_an_action_is_remapped() -> void:
	var screen := _make_screen()
	screen.remove_key(ACTION, InputBindings.keys(ACTION)[0])
	assert_false((UIKit.keyed(screen.input, "settings:reset_all") as Button).disabled)


func test_every_remappable_action_has_a_row() -> void:
	var screen := _make_screen()
	for action in InputBindings.actions():
		assert_not_null(UIKit.keyed(screen.input, "add:" + action), action)


# --- Reset all on the General, Graphics and Sound tabs ---

const RESETS := ["settings:reset_general", "settings:reset_graphics", "settings:reset_sound"]


func test_each_tab_reset_all_is_disabled_at_the_defaults() -> void:
	var screen := _make_screen()
	for key: String in RESETS:
		assert_true((UIKit.keyed(screen, key) as Button).disabled, key)


func test_changing_a_setting_enables_its_tabs_reset_all() -> void:
	var screen := _make_screen()
	(UIKit.keyed(screen, "settings:master_volume") as HSlider).value = 0.3
	assert_false((UIKit.keyed(screen, "settings:reset_sound") as Button).disabled)


func test_changing_a_setting_leaves_other_tabs_reset_all_disabled() -> void:
	var screen := _make_screen()
	(UIKit.keyed(screen, "settings:master_volume") as HSlider).value = 0.3
	assert_true((UIKit.keyed(screen, "settings:reset_general") as Button).disabled)


func test_sound_reset_all_restores_the_defaults() -> void:
	var screen := _make_screen()
	(UIKit.keyed(screen, "settings:master_volume") as HSlider).value = 0.3
	(UIKit.keyed(screen, "settings:reset_sound") as Button).pressed.emit()
	assert_true(GameSettings.current().is_default(GameSettings.SOUND))


func test_sound_reset_all_shows_the_defaults() -> void:
	var screen := _make_screen()
	(UIKit.keyed(screen, "settings:master_volume") as HSlider).value = 0.3
	(UIKit.keyed(screen, "settings:reset_sound") as Button).pressed.emit()
	var slider := UIKit.keyed(screen.sound, "settings:master_volume") as HSlider
	assert_almost_eq(slider.value, GameSettings.new().master_volume, 0.001)


func test_sound_reset_all_saves() -> void:
	var screen := _make_screen()
	(UIKit.keyed(screen, "settings:master_volume") as HSlider).value = 0.3
	(UIKit.keyed(screen, "settings:reset_sound") as Button).pressed.emit()
	assert_true(GameSettings.load_from(GameSettings.path).is_default(GameSettings.SOUND))


func test_general_reset_all_restores_show_legends() -> void:
	var screen := _make_screen()
	(UIKit.keyed(screen, "settings:show_legends") as CheckButton).button_pressed = not GameSettings.current().show_legends
	(UIKit.keyed(screen, "settings:reset_general") as Button).pressed.emit()
	assert_eq(GameSettings.current().show_legends, GameSettings.new().show_legends)


func test_graphics_reset_all_restores_the_defaults_and_applies_them() -> void:
	var screen := _make_screen()
	(UIKit.keyed(screen, "settings:render_scale") as HSlider).value = 0.5
	(UIKit.keyed(screen, "settings:reset_graphics") as Button).pressed.emit()
	assert_true(GameSettings.current().is_default(GameSettings.GRAPHICS))
	assert_called_count(screen._apply_graphics, 2)


func test_reset_all_leaves_other_tabs_settings_alone() -> void:
	var screen := _make_screen()
	(UIKit.keyed(screen, "settings:show_legends") as CheckButton).button_pressed = not GameSettings.current().show_legends
	(UIKit.keyed(screen, "settings:master_volume") as HSlider).value = 0.3
	(UIKit.keyed(screen, "settings:reset_sound") as Button).pressed.emit()
	assert_ne(GameSettings.current().show_legends, GameSettings.new().show_legends)


func test_reset_all_focuses_the_tabs_first_setting() -> void:
	var screen := _make_screen()
	screen.tabs.current_tab = 2
	(UIKit.keyed(screen, "settings:master_volume") as HSlider).value = 0.3
	(UIKit.keyed(screen, "settings:reset_sound") as Button).pressed.emit()
	assert_eq(get_viewport().gui_get_focus_owner(), UIKit.keyed(screen.sound, "settings:master_volume"))


func test_rebuilt_tab_does_not_keep_old_reset_buttons() -> void:
	var screen := _make_screen()
	for i in 3:
		(UIKit.keyed(screen, "settings:master_volume") as HSlider).value = 0.3
		(UIKit.keyed(screen, "settings:reset_sound") as Button).pressed.emit()
	assert_eq(screen._reset_buttons.size(), RESETS.size())


# --- Action row layout ---

## The chip (KeyChipPanel or KeyChipListeningPanel) holding [param action]'s key [param keycode].
func _chip(screen: SettingsScreen, action: String, keycode: Key) -> PanelContainer:
	var change := UIKit.keyed(screen.input, "key:%s:%d" % [action, keycode])
	return change.get_parent().get_parent() as PanelContainer


func test_a_keys_remove_button_is_in_the_keys_chip() -> void:
	var screen := _make_screen()
	var remove := UIKit.keyed(screen.input, "remove:%s:%d" % [ACTION, KEY_ENTER])
	assert_true(_chip(screen, ACTION, KEY_ENTER).is_ancestor_of(remove))


func test_a_keys_chip_holds_only_that_key() -> void:
	var screen := _make_screen()
	var chip := _chip(screen, ACTION, KEY_ENTER)
	assert_false(chip.is_ancestor_of(UIKit.keyed(screen.input, "remove:%s:%d" % [ACTION, KEY_SPACE])))


func test_add_key_is_outside_the_list_of_keys() -> void:
	var screen := _make_screen()
	var key_list := _chip(screen, ACTION, KEY_ENTER).get_parent()
	assert_false(key_list.is_ancestor_of(UIKit.keyed(screen.input, "add:" + ACTION)))


func test_reset_is_outside_the_list_of_keys() -> void:
	var screen := _make_screen()
	var key_list := _chip(screen, ACTION, KEY_ENTER).get_parent()
	assert_false(key_list.is_ancestor_of(UIKit.keyed(screen.input, "reset:" + ACTION)))


func test_many_keys_leave_add_key_in_place() -> void:
	var screen := _make_screen()
	for keycode: Key in [KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F]:
		InputBindings.bind(ACTION, _key(keycode))
	screen.build_input()
	var add := UIKit.keyed(screen.input, "add:" + ACTION)
	assert_false(_chip(screen, ACTION, KEY_F).get_parent().is_ancestor_of(add))


func test_the_key_being_changed_has_the_listening_chip() -> void:
	var screen := _make_screen()
	screen.listen(ACTION, InputBindings.keys(ACTION)[0])
	var keycode := InputBindings.keys(ACTION)[0].keycode
	assert_eq(_chip(screen, ACTION, keycode).theme_type_variation, &"KeyChipListeningPanel")


func test_other_keys_have_the_plain_chip() -> void:
	var screen := _make_screen()
	screen.listen(ACTION, InputBindings.keys(ACTION)[0])
	var other := InputBindings.keys(ACTION)[1].keycode
	assert_eq(_chip(screen, ACTION, other).theme_type_variation, &"KeyChipPanel")


func test_an_action_without_keys_says_so() -> void:
	var screen := _make_screen()
	for key in InputBindings.keys(ACTION):
		screen.remove_key(ACTION, key)
	assert_true(UIKit.has_label_containing(screen.input, "No keys"))
