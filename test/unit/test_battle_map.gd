extends GutTest
## Unit tests for the game map (scripts/battle/battle_map.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")
const MapScene := preload("res://scenes/battle/battle_map.tscn")


func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	Sandbox.end()


func _map() -> BattleMap:
	var map: BattleMap = MapScene.instantiate()
	add_child_autofree(map)
	return map


## A map built all at once for [method _battle], or for [param battle] if given.
func _built_map(battle: Battle = null) -> BattleMap:
	var map := _map()
	map.build(battle if battle else _battle())
	return map


## A battle with 2 battlefield features, one for each army and two units a side.
func _battle() -> Battle:
	var battle := BattleKit.battle()
	battle.player.units.append(BattleKit.unit("Second", 3))
	battle.opponent.units.append(BattleKit.unit("Second", 3))
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 4.0, Vector2(12, 5)))
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.AREA_OR_OBSTACLE, 4.0, Vector2(12, 15)))
	battle.player.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	battle.objectives = [BattleKit.feature("Objective", Vector2(15, 11))] as Array[MapFeature]
	return battle


func _stages(steps: Array[Dictionary]) -> Array:
	return steps.map(func(step: Dictionary) -> int: return step.stage)


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _escape() -> InputEventAction:
	return _action("ui_cancel")


func _header_is_off_screen(map: BattleMap) -> bool:
	return map.hud.header.position.y + map.hud.header.size.y < 1.0


## Waits until [param done] is true, or a little longer than the header's slide takes.
func _await_slide(done: Callable) -> void:
	await wait_until(done, BattleHud.SLIDE_SECONDS + 0.5)


# build_steps

func test_build_steps_has_a_step_per_terrain_feature_and_unit() -> void:
	var battle := _battle()
	var steps := _map().build_steps(battle)
	var terrain := battle.all_terrain().size()
	var units := battle.player.units.size() + battle.opponent.units.size()
	var of_stage := func(stage: BattleMap.Stage) -> int: return _stages(steps).count(stage)
	assert_eq(of_stage.call(BattleMap.Stage.BATTLEFIELD), 1, "one battlefield step")
	assert_eq(of_stage.call(BattleMap.Stage.TERRAIN), terrain, "a step per terrain feature")
	assert_eq(of_stage.call(BattleMap.Stage.OBJECTIVES), 1, "one objectives step")
	assert_eq(of_stage.call(BattleMap.Stage.PLAYER_MODELS) + of_stage.call(BattleMap.Stage.OPPONENT_MODELS), units,
			"a step per unit")


func test_build_steps_are_in_stage_order() -> void:
	var stages := _stages(_map().build_steps(_battle()))
	var sorted := stages.duplicate()
	sorted.sort()
	assert_eq(stages, sorted)


func test_build_steps_start_with_the_battlefield() -> void:
	assert_eq(_map().build_steps(_battle())[0].stage, BattleMap.Stage.BATTLEFIELD)


func test_build_steps_end_with_the_opponents_models() -> void:
	var steps := _map().build_steps(_battle())
	assert_eq(steps[steps.size() - 1].stage, BattleMap.Stage.OPPONENT_MODELS)


func test_every_step_has_text_and_something_to_run() -> void:
	for step in _map().build_steps(_battle()):
		assert_false(step.text.is_empty(), "step %s has text" % step.stage)
		assert_true(step.run.is_valid(), "step %s has something to run" % step.stage)


func test_an_army_without_units_still_has_a_step() -> void:
	var battle := _battle()
	battle.opponent.units.clear()
	assert_true(_stages(_map().build_steps(battle)).has(BattleMap.Stage.OPPONENT_MODELS))


func test_terrain_step_text_counts_the_features() -> void:
	var battle := _battle()
	var steps := _map().build_steps(battle)
	var total := battle.all_terrain().size()
	var texts: Array = steps.filter(func(step: Dictionary) -> bool: return step.stage == BattleMap.Stage.TERRAIN).map(func(step: Dictionary) -> String: return step.text)
	assert_string_contains(texts[0], "1 of %d" % total)
	assert_string_contains(texts[texts.size() - 1], "%d of %d" % [total, total])


func test_build_steps_do_nothing_until_run() -> void:
	var map := _map()
	var before := map.get_child_count()
	map.build_steps(_battle())
	assert_eq(map.get_child_count(), before)


func test_running_every_step_builds_the_map() -> void:
	var map := _map()
	for step in map.build_steps(_battle()):
		step.run.call()
	assert_not_null(map.camera)
	assert_not_null(map.hud)


# build

func test_build_adds_the_board() -> void:
	assert_not_null(_built_map().get_node_or_null("Board"))


func test_build_adds_both_territories() -> void:
	var map := _built_map()
	assert_not_null(map.get_node_or_null("PlayerTerritory"))
	assert_not_null(map.get_node_or_null("OpponentTerritory"))


func test_build_adds_the_camera() -> void:
	var map := _built_map()
	assert_is(map.camera, BattleCamera)
	assert_eq(map.camera.get_parent(), map)


func test_build_adds_the_hud() -> void:
	var map := _built_map()
	assert_is(map.hud, BattleHud)
	assert_true(map.hud.is_inside_tree())


func test_build_limits_the_camera_to_the_battlefield() -> void:
	var battle := _battle()
	var map := _built_map(battle)
	assert_eq(map.camera.bounds, Rect2(Vector2.ZERO, battle.battlefield_size))


func _placed_count(battle: Battle) -> int:
	return battle.all_terrain().filter(func(feature: BattleTerrain) -> bool: return feature.placed).size()


func test_build_adds_a_node_per_placed_terrain_feature() -> void:
	var battle := _battle()
	var map := _built_map(battle)
	assert_eq(map.terrain_root.get_child_count(), _placed_count(battle))


func test_build_leaves_army_terrain_for_deployment() -> void:
	var battle := _battle()
	_built_map(battle)
	assert_false(battle.player.terrain[0].placed)


func test_build_adds_a_node_per_objective() -> void:
	var battle := _battle()
	var map := _built_map(battle)
	assert_eq(map.objectives_root.get_child_count(), battle.objectives.size())


func test_build_leaves_the_armies_for_deployment() -> void:
	var map := _built_map()
	assert_eq(map.armies_root.get_child_count(), 0)


func test_build_does_not_deploy_any_unit() -> void:
	var battle := _battle()
	_built_map(battle)
	assert_false(battle.player.units[0].deployed)


func test_build_leaves_out_roads_when_the_battle_has_none() -> void:
	assert_null(_built_map().get_node_or_null("Roads"))


func test_build_adds_the_battles_roads() -> void:
	var battle := _battle()
	battle.roads = [BattleKit.rect_polygon(0, 10, 30, 2)] as Array[PackedVector2Array]
	assert_not_null(_built_map(battle).get_node_or_null("Roads"))


# Menu

func test_build_adds_a_hidden_pause_menu() -> void:
	var map := _built_map()
	assert_is(map.pause_menu, PauseMenu)
	assert_false(map.pause_menu.visible)


func test_the_menu_starts_closed() -> void:
	assert_false(_built_map().is_menu_open())


func test_menu_button_opens_the_menu() -> void:
	var map := _built_map()
	map.hud.menu_button.pressed.emit()
	assert_true(map.is_menu_open())


func test_escape_opens_the_menu() -> void:
	var map := _built_map()
	map._unhandled_input(_escape())
	assert_true(map.is_menu_open())


func test_other_input_does_not_open_the_menu() -> void:
	var map := _built_map()
	map._unhandled_input(_action("ui_accept"))
	assert_false(map.is_menu_open())


func test_open_menu_shows_the_pause_menu() -> void:
	var map := _built_map()
	map.open_menu()
	assert_true(map.pause_menu.visible)


func test_open_menu_slides_the_header_away() -> void:
	var map := _built_map()
	await get_tree().process_frame
	map.open_menu()
	await _await_slide(_header_is_off_screen.bind(map))
	assert_true(_header_is_off_screen(map), "the header slides off screen")


func test_open_menu_stops_the_camera() -> void:
	var map := _built_map()
	map.open_menu()
	assert_false(map.camera.is_processing())
	assert_false(map.camera.is_processing_unhandled_input())


func test_open_menu_before_the_map_is_built_does_nothing() -> void:
	var map := _map()
	map.open_menu()
	assert_false(map.is_menu_open())


func test_close_menu_closes_the_menu() -> void:
	var map := _built_map()
	map.open_menu()
	map.close_menu()
	assert_false(map.is_menu_open())


func test_close_menu_hides_the_pause_menu_after_the_fade() -> void:
	var map := _built_map()
	map.open_menu()
	map.close_menu()
	await wait_until(func() -> bool: return not map.pause_menu.visible, PauseMenu.FADE_SECONDS + 0.5)
	assert_false(map.pause_menu.visible)


func test_close_menu_restarts_the_camera() -> void:
	var map := _built_map()
	map.open_menu()
	map.close_menu()
	assert_true(map.camera.is_processing())
	assert_true(map.camera.is_processing_unhandled_input())


func test_close_menu_brings_the_header_back() -> void:
	var map := _built_map()
	await get_tree().process_frame
	map.open_menu()
	await _await_slide(_header_is_off_screen.bind(map))
	map.close_menu()
	await _await_slide(func() -> bool: return is_equal_approx(map.hud.header.position.y, 0.0))
	assert_almost_eq(map.hud.header.position.y, 0.0, 0.01)


func test_close_menu_while_closed_leaves_the_camera_alone() -> void:
	var map := _built_map()
	map.camera.set_process(false)
	map.close_menu()
	assert_false(map.camera.is_processing())


func test_resume_closes_the_menu() -> void:
	var map := _built_map()
	map.open_menu()
	map.pause_menu.resume_pressed.emit()
	assert_false(map.is_menu_open())


func test_escape_while_the_menu_is_open_leaves_it_open() -> void:
	var map := _built_map()
	map.open_menu()
	map._unhandled_input(_escape())
	assert_true(map.is_menu_open())
	assert_false(map.camera.is_processing())


func test_escape_reopens_the_menu_once_it_is_closing() -> void:
	var map := _built_map()
	map.open_menu()
	map.close_menu()
	map._unhandled_input(_escape())
	assert_true(map.is_menu_open())


func test_escape_before_the_map_is_built_does_nothing() -> void:
	var map := _map()
	map._unhandled_input(_escape())
	assert_false(map.is_menu_open())


func test_surrender_emits_surrendered() -> void:
	var map := _built_map()
	map.open_menu()
	watch_signals(map)
	map.pause_menu.surrender_pressed.emit()
	assert_signal_emitted(map, "surrendered")


func test_save_and_quit_emits_save_and_quit_requested() -> void:
	var map := _built_map()
	map.open_menu()
	watch_signals(map)
	map.pause_menu.save_and_quit_pressed.emit()
	assert_signal_emitted(map, "save_and_quit_requested")


func test_surrender_does_not_request_save_and_quit() -> void:
	var map := _built_map()
	watch_signals(map)
	map.pause_menu.surrender_pressed.emit()
	assert_signal_not_emitted(map, "save_and_quit_requested")


# Settings

func test_settings_button_opens_the_settings_screen() -> void:
	var map := _built_map()
	map.open_menu()
	map.pause_menu.settings_pressed.emit()
	assert_is(map.settings_screen, SettingsScreen)
	assert_true(map.settings_screen.is_inside_tree())


func test_settings_screen_is_added_to_the_overlay() -> void:
	var map := _built_map()
	map.open_settings()
	assert_eq(map.settings_screen.get_parent(), map.overlay)


func test_settings_screen_is_drawn_over_the_menu() -> void:
	var map := _built_map()
	map.open_settings()
	assert_gt(map.settings_screen.get_index(), map.pause_menu.get_index())


func test_open_settings_twice_keeps_one_screen() -> void:
	var map := _built_map()
	map.open_settings()
	var first := map.settings_screen
	map.open_settings()
	assert_eq(map.settings_screen, first)


func test_the_menu_stays_open_under_settings() -> void:
	var map := _built_map()
	map.open_menu()
	map.open_settings()
	assert_true(map.is_menu_open())


func test_settings_back_closes_settings() -> void:
	var map := _built_map()
	map.open_menu()
	map.open_settings()
	map.settings_screen.back_pressed.emit()
	assert_null(map.settings_screen)


func test_close_settings_frees_the_screen() -> void:
	var map := _built_map()
	map.open_settings()
	var screen := map.settings_screen
	map.close_settings()
	await get_tree().process_frame
	assert_false(is_instance_valid(screen))


func test_close_settings_refocuses_the_menus_settings_button() -> void:
	var map := _built_map()
	map.open_menu()
	map.open_settings()
	map.close_settings()
	assert_true(map.pause_menu.settings_button.has_focus())


func test_close_settings_refreshes_the_hud_controls() -> void:
	var map := _built_map()
	map.open_menu()
	map.open_settings()
	var old := map.hud.controls
	map.close_settings()
	assert_ne(map.hud.controls, old)


func test_close_settings_keeps_the_menu_open() -> void:
	var map := _built_map()
	map.open_menu()
	map.open_settings()
	map.close_settings()
	assert_true(map.is_menu_open())


func test_close_settings_without_settings_does_nothing() -> void:
	var map := _built_map()
	var controls := map.hud.controls
	map.close_settings()
	assert_eq(map.hud.controls, controls)


# start: the roll-off and deployment

func _rolled_map(battle: Battle, seed_value := 1) -> BattleMap:
	var map := _built_map(battle)
	map.rng.seed = seed_value
	return map


## A Matched Play battle before the roll-off: the territories come from the battleplan by role.
func _matched_battle() -> Battle:
	var battle := BattleKit.deployment_battle()
	battle.player_territory = [] as Array[PackedVector2Array]
	battle.opponent_territory = [] as Array[PackedVector2Array]
	battle.roles_assigned = false
	battle.battleplan = BattleKit.battleplan("Plan")
	return battle


## A Spearhead battle before the roll-off and the deployment map: two maps to pick from.
func _spearhead_battle() -> Battle:
	var battle := BattleKit.battle()
	battle.player_territory = [] as Array[PackedVector2Array]
	battle.opponent_territory = [] as Array[PackedVector2Array]
	battle.roles_assigned = false
	battle.battlepack = BattleKit.spearhead_pack("Pack", ["Aqshy"] as Array[String])
	battle.battlepack.deployment_maps = [BattleKit.deployment("First"), BattleKit.deployment("Second")] as Array[DeploymentMap]
	battle.realm = battle.battlepack.realms[0]
	return battle


func test_start_does_nothing_on_an_unbuilt_map() -> void:
	var map := _map()
	map.start()
	assert_eq(map.phase, BattleMap.Phase.BUILDING)
	assert_null(map.roll_off_panel)


func test_start_rolls_off_and_shows_the_roll_off_panel() -> void:
	var map := _rolled_map(_matched_battle())
	map.start()
	assert_eq(map.phase, BattleMap.Phase.ROLL_OFF)
	assert_not_null(map.battle.roll_off)
	assert_same(map.roll_off_panel.get_parent(), map.overlay)


func test_the_roll_off_panel_sits_under_the_menu() -> void:
	var map := _rolled_map(_matched_battle())
	map.start()
	assert_lt(map.roll_off_panel.get_index(), map.pause_menu.get_index())


func test_starting_twice_rolls_only_once() -> void:
	var map := _rolled_map(_matched_battle())
	map.start()
	var panel := map.roll_off_panel
	map.start()
	assert_same(map.roll_off_panel, panel)


func test_the_same_seed_gives_the_same_roll_off() -> void:
	var first := _rolled_map(_matched_battle(), 9)
	first.start()
	var second := _rolled_map(_matched_battle(), 9)
	second.start()
	assert_eq(first.battle.roll_off.rolls, second.battle.roll_off.rolls)


func test_roles_are_not_assigned_before_the_player_chooses() -> void:
	var map := _rolled_map(_matched_battle())
	map.start()
	assert_false(map.battle.roles_assigned)
	assert_false(map.battle.has_territories())


func test_choosing_attacker_in_matched_play_gives_territories_and_starts_deployment() -> void:
	var map := _rolled_map(_matched_battle())
	map.start()
	map.roll_off_panel.role_chosen.emit(true)
	assert_true(map.battle.player_is_attacker)
	assert_true(map.battle.has_territories())
	assert_eq(map.phase, BattleMap.Phase.DEPLOYMENT)
	assert_not_null(map.deployment_controller)


func test_choosing_defender_makes_the_opponent_the_attacker() -> void:
	var map := _rolled_map(_matched_battle())
	map.start()
	map.roll_off_panel.role_chosen.emit(false)
	assert_false(map.battle.player_is_attacker)
	assert_same(map.battle.attacker(), map.battle.opponent)


func test_the_roll_off_panel_is_removed_once_a_role_is_chosen() -> void:
	var map := _rolled_map(_matched_battle())
	map.start()
	var panel := map.roll_off_panel
	panel.role_chosen.emit(true)
	assert_null(map.roll_off_panel)
	assert_null(panel.get_parent())


func test_the_header_shows_the_roles_after_the_roll_off() -> void:
	var map := _rolled_map(_matched_battle())
	map.start()
	map.roll_off_panel.role_chosen.emit(true)
	assert_string_contains(map.hud.player_pill_label.text, "Attacker")


func test_the_roll_off_panel_is_gone_from_the_overlay_when_deployment_starts() -> void:
	var map := _rolled_map(_matched_battle())
	map.start()
	map.roll_off_panel.role_chosen.emit(true)
	assert_null(map.overlay.get_node_or_null("RollOffPanel"))


func test_deployment_shades_the_territory_too_close_to_the_enemy() -> void:
	var map := _rolled_map(_matched_battle())
	map.start()
	map.roll_off_panel.role_chosen.emit(true)
	assert_not_null(map.get_node_or_null("NoDeploy"))
	assert_not_null(map.get_node_or_null("PlayerTerritory"))


func test_deployment_puts_the_deployment_hud_in_the_overlay() -> void:
	var map := _rolled_map(_matched_battle())
	map.start()
	map.roll_off_panel.role_chosen.emit(true)
	assert_same(map.deployment_controller.hud.get_parent(), map.overlay)


func test_a_role_choice_outside_the_roll_off_is_ignored() -> void:
	var map := _rolled_map(_matched_battle())
	map.start()
	var panel := map.roll_off_panel
	panel.role_chosen.emit(true)
	var controller := map.deployment_controller
	map._on_role_chosen(false)
	assert_same(map.deployment_controller, controller)
	assert_true(map.battle.player_is_attacker)


func test_spearhead_attacker_leaves_the_deployment_map_to_the_ai() -> void:
	var map := _rolled_map(_spearhead_battle())
	map.start()
	map.roll_off_panel.role_chosen.emit(true)
	assert_null(map.map_picker)
	assert_true(map.battle.has_territories())
	assert_true(map.battle.deployment in map.battle.battlepack.deployment_maps)
	assert_eq(map.phase, BattleMap.Phase.DEPLOYMENT)


func test_spearhead_defender_picks_the_deployment_map() -> void:
	var map := _rolled_map(_spearhead_battle())
	map.start()
	map.roll_off_panel.role_chosen.emit(false)
	assert_eq(map.phase, BattleMap.Phase.DEPLOYMENT_MAP)
	assert_same(map.map_picker.get_parent(), map.overlay)
	assert_false(map.battle.has_territories())
	assert_null(map.deployment_controller)


func test_picking_a_map_gives_the_defender_its_territory_and_starts_deployment() -> void:
	var map := _rolled_map(_spearhead_battle())
	map.start()
	map.roll_off_panel.role_chosen.emit(false)
	var picked := map.battle.battlepack.deployment_maps[1]
	map.map_picker.chosen.emit(picked, false)
	assert_same(map.battle.deployment, picked)
	assert_eq(map.battle.player_territory, [picked.territory_b] as Array[PackedVector2Array])
	assert_eq(map.phase, BattleMap.Phase.DEPLOYMENT)
	assert_null(map.map_picker)


func test_spearhead_roles_give_each_side_its_terrain() -> void:
	var map := _rolled_map(_spearhead_battle())
	map.start()
	map.roll_off_panel.role_chosen.emit(false)
	assert_gt(map.battle.player.terrain.size(), 0)
	assert_gt(map.battle.opponent.terrain.size(), 0)


func test_deployment_finished_is_emitted_when_both_armies_are_down() -> void:
	var battle := _matched_battle()
	for army in [battle.player, battle.opponent]:
		var keep: Array[BattleUnit] = [army.units[4]]
		army.units = keep
		army.regiments = [] as Array[BattleRegiment]
	var map := _rolled_map(battle)
	map.start()
	map.roll_off_panel.role_chosen.emit(true)
	var controller := map.deployment_controller
	controller.ai_delay = 0.0
	watch_signals(map)
	controller.pick_unit(battle.player.units[0])
	controller.confirm()
	await wait_process_frames(3)
	assert_signal_emitted(map, "deployment_finished")
	assert_eq(map.phase, BattleMap.Phase.DEPLOYED)
