extends GutTest
## Unit tests for the deployment phase on the map (scripts/battle/deployment/deployment_controller.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")
const MapScene := preload("res://scenes/battle/battle_map.tscn")

var _battle: Battle
var _map: BattleMap
var _c: DeploymentController


func before_each() -> void:
	Sandbox.begin()
	_battle = BattleKit.deployment_battle()


func after_each() -> void:
	Sandbox.end()


## Builds the map for the current battle and starts the controller, the AI acting at once.
func _start() -> void:
	_map = MapScene.instantiate()
	add_child_autofree(_map)
	_map.build(_battle)
	_c = DeploymentController.new(_map)
	_c.ai_delay = 0.0
	_map.add_child(_c)
	_c.start(_map.overlay)


func _unit(army: BattleArmy, unit_name: String) -> BattleUnit:
	for unit in army.units:
		if unit.name == unit_name:
			return unit
	return null


func _me() -> BattleArmy:
	return _battle.player


func _problems(unit: BattleUnit) -> PackedStringArray:
	return DeploymentRules.unit_problems(_battle, _me(), unit, unit.positions, unit.facing)


func _middle(unit: BattleUnit) -> Vector2:
	var total := Vector2.ZERO
	for position in unit.positions:
		total += position
	return total / unit.positions.size()


func _reserve_entry(owner_name := "") -> DeploymentAbility:
	var declare := "Pick this unit." if not owner_name.is_empty() else "Pick friendly units."
	var ability := BattleKit.ability("Hide", PackedStringArray(["DEPLOY"]), "Set up this unit in reserve in the clouds.", declare)
	var owner := _unit(_me(), owner_name) if not owner_name.is_empty() else null
	var entry := BattleKit.deploy_entry(ability, "Warscroll", owner)
	_me().deployment_abilities.append(entry)
	_battle.opponent = _me().mirror()
	_battle.face_armies()
	return entry


func _single_unit_armies() -> void:
	for army in [_battle.player, _battle.opponent]:
		var keep: Array[BattleUnit] = [_unit(army, "Aux")]
		army.units = keep
		army.regiments = [] as Array[BattleRegiment]


# picking units

func test_picking_a_unit_gives_it_a_valid_starting_spot() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	assert_eq(unit.positions.size(), unit.model_count())
	assert_eq(_problems(unit).size(), 0)


func test_picking_a_unit_does_not_deploy_it_yet() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	assert_false(unit.deployed)


func test_picking_a_unit_puts_it_on_the_board() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	assert_true(_c.unit_nodes.has(unit))
	assert_same(_c.unit_nodes[unit].get_parent(), _map.armies_root)


func test_picking_a_unit_faces_it_towards_the_enemy() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	assert_eq(unit.facing, _me().facing)


func test_picking_a_unit_shows_the_placing_panel() -> void:
	_start()
	_c.pick_unit(_unit(_me(), "A1"))
	assert_not_null(_c.hud.confirm_button)


func test_picking_another_unit_takes_the_first_off_the_board() -> void:
	_start()
	var first := _unit(_me(), "A1")
	_c.pick_unit(first)
	var node: Node = _c.unit_nodes[first]
	_c.pick_unit(_unit(_me(), "A2"))
	assert_false(_c.unit_nodes.has(first))
	assert_eq(first.positions.size(), 0)
	assert_null(node.get_parent())


func test_a_unit_cannot_be_picked_out_of_turn() -> void:
	_battle.player_is_attacker = false
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	assert_false(_c.unit_nodes.has(unit))


func test_a_unit_outside_the_regiment_being_deployed_cannot_be_picked() -> void:
	_start()
	_c.pick_regiment(_me().regiments[0])
	var other := _unit(_me(), "B1")
	_c.pick_unit(other)
	assert_false(_c.unit_nodes.has(other))


func test_a_unit_gets_a_fallback_spot_when_there_is_no_room() -> void:
	_battle.player_territory = [BattleKit.rect_polygon(0, 0, 60, 1)] as Array[PackedVector2Array]
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	assert_eq(unit.positions.size(), unit.model_count())


# regiments

func test_picking_a_regiment_starts_deploying_it_and_picks_its_first_unit() -> void:
	_start()
	_c.pick_regiment(_me().regiments[0])
	assert_same(_c.deployment.regiment, _me().regiments[0])
	assert_true(_c.unit_nodes.has(_unit(_me(), "A1")))


func test_the_next_regiment_unit_is_picked_after_confirming_one() -> void:
	_start()
	_c.pick_regiment(_me().regiments[0])
	_c.confirm()
	await wait_process_frames(2)
	assert_true(_c.unit_nodes.has(_unit(_me(), "A2")))
	assert_same(_c.deployment.active, _me())


func test_cancelling_the_first_unit_of_a_regiment_leaves_the_regiment_going() -> void:
	_start()
	_c.pick_regiment(_me().regiments[0])
	_c.cancel()
	assert_same(_c.deployment.regiment, _me().regiments[0])
	assert_false(_c.unit_nodes.has(_unit(_me(), "A1")))


func test_cancelling_again_calls_off_the_regiment() -> void:
	_start()
	_c.pick_regiment(_me().regiments[0])
	_c.cancel()
	_c.cancel()
	assert_null(_c.deployment.regiment)


func test_calling_off_a_regiment_ends_it_at_once() -> void:
	_start()
	_c.pick_regiment(_me().regiments[0])
	_c.call_off_regiment()
	assert_null(_c.deployment.regiment)


func test_calling_off_a_regiment_drops_its_unit_being_placed() -> void:
	_start()
	_c.pick_regiment(_me().regiments[0])
	_c.call_off_regiment()
	var unit := _unit(_me(), "A1")
	assert_false(_c.unit_nodes.has(unit), "the unit being placed is taken off the board")
	assert_eq(unit.positions.size(), 0, "the unit being placed loses its spot")
	assert_false(_c.confirm().is_empty(), "nothing is left to confirm")


# arranging

func test_a_formation_rearranges_the_unit_coherently() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	var before := unit.positions.duplicate()
	_c.set_formation(Formations.Kind.LINE)
	assert_ne(unit.positions, before)
	assert_true(Coherency.is_coherent(unit.positions, unit.bases, unit.facing))


func test_a_formation_keeps_the_units_middle() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	var middle := _middle(unit)
	_c.set_formation(Formations.Kind.WEDGE)
	assert_almost_eq(_middle(unit), middle, Vector2(0.01, 0.01))


func test_a_formation_does_nothing_for_a_single_model() -> void:
	var solo := BattleKit.unit("Solo", 1)
	_battle.player.units.append(solo)
	_battle.opponent = _me().mirror()
	_start()
	_c.pick_unit(solo)
	var before := solo.positions.duplicate()
	_c.set_formation(Formations.Kind.LINE)
	assert_eq(solo.positions, before)


func test_a_formation_does_nothing_when_nothing_is_picked() -> void:
	_start()
	_c.set_formation(Formations.Kind.LINE)
	assert_eq(_c.hud.formation_buttons.size(), 0)


func test_turning_turns_the_unit_about_its_middle() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	var middle := _middle(unit)
	var facing := unit.facing
	_c.turn(0.5)
	assert_almost_eq(unit.facing, facing + 0.5, 0.0001)
	assert_almost_eq(_middle(unit), middle, Vector2(0.01, 0.01))


func test_turning_keeps_the_unit_coherent() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	_c.turn(0.7)
	assert_true(Coherency.is_coherent(unit.positions, unit.bases, unit.facing))


func test_turning_terrain_turns_the_feature() -> void:
	_me().terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	_battle.opponent = _me().mirror()
	_start()
	var feature := _me().terrain[0]
	_c.pick_terrain(feature)
	var rotation := feature.rotation
	_c.turn(0.4)
	assert_almost_eq(feature.rotation, rotation + 0.4, 0.0001)


func test_moving_to_a_point_puts_the_unit_there() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	_c.move_to(Vector2(12, 6))
	assert_almost_eq(_middle(unit), Vector2(12, 6), Vector2(0.01, 0.01))


func test_moving_a_unit_out_of_its_zone_raises_a_problem() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	_c.move_to(Vector2(30, 40))
	assert_gt(_problems(unit).size(), 0)
	assert_true(_c.hud.alert.visible)
	assert_true(_c.hud.confirm_button.disabled)


func test_moving_back_into_the_zone_clears_the_problem() -> void:
	_start()
	_c.pick_unit(_unit(_me(), "A1"))
	_c.move_to(Vector2(30, 40))
	_c.move_to(Vector2(30, 6))
	assert_false(_c.hud.alert.visible)


func test_moving_one_model_leaves_the_others() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	var before := unit.positions.duplicate()
	_c.move_model(0, Vector2(0, -2))
	assert_eq(unit.positions[1], before[1])
	assert_ne(unit.positions[0], before[0])


func test_moving_one_model_away_breaks_coherency() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	_c.move_model(0, Vector2(0, -6))
	assert_false(Coherency.is_coherent(unit.positions, unit.bases, unit.facing))
	assert_true(_c.hud.alert.visible)


func test_moving_model_minus_one_moves_the_whole_unit() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	var before := _middle(unit)
	_c.move_model(-1, Vector2(2, 0))
	assert_almost_eq(_middle(unit), before + Vector2(2, 0), Vector2(0.01, 0.01))


func test_moving_a_model_that_does_not_exist_changes_nothing() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	var before := unit.positions.duplicate()
	_c.move_model(99, Vector2(2, 0))
	assert_eq(unit.positions, before)


func test_undo_puts_the_unit_back_where_it_started() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	var positions := unit.positions.duplicate()
	var facing := unit.facing
	_c.move_to(Vector2(40, 8))
	_c.turn(1.0)
	_c.undo()
	assert_eq(unit.positions, positions)
	assert_eq(unit.facing, facing)


func test_undo_clears_the_formation_choice() -> void:
	_start()
	_c.pick_unit(_unit(_me(), "A1"))
	_c.set_formation(Formations.Kind.LINE)
	_c.undo()
	for button in _c.hud.formation_buttons:
		assert_false(button.button_pressed)


func test_undo_puts_terrain_back_where_it_started() -> void:
	_me().terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	_battle.opponent = _me().mirror()
	_start()
	var feature := _me().terrain[0]
	_c.pick_terrain(feature)
	var start := feature.position
	_c.move_to(Vector2(10, 4))
	assert_ne(feature.position, start)
	_c.undo()
	assert_eq(feature.position, start)


func test_the_model_under_a_point_is_found() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	assert_eq(_c.model_at(unit.positions[1]), 1)


func test_no_model_is_found_away_from_the_unit() -> void:
	_start()
	_c.pick_unit(_unit(_me(), "A1"))
	assert_eq(_c.model_at(Vector2(55, 40)), -1)


func test_no_model_is_found_when_nothing_is_picked() -> void:
	_start()
	assert_eq(_c.model_at(Vector2(30, 5)), -1)


# picking up and putting down

func _terrain_start() -> BattleTerrain:
	_me().terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	_battle.opponent = _me().mirror()
	_start()
	var feature := _me().terrain[0]
	_c.pick_terrain(feature)
	return feature


## A unit picked, put down and ready to be picked up again.
func _put_down_unit() -> BattleUnit:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	_c.put_down()
	return unit


func test_nothing_is_held_to_begin_with() -> void:
	_start()
	assert_false(_c.is_holding())


func test_a_picked_unit_starts_held() -> void:
	_start()
	_c.pick_unit(_unit(_me(), "A1"))
	assert_true(_c.is_holding())


func test_picked_terrain_starts_held() -> void:
	_terrain_start()
	assert_true(_c.is_holding())


func test_hovering_moves_the_held_unit_to_the_point() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	_c.hover(Vector2(12, 6))
	assert_almost_eq(_middle(unit), Vector2(12, 6), Vector2(0.01, 0.01))


func test_hovering_keeps_the_held_units_shape() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	var middle := _middle(unit)
	var offsets := PackedVector2Array()
	for position in unit.positions:
		offsets.append(position - middle)
	_c.hover(Vector2(12, 6))
	for i in unit.positions.size():
		assert_almost_eq(unit.positions[i] - _middle(unit), offsets[i], Vector2(0.01, 0.01))


func test_hovering_moves_held_terrain() -> void:
	var feature := _terrain_start()
	_c.hover(Vector2(12, 6))
	assert_almost_eq(feature.position, Vector2(12, 6), Vector2(0.01, 0.01))


func test_hovering_with_nothing_held_moves_nothing() -> void:
	var unit := _put_down_unit()
	var before := unit.positions.duplicate()
	_c.hover(Vector2(12, 6))
	assert_eq(unit.positions, before)


func test_clicking_while_holding_puts_it_down() -> void:
	_start()
	_c.pick_unit(_unit(_me(), "A1"))
	_c.click(Vector2(12, 6))
	assert_false(_c.is_holding())


func test_a_unit_put_down_stays_where_it_is() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	_c.hover(Vector2(12, 6))
	_c.click(Vector2(12, 6))
	_c.hover(Vector2(40, 6))
	assert_almost_eq(_middle(unit), Vector2(12, 6), Vector2(0.01, 0.01))


func test_clicking_a_model_picks_the_unit_up_again() -> void:
	var unit := _put_down_unit()
	_c.click(unit.positions[1])
	assert_true(_c.is_holding())


func test_picking_the_unit_up_by_a_model_does_not_make_it_jump() -> void:
	var unit := _put_down_unit()
	var middle := _middle(unit)
	_c.click(unit.positions[1])
	_c.hover(unit.positions[1])
	assert_almost_eq(_middle(unit), middle, Vector2(0.01, 0.01))


func test_a_unit_picked_up_by_a_model_follows_the_mouse() -> void:
	var unit := _put_down_unit()
	var middle := _middle(unit)
	_c.click(unit.positions[1])
	_c.hover(unit.positions[1] + Vector2(3, 1))
	assert_almost_eq(_middle(unit), middle + Vector2(3, 1), Vector2(0.01, 0.01))


func test_alt_clicking_a_model_picks_up_just_that_model() -> void:
	var unit := _put_down_unit()
	_c.click(unit.positions[1], true)
	assert_true(_c.is_holding())


func test_hovering_moves_only_the_model_picked_up() -> void:
	var unit := _put_down_unit()
	var before := unit.positions.duplicate()
	var at := unit.positions[1]
	_c.click(at, true)
	_c.hover(at + Vector2(0, -1.5))
	assert_ne(unit.positions[1], before[1])
	assert_eq([unit.positions[0], unit.positions[2]], [before[0], before[2]])


func test_clicking_empty_board_while_not_holding_does_nothing() -> void:
	var unit := _put_down_unit()
	var before := unit.positions.duplicate()
	_c.click(Vector2(55, 3))
	assert_eq(unit.positions, before)
	assert_false(_c.is_holding())


func test_clicking_with_nothing_being_placed_does_nothing() -> void:
	_start()
	_c.click(Vector2(30, 5))
	assert_false(_c.is_holding())


func test_clicking_inside_terrain_picks_it_up() -> void:
	var feature := _terrain_start()
	_c.put_down()
	_c.click(feature.position)
	assert_true(_c.is_holding())


func test_clicking_off_terrain_does_not_pick_it_up() -> void:
	var feature := _terrain_start()
	_c.put_down()
	_c.click(feature.position + Vector2(20, 0))
	assert_false(_c.is_holding())


func test_putting_down_releases_what_is_held() -> void:
	_start()
	_c.pick_unit(_unit(_me(), "A1"))
	_c.put_down()
	assert_false(_c.is_holding())


func test_putting_down_with_nothing_held_does_nothing_wrong() -> void:
	_start()
	_c.put_down()
	assert_false(_c.is_holding())


func test_undo_leaves_nothing_held() -> void:
	_start()
	_c.pick_unit(_unit(_me(), "A1"))
	_c.undo()
	assert_false(_c.is_holding())


func test_confirming_leaves_nothing_held() -> void:
	_start()
	_c.pick_unit(_unit(_me(), "A1"))
	_c.confirm()
	assert_false(_c.is_holding())


func test_confirming_terrain_leaves_nothing_held() -> void:
	_terrain_start()
	_c.confirm()
	assert_false(_c.is_holding())


# confirming

func test_confirming_deploys_the_unit() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	assert_eq(_c.confirm(), "")
	assert_true(unit.is_on_battlefield())


func test_confirming_hands_the_turn_to_the_ai_which_then_deploys() -> void:
	_start()
	_c.pick_unit(_unit(_me(), "A1"))
	_c.confirm()
	await wait_process_frames(2)
	assert_true(_unit(_battle.opponent, "A1").deployed)
	assert_same(_c.deployment.active, _me())


func test_confirming_an_invalid_spot_returns_the_error_and_deploys_nothing() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	_c.move_to(Vector2(30, 40))
	assert_ne(_c.confirm(), "")
	assert_false(unit.deployed)


func test_a_refused_confirm_leaves_the_unit_being_placed() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	_c.move_to(Vector2(30, 40))
	_c.confirm()
	_c.move_to(Vector2(30, 6))
	assert_eq(_c.confirm(), "")
	assert_true(unit.deployed)


func test_confirming_with_nothing_picked_says_so() -> void:
	_start()
	assert_ne(_c.confirm(), "")


func test_the_confirmed_unit_stays_on_the_board_without_rings() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	_c.confirm()
	assert_null(_c.unit_nodes[unit].get_node_or_null("Rings"))


func test_cancelling_takes_the_unit_off_the_board() -> void:
	_start()
	var unit := _unit(_me(), "A1")
	_c.pick_unit(unit)
	_c.cancel()
	assert_false(_c.unit_nodes.has(unit))
	assert_eq(unit.positions.size(), 0)
	assert_false(unit.deployed)


func test_cancelling_hides_the_placing_panel() -> void:
	_start()
	_c.pick_unit(_unit(_me(), "A1"))
	_c.cancel()
	assert_null(_c.hud.confirm_button)


# the AI

func test_the_ai_takes_the_first_turn_when_it_is_the_attacker() -> void:
	_battle.player_is_attacker = false
	_start()
	await wait_process_frames(2)
	var deployed := _battle.opponent.units.filter(func(u: BattleUnit) -> bool: return u.deployed)
	assert_eq(deployed.size(), 1)
	assert_same(_c.deployment.active, _me())


func test_the_player_cannot_pick_while_the_ai_is_to_act() -> void:
	_battle.player_is_attacker = false
	_start()
	assert_false(_c.is_player_turn())


# abilities

func test_an_ability_for_its_own_unit_starts_with_that_unit_picked() -> void:
	var entry := _reserve_entry("Aux")
	_start()
	_c.pick_ability(entry)
	assert_eq(_c.hud.target_buttons.size(), 1)
	assert_true(_c.hud.target_buttons[0].button_pressed)


func test_confirming_a_reserve_sets_the_unit_up_in_reserve() -> void:
	var entry := _reserve_entry("Aux")
	_start()
	_c.pick_ability(entry)
	assert_eq(_c.confirm(), "")
	var unit := _unit(_me(), "Aux")
	assert_true(unit.deployed)
	assert_ne(unit.reserve, "")


func test_an_ability_for_any_unit_asks_for_a_target_first() -> void:
	var entry := _reserve_entry()
	_start()
	_c.pick_ability(entry)
	assert_true(_c.hud.confirm_button.disabled)
	assert_true(_c.hud.alert.visible)


func test_confirming_without_a_target_is_refused() -> void:
	var entry := _reserve_entry()
	_start()
	_c.pick_ability(entry)
	assert_ne(_c.confirm(), "")


func test_toggling_a_target_picks_it_and_allows_confirming() -> void:
	var entry := _reserve_entry()
	_start()
	_c.pick_ability(entry)
	_c.toggle_target(_unit(_me(), "A1"))
	assert_false(_c.hud.confirm_button.disabled)
	assert_eq(_c.confirm(), "")
	assert_ne(_unit(_me(), "A1").reserve, "")


func test_toggling_a_target_twice_unpicks_it() -> void:
	var entry := _reserve_entry()
	_start()
	_c.pick_ability(entry)
	_c.toggle_target(_unit(_me(), "A1"))
	_c.toggle_target(_unit(_me(), "A1"))
	assert_true(_c.hud.confirm_button.disabled)


func test_several_targets_can_be_picked_for_a_reserve() -> void:
	var entry := _reserve_entry()
	_start()
	_c.pick_ability(entry)
	_c.toggle_target(_unit(_me(), "A1"))
	_c.toggle_target(_unit(_me(), "Aux"))
	_c.confirm()
	assert_ne(_unit(_me(), "A1").reserve, "")
	assert_ne(_unit(_me(), "Aux").reserve, "")


func test_toggling_a_target_without_an_ability_does_nothing() -> void:
	_start()
	_c.toggle_target(_unit(_me(), "A1"))
	assert_eq(_c.hud.target_buttons.size(), 0)


func test_cancelling_an_ability_uses_nothing() -> void:
	var entry := _reserve_entry("Aux")
	_start()
	_c.pick_ability(entry)
	_c.cancel()
	assert_false(_unit(_me(), "Aux").deployed)
	assert_eq(_c.hud.target_buttons.size(), 0)


func test_an_unusable_ability_cannot_be_picked() -> void:
	var entry := _reserve_entry("Aux")
	_battle.player_is_attacker = false
	_start()
	_c.pick_ability(entry)
	assert_eq(_c.hud.target_buttons.size(), 0)


func test_a_recorded_ability_is_used_in_the_abilities_step() -> void:
	var ability := BattleKit.ability("Scout", PackedStringArray(), "Do something.")
	ability.timing = DeploymentAbility.TIMING
	var entry := BattleKit.deploy_entry(ability)
	_me().deployment_abilities.append(entry)
	_battle.opponent = _me().mirror()
	for army in [_battle.player, _battle.opponent]:
		for unit: BattleUnit in army.units:
			unit.deployed = true
	_start()
	_c.pick_ability(entry)
	assert_eq(_c.confirm(), "")
	assert_true(_c.deployment.is_used(_me(), entry))


func test_passing_the_abilities_step_ends_it() -> void:
	var ability := BattleKit.ability("Scout", PackedStringArray(), "Do something.")
	ability.timing = DeploymentAbility.TIMING
	_me().deployment_abilities.append(BattleKit.deploy_entry(ability))
	_battle.opponent = _me().mirror()
	for army in [_battle.player, _battle.opponent]:
		for unit: BattleUnit in army.units:
			unit.deployed = true
	_start()
	_c.pass_step()
	await wait_process_frames(2)
	assert_true(_c.deployment.is_done())


# terrain

func test_the_terrain_step_starts_placing_the_first_feature() -> void:
	_me().terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	_battle.opponent = _me().mirror()
	_start()
	await wait_process_frames(2)
	assert_true(_c.terrain_nodes.has(_me().terrain[0]))


func test_picked_terrain_starts_in_a_valid_spot() -> void:
	_me().terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	_battle.opponent = _me().mirror()
	_start()
	var feature := _me().terrain[0]
	_c.pick_terrain(feature)
	var problems := DeploymentRules.terrain_problems(_battle, _me(), feature, feature.position, feature.rotation)
	assert_eq(problems.size(), 0)


func test_confirming_terrain_places_it() -> void:
	_me().terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	_battle.opponent = _me().mirror()
	_start()
	var feature := _me().terrain[0]
	_c.pick_terrain(feature)
	assert_eq(_c.confirm(), "")
	assert_true(feature.placed)


func test_terrain_in_a_bad_spot_cannot_be_confirmed() -> void:
	_me().terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	_battle.opponent = _me().mirror()
	_start()
	var feature := _me().terrain[0]
	_c.pick_terrain(feature)
	_c.move_to(Vector2(30, 40))
	assert_ne(_c.confirm(), "")
	assert_false(feature.placed)


func test_terrain_cannot_be_picked_in_the_units_step() -> void:
	_start()
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	_me().terrain.append(feature)
	_c.pick_terrain(feature)
	assert_false(_c.terrain_nodes.has(feature))


# finishing

func test_deployment_finishes_when_both_sides_are_down() -> void:
	_single_unit_armies()
	_start()
	watch_signals(_c)
	_c.pick_unit(_unit(_me(), "Aux"))
	_c.confirm()
	await wait_process_frames(3)
	assert_signal_emitted(_c, "finished")
	assert_true(_c.deployment.is_done())


func test_the_ais_units_are_on_the_board_once_deployed() -> void:
	_single_unit_armies()
	_start()
	_c.pick_unit(_unit(_me(), "Aux"))
	_c.confirm()
	await wait_process_frames(3)
	assert_true(_c.unit_nodes.has(_unit(_battle.opponent, "Aux")))


func test_the_hud_goes_into_the_overlay() -> void:
	_start()
	assert_same(_c.hud.get_parent(), _map.overlay)
