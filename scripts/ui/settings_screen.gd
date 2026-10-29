class_name SettingsScreen
extends Control
## The game's settings, in General, Graphics, Sound and Input tabs. Each change is applied and saved
## straight away, to [method GameSettings.current].

signal back_pressed

const VOLUMES: Array[Array] = [
	["master_volume", "Master volume", "Every sound in the game."],
	["bgm_volume", "BGM volume", "Background music."],
	["sfx_volume", "SFX volume", "Sound effects."],
]

var settings: GameSettings
## The action waiting for a key press, or empty if none is.
var listening_action := ""
## The key being replaced while listening, or null if a key is being added.
var _listening_key: InputEventKey
## Says which actions a newly bound key was taken from.
var _input_note: Label
## Each tab's Reset all button but Input's, with the settings it resets: {button: properties}.
var _reset_buttons := {}

@onready var back_button: Button = %BackButton
@onready var tabs: TabContainer = %Tabs
@onready var general: VBoxContainer = %General
@onready var graphics: VBoxContainer = %Graphics
@onready var sound: VBoxContainer = %Sound
@onready var input: VBoxContainer = %Input


func _ready() -> void:
	theme = UITheme.get_theme()
	settings = GameSettings.current()
	_read_window()
	back_button.icon = UITheme.icon("back")
	back_button.pressed.connect(back_pressed.emit)
	for tab: Control in [general, graphics, sound, input]:
		tabs.set_tab_title(tab.get_parent().get_index(), tab.name)
	_build_general()
	_build_graphics()
	_build_sound()
	build_input()
	back_button.grab_focus()


## While listening for a key, takes the next key press: Esc cancels and a click elsewhere cancels.
func _input(event: InputEvent) -> void:
	if listening_action.is_empty():
		return
	if event is InputEventMouseButton and event.pressed:
		cancel_listening()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return
	get_viewport().set_input_as_handled()
	if key.keycode == KEY_ESCAPE and key.get_modifiers_mask() == 0:
		cancel_listening()
	else:
		bind_key(key)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_pressed.emit()


# --- General ---


func _build_general() -> void:
	_clear(general)
	general.add_child(_reset_row(GameSettings.GENERAL, "general", "General", _save, _build_general))
	general.add_child(_switch("show_legends", "Show Legends armies",
			"Offer Legends factions and Armies of Renown when starting an army in the Forge. Legends rules aren't"
			+ " used in matched play.", _save))


# --- Graphics ---


func _build_graphics() -> void:
	_clear(graphics)
	graphics.add_child(_reset_row(GameSettings.GRAPHICS, "graphics", "Graphics", _apply_graphics, _build_graphics))
	graphics.add_child(_switch("fullscreen", "Fullscreen", "Fill the screen. Off plays in a window.", _apply_graphics))

	var items := []
	for i in DisplayServer.get_screen_count():
		var size := DisplayServer.screen_get_size(i)
		items.append(["Display %d · %d × %d" % [i + 1, size.x, size.y], i])
	if items.is_empty():
		items.append(["Display 1", 0])
	var display := UIBuilder.select(items, clampi(settings.display, 0, items.size() - 1),
			_setter("display", _apply_graphics), "settings:display", "Display")
	display.accessibility_name = "Display"
	display.disabled = items.size() < 2
	graphics.add_child(UIBuilder.setting_row("Display", display, "The screen the game is shown on."))

	graphics.add_child(_slider("render_scale", "Render scale", GameSettings.RENDER_SCALE_MIN, GameSettings.RENDER_SCALE_MAX,
			0.05, render_scale_text, _apply_graphics,
			("The resolution, as a share of the window's. Lower makes text and controls bigger and the battlefield"
			+ " faster to draw; higher makes them smaller and the battlefield sharper. Below %d%%, only the"
			+ " battlefield changes, so every screen still fits. Applies when you let go.")
			% ceili(100 / GameSettings.max_ui_scale()),
			true))
	graphics.add_child(_switch("window_resizable", "Window resizing",
			"Drag the window's edges and corners to resize it. Applies when not fullscreen.", _apply_graphics))
	graphics.add_child(_switch("vsync", "VSync",
			"Match the frame rate to the display's refresh rate, to stop screen tearing.", _apply_graphics))

	var limits := []
	for limit in GameSettings.FPS_LIMITS:
		limits.append(["Unlimited" if limit == 0 else "%d FPS" % limit, limit])
	if not settings.fps_limit in GameSettings.FPS_LIMITS:
		limits.append(["%d FPS" % settings.fps_limit, settings.fps_limit])
	var fps := UIBuilder.select(limits, settings.fps_limit, _setter("fps_limit", _apply_graphics), "settings:fps_limit",
			"FPS limit")
	fps.accessibility_name = "FPS limit"
	graphics.add_child(UIBuilder.setting_row("FPS limit", fps, "The most frames drawn each second."))


## The render scale as a percentage, with the resolution it gives, e.g. "75% · 1440 × 810".
func render_scale_text(scale: float) -> String:
	var size := GameSettings.render_size(scale, get_window())
	return "%d%% · %d × %d" % [roundi(scale * 100), size.x, size.y]


# --- Sound ---


func _build_sound() -> void:
	_clear(sound)
	sound.add_child(_reset_row(GameSettings.SOUND, "sound", "Sound", _apply_sound, _build_sound))
	for volume: Array in VOLUMES:
		sound.add_child(_slider(volume[0], volume[1], 0.0, 1.0, 0.01, percent_text, _apply_sound, volume[2]))
	sound.add_child(_switch("mute_in_background", "Mute in background",
			"Silence the game while its window isn't focused.", _save))


static func percent_text(value: float) -> String:
	return "%d%%" % roundi(value * 100)


# --- Input ---


## Builds the Input tab: each section's actions, with their keys. Rebuilt after every change, keeping
## the focused control's focus.
func build_input() -> void:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focus_key: String = focused.get_meta(&"focus_key", "") if focused and input.is_ancestor_of(focused) else ""
	var note := _input_note.text if _input_note else ""
	_clear(input)
	var help := UIBuilder.label("Select a key to change it, then press the new key. Esc cancels.", "DescriptionLabel",
			true)
	var reset_all := UIBuilder.button("Reset all", reset_all_keys, "settings:reset_all", "GhostButton",
			"Reset every key to its default")
	reset_all.disabled = Array(InputBindings.actions()).all(func(action: String) -> bool:
		return InputBindings.is_default(action))
	input.add_child(UIBuilder.hbox([help, reset_all], 16))
	_input_note = UIBuilder.label(note, "WarningLabel", true)
	_input_note.visible = not note.is_empty()
	input.add_child(_input_note)
	for section: String in InputBindings.SECTIONS:
		input.add_child(UIBuilder.label(section, "SectionLabel"))
		for entry: Array in InputBindings.SECTIONS[section]:
			input.add_child(_action_row(entry[0], entry[1]))
	if not focus_key.is_empty():
		var found := _keyed(input, focus_key)
		(found if found else back_button).grab_focus()


## An action's name; its keys, each a chip holding a button that changes the key and a button that
## removes it, wrapping onto more lines as needed; and Add key and Reset, apart from the keys. Reset is
## disabled while the action has its default keys.
func _action_row(action: String, action_name: String) -> PanelContainer:
	var title := UIBuilder.label(action_name, "CardTitleLabel")
	title.custom_minimum_size.x = 150
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var key_list := HFlowContainer.new()
	key_list.add_theme_constant_override("h_separation", 8)
	key_list.add_theme_constant_override("v_separation", 8)
	key_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_list.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for key in InputBindings.keys(action):
		var key_name := InputBindings.key_name(key)
		var code := InputBindings.key_code(key)
		var listening := listening_action == action and _listening_key != null \
				and InputBindings.key_code(_listening_key) == code
		var change := UIBuilder.button("Press a key…" if listening else key_name, listen.bind(action, key),
				"key:%s:%d" % [action, code], "KeyButton", "Change %s: %s" % [action_name, key_name])
		change.accessibility_name = change.tooltip_text
		change.custom_minimum_size.x = 80
		var remove := UIBuilder.icon_button("close", "Remove %s from %s" % [key_name, action_name],
				remove_key.bind(action, key), "remove:%s:%d" % [action, code], "SmallIconButton")
		remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		key_list.add_child(UIBuilder.panel("KeyChipListeningPanel" if listening else "KeyChipPanel",
				UIBuilder.hbox([change, remove], 2)))
	if key_list.get_child_count() == 0:
		key_list.add_child(UIBuilder.label("No keys", "MutedLabel"))
	var adding := listening_action == action and _listening_key == null
	var add := UIBuilder.button("Press a key…" if adding else "Add key", listen.bind(action, null), "add:" + action,
			"GoldButton" if adding else "GhostButton", "Add a key for " + action_name)
	add.accessibility_name = add.tooltip_text
	# Wide enough for "Press a key…", so the row doesn't shift while listening.
	add.custom_minimum_size.x = 120
	var reset := UIBuilder.button("Reset", reset_keys.bind(action), "reset:" + action, "GhostButton",
			"Reset %s to its default keys" % action_name)
	reset.accessibility_name = reset.tooltip_text
	reset.disabled = InputBindings.is_default(action)
	var buttons := UIBuilder.hbox([add, reset], 8)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return UIBuilder.panel("RowPanel", UIBuilder.hbox([title, key_list, buttons], 16))


## Waits for a key press to replace [param key] of [param action], or to add one if it's null.
func listen(action: String, key: InputEventKey) -> void:
	listening_action = action
	_listening_key = key
	build_input()


func cancel_listening() -> void:
	listening_action = ""
	_listening_key = null
	build_input()


## Binds [param key] to the action being listened for, and stops listening.
func bind_key(key: InputEventKey) -> void:
	var action := listening_action
	var bound := InputBindings.decode([key.get_keycode_with_modifiers() if key.keycode != KEY_NONE
			else key.get_physical_keycode_with_modifiers()])[0]
	var taken_from := InputBindings.bind(action, bound, _listening_key)
	listening_action = ""
	_listening_key = null
	var names := PackedStringArray()
	for other in taken_from:
		names.append(InputBindings.display_name(other))
	_set_input_note("%s was removed from %s." % [InputBindings.key_name(bound), ", ".join(names)] if not names.is_empty() else "")
	_input_changed("key:%s:%d" % [action, InputBindings.key_code(bound)])


func remove_key(action: String, key: InputEventKey) -> void:
	InputBindings.unbind(action, key)
	_set_input_note("")
	_input_changed("add:" + action)


func reset_keys(action: String) -> void:
	InputBindings.set_keys(action, InputBindings.default_keys(action))
	_set_input_note("")
	_input_changed("add:" + action)


func reset_all_keys() -> void:
	for action in InputBindings.actions():
		InputBindings.set_keys(action, InputBindings.default_keys(action))
	_set_input_note("")
	_input_changed("add:" + InputBindings.actions()[0])


func _set_input_note(text: String) -> void:
	if _input_note:
		_input_note.text = text


## Saves the input map's keys and rebuilds the Input tab, focusing the control keyed [param focus_key],
## else Reset all, else Back.
func _input_changed(focus_key: String) -> void:
	settings.store_input()
	_save()
	build_input()
	var found := _keyed(input, focus_key)
	if found == null or (found is BaseButton and found.disabled):
		found = _keyed(input, "settings:reset_all")
	if found is BaseButton and found.disabled:
		found = back_button
	found.grab_focus()


# --- Shared ---


## A Callable that sets [param property] of [member settings] to the value it's called with, then
## calls [param apply].
func _setter(property: String, apply: Callable) -> Callable:
	return func(value: Variant) -> void:
		settings.set(property, value)
		apply.call()
		_update_reset_buttons()


## A tab's Reset all button, on the right, which puts [param properties] back to their defaults, calls
## [param apply], then [param rebuild] to show them. It's disabled while they're all defaults.
func _reset_row(properties: PackedStringArray, key: String, tab_name: String, apply: Callable,
		rebuild: Callable) -> HBoxContainer:
	var button := UIBuilder.button("Reset all", reset_tab.bind(properties, apply, rebuild, "settings:reset_" + key),
			"settings:reset_" + key, "GhostButton", "Reset every %s setting to its default" % tab_name)
	button.accessibility_name = button.tooltip_text
	button.disabled = settings.is_default(properties)
	_reset_buttons[button] = properties
	return UIBuilder.hbox([UIBuilder.spacer(), button])


## Puts [param properties] back to their defaults, applies and saves them with [param apply], and
## rebuilds their tab with [param rebuild]. The tab's Reset all button (keyed [param focus_key]) is
## disabled now, so focus goes to the first setting after it.
func reset_tab(properties: PackedStringArray, apply: Callable, rebuild: Callable, focus_key: String) -> void:
	settings.reset(properties)
	apply.call()
	rebuild.call()
	var button := _keyed(self, focus_key)
	if button == null:
		back_button.grab_focus()
		return
	var next := button.find_next_valid_focus()
	(next if next and button.get_parent().get_parent().is_ancestor_of(next) else back_button).grab_focus()


func _update_reset_buttons() -> void:
	for button: Button in _reset_buttons:
		if is_instance_valid(button):
			button.disabled = settings.is_default(_reset_buttons[button])


## A switch for the bool [param property] of [member settings], calling [param apply] after it changes.
func _switch(property: String, title: String, description: String, apply: Callable) -> PanelContainer:
	return UIBuilder.switch_row(title, description, settings.get(property), _setter(property, apply),
			"settings:" + property)


## A slider for the number [param property] of [member settings], with its value as [param format]
## gives it beside it, calling [param apply] after each change. With [param on_release], a drag
## applies only when it ends, e.g. for a setting that resizes the slider itself.
func _slider(property: String, title: String, min_value: float, max_value: float, step: float, format: Callable,
		apply: Callable, note: String, on_release := false) -> PanelContainer:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = settings.get(property)
	slider.accessibility_name = title
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.set_meta(&"focus_key", "settings:" + property)
	var shown := UIBuilder.label(format.call(slider.value), "BodyLabel")
	shown.custom_minimum_size.x = 140
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var set_value := _setter(property, apply)
	var dragging := [false]
	slider.drag_started.connect(func() -> void: dragging[0] = true)
	slider.drag_ended.connect(func(changed: bool) -> void:
		dragging[0] = false
		if changed and on_release:
			set_value.call(slider.value))
	slider.value_changed.connect(func(value: float) -> void:
		shown.text = format.call(value)
		slider.accessibility_description = shown.text
		if not (on_release and dragging[0]):
			set_value.call(value))
	slider.accessibility_description = shown.text
	return UIBuilder.setting_row(title, UIBuilder.hbox([slider, shown], 16), note)


## Frees [param tab]'s rows, forgetting its Reset all button.
func _clear(tab: Node) -> void:
	for child in tab.get_children():
		for button: Variant in _reset_buttons.keys():
			if is_instance_valid(button) and child.is_ancestor_of(button):
				_reset_buttons.erase(button)
		tab.remove_child(child)
		child.queue_free()


## The control under [param node] with the focus_key meta [param key], or null.
func _keyed(node: Node, key: String) -> Control:
	for child in node.get_children():
		if child.get_meta(&"focus_key", "") == key:
			return child
		var found := _keyed(child, key)
		if found:
			return found
	return null


## Sets the Fullscreen switch's setting from the window. Separate so tests can stub it, as the test
## runner's window says nothing about the game's.
func _read_window() -> void:
	settings.read_window(get_window())


## Applies the graphics settings to the window and saves them. Separate so tests can stub it and
## leave the test runner's window alone.
func _apply_graphics() -> void:
	settings.apply_graphics(get_window())
	_save()


func _apply_sound() -> void:
	settings.apply_sound()
	_save()


func _save() -> void:
	var error := settings.save()
	if error != OK:
		push_error("Couldn't save settings to %s: %s" % [GameSettings.path, error_string(error)])
