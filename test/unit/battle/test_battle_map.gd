extends GutTest
## Unit tests for the game map (scripts/battle/battle_map.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")
const MapScene := preload("res://scenes/battle/battle_map.tscn")
const UIKit := preload("res://test/support/ui_kit.gd")

## A realm with no printed board image, so its roads are drawn.
const REALM_WITHOUT_A_PRINT := "Realm Without A Board"


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


func _a_road() -> Array[PackedVector2Array]:
	return [BattleKit.rect_polygon(0, 10, 30, 2)] as Array[PackedVector2Array]


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


# Names shown on hover

func test_the_built_map_shows_names_on_hover() -> void:
	assert_not_null(_built_map().get_node_or_null("MapHover") as MapHover)


func test_the_built_maps_names_start_hidden() -> void:
	var map := _built_map()
	var labels: Array[Node] = []
	for group: Node3D in [map.terrain_root, map.objectives_root, map.armies_root]:
		labels.append_array(group.find_children(ModelPlaceholder.HOVER_LABEL, "Label3D", true, false))
	assert_gt(labels.size(), 0)
	for label: Label3D in labels:
		assert_false(label.visible)


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
	battle.roads = _a_road()
	assert_not_null(_built_map(battle).get_node_or_null("Roads"))


func test_build_draws_roads_on_a_board_without_a_print() -> void:
	var battle := _battle()
	battle.realm = BattleKit.realm(REALM_WITHOUT_A_PRINT)
	battle.roads = _a_road()
	assert_not_null(_built_map(battle).get_node_or_null("Roads"))


func test_build_leaves_the_board_bare_without_a_print() -> void:
	var battle := _battle()
	battle.realm = BattleKit.realm(REALM_WITHOUT_A_PRINT)
	assert_null(_built_map(battle).get_node("Board").get_node_or_null("Print"))


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


func _key(keycode: Key) -> InputEventKey:
	return InputBindings.decode([keycode])[0]


func test_close_settings_refreshes_the_hud_controls() -> void:
	var map := _built_map()
	map.open_menu()
	map.open_settings()
	InputBindings.set_keys("camera_forward", [_key(KEY_I)])
	map.close_settings()
	assert_true(UIKit.has_label_containing(map.hud.controls, BattleHud.move_keys()))


func test_close_settings_keeps_the_menu_open() -> void:
	var map := _built_map()
	map.open_menu()
	map.open_settings()
	map.close_settings()
	assert_true(map.is_menu_open())


func test_close_settings_without_settings_does_nothing() -> void:
	var map := _built_map()
	map.open_menu()
	InputBindings.set_keys("camera_forward", [_key(KEY_I)])
	map.close_settings()
	assert_false(UIKit.has_label_containing(map.hud.controls, BattleHud.move_keys()), "the HUD isn't refreshed")
	assert_false(map.pause_menu.settings_button.has_focus(), "the settings button isn't focused")


# start: the roll-off and deployment

## A Matched Play battle before the roll-off: the territories come from the battleplan by role.
func _matched_battle() -> Battle:
	var battle := BattleKit.deployment_battle()
	battle.player_territory = [] as Array[PackedVector2Array]
	battle.opponent_territory = [] as Array[PackedVector2Array]
	battle.roles_assigned = false
	battle.battleplan = BattleKit.battleplan("Plan")
	return battle


## A Spearhead battle before the roll-off: the sides Aqshy and Ghyran, none picked, and two maps to
## pick from. Both armies are a Spearhead that has yet to pick its regiment ability and enhancement.
func _spearhead_battle() -> Battle:
	var battle := BattleKit.battle()
	battle.player_territory = [] as Array[PackedVector2Array]
	battle.opponent_territory = [] as Array[PackedVector2Array]
	battle.roles_assigned = false
	battle.battlepack = BattleKit.spearhead_pack("Pack", ["Aqshy", "Ghyran"] as Array[String])
	battle.battlepack.deployment_maps = [BattleKit.deployment("First"), BattleKit.deployment("Second")] as Array[DeploymentMap]
	battle.title = "Pack"
	battle.player = BattleKit.spearhead_army(BattleKit.spearhead_with_options())
	battle.opponent = battle.player.mirror()
	battle.face_armies()
	return battle


## [method _spearhead_battle] on its first side, as if the setup had named it.
func _battle_on_a_side() -> Battle:
	var battle := _spearhead_battle()
	battle.choose_realm(battle.battlepack.realms[0])
	return battle


## A map of [param battle] showing its roll-off, rolled with [param seed_value].
func _started(battle: Battle, seed_value := 1) -> BattleMap:
	var map := _built_map(battle)
	map.rng.seed = seed_value
	map.start()
	return map


## A map whose roll-off the player has taken as the attacker, or the defender if [param attacks]
## is false, on [param battle].
func _after_roll_off(battle: Battle, attacks: bool, seed_value := 1) -> BattleMap:
	var map := _started(battle, seed_value)
	map.roll_off_panel.role_chosen.emit(attacks)
	return map


func _pick_options(map: BattleMap, regiment := "Charge", enhancement := "Banner") -> void:
	map.options_picker.chosen.emit(regiment, enhancement)


## A map of a [method _spearhead_battle], or of [param battle], whose player attacks and has picked
## its options, so the AI has picked the side and the deployment map.
func _attacker_after_options(battle: Battle = null, seed_value := 1) -> BattleMap:
	var map := _after_roll_off(battle if battle else _spearhead_battle(), true, seed_value)
	_pick_options(map)
	return map


## A map of a [method _spearhead_battle], or of [param battle], whose player defends and has picked
## its options, so its map picker is open.
func _defender_at_the_map_picker(battle: Battle = null) -> BattleMap:
	var map := _after_roll_off(battle if battle else _spearhead_battle(), false)
	_pick_options(map)
	return map


## Picks [param side] and the first deployment map on [param map]'s map picker.
func _pick_side(map: BattleMap, side: RealmBattlefield) -> void:
	map.map_picker.chosen.emit(side, map.battle.battlepack.deployment_maps[0], true)


func test_start_does_nothing_on_an_unbuilt_map() -> void:
	var map := _map()
	map.start()
	assert_eq(map.phase, BattleMap.Phase.BUILDING)
	assert_null(map.roll_off_panel)


func test_start_moves_to_the_roll_off() -> void:
	assert_eq(_started(_matched_battle()).phase, BattleMap.Phase.ROLL_OFF)


func test_start_rolls_off() -> void:
	assert_not_null(_started(_matched_battle()).battle.roll_off)


func test_start_shows_the_roll_off_panel_in_the_overlay() -> void:
	var map := _started(_matched_battle())
	assert_same(map.roll_off_panel.get_parent(), map.overlay)


func test_the_roll_off_panel_sits_under_the_menu() -> void:
	var map := _started(_matched_battle())
	assert_lt(map.roll_off_panel.get_index(), map.pause_menu.get_index())


func test_starting_twice_rolls_only_once() -> void:
	var map := _started(_matched_battle())
	var panel := map.roll_off_panel
	var roll_off := map.battle.roll_off
	map.start()
	assert_same(map.roll_off_panel, panel)
	assert_same(map.battle.roll_off, roll_off)


func test_the_same_seed_gives_the_same_roll_off() -> void:
	var first := _started(_matched_battle(), 9)
	var second := _started(_matched_battle(), 9)
	assert_eq(first.battle.roll_off.rolls, second.battle.roll_off.rolls)


func test_roles_are_not_assigned_before_the_player_chooses() -> void:
	var map := _started(_matched_battle())
	assert_false(map.battle.roles_assigned)
	assert_false(map.battle.has_territories())


func test_choosing_attacker_makes_the_player_the_attacker() -> void:
	assert_true(_after_roll_off(_matched_battle(), true).battle.player_is_attacker)


func test_choosing_a_role_in_matched_play_gives_territories() -> void:
	assert_true(_after_roll_off(_matched_battle(), true).battle.has_territories())


func test_choosing_a_role_in_matched_play_starts_deployment() -> void:
	var map := _after_roll_off(_matched_battle(), true)
	assert_eq(map.phase, BattleMap.Phase.DEPLOYMENT)
	assert_not_null(map.deployment_controller)


func test_choosing_defender_makes_the_opponent_the_attacker() -> void:
	var map := _after_roll_off(_matched_battle(), false)
	assert_false(map.battle.player_is_attacker)
	assert_same(map.battle.attacker(), map.battle.opponent)


func test_the_roll_off_panel_is_removed_once_a_role_is_chosen() -> void:
	var map := _started(_matched_battle())
	var panel := map.roll_off_panel
	panel.role_chosen.emit(true)
	assert_null(map.roll_off_panel)
	assert_null(panel.get_parent())


func test_the_header_shows_the_roles_after_the_roll_off() -> void:
	var map := _after_roll_off(_matched_battle(), true)
	assert_string_contains(map.hud.player_pill_label.text, "Attacker")


func test_the_roll_off_panel_is_gone_from_the_overlay_when_deployment_starts() -> void:
	var map := _after_roll_off(_matched_battle(), true)
	assert_null(map.overlay.get_node_or_null("RollOffPanel"))


func test_deployment_shades_the_territory_too_close_to_the_enemy() -> void:
	var map := _after_roll_off(_matched_battle(), true)
	assert_not_null(map.get_node_or_null("NoDeploy"))


func test_deployment_draws_the_territory_the_role_gives() -> void:
	var map := _after_roll_off(_matched_battle(), true)
	assert_not_null(map.get_node_or_null("PlayerTerritory"))


func test_deployment_puts_the_deployment_hud_in_the_overlay() -> void:
	var map := _after_roll_off(_matched_battle(), true)
	assert_same(map.deployment_controller.hud.get_parent(), map.overlay)


func test_a_role_choice_outside_the_roll_off_is_ignored() -> void:
	var map := _started(_matched_battle())
	var panel := map.roll_off_panel
	panel.role_chosen.emit(true)
	var controller := map.deployment_controller
	panel.role_chosen.emit(false)
	assert_same(map.deployment_controller, controller)
	assert_true(map.battle.player_is_attacker)


# Spearhead: picking abilities, the side and the deployment map

func test_matched_play_has_no_spearhead_options_to_pick() -> void:
	var map := _after_roll_off(_matched_battle(), true)
	assert_null(map.options_picker)
	assert_eq(map.phase, BattleMap.Phase.DEPLOYMENT)


func test_a_spearhead_attacker_picks_its_options_first() -> void:
	var map := _after_roll_off(_spearhead_battle(), true)
	assert_eq(map.phase, BattleMap.Phase.SPEARHEAD_OPTIONS)
	assert_same(map.options_picker.get_parent(), map.overlay)


func test_deployment_waits_while_a_spearhead_attacker_picks_its_options() -> void:
	var map := _after_roll_off(_spearhead_battle(), true)
	assert_null(map.deployment_controller)
	assert_false(map.battle.has_territories())


func test_the_attackers_picker_is_made_for_the_players_army() -> void:
	var map := _after_roll_off(_spearhead_battle(), true)
	assert_same(map.options_picker.army, map.battle.player)
	assert_true(map.options_picker.is_attacker)


func test_the_ai_has_not_picked_while_the_attacker_picks() -> void:
	var map := _after_roll_off(_spearhead_battle(), true)
	assert_true(map.battle.opponent.needs_spearhead_options())


func test_the_players_options_are_set_on_their_army() -> void:
	var map := _after_roll_off(_spearhead_battle(), true)
	_pick_options(map, "Ambush", "Crown")
	assert_eq([map.battle.player.regiment_ability, map.battle.player.enhancement], ["Ambush", "Crown"])
	assert_not_null(map.battle.player.deployment_ability("Ambush"))


func test_the_ai_defender_picks_its_options_once_the_player_has() -> void:
	var map := _attacker_after_options()
	assert_false(map.battle.opponent.needs_spearhead_options())
	assert_true(map.battle.opponent.regiment_ability in ["Charge", "Ambush"])
	assert_true(map.battle.opponent.enhancement in ["Banner", "Crown"])


func test_the_ais_options_are_among_its_spearheads() -> void:
	for seed_value in 8:
		var map := _attacker_after_options(null, seed_value)
		assert_not_null(map.battle.opponent.deployment_ability(map.battle.opponent.regiment_ability), "seed %d" % seed_value)
		assert_not_null(map.battle.opponent.deployment_ability(map.battle.opponent.enhancement), "seed %d" % seed_value)


func test_the_ai_picks_different_options_with_different_seeds() -> void:
	var picks := {}
	for seed_value in 24:
		var map := _attacker_after_options(null, seed_value)
		picks[map.battle.opponent.regiment_ability + map.battle.opponent.enhancement] = true
	assert_gt(picks.size(), 1)


func test_the_options_picker_is_removed_once_the_player_has_picked() -> void:
	var map := _after_roll_off(_spearhead_battle(), true)
	var picker := map.options_picker
	_pick_options(map)
	assert_null(map.options_picker)
	assert_null(picker.get_parent())


func test_a_spearhead_attacker_is_not_asked_for_the_side_and_map() -> void:
	assert_null(_attacker_after_options().map_picker)


func test_the_ai_defender_picks_the_side_and_map() -> void:
	var map := _attacker_after_options()
	assert_true(map.battle.has_territories())
	assert_true(map.battle.deployment in map.battle.battlepack.deployment_maps)
	assert_true(map.battle.realm in map.battle.battlepack.realms)


func test_deployment_starts_once_the_ai_defender_has_picked() -> void:
	var map := _attacker_after_options()
	assert_eq(map.phase, BattleMap.Phase.DEPLOYMENT)
	assert_not_null(map.deployment_controller)


func test_the_ai_defender_keeps_the_side_the_setup_named() -> void:
	for seed_value in 8:
		var battle := _battle_on_a_side()
		var side := battle.realm
		var map := _attacker_after_options(battle, seed_value)
		assert_same(map.battle.realm, side, "seed %d" % seed_value)


func test_the_ai_defender_picks_either_side() -> void:
	var sides := {}
	for seed_value in 24:
		var map := _attacker_after_options(null, seed_value)
		sides[map.battle.realm.name] = true
	assert_eq(sides.size(), 2)


func test_the_ai_defenders_side_has_its_objectives_drawn() -> void:
	var map := _attacker_after_options()
	assert_eq(map.objectives_root.get_child_count(), map.battle.objectives.size())


func test_the_ai_defenders_side_is_the_title() -> void:
	var map := _attacker_after_options()
	assert_eq(map.hud.title_label.text, map.battle.realm.name)


func test_the_ai_attacker_picks_before_a_spearhead_defender() -> void:
	var map := _after_roll_off(_spearhead_battle(), false)
	assert_eq(map.phase, BattleMap.Phase.SPEARHEAD_OPTIONS)
	assert_false(map.battle.opponent.needs_spearhead_options())


func test_a_spearhead_defender_sees_the_attackers_picks() -> void:
	var map := _after_roll_off(_spearhead_battle(), false)
	assert_false(map.options_picker.is_attacker)
	assert_same(map.options_picker.opponent, map.battle.opponent)


func test_a_spearhead_defender_picks_options_before_the_side() -> void:
	var map := _after_roll_off(_spearhead_battle(), false)
	assert_null(map.map_picker)
	assert_null(map.deployment_controller)
	assert_true(map.battle.player.needs_spearhead_options())


func test_a_spearhead_defender_then_gets_the_map_picker() -> void:
	var map := _defender_at_the_map_picker()
	assert_eq(map.phase, BattleMap.Phase.DEPLOYMENT_MAP)
	assert_same(map.map_picker.get_parent(), map.overlay)


func test_the_map_picker_offers_both_sides() -> void:
	assert_eq(_defender_at_the_map_picker().map_picker.realm_buttons.size(), 2)


func test_deployment_waits_while_the_defender_picks_the_side_and_map() -> void:
	var map := _defender_at_the_map_picker()
	assert_false(map.battle.has_territories())
	assert_null(map.deployment_controller)


func test_the_options_picker_makes_way_for_the_map_picker() -> void:
	assert_null(_defender_at_the_map_picker().options_picker)


func test_picking_a_map_gives_the_defender_its_territory() -> void:
	var map := _defender_at_the_map_picker()
	var picked := map.battle.battlepack.deployment_maps[1]
	map.map_picker.chosen.emit(map.battle.battlepack.realms[0], picked, false)
	assert_same(map.battle.deployment, picked)
	assert_eq(map.battle.player_territory, [picked.territory_b] as Array[PackedVector2Array])


func test_picking_a_map_starts_deployment() -> void:
	var map := _defender_at_the_map_picker()
	_pick_side(map, map.battle.battlepack.realms[0])
	assert_eq(map.phase, BattleMap.Phase.DEPLOYMENT)


func test_the_map_picker_is_removed_once_a_map_is_picked() -> void:
	var map := _defender_at_the_map_picker()
	var picker := map.map_picker
	_pick_side(map, map.battle.battlepack.realms[0])
	assert_null(map.map_picker)
	assert_null(picker.get_parent())


func test_picking_a_side_chooses_the_realm() -> void:
	var map := _defender_at_the_map_picker()
	var side := map.battle.battlepack.realms[1]
	_pick_side(map, side)
	assert_same(map.battle.realm, side)
	assert_eq(map.battle.title, "Ghyran")


func test_picking_a_side_redraws_the_title() -> void:
	var map := _defender_at_the_map_picker()
	_pick_side(map, map.battle.battlepack.realms[1])
	assert_eq(map.hud.title_label.text, "Ghyran")


func test_picking_a_side_redraws_the_objectives() -> void:
	var map := _defender_at_the_map_picker()
	var side := map.battle.battlepack.realms[1]
	side.objectives = [BattleKit.feature("A", Vector2(5, 5)), BattleKit.feature("B", Vector2(9, 9)), BattleKit.feature("C", Vector2(12, 4))] as Array[MapFeature]
	_pick_side(map, side)
	assert_eq(map.objectives_root.get_child_count(), 3)


func test_picking_a_side_redraws_the_terrain() -> void:
	var map := _defender_at_the_map_picker()
	var side := map.battle.battlepack.realms[1]
	side.terrain = [BattleKit.feature("Wall", Vector2(3, 3)), BattleKit.feature("Wall", Vector2(6, 6))] as Array[MapFeature]
	_pick_side(map, side)
	assert_eq(map.terrain_root.get_child_count(), _placed_count(map.battle))
	assert_gte(map.terrain_root.get_child_count(), 2)


func test_picking_a_side_leaves_one_board() -> void:
	var map := _defender_at_the_map_picker()
	_pick_side(map, map.battle.battlepack.realms[1])
	await wait_process_frames(2)
	# By material, not name: Godot renames a node added beside one of the same name.
	var boards := map.get_children().filter(func(node: Node) -> bool:
		return node is MeshInstance3D and node.material_override == BoardBuilder.BOARD)
	assert_eq(boards.size(), 1)


func test_picking_a_side_draws_its_roads_on_a_board_without_a_print() -> void:
	var map := _defender_at_the_map_picker()
	var side := map.battle.battlepack.realms[1]
	side.name = REALM_WITHOUT_A_PRINT
	side.roads = _a_road()
	_pick_side(map, side)
	await wait_process_frames(2)
	assert_not_null(map.get_node_or_null("Roads"))


func test_picking_a_side_without_roads_removes_the_old_ones() -> void:
	var battle := _spearhead_battle()
	battle.battlepack.realms[0].name = REALM_WITHOUT_A_PRINT
	battle.battlepack.realms[0].roads = _a_road()
	battle.choose_realm(battle.battlepack.realms[0])
	var map := _defender_at_the_map_picker(battle)
	assert_not_null(map.get_node_or_null("Roads"), "the first side has roads to remove")
	battle.battlepack.realms[1].name = "Another Realm Without A Board"
	_pick_side(map, battle.battlepack.realms[1])
	await wait_process_frames(2)
	assert_null(map.get_node_or_null("Roads"))


func test_picking_the_same_side_does_not_redraw_it() -> void:
	var battle := _battle_on_a_side()
	var map := _defender_at_the_map_picker(battle)
	var objectives := map.objectives_root.get_children()
	_pick_side(map, battle.realm)
	assert_eq(map.objectives_root.get_children(), objectives)
	assert_same(battle.realm, battle.battlepack.realms[0])


func test_the_map_picker_starts_on_the_side_the_setup_named() -> void:
	# The second side, as the picker starts on the first without one named.
	var battle := _spearhead_battle()
	battle.choose_realm(battle.battlepack.realms[1])
	var map := _defender_at_the_map_picker(battle)
	assert_true(map.map_picker.realm_buttons[1].button_pressed)
	assert_false(map.map_picker.realm_buttons[0].button_pressed)


func test_the_map_picker_starts_on_the_first_side_without_one() -> void:
	var map := _defender_at_the_map_picker()
	assert_same(map.map_picker.selection()[0], map.battle.battlepack.realms[0])


## [method _battle_on_a_side] with its deployment map and territories already chosen.
func _battle_with_territories() -> Battle:
	var battle := _battle_on_a_side()
	battle.choose_deployment(battle.battlepack.deployment_maps[0], true)
	return battle


func test_territories_already_set_skip_the_map_and_side() -> void:
	var battle := _battle_with_territories()
	battle.player.choose_spearhead_options("Charge", "Banner")
	battle.opponent.choose_spearhead_options("Ambush", "Crown")
	var map := _after_roll_off(battle, false)
	assert_null(map.options_picker)
	assert_null(map.map_picker)
	assert_eq(map.phase, BattleMap.Phase.DEPLOYMENT)


func test_territories_already_set_still_ask_for_unpicked_options() -> void:
	var map := _after_roll_off(_battle_with_territories(), true)
	assert_eq(map.phase, BattleMap.Phase.SPEARHEAD_OPTIONS)


func test_territories_already_set_go_straight_to_deployment_after_the_options() -> void:
	var map := _attacker_after_options(_battle_with_territories())
	assert_null(map.map_picker)
	assert_eq(map.phase, BattleMap.Phase.DEPLOYMENT)


func test_options_already_picked_are_not_asked_for_again() -> void:
	var battle := _spearhead_battle()
	battle.player.choose_spearhead_options("Charge", "Banner")
	battle.opponent.choose_spearhead_options("Ambush", "Crown")
	var map := _after_roll_off(battle, false)
	assert_null(map.options_picker)
	assert_eq(map.phase, BattleMap.Phase.DEPLOYMENT_MAP)


func test_a_spearhead_with_nothing_to_pick_goes_straight_to_the_battlefield() -> void:
	var battle := _spearhead_battle()
	for army in [battle.player, battle.opponent]:
		army.spearhead.regiment_abilities = [] as Array[Ability]
		army.spearhead.enhancements = [] as Array[Ability]
	var map := _after_roll_off(battle, false)
	assert_null(map.options_picker)
	assert_eq(map.phase, BattleMap.Phase.DEPLOYMENT_MAP)


func test_a_stray_options_choice_is_ignored_once_deployment_starts() -> void:
	var map := _after_roll_off(_spearhead_battle(), true)
	var picker := map.options_picker
	_pick_options(map)
	var controller := map.deployment_controller
	picker.chosen.emit("Ambush", "Crown")
	assert_same(map.deployment_controller, controller)
	assert_eq(map.battle.player.regiment_ability, "Charge")


func test_spearhead_roles_give_each_side_its_terrain() -> void:
	var map := _attacker_after_options()
	assert_gt(map.battle.player.terrain.size(), 0)
	assert_gt(map.battle.opponent.terrain.size(), 0)


## A [method _matched_battle] with each army down to its auxiliary unit, so one set-up deploys it.
func _matched_battle_of_one_unit_a_side() -> Battle:
	var battle := _matched_battle()
	for army in [battle.player, battle.opponent]:
		var auxiliary: Array[BattleUnit] = [army.units.back()]
		army.units = auxiliary
		army.regiments = [] as Array[BattleRegiment]
	return battle


## [method BattleKit.deployment_battle] with faction terrain in the player's territory, already set
## up unless [param placed] is false.
func _battle_with_faction_terrain(placed := true) -> Battle:
	var battle := BattleKit.deployment_battle()
	battle.player.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 4.0, Vector2(30, 9), placed))
	return battle


func test_deployment_finished_is_emitted_when_both_armies_are_down() -> void:
	var battle := _matched_battle_of_one_unit_a_side()
	var map := _after_roll_off(battle, true)
	var controller := map.deployment_controller
	controller.ai_delay = 0.0
	watch_signals(map)
	controller.pick_unit(battle.player.units[0])
	controller.confirm()
	await wait_process_frames(3)
	assert_signal_emitted(map, "deployment_finished")
	assert_eq(map.phase, BattleMap.Phase.BATTLE, "The battle rounds take over from deployment")


func test_the_terrain_step_shades_without_a_label() -> void:
	# With terrain set up, as this battle's territory has nothing else to shade for terrain.
	var map := _built_map(_battle_with_faction_terrain())
	map.show_no_deploy(true)
	var shade := map.get_node("NoDeploy")
	assert_gt(shade.get_child_count(), 0, "there is shading to label")
	assert_eq(shade.find_children("*", "Label3D", true, false).size(), 0)


func test_the_terrain_step_shades_around_terrain_already_set_up() -> void:
	var map := _built_map(_battle_with_faction_terrain())
	map.show_no_deploy(true)
	var shade := map.get_node_or_null("NoDeploy")
	assert_gt(shade.find_children("*", "MeshInstance3D", true, false).size(), 0)


func test_the_terrain_step_does_not_shade_around_terrain_not_yet_set_up() -> void:
	var map := _built_map(_battle_with_faction_terrain(false))
	map.show_no_deploy(true)
	var shade := map.get_node_or_null("NoDeploy")
	assert_eq(shade.get_child_count(), 0)


func test_the_unit_step_does_not_shade_around_terrain() -> void:
	var bare := _built_map(BattleKit.deployment_battle())
	bare.show_no_deploy(false)
	var map := _built_map(_battle_with_faction_terrain())
	map.show_no_deploy(false)
	assert_eq(map.get_node("NoDeploy").get_child_count(), bare.get_node("NoDeploy").get_child_count())


func test_showing_the_shade_again_replaces_it() -> void:
	var map := _built_map(BattleKit.deployment_battle())
	map.show_no_deploy(true)
	var children := map.get_child_count()
	map.show_no_deploy(true)
	assert_eq(map.get_child_count(), children)


func test_the_unit_step_labels_the_shade_with_the_enemy_gap() -> void:
	var map := _built_map(BattleKit.deployment_battle())
	map.show_no_deploy(false)
	var shade := map.get_node_or_null("NoDeploy")
	assert_not_null(shade)
	var labels := shade.find_children("*", "Label3D", true, false)
	assert_gt(labels.size(), 0)
	assert_string_contains((labels[0] as Label3D).text, "Within")
