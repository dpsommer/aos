extends GutTest
## Unit tests for the remappable input actions (scripts/settings/input_bindings.gd).

const Sandbox := preload("res://test/support/sandbox.gd")

const ACTION := "ui_accept"
const OTHER := "ui_cancel"


## Binding edits the real InputMap, so each test starts and ends on the default keys.
func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	Sandbox.end()


func _key(keycode: Key, modifiers := 0) -> InputEventKey:
	return InputBindings.decode([keycode | modifiers])[0]


func _codes(action: String) -> Array[int]:
	return InputBindings.encode(InputBindings.keys(action))


# --- Actions ---


func test_actions_lists_every_section_action() -> void:
	var expected := 0
	for section: String in InputBindings.SECTIONS:
		expected += InputBindings.SECTIONS[section].size()
	assert_eq(InputBindings.actions().size(), expected)


func test_every_remappable_action_exists_in_the_input_map() -> void:
	for action in InputBindings.actions():
		assert_true(InputMap.has_action(action), action)


func test_is_remappable_is_true_for_listed_actions_only() -> void:
	assert_true(InputBindings.is_remappable(InputBindings.actions()[0]))
	assert_false(InputBindings.is_remappable("not_an_action"))


func test_display_name_is_found_for_a_listed_action() -> void:
	assert_ne(InputBindings.display_name(ACTION), ACTION)


func test_display_name_falls_back_to_the_action() -> void:
	assert_eq(InputBindings.display_name("not_an_action"), "not_an_action")


# --- Defaults ---


func test_every_action_starts_on_its_default_keys() -> void:
	for action in InputBindings.actions():
		assert_true(InputBindings.is_default(action), action)


func test_default_keys_only_has_keys() -> void:
	for action in InputBindings.actions():
		for key in InputBindings.default_keys(action):
			assert_is(key, InputEventKey)


func test_default_keys_of_unknown_action_is_empty() -> void:
	assert_eq(InputBindings.default_keys("not_an_action").size(), 0)


func test_is_default_is_false_after_set_keys() -> void:
	InputBindings.set_keys(ACTION, [_key(KEY_Q)])
	assert_false(InputBindings.is_default(ACTION))


func test_is_default_is_true_after_restoring_the_defaults() -> void:
	InputBindings.set_keys(ACTION, [_key(KEY_Q)])
	InputBindings.set_keys(ACTION, InputBindings.default_keys(ACTION))
	assert_true(InputBindings.is_default(ACTION))


# --- set_keys ---


func test_set_keys_replaces_the_actions_keys() -> void:
	InputBindings.set_keys(ACTION, [_key(KEY_Q), _key(KEY_W)])
	assert_eq(_codes(ACTION), [KEY_Q, KEY_W] as Array[int])


func test_set_keys_with_none_removes_every_key() -> void:
	InputBindings.set_keys(ACTION, [])
	assert_eq(InputBindings.keys(ACTION).size(), 0)


func test_set_keys_keeps_other_events() -> void:
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_X
	InputMap.action_add_event(ACTION, button)
	InputBindings.set_keys(ACTION, [_key(KEY_Q)])
	assert_true(InputMap.action_has_event(ACTION, button))


func test_set_keys_leaves_other_actions_alone() -> void:
	var before := _codes(OTHER)
	InputBindings.set_keys(ACTION, [_key(KEY_Q)])
	assert_eq(_codes(OTHER), before)


# --- bind ---


func test_bind_adds_a_key() -> void:
	var before := _codes(ACTION)
	InputBindings.bind(ACTION, _key(KEY_Q))
	assert_eq(_codes(ACTION), before + [KEY_Q] as Array[int])


func test_bind_replacing_swaps_that_key() -> void:
	InputBindings.set_keys(ACTION, [_key(KEY_Q), _key(KEY_W)])
	InputBindings.bind(ACTION, _key(KEY_E), _key(KEY_Q))
	assert_eq(_codes(ACTION), [KEY_E, KEY_W] as Array[int])


func test_bind_replacing_a_key_the_action_lacks_adds_it() -> void:
	InputBindings.set_keys(ACTION, [_key(KEY_Q)])
	InputBindings.bind(ACTION, _key(KEY_E), _key(KEY_Z))
	assert_eq(_codes(ACTION), [KEY_Q, KEY_E] as Array[int])


func test_bind_takes_the_key_from_another_action() -> void:
	InputBindings.set_keys(OTHER, [_key(KEY_F9)])
	InputBindings.bind(ACTION, _key(KEY_F9))
	assert_eq(InputBindings.keys(OTHER).size(), 0)


func test_bind_returns_the_actions_it_took_the_key_from() -> void:
	InputBindings.set_keys(OTHER, [_key(KEY_F9)])
	assert_eq(InputBindings.bind(ACTION, _key(KEY_F9)), PackedStringArray([OTHER]))


func test_bind_returns_nothing_when_no_action_had_the_key() -> void:
	assert_eq(InputBindings.bind(ACTION, _key(KEY_F9)).size(), 0)


func test_bind_does_not_report_the_action_itself() -> void:
	InputBindings.set_keys(ACTION, [_key(KEY_F9)])
	assert_eq(InputBindings.bind(ACTION, _key(KEY_F9)).size(), 0)


func test_bind_keeps_a_key_with_different_modifiers_on_other_actions() -> void:
	InputBindings.set_keys(OTHER, [_key(KEY_Q, KEY_MASK_SHIFT)])
	InputBindings.bind(ACTION, _key(KEY_Q))
	assert_eq(_codes(OTHER), [KEY_Q | KEY_MASK_SHIFT] as Array[int])


func test_bind_does_not_duplicate_a_key_the_action_has() -> void:
	InputBindings.set_keys(ACTION, [_key(KEY_Q)])
	InputBindings.bind(ACTION, _key(KEY_Q))
	assert_eq(_codes(ACTION), [KEY_Q] as Array[int])


# --- unbind ---


func test_unbind_removes_only_that_key() -> void:
	InputBindings.set_keys(ACTION, [_key(KEY_Q), _key(KEY_W)])
	InputBindings.unbind(ACTION, _key(KEY_Q))
	assert_eq(_codes(ACTION), [KEY_W] as Array[int])


func test_unbind_ignores_a_key_the_action_lacks() -> void:
	InputBindings.set_keys(ACTION, [_key(KEY_Q)])
	InputBindings.unbind(ACTION, _key(KEY_W))
	assert_eq(_codes(ACTION), [KEY_Q] as Array[int])


func test_unbind_distinguishes_modifiers() -> void:
	InputBindings.set_keys(ACTION, [_key(KEY_Q), _key(KEY_Q, KEY_MASK_SHIFT)])
	InputBindings.unbind(ACTION, _key(KEY_Q))
	assert_eq(_codes(ACTION), [KEY_Q | KEY_MASK_SHIFT] as Array[int])


# --- encode and decode ---


func test_decode_round_trips_plain_keys() -> void:
	var codes: Array[int] = [KEY_Q, KEY_ENTER]
	assert_eq(InputBindings.encode(InputBindings.decode(codes)), codes)


func test_decode_round_trips_modifiers() -> void:
	var codes: Array[int] = [KEY_S | KEY_MASK_SHIFT | KEY_MASK_ALT | KEY_MASK_CTRL | KEY_MASK_META]
	assert_eq(InputBindings.encode(InputBindings.decode(codes)), codes)


func test_decode_sets_modifier_flags() -> void:
	var key := InputBindings.decode([KEY_S | KEY_MASK_SHIFT | KEY_MASK_CTRL])[0]
	assert_true(key.shift_pressed)
	assert_true(key.ctrl_pressed)
	assert_false(key.alt_pressed)
	assert_false(key.meta_pressed)
	assert_eq(key.keycode, KEY_S)


func test_decode_sets_command_or_control_autoremap() -> void:
	var key := InputBindings.decode([KEY_S | KEY_MASK_CMD_OR_CTRL])[0]
	assert_true(key.command_or_control_autoremap)
	assert_eq(key.keycode, KEY_S)


func test_decode_accepts_floats() -> void:
	assert_eq(InputBindings.decode([float(KEY_Q)])[0].keycode, KEY_Q)


func test_decode_ignores_non_numeric_entries() -> void:
	var keys := InputBindings.decode(["Q", null, KEY_W, [1]])
	assert_eq(InputBindings.encode(keys), [KEY_W] as Array[int])


func test_decode_of_a_non_array_is_empty() -> void:
	assert_eq(InputBindings.decode("nonsense").size(), 0)
	assert_eq(InputBindings.decode(null).size(), 0)


func test_encode_of_no_keys_is_empty() -> void:
	assert_eq(InputBindings.encode([] as Array[InputEventKey]).size(), 0)


func test_key_name_is_not_empty() -> void:
	assert_ne(InputBindings.key_name(_key(KEY_Q, KEY_MASK_SHIFT)), "")


func test_encode_keeps_command_or_control_portable() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_S
	key.command_or_control_autoremap = true
	var decoded := InputBindings.decode(InputBindings.encode([key]))[0]
	assert_true(decoded.command_or_control_autoremap)
	assert_eq(InputBindings.key_code(decoded), InputBindings.key_code(key))


# --- Battle section ---


func test_battle_section_lists_the_camera_actions() -> void:
	var actions: Array[String] = []
	for entry: Array in InputBindings.SECTIONS["Battle"]:
		actions.append(entry[0])
	assert_eq(actions.size(), 6)
	for action in ["camera_forward", "camera_back", "camera_left", "camera_right", "camera_rotate_left", "camera_rotate_right"]:
		assert_true(action in actions, action)


func test_every_camera_action_has_a_default_key() -> void:
	for entry: Array in InputBindings.SECTIONS["Battle"]:
		assert_gt(InputBindings.keys(entry[0]).size(), 0, entry[0])


func test_camera_actions_have_different_default_keys() -> void:
	var seen := {}
	for entry: Array in InputBindings.SECTIONS["Battle"]:
		for code in _codes(entry[0]):
			assert_false(seen.has(code), entry[0])
			seen[code] = true


func test_camera_actions_have_display_names() -> void:
	for entry: Array in InputBindings.SECTIONS["Battle"]:
		assert_eq(InputBindings.display_name(entry[0]), entry[1])
