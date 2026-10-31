extends GutTest
## Unit tests for the game map's overlay (scripts/ui/battle/battle_hud.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")
const UIKit := preload("res://test/support/ui_kit.gd")


func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	Sandbox.end()


func _key(keycode: Key) -> InputEventKey:
	return InputBindings.decode([keycode])[0]


func _hud(battle: Battle = null) -> BattleHud:
	var hud := BattleHud.new(battle if battle else BattleKit.battle())
	add_child_autofree(hud)
	return hud


func test_move_keys_show_the_default_keys() -> void:
	assert_eq(BattleHud.move_keys(), "WASD")


func test_turn_keys_show_the_default_keys() -> void:
	assert_eq(BattleHud.turn_keys(), "Q/E")


func test_move_keys_follow_a_rebinding() -> void:
	InputBindings.set_keys("camera_forward", [_key(KEY_I)])
	assert_eq(BattleHud.move_keys(), "IASD")


func test_turn_keys_follow_a_rebinding() -> void:
	InputBindings.set_keys("camera_rotate_left", [_key(KEY_Z)])
	assert_eq(BattleHud.turn_keys(), "Z/E")


func test_long_key_names_are_separated() -> void:
	InputBindings.set_keys("camera_forward", [_key(KEY_UP)])
	assert_string_contains(BattleHud.move_keys(), "/")


func test_unbound_move_keys_say_none() -> void:
	for action in ["camera_forward", "camera_left", "camera_back", "camera_right"]:
		InputBindings.set_keys(action, [])
	assert_eq(BattleHud.move_keys(), "None")


func test_an_unbound_key_is_left_out() -> void:
	InputBindings.set_keys("camera_rotate_left", [])
	assert_eq(BattleHud.turn_keys(), InputBindings.key_name(InputBindings.keys("camera_rotate_right")[0]))


func test_controls_panel_shows_the_current_keys() -> void:
	InputBindings.set_keys("camera_forward", [_key(KEY_I)])
	assert_true(UIKit.has_label_containing(_hud(), BattleHud.move_keys()))


func test_title_is_the_battles_title() -> void:
	var battle := BattleKit.battle()
	battle.title = "Fire and Jade"
	assert_eq(_hud(battle).title_label.text, "Fire and Jade")


func test_pills_show_who_is_the_attacker() -> void:
	var battle := BattleKit.battle()
	battle.player_is_attacker = true
	var hud := _hud(battle)
	assert_true(UIKit.has_label_containing(hud.player_pill, "Attacker"))
	assert_true(UIKit.has_label_containing(hud.opponent_pill, "Defender"))


func test_pills_swap_when_the_player_defends() -> void:
	var battle := BattleKit.battle()
	battle.player_is_attacker = false
	var hud := _hud(battle)
	assert_true(UIKit.has_label_containing(hud.player_pill, "Defender"))
	assert_true(UIKit.has_label_containing(hud.opponent_pill, "Attacker"))


func test_menu_button_emits_menu_pressed() -> void:
	var hud := _hud()
	watch_signals(hud)
	hud.menu_button.pressed.emit()
	assert_signal_emitted(hud, "menu_pressed")


func test_hud_does_not_block_the_mouse() -> void:
	assert_eq(_hud().mouse_filter, Control.MOUSE_FILTER_IGNORE)
