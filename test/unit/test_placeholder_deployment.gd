extends GutTest
## Unit tests for the placeholder deployment (scripts/battle/placeholder_deployment.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")


## A deployed battle: each side has two units and a terrain feature, with some battlefield terrain.
func _deployed() -> Battle:
	var battle := BattleKit.battle()
	battle.player.units.append(BattleKit.unit("Player Big", 12, 40.0))
	battle.opponent.units.append(BattleKit.unit("Opponent Big", 12, 40.0))
	battle.player.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	battle.opponent.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false))
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 4.0, Vector2(8, 11)))
	battle.objectives = [BattleKit.feature("Objective", Vector2(15, 11))] as Array[MapFeature]
	PlaceholderDeployment.deploy(battle)
	return battle


func _circles(army: BattleArmy) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for unit in army.units:
		for i in unit.positions.size():
			result.append(Vector3(unit.positions[i].x, unit.positions[i].y, unit.bases[i].footprint().x / 2))
	return result


# deploy

func test_every_model_gets_a_position() -> void:
	var battle := _deployed()
	for army in [battle.player, battle.opponent]:
		for unit: BattleUnit in army.units:
			assert_eq(unit.positions.size(), unit.model_count(), unit.name)


func test_every_player_model_is_wholly_within_the_players_territory() -> void:
	var battle := _deployed()
	for circle in _circles(battle.player):
		assert_true(PlaceholderDeployment.is_wholly_within(battle.player_territory, Vector2(circle.x, circle.y), circle.z))


func test_every_opponent_model_is_wholly_within_the_opponents_territory() -> void:
	var battle := _deployed()
	for circle in _circles(battle.opponent):
		assert_true(PlaceholderDeployment.is_wholly_within(battle.opponent_territory, Vector2(circle.x, circle.y), circle.z))


func test_no_two_bases_overlap() -> void:
	var battle := _deployed()
	var all := _circles(battle.player) + _circles(battle.opponent)
	var overlaps := 0
	for i in all.size():
		for j in range(i + 1, all.size()):
			if Vector2(all[i].x, all[i].y).distance_to(Vector2(all[j].x, all[j].y)) < all[i].z + all[j].z - 0.001:
				overlaps += 1
	assert_eq(overlaps, 0)


func test_models_are_clear_of_battlefield_terrain() -> void:
	var battle := _deployed()
	var feature := battle.terrain[0]
	for circle in _circles(battle.player) + _circles(battle.opponent):
		assert_gt(Vector2(circle.x, circle.y).distance_to(feature.position), circle.z + feature.reach() - 0.001)


func test_models_are_clear_of_army_terrain() -> void:
	var battle := _deployed()
	var feature := battle.player.terrain[0]
	for circle in _circles(battle.player):
		assert_gt(Vector2(circle.x, circle.y).distance_to(feature.position), circle.z + feature.reach() - 0.001)


func test_army_terrain_is_placed() -> void:
	var battle := _deployed()
	assert_true(battle.player.terrain[0].placed)
	assert_true(battle.opponent.terrain[0].placed)


func test_army_terrain_is_in_its_own_territory() -> void:
	var battle := _deployed()
	var player_feature := battle.player.terrain[0]
	var opponent_feature := battle.opponent.terrain[0]
	assert_true(PlaceholderDeployment.is_wholly_within(battle.player_territory, player_feature.position, player_feature.reach()))
	assert_true(PlaceholderDeployment.is_wholly_within(battle.opponent_territory, opponent_feature.position, opponent_feature.reach()))


func test_army_terrain_keeps_clear_of_objectives() -> void:
	var battle := _deployed()
	for feature in [battle.player.terrain[0], battle.opponent.terrain[0]]:
		assert_gt(feature.position.distance_to(battle.objectives[0].position), feature.reach())


func test_armies_face_each_other() -> void:
	var battle := _deployed()
	assert_gt(Vector2.from_angle(battle.player.facing).x, 0.0)
	assert_lt(Vector2.from_angle(battle.opponent.facing).x, 0.0)


func test_armies_fill_from_the_edge_farthest_from_the_enemy() -> void:
	var battle := _deployed()
	var player_x := 0.0
	for circle in _circles(battle.player):
		player_x += circle.x
	var count := _circles(battle.player).size()
	assert_lt(player_x / count, 5.0)


func test_deploying_without_terrain_or_units_does_nothing_wrong() -> void:
	var battle := BattleKit.battle()
	battle.player.units.clear()
	battle.opponent.units.clear()
	PlaceholderDeployment.deploy(battle)
	assert_eq(battle.player.model_count(), 0)


# formation

func test_formation_has_a_position_for_every_model() -> void:
	assert_eq(PlaceholderDeployment.formation(13, 1.0, Vector2.LEFT).size(), 13)


func test_formation_of_no_models_is_empty() -> void:
	assert_eq(PlaceholderDeployment.formation(0, 1.0, Vector2.LEFT).size(), 0)


func test_small_unit_stands_in_a_single_rank() -> void:
	var back := Vector2.LEFT
	var offsets := PlaceholderDeployment.formation(5, 1.0, back)
	for offset in offsets:
		assert_almost_eq(offset.dot(back), 0.0, 0.001)


func test_large_unit_stands_in_more_than_one_rank() -> void:
	var back := Vector2.LEFT
	var offsets := PlaceholderDeployment.formation(8, 1.0, back)
	var ranks := {}
	for offset in offsets:
		ranks[snappedf(offset.dot(back), 0.01)] = true
	assert_gt(ranks.size(), 1)


func test_later_ranks_are_towards_the_enemy() -> void:
	var back := Vector2.LEFT
	var offsets := PlaceholderDeployment.formation(8, 1.0, back)
	assert_lt(offsets[offsets.size() - 1].dot(back), offsets[0].dot(back))


func test_a_rank_is_centred_on_the_middle_of_the_back_rank() -> void:
	var offsets := PlaceholderDeployment.formation(5, 1.0, Vector2.LEFT)
	var total := Vector2.ZERO
	for offset in offsets:
		total += offset
	assert_almost_eq(total, Vector2.ZERO, Vector2(0.001, 0.001))


func test_neighbours_in_a_rank_are_one_step_apart() -> void:
	var offsets := PlaceholderDeployment.formation(4, 2.5, Vector2.LEFT)
	assert_almost_eq(offsets[0].distance_to(offsets[1]), 2.5, 0.001)


func test_ranks_are_one_step_apart() -> void:
	var back := Vector2.LEFT
	var offsets := PlaceholderDeployment.formation(8, 1.5, back)
	assert_almost_eq(offsets[0].distance_to(offsets[4]), 1.5, 0.001)


func test_a_rank_never_has_more_than_the_maximum_models() -> void:
	var offsets := PlaceholderDeployment.formation(100, 1.0, Vector2.LEFT)
	var in_front_rank := 0
	for offset in offsets:
		if absf(offset.dot(Vector2.LEFT)) < 0.001:
			in_front_rank += 1
	assert_lte(in_front_rank, PlaceholderDeployment.MAX_RANK)


# centroid

func test_centroid_of_a_rectangle_is_its_middle() -> void:
	var polygons: Array[PackedVector2Array] = [BattleKit.rect_polygon(2, 4, 10, 6)]
	assert_eq(PlaceholderDeployment.centroid(polygons), Vector2(7, 7))


func test_centroid_of_nothing_is_the_origin() -> void:
	assert_eq(PlaceholderDeployment.centroid([] as Array[PackedVector2Array]), Vector2.ZERO)


func test_centroid_averages_every_polygon() -> void:
	var polygons: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 2, 2), BattleKit.rect_polygon(10, 0, 2, 2)]
	assert_eq(PlaceholderDeployment.centroid(polygons), Vector2(6, 1))


# is_wholly_within

func test_circle_inside_a_territory_is_wholly_within() -> void:
	var polygons: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 10, 10)]
	assert_true(PlaceholderDeployment.is_wholly_within(polygons, Vector2(5, 5), 2.0))


func test_circle_crossing_an_edge_is_not_wholly_within() -> void:
	var polygons: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 10, 10)]
	assert_false(PlaceholderDeployment.is_wholly_within(polygons, Vector2(1, 5), 2.0))


func test_circle_outside_is_not_within() -> void:
	var polygons: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 10, 10)]
	assert_false(PlaceholderDeployment.is_wholly_within(polygons, Vector2(20, 5), 1.0))


func test_circle_may_touch_the_edge() -> void:
	var polygons: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 10, 10)]
	assert_true(PlaceholderDeployment.is_wholly_within(polygons, Vector2(2, 5), 2.0))


func test_circle_within_any_of_several_polygons_counts() -> void:
	var polygons: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 6, 4), BattleKit.rect_polygon(20, 0, 10, 10)]
	assert_true(PlaceholderDeployment.is_wholly_within(polygons, Vector2(25, 5), 2.0))


# spot_for_unit

func _field() -> Battle:
	return BattleKit.deployment_battle()


func _on_battlefield(unit: BattleUnit, at: Vector2) -> void:
	unit.positions = PackedVector2Array([at])
	unit.deployed = true


func test_spot_for_a_unit_has_a_position_per_model() -> void:
	var battle := _field()
	var unit := battle.player.units[0]
	assert_eq(PlaceholderDeployment.spot_for_unit(battle, battle.player, unit).size(), unit.model_count())


func test_spot_for_a_unit_breaks_no_deployment_rule() -> void:
	var battle := _field()
	var unit := battle.player.units[0]
	var positions := PlaceholderDeployment.spot_for_unit(battle, battle.player, unit)
	assert_eq(DeploymentRules.unit_problems(battle, battle.player, unit, positions, battle.player.facing).size(), 0)


func test_spot_for_a_unit_does_not_deploy_it() -> void:
	var battle := _field()
	var unit := battle.player.units[0]
	PlaceholderDeployment.spot_for_unit(battle, battle.player, unit)
	assert_false(unit.deployed)
	assert_eq(unit.positions.size(), 0)


func test_spot_for_a_unit_keeps_clear_of_deployed_units() -> void:
	var battle := _field()
	var first := battle.player.units[0]
	var second := battle.player.units[1]
	var first_spot := PlaceholderDeployment.spot_for_unit(battle, battle.player, first)
	first.positions = first_spot
	first.deployed = true
	var second_spot := PlaceholderDeployment.spot_for_unit(battle, battle.player, second)
	assert_eq(DeploymentRules.unit_problems(battle, battle.player, second, second_spot, battle.player.facing).size(), 0)


func test_spot_for_a_unit_is_in_the_matched_play_zone() -> void:
	var battle := _field()
	var zone := DeploymentRules.unit_zone(battle, battle.player)
	var unit := battle.player.units[0]
	var positions := PlaceholderDeployment.spot_for_unit(battle, battle.player, unit)
	for i in positions.size():
		assert_true(DeploymentRules.is_wholly_within(zone, DeploymentRules.base_outline(unit.bases[i], positions[i], 0.0)))


func test_spot_for_a_unit_is_empty_when_there_is_no_room() -> void:
	var battle := _field()
	var tiny: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 1, 1)]
	assert_eq(PlaceholderDeployment.spot_for_unit(battle, battle.player, battle.player.units[0], tiny).size(), 0)


func test_spot_for_a_unit_uses_a_given_zone() -> void:
	var battle := _field()
	var zone: Array[PackedVector2Array] = [BattleKit.rect_polygon(40, 2, 15, 10)]
	var positions := PlaceholderDeployment.spot_for_unit(battle, battle.player, battle.player.units[0], zone)
	assert_gt(positions.size(), 0)
	for position in positions:
		assert_gt(position.x, 40.0)


func test_spot_for_a_unit_keeps_clear_of_battlefield_terrain() -> void:
	var battle := _field()
	var first_spot := PlaceholderDeployment.spot_for_unit(battle, battle.player, battle.player.units[0])
	var blocker := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, first_spot[0], true)
	battle.terrain.append(blocker)
	var unit := battle.player.units[0]
	var positions := PlaceholderDeployment.spot_for_unit(battle, battle.player, unit)
	assert_eq(DeploymentRules.unit_problems(battle, battle.player, unit, positions, battle.player.facing).size(), 0)
	assert_ne(positions, first_spot)


func test_spot_for_a_big_unit_still_fits() -> void:
	var battle := _field()
	var unit := BattleKit.unit("Horde", 40)
	battle.player.units.append(unit)
	var positions := PlaceholderDeployment.spot_for_unit(battle, battle.player, unit)
	assert_eq(positions.size(), 40)


# spot_for_terrain

func _terrain_field() -> Battle:
	var battle := _field()
	battle.player_territory = [BattleKit.rect_polygon(0, 0, 10, 10)] as Array[PackedVector2Array]
	return battle


func test_spot_for_terrain_has_a_position_and_rotation() -> void:
	var battle := _field()
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	var spot := PlaceholderDeployment.spot_for_terrain(battle, battle.player, feature)
	assert_true(spot.has("at"))
	assert_true(spot.has("rotation"))


func test_spot_for_terrain_breaks_no_deployment_rule() -> void:
	var battle := _field()
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	var spot := PlaceholderDeployment.spot_for_terrain(battle, battle.player, feature)
	assert_eq(DeploymentRules.terrain_problems(battle, battle.player, feature, spot.at, spot.rotation).size(), 0)


func test_spot_for_terrain_keeps_away_from_other_terrain() -> void:
	var battle := _field()
	var other := BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 2.0, Vector2(5, 11))
	battle.terrain.append(other)
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	var spot := PlaceholderDeployment.spot_for_terrain(battle, battle.player, feature)
	assert_gt(spot.at.distance_to(other.position), 8.0)


func test_spot_for_terrain_leaves_room_for_the_armys_next_feature() -> void:
	var battle := _terrain_field()
	var first := BattleKit.terrain(BattleTerrain.Kind.FACTION, 2.0, Vector2.ZERO, false)
	var second := BattleKit.terrain(BattleTerrain.Kind.FACTION, 2.0, Vector2.ZERO, false)
	battle.player.terrain.append_array([first, second])
	var spot := PlaceholderDeployment.spot_for_terrain(battle, battle.player, first)
	first.position = spot.at
	first.rotation = spot.rotation
	first.placed = true
	assert_true(PlaceholderDeployment.has_terrain_spot(battle, battle.player, second))


func test_spot_for_terrain_is_empty_when_nowhere_meets_the_rules() -> void:
	var battle := _terrain_field()
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 2.0, Vector2(5, 5)))
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	assert_true(PlaceholderDeployment.spot_for_terrain(battle, battle.player, feature).is_empty())


func test_relaxed_spot_for_terrain_goes_nearer_other_terrain() -> void:
	var battle := _terrain_field()
	var other := BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 2.0, Vector2(5, 5))
	battle.terrain.append(other)
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	var spot := PlaceholderDeployment.spot_for_terrain(battle, battle.player, feature, true)
	assert_false(spot.is_empty())


func test_relaxed_spot_for_terrain_still_keeps_off_other_terrain() -> void:
	var battle := _terrain_field()
	var other := BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 2.0, Vector2(5, 5))
	battle.terrain.append(other)
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	var spot := PlaceholderDeployment.spot_for_terrain(battle, battle.player, feature, true)
	var gap := DeploymentRules.gap_between(DeploymentRules.terrain_outline(feature, spot.at, spot.rotation),
			DeploymentRules.terrain_outline(other, other.position, other.rotation))
	assert_gt(gap, 0.0)


func test_spot_for_terrain_is_empty_when_the_feature_is_bigger_than_the_territory() -> void:
	var battle := _terrain_field()
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 20.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	assert_true(PlaceholderDeployment.spot_for_terrain(battle, battle.player, feature, true).is_empty())


func test_spot_for_terrain_puts_the_first_feature_away_from_the_middle_of_the_territory() -> void:
	var battle := _field()
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	var spot := PlaceholderDeployment.spot_for_terrain(battle, battle.player, feature)
	assert_gt(spot.at.distance_to(PlaceholderDeployment.centroid(battle.player_territory)), 3.0)


func test_spot_for_terrain_puts_the_second_feature_away_from_the_first() -> void:
	var battle := _field()
	var first := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2(5, 5))
	var second := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append_array([first, second])
	var spot := PlaceholderDeployment.spot_for_terrain(battle, battle.player, second)
	assert_gt(spot.at.distance_to(first.position), DeploymentRules.FACTION_TERRAIN_GAP + 3.0)


# first_terrain_spot and has_terrain_spot

func test_first_terrain_spot_has_a_position_and_rotation() -> void:
	var battle := _field()
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	var spot := PlaceholderDeployment.first_terrain_spot(battle, battle.player, feature)
	assert_true(spot.has("at") and spot.has("rotation"))


func test_first_terrain_spot_breaks_no_deployment_rule() -> void:
	var battle := _field()
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	var spot := PlaceholderDeployment.first_terrain_spot(battle, battle.player, feature)
	assert_eq(DeploymentRules.terrain_problems(battle, battle.player, feature, spot.at, spot.rotation).size(), 0)


func test_first_terrain_spot_is_empty_when_nowhere_meets_the_rules() -> void:
	var battle := _terrain_field()
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 2.0, Vector2(5, 5)))
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	assert_true(PlaceholderDeployment.first_terrain_spot(battle, battle.player, feature).is_empty())


func test_relaxed_first_terrain_spot_goes_where_the_rules_gap_is_not_met() -> void:
	var battle := _terrain_field()
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 2.0, Vector2(5, 5)))
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	assert_false(PlaceholderDeployment.first_terrain_spot(battle, battle.player, feature, true).is_empty())


func test_there_is_a_terrain_spot_with_room() -> void:
	var battle := _field()
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	assert_true(PlaceholderDeployment.has_terrain_spot(battle, battle.player, feature))


func test_there_is_no_terrain_spot_when_other_terrain_leaves_no_gap() -> void:
	var battle := _terrain_field()
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 2.0, Vector2(5, 5)))
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 3.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	assert_false(PlaceholderDeployment.has_terrain_spot(battle, battle.player, feature))


func test_there_is_no_terrain_spot_for_a_feature_bigger_than_the_territory() -> void:
	var battle := _terrain_field()
	var feature := BattleKit.terrain(BattleTerrain.Kind.FACTION, 20.0, Vector2.ZERO, false)
	battle.player.terrain.append(feature)
	assert_false(PlaceholderDeployment.has_terrain_spot(battle, battle.player, feature))


# space_of

func test_space_holds_placed_terrain() -> void:
	var battle := _field()
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 4.0, Vector2(20, 9)))
	assert_false(PlaceholderDeployment.space_of(battle).is_clear(Vector2(20, 9), 0.5))


func test_space_ignores_unplaced_terrain() -> void:
	var battle := _field()
	battle.player.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 4.0, Vector2(20, 9), false))
	assert_true(PlaceholderDeployment.space_of(battle).is_clear(Vector2(20, 9), 0.5))


func test_space_holds_deployed_models_of_both_armies() -> void:
	var battle := _field()
	_on_battlefield(battle.player.units[0], Vector2(10, 5))
	_on_battlefield(battle.opponent.units[0], Vector2(50, 39))
	var space := PlaceholderDeployment.space_of(battle)
	assert_false(space.is_clear(Vector2(10, 5), 0.2))
	assert_false(space.is_clear(Vector2(50, 39), 0.2))


func test_space_ignores_units_not_yet_deployed() -> void:
	var battle := _field()
	battle.player.units[0].positions = PackedVector2Array([Vector2(10, 5)])
	assert_true(PlaceholderDeployment.space_of(battle).is_clear(Vector2(10, 5), 0.2))


func test_space_ignores_units_in_reserve() -> void:
	var battle := _field()
	_on_battlefield(battle.player.units[0], Vector2(10, 5))
	battle.player.units[0].reserve = "in the clouds"
	assert_true(PlaceholderDeployment.space_of(battle).is_clear(Vector2(10, 5), 0.2))


func test_space_is_clear_away_from_everything() -> void:
	var battle := _field()
	_on_battlefield(battle.player.units[0], Vector2(10, 5))
	assert_true(PlaceholderDeployment.space_of(battle).is_clear(Vector2(40, 5), 0.5))


func test_spot_for_a_unit_keeps_clear_of_staged_units() -> void:
	var battle := _field()
	var first := battle.player.units[0]
	var second := battle.player.units[1]
	first.positions = PlaceholderDeployment.spot_for_unit(battle, battle.player, first)
	var staged: Array[BattleUnit] = [first]
	var spot := PlaceholderDeployment.spot_for_unit(battle, battle.player, second, [], staged)
	assert_eq(DeploymentRules.unit_problems(battle, battle.player, second, spot, battle.player.facing, [], staged).size(), 0)


func test_space_of_includes_the_models_of_staged_units() -> void:
	var battle := _field()
	var unit := battle.player.units[0]
	unit.positions = PlaceholderDeployment.spot_for_unit(battle, battle.player, unit)
	var staged: Array[BattleUnit] = [unit]
	assert_true(PlaceholderDeployment.space_of(battle).is_clear(unit.positions[0], 0.1))
	assert_false(PlaceholderDeployment.space_of(battle, staged).is_clear(unit.positions[0], 0.1))


func test_space_of_ignores_staged_units_that_are_deployed() -> void:
	var battle := _field()
	var unit := battle.player.units[0]
	unit.positions = PlaceholderDeployment.spot_for_unit(battle, battle.player, unit)
	unit.deployed = true
	var staged: Array[BattleUnit] = [unit]
	assert_eq(PlaceholderDeployment.space_of(battle, staged).is_clear(unit.positions[0], 0.1),
			PlaceholderDeployment.space_of(battle).is_clear(unit.positions[0], 0.1))


func test_space_of_ignores_terrain_models_can_stand_in_when_asked() -> void:
	var battle := _field()
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 4.0, Vector2(15, 11)))
	assert_false(PlaceholderDeployment.space_of(battle).is_clear(Vector2(15, 11), 0.1))
	assert_true(PlaceholderDeployment.space_of(battle, [], false).is_clear(Vector2(15, 11), 0.1))


func test_space_of_keeps_faction_terrain_when_ignoring_the_rest() -> void:
	var battle := _field()
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 4.0, Vector2(15, 11)))
	assert_false(PlaceholderDeployment.space_of(battle, [], false).is_clear(Vector2(15, 11), 0.1))


# spot_for_unit: coherency

func _coherent_spot(unit: BattleUnit) -> bool:
	var battle := BattleKit.cramped_spearhead_battle([unit] as Array[BattleUnit])
	battle.battlefield_size = Vector2(60, 44)
	battle.player_territory = [BattleKit.rect_polygon(0, 0, 60, 20)] as Array[PackedVector2Array]
	battle.opponent_territory = [BattleKit.rect_polygon(0, 24, 60, 20)] as Array[PackedVector2Array]
	var positions := PlaceholderDeployment.spot_for_unit(battle, battle.player, unit)
	return positions.size() == unit.model_count() and Coherency.is_coherent(positions, unit.bases, battle.player.facing)


func test_a_spot_for_a_mixed_base_unit_is_coherent() -> void:
	assert_true(_coherent_spot(BattleKit.mixed_unit("Hunters", [[2, 40.0], [3, 28.5], [6, 25.0]])))


func test_a_spot_for_a_big_unit_of_one_base_size_is_coherent() -> void:
	assert_true(_coherent_spot(BattleKit.unit("Big", 11, 32.0)))


# spots_for_army

func _spots(battle: Battle, units: Array[BattleUnit], staged: Array[BattleUnit] = []) -> Dictionary:
	return PlaceholderDeployment.spots_for_army(battle, battle.player, units, staged)


func _cramped() -> Battle:
	return BattleKit.cramped_spearhead_battle(BattleKit.cramped_units())


func test_the_army_spots_cover_every_unit() -> void:
	var battle := _cramped()
	var spots := _spots(battle, battle.player.units)
	for unit in battle.player.units:
		assert_eq(spots[unit].size(), unit.model_count(), unit.name)


func test_the_army_spots_pass_the_deployment_rules() -> void:
	var battle := _cramped()
	var spots := _spots(battle, battle.player.units)
	for unit in battle.player.units:
		unit.positions = spots[unit]
		unit.facing = battle.player.facing
	for unit in battle.player.units:
		var problems := DeploymentRules.unit_problems(battle, battle.player, unit, unit.positions, unit.facing, [], battle.player.units)
		assert_eq(problems.size(), 0, "%s: %s" % [unit.name, problems])


func test_the_army_spots_do_not_overlap_between_units() -> void:
	var battle := _cramped()
	var spots := _spots(battle, battle.player.units)
	var models: Array = []
	for unit in battle.player.units:
		for i in unit.model_count():
			models.append([unit.bases[i], spots[unit][i]])
	var facing := battle.player.facing
	var overlapping := 0
	for i in models.size():
		for j in range(i + 1, models.size()):
			if DeploymentRules.bases_overlap(models[i][0], models[i][1], facing, models[j][0], models[j][1], facing):
				overlapping += 1
	assert_eq(overlapping, 0)


func test_the_army_spots_leave_the_units_as_they_were() -> void:
	var battle := _cramped()
	var unit := battle.player.units[0]
	var before := PackedVector2Array([Vector2(1, 1)])
	unit.positions = before
	unit.facing = 0.123
	_spots(battle, battle.player.units)
	assert_eq(unit.positions, before)
	assert_eq(unit.facing, 0.123)


func test_the_army_spots_keep_clear_of_staged_units() -> void:
	var battle := BattleKit.cramped_spearhead_battle([BattleKit.unit("Staged", 5), BattleKit.unit("New", 5)] as Array[BattleUnit])
	var staged_unit := battle.player.units[0]
	var other := battle.player.units[1]
	staged_unit.facing = battle.player.facing
	staged_unit.positions = _spots(battle, [staged_unit] as Array[BattleUnit])[staged_unit]
	var staged: Array[BattleUnit] = [staged_unit]
	var spot: PackedVector2Array = _spots(battle, [other] as Array[BattleUnit], staged)[other]
	other.facing = battle.player.facing
	assert_eq(DeploymentRules.unit_problems(battle, battle.player, other, spot, other.facing, [], staged).size(), 0)


func test_a_cramped_zone_fits_what_spreading_out_cannot() -> void:
	var battle := _cramped()
	var staged: Array[BattleUnit] = []
	var without_room := 0
	for unit in battle.player.units:
		unit.facing = battle.player.facing
		unit.positions = PlaceholderDeployment.spot_for_unit(battle, battle.player, unit, [], staged)
		without_room += 1 if unit.positions.is_empty() else 0
		staged.append(unit)
	assert_gt(without_room, 0, "the scenario needs a zone too cramped to spread out in")
	var spots := _spots(battle, battle.player.units)
	for unit in battle.player.units:
		assert_eq(spots[unit].size(), unit.model_count(), unit.name)


func test_a_big_oval_fits_a_cramped_zone_packed_in() -> void:
	var unit := BattleKit.oval_unit("Beast", 120.0, 92.0)
	var battle := BattleKit.cramped_spearhead_battle([unit] as Array[BattleUnit])
	var spot := PlaceholderDeployment.spot_for_unit(battle, battle.player, unit, [], [], true)
	assert_eq(spot.size(), 1)


## A 6" by 4" zone, so that a search of it that finds nothing is quick.
func _small_zone() -> Array[PackedVector2Array]:
	return [BattleKit.rect_polygon(0, 0, 6, 4)] as Array[PackedVector2Array]


func test_models_packed_in_may_stand_in_terrain_that_isnt_faction_terrain() -> void:
	var unit := BattleKit.unit("Unit", 3)
	var battle := BattleKit.cramped_spearhead_battle([unit] as Array[BattleUnit])
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 20.0, Vector2(2, 2)))
	assert_false(PlaceholderDeployment.spot_for_unit(battle, battle.player, unit, _small_zone(), [], true).is_empty())


func test_models_packed_in_keep_off_faction_terrain() -> void:
	var unit := BattleKit.unit("Unit", 1)
	var battle := BattleKit.cramped_spearhead_battle([unit] as Array[BattleUnit])
	battle.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION, 20.0, Vector2(2, 2)))
	assert_true(PlaceholderDeployment.spot_for_unit(battle, battle.player, unit, _small_zone(), [], true).is_empty())
