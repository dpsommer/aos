extends GutTest
## Unit tests for Spearhead's deployment map picker (scripts/ui/battle/deployment_map_picker.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")


func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	Sandbox.end()


func _battle(map_names: Array[String] = ["First", "Second"]) -> Battle:
	var battle := BattleKit.battle()
	battle.battlepack = BattleKit.spearhead_pack("Pack", ["Aqshy"] as Array[String])
	var maps: Array[DeploymentMap] = []
	for map_name in map_names:
		maps.append(BattleKit.deployment(map_name))
	battle.battlepack.deployment_maps = maps
	battle.realm = battle.battlepack.realms[0]
	return battle


func _picker(battle: Battle = null) -> DeploymentMapPicker:
	var picker := DeploymentMapPicker.new(battle if battle else _battle())
	add_child_autofree(picker)
	return picker


func test_there_is_a_button_per_map() -> void:
	assert_eq(_picker().map_buttons.size(), 2)


func test_the_first_map_and_territory_a_are_picked_to_begin_with() -> void:
	var battle := _battle()
	var picker := _picker(battle)
	assert_eq(picker.selection(), [battle.battlepack.deployment_maps[0], true])


func test_the_first_map_button_starts_pressed() -> void:
	var picker := _picker()
	assert_true(picker.map_buttons[0].button_pressed)
	assert_false(picker.map_buttons[1].button_pressed)


func test_picking_a_map_selects_it() -> void:
	var battle := _battle()
	var picker := _picker(battle)
	picker.map_buttons[1].pressed.emit()
	assert_same(picker.selection()[0], battle.battlepack.deployment_maps[1])
	assert_true(picker.map_buttons[1].button_pressed)
	assert_false(picker.map_buttons[0].button_pressed)


func test_picking_territory_b_selects_it() -> void:
	var picker := _picker()
	picker.territory_b_button.pressed.emit()
	assert_false(picker.selection()[1])
	assert_true(picker.territory_b_button.button_pressed)
	assert_false(picker.territory_a_button.button_pressed)


func test_picking_territory_a_again_selects_it() -> void:
	var picker := _picker()
	picker.territory_b_button.pressed.emit()
	picker.territory_a_button.pressed.emit()
	assert_true(picker.selection()[1])


func test_confirm_emits_the_picked_map_and_territory() -> void:
	var battle := _battle()
	var picker := _picker(battle)
	picker.map_buttons[1].pressed.emit()
	picker.territory_b_button.pressed.emit()
	watch_signals(picker)
	picker.confirm_button.pressed.emit()
	assert_signal_emitted_with_parameters(picker, "chosen", [battle.battlepack.deployment_maps[1], false])


func test_confirm_emits_the_default_without_any_picking() -> void:
	var battle := _battle()
	var picker := _picker(battle)
	watch_signals(picker)
	picker.confirm_button.pressed.emit()
	assert_signal_emitted_with_parameters(picker, "chosen", [battle.battlepack.deployment_maps[0], true])


func test_the_confirm_button_names_the_pick() -> void:
	var picker := _picker()
	picker.map_buttons[1].pressed.emit()
	picker.territory_b_button.pressed.emit()
	assert_string_contains(picker.confirm_button.text, "Second")
	assert_string_contains(picker.confirm_button.text, "B")


func test_a_preview_of_the_picked_map_is_shown() -> void:
	assert_eq(_picker().preview_holder.get_child_count(), 1)


func test_changing_the_pick_keeps_a_single_preview() -> void:
	var picker := _picker()
	picker.map_buttons[1].pressed.emit()
	await wait_process_frames(1)
	assert_eq(picker.preview_holder.get_child_count(), 1)


func test_without_maps_nothing_can_be_confirmed() -> void:
	var picker := _picker(_battle([] as Array[String]))
	watch_signals(picker)
	assert_true(picker.confirm_button.disabled)
	picker.confirm_button.pressed.emit()
	assert_signal_not_emitted(picker, "chosen")


func test_without_maps_there_are_no_map_buttons() -> void:
	assert_eq(_picker(_battle([] as Array[String])).map_buttons.size(), 0)
