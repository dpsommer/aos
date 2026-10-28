extends GutTest
## Unit tests for the saved settings (scripts/settings/game_settings.gd).

const Sandbox := preload("res://test/support/sandbox.gd")

const FILE := "user://test_game_settings.cfg"


## The input map and audio buses are global, and current() is shared, so use the sandbox.
func before_each() -> void:
	Sandbox.begin()
	DirAccess.remove_absolute(FILE)


func after_each() -> void:
	DirAccess.remove_absolute(FILE)
	Sandbox.end()


func _write(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.set_value(section, key, value)
	config.save(FILE)


# --- load_from ---


func test_load_from_a_missing_file_gives_defaults() -> void:
	var loaded := GameSettings.load_from(FILE)
	var defaults := GameSettings.new()
	assert_eq(loaded.show_legends, defaults.show_legends)
	assert_eq(loaded.fullscreen, defaults.fullscreen)
	assert_eq(loaded.render_scale, defaults.render_scale)
	assert_eq(loaded.fps_limit, defaults.fps_limit)
	assert_eq(loaded.master_volume, defaults.master_volume)
	assert_eq(loaded.key_bindings.size(), 0)


func test_load_from_an_unreadable_file_gives_defaults() -> void:
	var handle := FileAccess.open(FILE, FileAccess.WRITE)
	handle.store_string("[[[ not a config ===")
	handle.close()
	assert_eq(GameSettings.load_from(FILE).render_scale, GameSettings.new().render_scale)
	assert_engine_error("ConfigFile parse error")


func test_load_from_missing_values_keep_defaults() -> void:
	_write("general", "show_legends", false)
	var loaded := GameSettings.load_from(FILE)
	assert_false(loaded.show_legends)
	assert_eq(loaded.vsync, GameSettings.new().vsync)


func test_load_from_clamps_render_scale() -> void:
	_write("graphics", "render_scale", 99.0)
	assert_eq(GameSettings.load_from(FILE).render_scale, GameSettings.RENDER_SCALE_MAX)
	_write("graphics", "render_scale", 0.0)
	assert_eq(GameSettings.load_from(FILE).render_scale, GameSettings.RENDER_SCALE_MIN)


func test_load_from_clamps_volumes() -> void:
	_write("sound", "bgm_volume", 5.0)
	assert_eq(GameSettings.load_from(FILE).bgm_volume, 1.0)
	_write("sound", "bgm_volume", -1.0)
	assert_eq(GameSettings.load_from(FILE).bgm_volume, 0.0)


func test_load_from_does_not_allow_a_negative_fps_limit() -> void:
	_write("graphics", "fps_limit", -30)
	assert_eq(GameSettings.load_from(FILE).fps_limit, 0)


func test_load_from_ignores_unknown_input_actions() -> void:
	_write("input", "not_an_action", [KEY_Q])
	assert_eq(GameSettings.load_from(FILE).key_bindings.size(), 0)


func test_load_from_reads_remapped_input_actions() -> void:
	_write("input", "ui_accept", [KEY_Q])
	assert_true(GameSettings.load_from(FILE).key_bindings.has("ui_accept"))


# --- save ---


func test_save_then_load_round_trips_values() -> void:
	var settings := GameSettings.new()
	settings.show_legends = not settings.show_legends
	settings.fullscreen = not settings.fullscreen
	settings.display = 1
	settings.render_scale = 0.75
	settings.window_resizable = not settings.window_resizable
	settings.vsync = not settings.vsync
	settings.fps_limit = GameSettings.FPS_LIMITS[1]
	settings.master_volume = 0.25
	settings.bgm_volume = 0.5
	settings.sfx_volume = 0.0
	settings.mute_in_background = not settings.mute_in_background
	assert_eq(settings.save(FILE), OK)
	var loaded := GameSettings.load_from(FILE)
	for property in ["show_legends", "fullscreen", "display", "render_scale", "window_resizable", "vsync",
			"fps_limit", "master_volume", "bgm_volume", "sfx_volume", "mute_in_background"]:
		assert_eq(loaded.get(property), settings.get(property), property)


func test_save_then_load_round_trips_key_bindings() -> void:
	var settings := GameSettings.new()
	settings.key_bindings["ui_accept"] = [KEY_Q | KEY_MASK_SHIFT]
	settings.save(FILE)
	assert_eq(GameSettings.load_from(FILE).key_bindings["ui_accept"], [KEY_Q | KEY_MASK_SHIFT])


func test_save_leaves_default_actions_out_of_the_input_section() -> void:
	GameSettings.new().save(FILE)
	var config := ConfigFile.new()
	config.load(FILE)
	assert_false(config.has_section("input"))


func test_save_defaults_to_the_settings_path() -> void:
	GameSettings.new().save()
	assert_true(FileAccess.file_exists(GameSettings.path))


func test_save_to_an_unwritable_path_returns_an_error() -> void:
	assert_ne(GameSettings.new().save("user://test_missing_directory/settings.cfg"), OK)


# --- current ---


func test_current_returns_the_same_settings_each_time() -> void:
	assert_same(GameSettings.current(), GameSettings.current())


func test_current_loads_from_path() -> void:
	var settings := GameSettings.new()
	settings.show_legends = false
	settings.save()
	GameSettings.reset_current()
	assert_false(GameSettings.current().show_legends)


func test_reset_current_forgets_unsaved_changes() -> void:
	GameSettings.current().show_legends = false
	GameSettings.reset_current()
	assert_true(GameSettings.current().show_legends)


# --- Input ---


func test_store_input_records_remapped_actions() -> void:
	var settings := GameSettings.new()
	InputBindings.set_keys("ui_accept", InputBindings.decode([KEY_Q]))
	settings.store_input()
	assert_eq(settings.key_bindings["ui_accept"], [KEY_Q])


func test_store_input_leaves_default_actions_out() -> void:
	var settings := GameSettings.new()
	InputBindings.set_keys("ui_accept", InputBindings.decode([KEY_Q]))
	settings.store_input()
	assert_false(settings.key_bindings.has("ui_cancel"))


func test_store_input_forgets_actions_back_on_defaults() -> void:
	var settings := GameSettings.new()
	settings.key_bindings["ui_accept"] = [KEY_Q]
	settings.store_input()
	assert_eq(settings.key_bindings.size(), 0)


func test_apply_input_sets_remapped_keys() -> void:
	var settings := GameSettings.new()
	settings.key_bindings["ui_accept"] = [KEY_Q]
	settings.apply_input()
	assert_eq(InputBindings.encode(InputBindings.keys("ui_accept")), [KEY_Q] as Array[int])


func test_apply_input_restores_defaults_for_unlisted_actions() -> void:
	InputBindings.set_keys("ui_cancel", InputBindings.decode([KEY_Q]))
	GameSettings.new().apply_input()
	assert_true(InputBindings.is_default("ui_cancel"))


# --- Sound ---


func _master_volume() -> float:
	return AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(&"Master"))


func test_apply_sound_sets_the_bus_volumes() -> void:
	var settings := GameSettings.new()
	settings.master_volume = 0.5
	settings.apply_sound()
	assert_almost_eq(_master_volume(), 0.5, 0.01)


func test_apply_sound_sets_the_bgm_and_sfx_buses() -> void:
	var settings := GameSettings.new()
	settings.bgm_volume = 0.25
	settings.sfx_volume = 0.75
	settings.apply_sound()
	assert_almost_eq(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(GameSettings.BGM_BUS)), 0.25, 0.01)
	assert_almost_eq(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(GameSettings.SFX_BUS)), 0.75, 0.01)


func test_apply_focus_mutes_when_unfocused() -> void:
	var settings := GameSettings.new()
	settings.apply_focus(false)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")))
	settings.apply_focus(true)


func test_apply_focus_unmutes_when_focused() -> void:
	var settings := GameSettings.new()
	settings.apply_focus(false)
	settings.apply_focus(true)
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")))


func test_apply_focus_does_not_mute_when_mute_in_background_is_off() -> void:
	var settings := GameSettings.new()
	settings.mute_in_background = false
	settings.apply_focus(false)
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")))


## A window in the tree, in [param mode], freed after the test. Never shown, so the test runner's
## own window is left alone.
func _window(mode: Window.Mode) -> Window:
	var window := Window.new()
	window.visible = false
	add_child_autofree(window)
	window.mode = mode
	return window


func test_read_window_turns_fullscreen_on_for_a_fullscreen_window() -> void:
	var settings := GameSettings.new()
	settings.fullscreen = false
	var window := _window(Window.MODE_FULLSCREEN)
	if window.mode != Window.MODE_FULLSCREEN:
		pending("this display server can't make a window fullscreen")
		return
	settings.read_window(window)
	assert_true(settings.fullscreen)


func test_read_window_turns_fullscreen_off_for_a_windowed_window() -> void:
	var settings := GameSettings.new()
	settings.fullscreen = true
	settings.read_window(_window(Window.MODE_WINDOWED))
	assert_false(settings.fullscreen)


func test_apply_graphics_sets_the_content_scale_to_the_ui_scale() -> void:
	var settings := GameSettings.new()
	settings.render_scale = 0.8
	var window := _window(Window.MODE_WINDOWED)
	settings.apply_graphics(window)
	assert_almost_eq(window.content_scale_factor, GameSettings.ui_scale(0.8), 0.001)


func test_ui_scale_is_the_inverse_of_a_render_scale_within_the_cap() -> void:
	var scale := 1.0 / minf(GameSettings.max_ui_scale(), 1.2)
	assert_almost_eq(GameSettings.ui_scale(scale), 1.0 / scale, 0.001)


func test_ui_scale_shrinks_text_for_a_high_render_scale() -> void:
	assert_lt(GameSettings.ui_scale(GameSettings.RENDER_SCALE_MAX), 1.0)


func test_ui_scale_never_exceeds_the_cap() -> void:
	assert_almost_eq(GameSettings.ui_scale(GameSettings.RENDER_SCALE_MIN), GameSettings.max_ui_scale(), 0.001)


func test_max_ui_scale_leaves_the_minimum_ui_size() -> void:
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	var room := base / GameSettings.max_ui_scale()
	assert_true(room.x >= GameSettings.MIN_UI_SIZE.x - 0.001 and room.y >= GameSettings.MIN_UI_SIZE.y - 0.001, str(room))


func test_apply_graphics_sets_the_3d_scale_to_render_scale() -> void:
	var settings := GameSettings.new()
	settings.render_scale = 0.75
	var window := _window(Window.MODE_WINDOWED)
	settings.apply_graphics(window)
	assert_almost_eq(window.scaling_3d_scale, 0.75, 0.001)


func test_reset_puts_the_properties_back_to_their_defaults() -> void:
	var settings := GameSettings.new()
	settings.master_volume = 0.2
	settings.reset(GameSettings.SOUND)
	assert_almost_eq(settings.master_volume, GameSettings.new().master_volume, 0.001)


func test_reset_leaves_other_properties_alone() -> void:
	var settings := GameSettings.new()
	settings.show_legends = not settings.show_legends
	settings.reset(GameSettings.SOUND)
	assert_ne(settings.show_legends, GameSettings.new().show_legends)


func test_is_default_is_true_for_new_settings() -> void:
	assert_true(GameSettings.new().is_default(GameSettings.GRAPHICS))


func test_is_default_is_false_after_a_change() -> void:
	var settings := GameSettings.new()
	settings.render_scale = 0.5
	assert_false(settings.is_default(GameSettings.GRAPHICS))


func test_is_default_ignores_float_rounding() -> void:
	var settings := GameSettings.new()
	settings.sfx_volume = GameSettings.new().sfx_volume + 1e-9
	assert_true(settings.is_default(GameSettings.SOUND))


func test_every_tab_property_is_a_setting() -> void:
	var settings := GameSettings.new()
	for property in GameSettings.GENERAL + GameSettings.GRAPHICS + GameSettings.SOUND:
		assert_true(property in settings, property)
