extends GutTest
## Unit tests for the deployment geometry and rules (scripts/battle/deployment/deployment_rules.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")

const INCH := 25.4


## A Matched Play battle: the player's territory is y 0 to 18, the opponent's y 26 to 44, so the
## player's units must be at y 17 or less.
func _matched() -> Battle:
	var battle := BattleKit.battle()
	battle.mode = BattleSetup.Mode.MATCHED_PLAY
	battle.battlefield_size = Vector2(60, 44)
	battle.player_territory = [BattleKit.rect_polygon(0, 0, 60, 18)] as Array[PackedVector2Array]
	battle.opponent_territory = [BattleKit.rect_polygon(0, 26, 60, 18)] as Array[PackedVector2Array]
	battle.face_armies()
	return battle


func _round(diameter_inches := 1.0) -> BaseSize:
	return BaseSize.round_base(diameter_inches * INCH)


func _unit(count: int, diameter_inches := 1.0) -> BattleUnit:
	var unit := BattleKit.unit("Unit", count)
	var bases: Array[BaseSize] = []
	for i in count:
		bases.append(_round(diameter_inches))
	unit.bases = bases
	return unit


func _row(count: int, from: Vector2, spacing := 1.2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in count:
		result.append(from + Vector2(i * spacing, 0))
	return result


func _deploy_at(unit: BattleUnit, positions: PackedVector2Array) -> void:
	unit.positions = positions
	unit.deployed = true


func _bounds(polygons: Array[PackedVector2Array]) -> Rect2:
	var bounds := Rect2(polygons[0][0], Vector2.ZERO)
	for polygon in polygons:
		for point in polygon:
			bounds = bounds.expand(point)
	return bounds


# zone

func test_zone_stops_short_of_enemy_territory_by_the_gap() -> void:
	var own: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 10, 22)]
	var enemy: Array[PackedVector2Array] = [BattleKit.rect_polygon(12, 0, 10, 22)]
	var bounds := _bounds(DeploymentRules.zone(own, enemy, 6.0))
	assert_almost_eq(bounds.end.x, 6.0, 0.01)


func test_zone_keeps_the_far_edge_of_own_territory() -> void:
	var own: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 10, 22)]
	var enemy: Array[PackedVector2Array] = [BattleKit.rect_polygon(30, 0, 10, 22)]
	var bounds := _bounds(DeploymentRules.zone(own, enemy, 6.0))
	assert_almost_eq(bounds.position.x, 0.0, 0.01)
	assert_almost_eq(bounds.end.x, 10.0, 0.01)


func test_zone_is_empty_when_the_gap_covers_all_own_territory() -> void:
	var own: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 10, 22)]
	var enemy: Array[PackedVector2Array] = [BattleKit.rect_polygon(12, 0, 10, 22)]
	assert_eq(DeploymentRules.zone(own, enemy, 20.0).size(), 0)


func test_zone_without_enemy_territory_is_the_own_territory() -> void:
	var own: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 10, 22)]
	assert_eq(DeploymentRules.zone(own, [] as Array[PackedVector2Array], 6.0).size(), 1)


func test_zone_gap_zero_keeps_everything_not_touching() -> void:
	var own: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 10, 22)]
	var enemy: Array[PackedVector2Array] = [BattleKit.rect_polygon(12, 0, 10, 22)]
	assert_almost_eq(_bounds(DeploymentRules.zone(own, enemy, 0.0)).end.x, 10.0, 0.01)


# unit_zone

func test_matched_play_unit_zone_uses_the_larger_gap() -> void:
	var battle := _matched()
	var bounds := _bounds(DeploymentRules.unit_zone(battle, battle.player))
	assert_gt(bounds.end.y, 16.5)
	assert_lt(bounds.end.y, 17.5)


func test_spearhead_unit_zone_uses_a_smaller_gap_than_matched_play() -> void:
	var matched := _matched()
	var spearhead := _matched()
	spearhead.mode = BattleSetup.Mode.SPEARHEAD
	var matched_end := _bounds(DeploymentRules.unit_zone(matched, matched.player)).end.y
	var spearhead_end := _bounds(DeploymentRules.unit_zone(spearhead, spearhead.player)).end.y
	assert_gt(spearhead_end, matched_end)


func test_unit_zone_of_the_opponent_is_on_its_own_side() -> void:
	var battle := _matched()
	var bounds := _bounds(DeploymentRules.unit_zone(battle, battle.opponent))
	assert_gt(bounds.position.y, 26.5)


# terrain_zone

func test_matched_play_terrain_zone_is_the_whole_territory() -> void:
	var battle := _matched()
	assert_eq(DeploymentRules.terrain_zone(battle, battle.player), battle.player_territory)


func test_spearhead_terrain_zone_keeps_off_the_long_edges() -> void:
	var battle := BattleKit.battle()
	var bounds := _bounds(DeploymentRules.terrain_zone(battle, battle.player))
	assert_gt(bounds.position.y, 2.5)
	assert_lt(bounds.end.y, battle.battlefield_size.y - 2.5)


func test_spearhead_terrain_zone_keeps_off_enemy_territory() -> void:
	var battle := BattleKit.battle()
	battle.opponent_territory = [BattleKit.rect_polygon(12, 0, 18, 22)] as Array[PackedVector2Array]
	var bounds := _bounds(DeploymentRules.terrain_zone(battle, battle.player))
	assert_lt(bounds.end.x, 9.5)


func test_spearhead_terrain_zone_works_for_a_battlefield_taller_than_wide() -> void:
	var battle := BattleKit.battle()
	battle.battlefield_size = Vector2(22, 30)
	battle.player_territory = [BattleKit.rect_polygon(0, 0, 22, 10)] as Array[PackedVector2Array]
	battle.opponent_territory = [BattleKit.rect_polygon(0, 20, 22, 10)] as Array[PackedVector2Array]
	var bounds := _bounds(DeploymentRules.terrain_zone(battle, battle.player))
	assert_gt(bounds.position.x, 2.5)
	assert_lt(bounds.end.x, 19.5)


# outlines

func test_round_base_outline_is_as_wide_as_the_base() -> void:
	var outline := DeploymentRules.base_outline(_round(2.0), Vector2(10, 10), 0.0)
	var bounds := _bounds([outline] as Array[PackedVector2Array])
	assert_almost_eq(bounds.size.x, 2.0, 0.05)
	assert_almost_eq(bounds.size.y, 2.0, 0.05)


func test_oval_base_outline_is_long_along_the_facing() -> void:
	var outline := DeploymentRules.base_outline(BaseSize.oval(2 * INCH, 1 * INCH), Vector2.ZERO, 0.0)
	var bounds := _bounds([outline] as Array[PackedVector2Array])
	assert_gt(bounds.size.x, bounds.size.y)


func test_oval_base_outline_turns_with_the_facing() -> void:
	var outline := DeploymentRules.base_outline(BaseSize.oval(2 * INCH, 1 * INCH), Vector2.ZERO, PI / 2)
	var bounds := _bounds([outline] as Array[PackedVector2Array])
	assert_gt(bounds.size.y, bounds.size.x)


func test_model_base_outline_is_a_rectangle() -> void:
	var outline := DeploymentRules.base_outline(BaseSize.model(2 * INCH, 1 * INCH), Vector2.ZERO, 0.0)
	assert_eq(outline.size(), 4)


func test_outline_is_centred_on_the_model() -> void:
	var outline := DeploymentRules.base_outline(_round(), Vector2(7, 3), 0.4)
	assert_almost_eq(_bounds([outline] as Array[PackedVector2Array]).get_center(), Vector2(7, 3), Vector2(0.05, 0.05))


func test_round_terrain_outline_is_not_a_rectangle() -> void:
	var feature := BattleKit.terrain(BattleTerrain.Kind.PLACE_OF_POWER, 4.0)
	assert_gt(DeploymentRules.terrain_outline(feature, Vector2.ZERO, 0.0).size(), 4)


func test_square_terrain_outline_is_a_rectangle() -> void:
	var feature := BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 4.0)
	assert_eq(DeploymentRules.terrain_outline(feature, Vector2.ZERO, 0.0).size(), 4)


# is_wholly_within

func test_outline_inside_a_polygon_is_wholly_within() -> void:
	var polygons: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 10, 10)]
	assert_true(DeploymentRules.is_wholly_within(polygons, DeploymentRules.base_outline(_round(), Vector2(5, 5), 0.0)))


func test_outline_crossing_an_edge_is_not_wholly_within() -> void:
	var polygons: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 10, 10)]
	assert_false(DeploymentRules.is_wholly_within(polygons, DeploymentRules.base_outline(_round(), Vector2(9.8, 5), 0.0)))


func test_outline_touching_an_edge_is_wholly_within() -> void:
	var polygons: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 10, 10)]
	assert_true(DeploymentRules.is_wholly_within(polygons, DeploymentRules.base_outline(_round(), Vector2(9.5, 5), 0.0)))


func test_outline_spanning_two_polygons_is_not_wholly_within_either() -> void:
	var polygons: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 5, 10), BattleKit.rect_polygon(6, 0, 5, 10)]
	assert_false(DeploymentRules.is_wholly_within(polygons, DeploymentRules.base_outline(_round(2.0), Vector2(5.5, 5), 0.0)))


func test_nothing_is_within_no_polygons() -> void:
	assert_false(DeploymentRules.is_wholly_within([] as Array[PackedVector2Array], DeploymentRules.base_outline(_round(), Vector2.ZERO, 0.0)))


# bases_overlap and base_gap

func test_separate_bases_do_not_overlap() -> void:
	assert_false(DeploymentRules.bases_overlap(_round(), Vector2.ZERO, 0.0, _round(), Vector2(3, 0), 0.0))


func test_intersecting_bases_overlap() -> void:
	assert_true(DeploymentRules.bases_overlap(_round(), Vector2.ZERO, 0.0, _round(), Vector2(0.5, 0), 0.0))


func test_touching_bases_do_not_overlap() -> void:
	assert_false(DeploymentRules.bases_overlap(_round(), Vector2.ZERO, 0.0, _round(), Vector2(1, 0), 0.0))


func test_overlapping_ovals_are_detected() -> void:
	var oval := BaseSize.oval(2 * INCH, 1 * INCH)
	assert_true(DeploymentRules.bases_overlap(oval, Vector2.ZERO, 0.0, oval, Vector2(1, 0.2), 0.0))


func test_ovals_side_by_side_across_their_length_do_not_overlap() -> void:
	var oval := BaseSize.oval(2 * INCH, 1 * INCH)
	assert_false(DeploymentRules.bases_overlap(oval, Vector2.ZERO, 0.0, oval, Vector2(0, 3), 0.0))


func test_oval_facing_changes_whether_ovals_overlap() -> void:
	var oval := BaseSize.oval(3 * INCH, 1 * INCH)
	var lengthways := DeploymentRules.bases_overlap(oval, Vector2.ZERO, 0.0, oval, Vector2(2.0, 0), 0.0)
	var sideways := DeploymentRules.bases_overlap(oval, Vector2.ZERO, PI / 2, oval, Vector2(2.0, 0), PI / 2)
	assert_true(lengthways)
	assert_false(sideways)


func test_round_base_gap_is_edge_to_edge() -> void:
	assert_almost_eq(DeploymentRules.base_gap(_round(), Vector2.ZERO, 0.0, _round(), Vector2(1.5, 0), 0.0), 0.5, 0.01)


func test_round_base_gap_is_zero_when_overlapping() -> void:
	assert_eq(DeploymentRules.base_gap(_round(), Vector2.ZERO, 0.0, _round(), Vector2(0.3, 0), 0.0), 0.0)


func test_model_base_gap_is_measured_between_outlines() -> void:
	var model := BaseSize.model(1 * INCH, 1 * INCH)
	assert_almost_eq(DeploymentRules.base_gap(model, Vector2.ZERO, 0.0, model, Vector2(2.0, 0), 0.0), 1.0, 0.01)


func test_oval_base_gap_is_zero_when_overlapping() -> void:
	var oval := BaseSize.oval(2 * INCH, 1 * INCH)
	assert_eq(DeploymentRules.base_gap(oval, Vector2.ZERO, 0.0, oval, Vector2(0.5, 0), 0.0), 0.0)


func test_reach_of_a_round_base_is_its_radius() -> void:
	assert_almost_eq(DeploymentRules.reach_of(_round(2.0)), 1.0, 0.01)


func test_reach_of_a_model_covers_its_corners() -> void:
	var model := BaseSize.model(2 * INCH, 2 * INCH)
	assert_gt(DeploymentRules.reach_of(model), 1.0)


# is_impassable

func test_faction_terrain_is_impassable() -> void:
	assert_true(DeploymentRules.is_impassable(BattleKit.terrain(BattleTerrain.Kind.FACTION)))


func test_battlefield_terrain_can_be_stood_in() -> void:
	assert_false(DeploymentRules.is_impassable(BattleKit.terrain(BattleTerrain.Kind.OBSCURING)))


# unit_problems and invalid_models

func test_a_unit_inside_its_zone_has_no_problems() -> void:
	var battle := _matched()
	var problems := DeploymentRules.unit_problems(battle, battle.player, _unit(3), _row(3, Vector2(10, 5)), 0.0)
	assert_eq(problems.size(), 0)


func test_a_unit_in_the_gap_next_to_enemy_territory_is_outside_the_zone() -> void:
	var battle := _matched()
	var unit := _unit(3)
	var bad := DeploymentRules.invalid_models(battle, battle.player, unit, _row(3, Vector2(10, 17.8)), 0.0)
	assert_eq(bad.outside.size(), 3)


func test_a_unit_just_inside_the_gap_is_inside_the_zone() -> void:
	var battle := _matched()
	var bad := DeploymentRules.invalid_models(battle, battle.player, _unit(3), _row(3, Vector2(10, 16.0)), 0.0)
	assert_eq(bad.outside.size(), 0)


func test_the_same_spot_is_fine_in_spearhead_but_not_in_matched_play() -> void:
	var matched := _matched()
	var spearhead := _matched()
	spearhead.mode = BattleSetup.Mode.SPEARHEAD
	var positions := _row(3, Vector2(10, 17.0))
	assert_gt(DeploymentRules.invalid_models(matched, matched.player, _unit(3), positions, 0.0).outside.size(), 0)
	assert_eq(DeploymentRules.invalid_models(spearhead, spearhead.player, _unit(3), positions, 0.0).outside.size(), 0)


func test_only_the_models_outside_are_listed() -> void:
	var battle := _matched()
	var positions := PackedVector2Array([Vector2(10, 5), Vector2(11.2, 5), Vector2(12.4, 18.5)])
	var bad := DeploymentRules.invalid_models(battle, battle.player, _unit(3), positions, 0.0)
	assert_eq(bad.outside, PackedInt32Array([2]))


func test_outside_problem_says_which_way_the_gap_is() -> void:
	var battle := _matched()
	var problems := DeploymentRules.unit_problems(battle, battle.player, _unit(1), PackedVector2Array([Vector2(10, 18.5)]), 0.0)
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "deployable zone")


func test_a_zone_override_replaces_the_army_zone() -> void:
	var battle := _matched()
	var small: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 5, 5)]
	var bad := DeploymentRules.invalid_models(battle, battle.player, _unit(1), PackedVector2Array([Vector2(10, 10)]), 0.0, small)
	assert_eq(bad.outside.size(), 1)


func test_models_overlapping_each_other_are_flagged() -> void:
	var battle := _matched()
	var positions := PackedVector2Array([Vector2(10, 5), Vector2(10.4, 5)])
	var bad := DeploymentRules.invalid_models(battle, battle.player, _unit(2), positions, 0.0)
	assert_eq(bad.overlapping, PackedInt32Array([0, 1]))


func test_models_overlapping_a_deployed_unit_are_flagged() -> void:
	var battle := _matched()
	var other := _unit(1)
	battle.player.units.append(other)
	_deploy_at(other, PackedVector2Array([Vector2(10, 5)]))
	var bad := DeploymentRules.invalid_models(battle, battle.player, _unit(1), PackedVector2Array([Vector2(10.3, 5)]), 0.0)
	assert_eq(bad.overlapping.size(), 1)


func test_models_overlapping_an_enemy_unit_are_flagged() -> void:
	var battle := _matched()
	var enemy := _unit(1)
	battle.opponent.units.append(enemy)
	_deploy_at(enemy, PackedVector2Array([Vector2(10, 5)]))
	var bad := DeploymentRules.invalid_models(battle, battle.player, _unit(1), PackedVector2Array([Vector2(10.3, 5)]), 0.0)
	assert_eq(bad.overlapping.size(), 1)


func test_a_unit_does_not_overlap_its_own_old_position() -> void:
	var battle := _matched()
	var unit := _unit(1)
	battle.player.units.append(unit)
	_deploy_at(unit, PackedVector2Array([Vector2(10, 5)]))
	var bad := DeploymentRules.invalid_models(battle, battle.player, unit, PackedVector2Array([Vector2(10.3, 5)]), 0.0)
	assert_eq(bad.overlapping.size(), 0)


func test_units_in_reserve_are_not_in_the_way() -> void:
	var battle := _matched()
	var other := _unit(1)
	battle.player.units.append(other)
	_deploy_at(other, PackedVector2Array([Vector2(10, 5)]))
	other.reserve = "in the clouds"
	var bad := DeploymentRules.invalid_models(battle, battle.player, _unit(1), PackedVector2Array([Vector2(10.3, 5)]), 0.0)
	assert_eq(bad.overlapping.size(), 0)


func test_models_overlapping_placed_faction_terrain_are_flagged() -> void:
	var battle := _matched()
	battle.player.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 4.0, Vector2(10, 5)))
	var bad := DeploymentRules.invalid_models(battle, battle.player, _unit(1), PackedVector2Array([Vector2(10, 5)]), 0.0)
	assert_eq(bad.overlapping.size(), 1)


func test_models_can_stand_on_battlefield_terrain() -> void:
	var battle := _matched()
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 4.0, Vector2(10, 5)))
	var bad := DeploymentRules.invalid_models(battle, battle.player, _unit(1), PackedVector2Array([Vector2(10, 5)]), 0.0)
	assert_eq(bad.overlapping.size(), 0)


func test_models_ignore_unplaced_faction_terrain() -> void:
	var battle := _matched()
	battle.player.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 4.0, Vector2(10, 5), false))
	var bad := DeploymentRules.invalid_models(battle, battle.player, _unit(1), PackedVector2Array([Vector2(10, 5)]), 0.0)
	assert_eq(bad.overlapping.size(), 0)


func test_overlap_problem_is_reported() -> void:
	var battle := _matched()
	var problems := DeploymentRules.unit_problems(battle, battle.player, _unit(2), PackedVector2Array([Vector2(10, 5), Vector2(10.4, 5)]), 0.0)
	assert_string_contains(problems[0], "overlapping")


func test_incoherent_models_are_flagged() -> void:
	var battle := _matched()
	var bad := DeploymentRules.invalid_models(battle, battle.player, _unit(2), PackedVector2Array([Vector2(10, 5), Vector2(15, 5)]), 0.0)
	assert_eq(bad.incoherent.size(), 2)


func test_incoherent_problem_asks_for_another_model_in_a_small_unit() -> void:
	var battle := _matched()
	var problems := DeploymentRules.unit_problems(battle, battle.player, _unit(2), PackedVector2Array([Vector2(10, 5), Vector2(15, 5)]), 0.0)
	assert_string_contains(problems[0], "another model")


func test_incoherent_problem_asks_for_two_models_in_a_large_unit() -> void:
	var battle := _matched()
	var unit := _unit(8)
	var positions := _row(7, Vector2(10, 5))
	positions.append(Vector2(30, 5))
	var problems := DeploymentRules.unit_problems(battle, battle.player, unit, positions, 0.0)
	assert_string_contains(problems[problems.size() - 1], "2 other models")


func test_a_single_problem_per_reason_however_many_models() -> void:
	var battle := _matched()
	var problems := DeploymentRules.unit_problems(battle, battle.player, _unit(3), _row(3, Vector2(10, 40)), 0.0)
	assert_eq(problems.size(), 1)


func test_one_model_problem_reads_in_the_singular() -> void:
	var battle := _matched()
	var problems := DeploymentRules.unit_problems(battle, battle.player, _unit(1), PackedVector2Array([Vector2(10, 40)]), 0.0)
	assert_string_contains(problems[0], "1 model is")


# terrain_problems

func test_terrain_in_its_territory_has_no_problems() -> void:
	var battle := _matched()
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	assert_eq(DeploymentRules.terrain_problems(battle, battle.player, feature, Vector2(30, 9), 0.0).size(), 0)


func test_terrain_outside_its_territory_is_a_problem() -> void:
	var battle := _matched()
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	var problems := DeploymentRules.terrain_problems(battle, battle.player, feature, Vector2(30, 30), 0.0)
	assert_string_contains(problems[0], "territory")


func test_terrain_partly_over_the_territory_edge_is_a_problem() -> void:
	var battle := _matched()
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 4.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	assert_gt(DeploymentRules.terrain_problems(battle, battle.player, feature, Vector2(30, 17), 0.0).size(), 0)


func test_matched_play_terrain_too_close_to_an_objective_is_a_problem() -> void:
	var battle := _matched()
	battle.objectives = [BattleKit.feature("Objective", Vector2(30, 9))] as Array[MapFeature]
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	var problems := DeploymentRules.terrain_problems(battle, battle.player, feature, Vector2(30, 12), 0.0)
	assert_true(Array(problems).any(func(p: String) -> bool: return p.contains("objectives")))


func test_matched_play_terrain_beyond_three_inches_from_an_objective_is_fine() -> void:
	var battle := _matched()
	battle.objectives = [BattleKit.feature("Objective", Vector2(30, 9))] as Array[MapFeature]
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	assert_eq(DeploymentRules.terrain_problems(battle, battle.player, feature, Vector2(45, 9), 0.0).size(), 0)


func test_matched_play_terrain_near_other_terrain_is_a_problem() -> void:
	var battle := _matched()
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 4.0, Vector2(20, 9)))
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	var problems := DeploymentRules.terrain_problems(battle, battle.player, feature, Vector2(24.5, 9), 0.0)
	assert_true(Array(problems).any(func(p: String) -> bool: return p.contains("other terrain")))


func test_matched_play_terrain_far_from_other_terrain_is_fine() -> void:
	var battle := _matched()
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 4.0, Vector2(20, 9)))
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	assert_eq(DeploymentRules.terrain_problems(battle, battle.player, feature, Vector2(40, 9), 0.0).size(), 0)


func test_a_feature_is_not_near_itself() -> void:
	var battle := _matched()
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2(30, 9), true)
	battle.player.terrain.append(feature)
	assert_eq(DeploymentRules.terrain_problems(battle, battle.player, feature, Vector2(30, 9), 0.0).size(), 0)


func test_unplaced_terrain_does_not_count_as_near() -> void:
	var battle := _matched()
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 4.0, Vector2(30, 9), false))
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	assert_eq(DeploymentRules.terrain_problems(battle, battle.player, feature, Vector2(30, 9), 0.0).size(), 0)


func test_terrain_gap_override_lets_terrain_go_closer() -> void:
	var battle := _matched()
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 4.0, Vector2(20, 9)))
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	var at := Vector2(24.5, 9)
	assert_gt(DeploymentRules.terrain_problems(battle, battle.player, feature, at, 0.0).size(), 0)
	assert_eq(DeploymentRules.terrain_problems(battle, battle.player, feature, at, 0.0, 0.0).size(), 0)


func test_terrain_gap_override_still_forbids_touching() -> void:
	var battle := _matched()
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 4.0, Vector2(20, 9)))
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	assert_gt(DeploymentRules.terrain_problems(battle, battle.player, feature, Vector2(22.5, 9), 0.0, 0.0).size(), 0)


func test_spearhead_terrain_must_be_farther_from_other_terrain_than_matched_play() -> void:
	var matched := _matched()
	var spearhead := _matched()
	spearhead.mode = BattleSetup.Mode.SPEARHEAD
	var spots := []
	for battle in [matched, spearhead]:
		battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 4.0, Vector2(20, 9)))
		var feature := BattleKit.terrain(BattleTerrain.Kind.SPEARHEAD, 3.0, Vector2.ZERO, false)
		battle.player.terrain.append(feature)
		spots.append(DeploymentRules.terrain_problems(battle, battle.player, feature, Vector2(27.5, 9), 0.0).size())
	assert_eq(spots[0], 0)
	assert_gt(spots[1], 0)


func test_spearhead_terrain_on_an_objective_is_a_problem() -> void:
	var battle := BattleKit.battle()
	battle.objectives = [BattleKit.feature("Objective", Vector2(5, 11))] as Array[MapFeature]
	var feature := BattleKit.terrain(BattleTerrain.Kind.SPEARHEAD, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	var problems := DeploymentRules.terrain_problems(battle, battle.player, feature, Vector2(5, 11), 0.0)
	assert_true(Array(problems).any(func(p: String) -> bool: return p.contains("objective")))


func test_spearhead_terrain_beside_an_objective_is_fine() -> void:
	var battle := BattleKit.battle()
	battle.objectives = [BattleKit.feature("Objective", Vector2(5, 11))] as Array[MapFeature]
	var feature := BattleKit.terrain(BattleTerrain.Kind.SPEARHEAD, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	assert_eq(DeploymentRules.terrain_problems(battle, battle.player, feature, Vector2(5, 15.5), 0.0).size(), 0)


func test_spearhead_terrain_near_the_long_edge_is_a_problem() -> void:
	var battle := BattleKit.battle()
	var feature := BattleKit.terrain(BattleTerrain.Kind.SPEARHEAD, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	var problems := DeploymentRules.terrain_problems(battle, battle.player, feature, Vector2(5, 2), 0.0)
	assert_string_contains(problems[0], "long battlefield edges")


func test_terrain_over_a_deployed_model_is_a_problem() -> void:
	var battle := _matched()
	var unit := _unit(1)
	battle.player.units.append(unit)
	_deploy_at(unit, PackedVector2Array([Vector2(30, 9)]))
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	var problems := DeploymentRules.terrain_problems(battle, battle.player, feature, Vector2(30, 9), 0.0)
	assert_true(Array(problems).any(func(p: String) -> bool: return p.contains("models")))


# staged units

func test_models_overlapping_a_staged_unit_are_flagged() -> void:
	var battle := _matched()
	var staged := _unit(3)
	staged.positions = _row(3, Vector2(10, 5))
	var staged_units: Array[BattleUnit] = [staged]
	var bad := DeploymentRules.invalid_models(battle, battle.player, _unit(3), _row(3, Vector2(10, 5)), 0.0, [], staged_units)
	assert_eq(bad.overlapping.size(), 3)


func test_models_clear_of_a_staged_unit_are_not_flagged() -> void:
	var battle := _matched()
	var staged := _unit(3)
	staged.positions = _row(3, Vector2(10, 5))
	var staged_units: Array[BattleUnit] = [staged]
	var bad := DeploymentRules.invalid_models(battle, battle.player, _unit(3), _row(3, Vector2(30, 5)), 0.0, [], staged_units)
	assert_eq(bad.overlapping.size(), 0)


func test_a_staged_unit_does_not_overlap_itself() -> void:
	var battle := _matched()
	var unit := _unit(3)
	unit.positions = _row(3, Vector2(10, 5))
	var staged_units: Array[BattleUnit] = [unit]
	assert_eq(DeploymentRules.unit_problems(battle, battle.player, unit, unit.positions, 0.0, [], staged_units).size(), 0)


func test_a_deployed_staged_unit_is_only_counted_once() -> void:
	var battle := _matched()
	var other := _unit(3)
	other.positions = _row(3, Vector2(10, 5))
	other.deployed = true
	battle.player.units.append(other)
	var staged_units: Array[BattleUnit] = [other]
	var bad := DeploymentRules.invalid_models(battle, battle.player, _unit(3), _row(3, Vector2(10, 5)), 0.0, [], staged_units)
	assert_eq(bad.overlapping.size(), 3)


func test_unit_problems_mention_overlap_with_a_staged_unit() -> void:
	var battle := _matched()
	var staged := _unit(3)
	staged.positions = _row(3, Vector2(10, 5))
	var staged_units: Array[BattleUnit] = [staged]
	var without := DeploymentRules.unit_problems(battle, battle.player, _unit(3), _row(3, Vector2(10, 5)), 0.0)
	var with := DeploymentRules.unit_problems(battle, battle.player, _unit(3), _row(3, Vector2(10, 5)), 0.0, [], staged_units)
	assert_gt(with.size(), without.size())
