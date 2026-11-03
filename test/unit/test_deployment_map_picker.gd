extends GutTest
## Unit tests for Spearhead's deployment map picker (scripts/ui/battle/deployment_map_picker.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")


func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	Sandbox.end()


## A battle whose battlepack has the sides Aqshy and Ghyran, with the realm picked unless
## [param picked_realm] is false.
func _battle(map_names: Array[String] = ["First", "Second"], picked_realm := true) -> Battle:
	var battle := BattleKit.battle()
	battle.battlepack = BattleKit.spearhead_pack("Pack", ["Aqshy", "Ghyran"] as Array[String])
	var maps: Array[DeploymentMap] = []
	for map_name in map_names:
		maps.append(BattleKit.deployment(map_name))
	battle.battlepack.deployment_maps = maps
	battle.realm = battle.battlepack.realms[0] if picked_realm else null
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
	assert_eq(picker.selection(), [battle.battlepack.realms[0], battle.battlepack.deployment_maps[0], true])


func test_the_first_map_button_starts_pressed() -> void:
	var picker := _picker()
	assert_true(picker.map_buttons[0].button_pressed)
	assert_false(picker.map_buttons[1].button_pressed)


func test_picking_a_map_selects_it() -> void:
	var battle := _battle()
	var picker := _picker(battle)
	picker.map_buttons[1].pressed.emit()
	assert_same(picker.selection()[1], battle.battlepack.deployment_maps[1])
	assert_true(picker.map_buttons[1].button_pressed)
	assert_false(picker.map_buttons[0].button_pressed)


func test_picking_territory_b_selects_it() -> void:
	var picker := _picker()
	picker.territory_b_button.pressed.emit()
	assert_false(picker.selection()[2])
	assert_true(picker.territory_b_button.button_pressed)
	assert_false(picker.territory_a_button.button_pressed)


func test_picking_territory_a_again_selects_it() -> void:
	var picker := _picker()
	picker.territory_b_button.pressed.emit()
	picker.territory_a_button.pressed.emit()
	assert_true(picker.selection()[2])


func test_confirm_emits_the_picked_map_and_territory() -> void:
	var battle := _battle()
	var picker := _picker(battle)
	picker.map_buttons[1].pressed.emit()
	picker.territory_b_button.pressed.emit()
	watch_signals(picker)
	picker.confirm_button.pressed.emit()
	assert_signal_emitted_with_parameters(picker, "chosen", [battle.battlepack.realms[0], battle.battlepack.deployment_maps[1], false])


func test_confirm_emits_the_default_without_any_picking() -> void:
	var battle := _battle()
	var picker := _picker(battle)
	watch_signals(picker)
	picker.confirm_button.pressed.emit()
	assert_signal_emitted_with_parameters(picker, "chosen", [battle.battlepack.realms[0], battle.battlepack.deployment_maps[0], true])


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


func test_there_is_a_button_per_side() -> void:
	assert_eq(_picker().realm_buttons.size(), 2)


func test_the_battles_side_is_picked_to_begin_with() -> void:
	var battle := _battle()
	battle.realm = battle.battlepack.realms[1]
	var picker := _picker(battle)
	assert_same(picker.selection()[0], battle.realm)
	assert_true(picker.realm_buttons[1].button_pressed)


func test_the_first_side_is_picked_when_the_battle_has_none() -> void:
	var battle := _battle(["First", "Second"], false)
	var picker := _picker(battle)
	assert_same(picker.selection()[0], battle.battlepack.realms[0])
	assert_true(picker.realm_buttons[0].button_pressed)


func test_picking_a_side_selects_it() -> void:
	var battle := _battle()
	var picker := _picker(battle)
	picker.realm_buttons[1].pressed.emit()
	assert_same(picker.selection()[0], battle.battlepack.realms[1])
	assert_true(picker.realm_buttons[1].button_pressed)
	assert_false(picker.realm_buttons[0].button_pressed)


func test_picking_a_side_keeps_the_map_and_territory() -> void:
	var battle := _battle()
	var picker := _picker(battle)
	picker.map_buttons[1].pressed.emit()
	picker.territory_b_button.pressed.emit()
	picker.realm_buttons[1].pressed.emit()
	assert_eq(picker.selection(), [battle.battlepack.realms[1], battle.battlepack.deployment_maps[1], false])


func test_confirm_emits_the_picked_side() -> void:
	var battle := _battle()
	var picker := _picker(battle)
	picker.realm_buttons[1].pressed.emit()
	watch_signals(picker)
	picker.confirm_button.pressed.emit()
	assert_signal_emitted_with_parameters(picker, "chosen", [battle.battlepack.realms[1], battle.battlepack.deployment_maps[0], true])


func test_the_confirm_button_names_the_side() -> void:
	var picker := _picker()
	picker.realm_buttons[1].pressed.emit()
	assert_string_contains(picker.confirm_button.text, "Ghyran")


func test_changing_the_side_keeps_a_single_preview() -> void:
	var picker := _picker()
	picker.realm_buttons[1].pressed.emit()
	await wait_process_frames(1)
	assert_eq(picker.preview_holder.get_child_count(), 1)
