class_name InputBindings
extends RefCounted
## The input actions players can remap, and their keys. An action's keys are its [InputEventKey]s in
## the [InputMap]; its other events (e.g. gamepad buttons) are left alone.

## Remappable actions in display order, as [action, name] pairs, by section.
const SECTIONS := {
	"Menus": [
		["ui_accept", "Confirm"],
		["ui_cancel", "Back"],
		["ui_up", "Up"],
		["ui_down", "Down"],
		["ui_left", "Left"],
		["ui_right", "Right"],
		["ui_focus_next", "Next control"],
		["ui_focus_prev", "Previous control"],
	],
	"Forge": [
		["save_army", "Save army"],
	],
}


## Every remappable action, in display order.
static func actions() -> PackedStringArray:
	var result := PackedStringArray()
	for section: String in SECTIONS:
		for entry: Array in SECTIONS[section]:
			result.append(entry[0])
	return result


static func is_remappable(action: String) -> bool:
	return action in actions()


static func display_name(action: String) -> String:
	for section: String in SECTIONS:
		for entry: Array in SECTIONS[section]:
			if entry[0] == action:
				return entry[1]
	return action


## [param action]'s keys in the [InputMap].
static func keys(action: String) -> Array[InputEventKey]:
	var result: Array[InputEventKey] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			result.append(event)
	return result


## [param action]'s keys as project.godot (or the engine, for built-in actions) defines them.
static func default_keys(action: String) -> Array[InputEventKey]:
	var result: Array[InputEventKey] = []
	var setting: Variant = ProjectSettings.get_setting("input/" + action)
	if setting is Dictionary:
		for event: InputEvent in setting.get("events", []):
			if event is InputEventKey:
				result.append(event)
	return result


static func is_default(action: String) -> bool:
	return encode(keys(action)) == encode(default_keys(action))


## Replaces [param action]'s keys with [param new_keys], keeping its other events.
static func set_keys(action: String, new_keys: Array[InputEventKey]) -> void:
	for event in keys(action):
		InputMap.action_erase_event(action, event)
	for event in new_keys:
		InputMap.action_add_event(action, event)


## Binds [param key] to [param action], replacing [param replacing] if it's one of the action's keys,
## else adding it. The key is taken from any other remappable action that has it. Returns the
## actions it was taken from.
static func bind(action: String, key: InputEventKey, replacing: InputEventKey = null) -> PackedStringArray:
	var taken_from := PackedStringArray()
	var code := key_code(key)
	for other in actions():
		var kept: Array[InputEventKey] = []
		for event in keys(other):
			if key_code(event) != code:
				kept.append(event)
		if kept.size() < keys(other).size() and other != action:
			taken_from.append(other)
		set_keys(other, kept)
	var new_keys := keys(action)
	var index := -1
	if replacing:
		for i in new_keys.size():
			if key_code(new_keys[i]) == key_code(replacing):
				index = i
	var bound := decode([code])[0]
	if index >= 0:
		new_keys[index] = bound
	else:
		new_keys.append(bound)
	set_keys(action, new_keys)
	return taken_from


## Removes [param key] from [param action].
static func unbind(action: String, key: InputEventKey) -> void:
	var kept: Array[InputEventKey] = []
	for event in keys(action):
		if key_code(event) != key_code(key):
			kept.append(event)
	set_keys(action, kept)


## A key with its modifiers as one number, e.g. [code]KEY_S | KEY_MASK_CTRL[/code]. Command or Control
## keys that follow the platform keep [constant KEY_MASK_CMD_OR_CTRL].
static func key_code(key: InputEventKey) -> int:
	var code := key.get_keycode_with_modifiers()
	if key.command_or_control_autoremap:
		# The engine resolves the flag to this platform's modifier; keep it portable instead.
		var platform_mask := KEY_MASK_META if OS.has_feature("macos") else KEY_MASK_CTRL
		code = (code & ~platform_mask) | KEY_MASK_CMD_OR_CTRL
	return code


## [param key]'s name, e.g. "Enter" or "Shift+Tab", with Command or Control named for this platform.
static func key_name(key: InputEventKey) -> String:
	return key.as_text()


## Keys as saved in the settings: [method key_code] for each.
static func encode(key_list: Array[InputEventKey]) -> Array[int]:
	var result: Array[int] = []
	for key in key_list:
		result.append(key_code(key))
	return result


## The keys saved by [method encode]. Ignores anything that isn't a key code.
static func decode(codes: Variant) -> Array[InputEventKey]:
	var result: Array[InputEventKey] = []
	if not codes is Array:
		return result
	for code: Variant in codes:
		if not (code is int or code is float):
			continue
		var value := int(code)
		var key := InputEventKey.new()
		key.keycode = value & KEY_CODE_MASK
		key.shift_pressed = value & KEY_MASK_SHIFT != 0
		key.alt_pressed = value & KEY_MASK_ALT != 0
		key.ctrl_pressed = value & KEY_MASK_CTRL != 0
		key.meta_pressed = value & KEY_MASK_META != 0
		key.command_or_control_autoremap = value & KEY_MASK_CMD_OR_CTRL != 0
		result.append(key)
	return result
