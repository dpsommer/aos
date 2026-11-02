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


func _header_is_off_screen(hud: BattleHud) -> bool:
	return hud.header.position.y + hud.header.size.y < 1.0


## Waits until [param done] is true, or a little longer than a slide takes.
func _await_slide(done: Callable) -> void:
	await wait_until(done, BattleHud.SLIDE_SECONDS + 0.5)


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


func test_menu_button_is_the_last_thing_in_the_header() -> void:
	var hud := _hud()
	var row := hud.menu_button.get_parent()
	assert_eq(row.get_child(row.get_child_count() - 1), hud.menu_button)


func test_menu_button_is_inside_the_header() -> void:
	var hud := _hud()
	assert_true(hud.header.is_ancestor_of(hud.menu_button))


func test_menu_button_is_an_icon_button() -> void:
	var button := _hud().menu_button
	assert_not_null(button.icon)
	assert_true(button.text.is_empty())


func test_header_starts_at_the_top_of_the_screen() -> void:
	assert_eq(_hud().header.position.y, 0.0)


func test_hiding_the_header_slides_it_off_screen() -> void:
	var hud := _hud()
	await get_tree().process_frame
	hud.set_header_hidden(true)
	await _await_slide(_header_is_off_screen.bind(hud))
	assert_true(_header_is_off_screen(hud), "the header slides off screen")


func test_showing_the_header_slides_it_back() -> void:
	var hud := _hud()
	await get_tree().process_frame
	hud.set_header_hidden(true)
	await _await_slide(_header_is_off_screen.bind(hud))
	hud.set_header_hidden(false)
	await _await_slide(func() -> bool: return is_equal_approx(hud.header.position.y, 0.0))
	assert_almost_eq(hud.header.position.y, 0.0, 0.01)


func test_refresh_controls_shows_rebound_keys() -> void:
	var hud := _hud()
	InputBindings.set_keys("camera_forward", [_key(KEY_I)])
	hud.refresh_controls()
	assert_true(UIKit.has_label_containing(hud.controls, BattleHud.move_keys()))


func test_refresh_controls_replaces_the_old_panel() -> void:
	var hud := _hud()
	var old := hud.controls
	hud.refresh_controls()
	assert_ne(hud.controls, old)
	assert_eq(hud.controls.get_parent(), hud)


func test_refresh_controls_keeps_a_single_controls_panel() -> void:
	var hud := _hud()
	var before := hud.get_child_count()
	hud.refresh_controls()
	await get_tree().process_frame
	assert_eq(hud.get_child_count(), before)


func test_menu_tooltip_names_the_back_key() -> void:
	assert_eq(BattleHud.menu_tooltip(), "Menu (%s)" % InputBindings.key_name(InputBindings.keys("ui_cancel")[0]))


func test_menu_tooltip_follows_a_rebinding() -> void:
	InputBindings.set_keys("ui_cancel", [_key(KEY_P)])
	assert_eq(BattleHud.menu_tooltip(), "Menu (P)")


func test_menu_tooltip_names_only_the_first_back_key() -> void:
	InputBindings.set_keys("ui_cancel", [_key(KEY_P), _key(KEY_O)])
	assert_false(BattleHud.menu_tooltip().contains("O"))


func test_menu_tooltip_has_no_key_when_back_is_unbound() -> void:
	InputBindings.set_keys("ui_cancel", [])
	assert_eq(BattleHud.menu_tooltip(), "Menu")


func test_menu_button_shows_the_menu_tooltip() -> void:
	InputBindings.set_keys("ui_cancel", [_key(KEY_P)])
	assert_eq(_hud().menu_button.tooltip_text, "Menu (P)")


func test_refresh_controls_updates_the_menu_tooltip() -> void:
	var hud := _hud()
	InputBindings.set_keys("ui_cancel", [_key(KEY_P)])
	hud.refresh_controls()
	assert_eq(hud.menu_button.tooltip_text, "Menu (P)")


# roles and the pills

func test_pills_omit_roles_before_the_roll_off() -> void:
	var battle := BattleKit.battle()
	battle.roles_assigned = false
	var hud := _hud(battle)
	assert_false(UIKit.has_label_containing(hud.player_pill, "Attacker"))
	assert_false(UIKit.has_label_containing(hud.player_pill, "Defender"))
	assert_false(UIKit.has_label_containing(hud.opponent_pill, "Attacker"))
	assert_false(UIKit.has_label_containing(hud.opponent_pill, "Defender"))


func test_pills_show_the_roles_once_refreshed_after_the_roll_off() -> void:
	var battle := BattleKit.battle()
	battle.roles_assigned = false
	var hud := _hud(battle)
	battle.roles_assigned = true
	hud.refresh_roles()
	assert_true(UIKit.has_label_containing(hud.player_pill, "Attacker"))


func test_pills_show_how_many_units_each_side_has_left() -> void:
	var hud := _hud()
	hud.refresh_roles(3, 5)
	assert_true(UIKit.has_label_containing(hud.player_pill, "3 left"))
	assert_true(UIKit.has_label_containing(hud.opponent_pill, "5 left"))


func test_pills_leave_the_count_out_by_default() -> void:
	var hud := _hud()
	hud.refresh_roles()
	assert_false(UIKit.has_label_containing(hud.player_pill, "left"))


func test_a_side_with_none_left_says_so() -> void:
	var hud := _hud()
	hud.refresh_roles(0, 2)
	assert_true(UIKit.has_label_containing(hud.player_pill, "0 left"))


func test_the_pill_text_separates_its_parts() -> void:
	var hud := _hud()
	hud.refresh_roles(4, -1)
	assert_string_contains(hud.player_pill_label.text, " · ")


# set_phase

func test_set_phase_shows_the_phase_name() -> void:
	var hud := _hud()
	hud.set_phase("DEPLOYMENT")
	assert_eq(hud.phase_label.text, "DEPLOYMENT")


func test_set_phase_without_steps_hides_the_step_list() -> void:
	var hud := _hud()
	hud.set_phase("DEPLOYMENT", PackedStringArray(["One", "Two"]), 0)
	hud.set_phase("PRE-BATTLE")
	assert_false(hud.steps_row.visible)


func test_set_phase_lists_each_step() -> void:
	var hud := _hud()
	hud.set_phase("DEPLOYMENT", PackedStringArray(["Terrain", "Armies", "Abilities"]), 1)
	assert_true(UIKit.has_label_containing(hud.steps_row, "Terrain"))
	assert_true(UIKit.has_label_containing(hud.steps_row, "Armies"))
	assert_true(UIKit.has_label_containing(hud.steps_row, "Abilities"))
	assert_true(hud.steps_row.visible)


func test_set_phase_ticks_the_steps_before_the_current_one() -> void:
	var hud := _hud()
	hud.set_phase("DEPLOYMENT", PackedStringArray(["Terrain", "Armies", "Abilities"]), 1)
	var texts := UIKit.label_texts(hud.steps_row)
	assert_true(texts[0].begins_with("✓"))
	assert_false(texts[1].begins_with("✓"))
	assert_false(texts[2].begins_with("✓"))


func test_set_phase_marks_the_current_step_for_screen_readers() -> void:
	var hud := _hud()
	hud.set_phase("DEPLOYMENT", PackedStringArray(["Terrain", "Armies"]), 1)
	var labels := UIKit.find_all(hud.steps_row, func(n: Node) -> bool: return n is Label)
	assert_string_contains((labels[1] as Label).accessibility_name, "current step")
	assert_string_contains((labels[0] as Label).accessibility_name, "done")


func test_set_phase_replaces_the_previous_steps() -> void:
	var hud := _hud()
	hud.set_phase("DEPLOYMENT", PackedStringArray(["Terrain", "Armies"]), 0)
	hud.set_phase("DEPLOYMENT", PackedStringArray(["Armies"]), 0)
	await wait_process_frames(1)
	assert_eq(UIKit.label_texts(hud.steps_row).size(), 1)


# extra controls

func test_extra_controls_are_added_to_the_controls_panel() -> void:
	var hud := _hud()
	hud.set_extra_controls(PackedStringArray(["R  rotate unit"]))
	assert_true(UIKit.has_label_containing(hud.controls, "rotate unit"))


func test_removing_the_extra_controls_takes_them_off_the_panel() -> void:
	var hud := _hud()
	hud.set_extra_controls(PackedStringArray(["R  rotate unit"]))
	hud.set_extra_controls(PackedStringArray())
	assert_false(UIKit.has_label_containing(hud.controls, "rotate unit"))


func test_extra_controls_survive_a_refresh_of_the_keys() -> void:
	var hud := _hud()
	hud.set_extra_controls(PackedStringArray(["R  rotate unit"]))
	hud.refresh_controls()
	assert_true(UIKit.has_label_containing(hud.controls, "rotate unit"))


func test_controls_bottom_moves_the_panel_up() -> void:
	var hud := _hud()
	var before := hud.controls.position.y
	hud.set_controls_bottom(200.0)
	assert_lt(hud.controls.position.y, before)


func test_the_raised_controls_panel_stays_raised_after_a_refresh() -> void:
	var hud := _hud()
	hud.set_controls_bottom(200.0)
	var raised := hud.controls.position.y
	hud.refresh_controls()
	assert_eq(hud.controls.position.y, raised)


# key_for

func test_key_for_is_the_first_bound_key() -> void:
	InputBindings.set_keys("camera_forward", [_key(KEY_I)])
	assert_eq(BattleHud.key_for("camera_forward"), "I")


func test_key_for_an_unbound_action_says_none() -> void:
	InputBindings.set_keys("camera_forward", [])
	assert_eq(BattleHud.key_for("camera_forward"), "None")


func test_refreshing_the_controls_does_not_repeat_the_camera_lines() -> void:
	var hud := _hud()
	var before := UIKit.label_texts(hud.controls).size()
	hud.refresh_controls()
	assert_eq(UIKit.label_texts(hud.controls).size(), before)
