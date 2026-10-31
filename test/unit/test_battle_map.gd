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


# build_steps

func test_build_steps_has_a_step_per_terrain_feature_and_unit() -> void:
	var battle := _battle()
	var steps := _map().build_steps(battle)
	var terrain := battle.all_terrain().size()
	var units := battle.player.units.size() + battle.opponent.units.size()
	var of_stage := func(stage: BattleMap.Stage) -> int: return _stages(steps).count(stage)
	assert_eq(of_stage.call(BattleMap.Stage.BATTLEFIELD), 1)
	assert_eq(of_stage.call(BattleMap.Stage.TERRAIN), terrain)
	assert_eq(of_stage.call(BattleMap.Stage.OBJECTIVES), 1)
	assert_eq(of_stage.call(BattleMap.Stage.PLAYER_MODELS) + of_stage.call(BattleMap.Stage.OPPONENT_MODELS), units)


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
		assert_false(step.text.is_empty())
		assert_true(step.run.is_valid())


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
	var map := _map()
	map.build(_battle())
	assert_not_null(map.get_node_or_null("Board"))


func test_build_adds_both_territories() -> void:
	var map := _map()
	map.build(_battle())
	assert_not_null(map.get_node_or_null("PlayerTerritory"))
	assert_not_null(map.get_node_or_null("OpponentTerritory"))


func test_build_adds_the_camera() -> void:
	var map := _map()
	map.build(_battle())
	assert_is(map.camera, BattleCamera)
	assert_eq(map.camera.get_parent(), map)


func test_build_adds_the_hud() -> void:
	var map := _map()
	map.build(_battle())
	assert_is(map.hud, BattleHud)
	assert_true(map.hud.is_inside_tree())


func test_build_limits_the_camera_to_the_battlefield() -> void:
	var map := _map()
	var battle := _battle()
	map.build(battle)
	assert_eq(map.camera.bounds, Rect2(Vector2.ZERO, battle.battlefield_size))


func test_build_adds_a_node_per_placed_terrain_feature() -> void:
	var map := _map()
	var battle := _battle()
	map.build(battle)
	assert_eq(map.terrain_root.get_child_count(), battle.all_terrain().size())


func test_build_skips_terrain_that_was_never_placed() -> void:
	var map := _map()
	var battle := _battle()
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 4.0, Vector2.ZERO, false))
	map.build(battle)
	assert_eq(map.terrain_root.get_child_count(), battle.all_terrain().size() - 1)


func test_build_adds_a_node_per_objective() -> void:
	var map := _map()
	map.build(_battle())
	assert_eq(map.objectives_root.get_child_count(), 1)


func test_build_adds_a_node_per_unit() -> void:
	var map := _map()
	map.build(_battle())
	assert_eq(map.armies_root.get_child_count(), 4)


func test_build_deploys_the_armies() -> void:
	var map := _map()
	var battle := _battle()
	map.build(battle)
	assert_eq(battle.player.units[0].positions.size(), battle.player.units[0].model_count())


func test_build_includes_roads_only_when_the_battle_has_them() -> void:
	var without := _map()
	without.build(_battle())
	assert_null(without.get_node_or_null("Roads"))
	var battle := _battle()
	battle.roads = [BattleKit.rect_polygon(0, 10, 30, 2)] as Array[PackedVector2Array]
	var with := _map()
	with.build(battle)
	assert_not_null(with.get_node_or_null("Roads"))


# Menu

func test_menu_button_requests_the_menu() -> void:
	var map := _map()
	map.build(_battle())
	watch_signals(map)
	map.hud.menu_button.pressed.emit()
	assert_signal_emitted(map, "menu_requested")


func test_escape_requests_the_menu() -> void:
	var map := _map()
	map.build(_battle())
	watch_signals(map)
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	map._unhandled_input(event)
	assert_signal_emitted(map, "menu_requested")


func test_other_input_does_not_request_the_menu() -> void:
	var map := _map()
	map.build(_battle())
	watch_signals(map)
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	map._unhandled_input(event)
	assert_signal_not_emitted(map, "menu_requested")
