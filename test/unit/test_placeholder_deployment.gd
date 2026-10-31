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
	var polygons: Array[PackedVector2Array] = [BattleKit.rect_polygon(0, 0, 4, 4), BattleKit.rect_polygon(20, 0, 10, 10)]
	assert_true(PlaceholderDeployment.is_wholly_within(polygons, Vector2(25, 5), 2.0))
