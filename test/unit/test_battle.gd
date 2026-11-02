extends GutTest
## Unit tests for a battle's roles and territories (scripts/battle/battle.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")


## A Matched Play battle from a battleplan, before the roll-off.
func _matched() -> Battle:
	var battle := Battle.new()
	battle.mode = BattleSetup.Mode.MATCHED_PLAY
	battle.battlefield_size = Vector2(60, 44)
	battle.battleplan = BattleKit.battleplan("Plan")
	battle.player = BattleKit.army("Player Unit")
	battle.opponent = BattleKit.army("Opponent Unit")
	return battle


## A Spearhead battle from a battlepack, before the roll-off and the deployment map.
func _spearhead() -> Battle:
	var battle := Battle.new()
	battle.mode = BattleSetup.Mode.SPEARHEAD
	battle.battlefield_size = Vector2(30, 22)
	battle.battlepack = BattleKit.spearhead_pack("Pack", ["Aqshy"] as Array[String])
	battle.player = BattleKit.army("Player Unit")
	battle.opponent = BattleKit.army("Opponent Unit")
	return battle


func _names(terrain: Array[BattleTerrain]) -> Array[String]:
	var result: Array[String] = []
	for feature in terrain:
		result.append(feature.name)
	return result


func _first_y(polygons: Array[PackedVector2Array]) -> float:
	return polygons[0][0].y


# assign_roles in Matched Play

func test_matched_play_attacker_takes_the_attacker_territory() -> void:
	var battle := _matched()
	battle.assign_roles(true)
	assert_eq(_first_y(battle.player_territory), 0.0)
	assert_gt(_first_y(battle.opponent_territory), 20.0)


func test_matched_play_defender_takes_the_defender_territory() -> void:
	var battle := _matched()
	battle.assign_roles(false)
	assert_gt(_first_y(battle.player_territory), 20.0)
	assert_eq(_first_y(battle.opponent_territory), 0.0)


func test_matched_play_roles_are_marked_assigned() -> void:
	var battle := _matched()
	battle.assign_roles(false)
	assert_true(battle.roles_assigned)
	assert_false(battle.player_is_attacker)


func test_matched_play_territories_merge_touching_rects() -> void:
	var battle := _matched()
	battle.assign_roles(true)
	assert_eq(battle.opponent_territory.size(), 1)


func test_matched_play_roles_give_both_sides_territory() -> void:
	var battle := _matched()
	assert_false(battle.has_territories())
	battle.assign_roles(true)
	assert_true(battle.has_territories())


func test_matched_play_roles_turn_the_armies_to_face_each_other() -> void:
	var battle := _matched()
	battle.assign_roles(true)
	assert_gt(sin(battle.player.facing), 0.9)
	assert_lt(sin(battle.opponent.facing), -0.9)


func test_matched_play_roles_leave_terrain_alone() -> void:
	var battle := _matched()
	battle.player.terrain.append(BattleKit.terrain(BattleTerrain.Kind.FACTION))
	battle.assign_roles(true)
	assert_eq(battle.player.terrain.size(), 1)


# assign_roles in Spearhead

func test_spearhead_attacker_takes_the_second_terrain_group() -> void:
	var battle := _spearhead()
	battle.assign_roles(true)
	assert_eq(_names(battle.player.terrain), ["Ruin", "Tower"] as Array[String])
	assert_eq(_names(battle.opponent.terrain), ["Wall"] as Array[String])


func test_spearhead_defender_takes_the_first_terrain_group() -> void:
	var battle := _spearhead()
	battle.assign_roles(false)
	assert_eq(_names(battle.player.terrain), ["Wall"] as Array[String])
	assert_eq(_names(battle.opponent.terrain), ["Ruin", "Tower"] as Array[String])


func test_spearhead_roles_do_not_set_territories_before_the_map_is_chosen() -> void:
	var battle := _spearhead()
	battle.assign_roles(true)
	assert_false(battle.has_territories())


func test_spearhead_terrain_features_are_not_placed_yet() -> void:
	var battle := _spearhead()
	battle.assign_roles(true)
	for feature in battle.player.terrain:
		assert_false(feature.placed)


func test_assigning_roles_without_a_plan_or_pack_only_records_them() -> void:
	var battle := BattleKit.battle()
	battle.roles_assigned = false
	battle.assign_roles(false)
	assert_true(battle.roles_assigned)
	assert_false(battle.player_is_attacker)
	assert_true(battle.has_territories())


# choose_deployment

func test_choosing_a_map_gives_the_player_territory_a() -> void:
	var battle := _spearhead()
	var map := BattleKit.deployment("Map")
	battle.choose_deployment(map, true)
	assert_eq(battle.player_territory, [map.territory_a] as Array[PackedVector2Array])
	assert_eq(battle.opponent_territory, [map.territory_b] as Array[PackedVector2Array])


func test_choosing_a_map_can_give_the_player_territory_b() -> void:
	var battle := _spearhead()
	var map := BattleKit.deployment("Map")
	battle.choose_deployment(map, false)
	assert_eq(battle.player_territory, [map.territory_b] as Array[PackedVector2Array])


func test_choosing_a_map_records_it_and_gives_both_sides_territory() -> void:
	var battle := _spearhead()
	var map := BattleKit.deployment("Map")
	battle.choose_deployment(map, true)
	assert_same(battle.deployment, map)
	assert_true(battle.has_territories())


func test_choosing_a_map_faces_the_armies_at_each_other() -> void:
	var battle := _spearhead()
	battle.choose_deployment(BattleKit.deployment("Map"), true)
	assert_gt(cos(battle.player.facing), 0.9)
	assert_lt(cos(battle.opponent.facing), -0.9)


# face_armies

func test_face_armies_turns_undeployed_units_with_their_army() -> void:
	var battle := BattleKit.battle()
	battle.player.units[0].facing = 3.0
	battle.face_armies()
	assert_eq(battle.player.units[0].facing, battle.player.facing)


func test_face_armies_leaves_deployed_units_as_they_stand() -> void:
	var battle := BattleKit.battle()
	battle.player.units[0].deployed = true
	battle.player.units[0].facing = 3.0
	battle.face_armies()
	assert_eq(battle.player.units[0].facing, 3.0)


func test_face_armies_copes_with_one_territory_on_top_of_the_other() -> void:
	var battle := BattleKit.battle()
	battle.opponent_territory = battle.player_territory
	battle.face_armies()
	assert_false(is_nan(battle.player.facing))


# has_territories

func test_a_battle_without_territory_has_none() -> void:
	assert_false(Battle.new().has_territories())


func test_one_territory_is_not_enough() -> void:
	var battle := BattleKit.battle()
	battle.opponent_territory = [] as Array[PackedVector2Array]
	assert_false(battle.has_territories())


# roles

func test_the_attacker_is_the_player_when_the_player_attacks() -> void:
	var battle := BattleKit.battle()
	assert_same(battle.attacker(), battle.player)
	assert_same(battle.defender(), battle.opponent)


func test_the_attacker_is_the_opponent_otherwise() -> void:
	var battle := BattleKit.battle()
	battle.player_is_attacker = false
	assert_same(battle.attacker(), battle.opponent)
	assert_same(battle.defender(), battle.player)


func test_enemy_of_is_the_other_army() -> void:
	var battle := BattleKit.battle()
	assert_same(battle.enemy_of(battle.player), battle.opponent)
	assert_same(battle.enemy_of(battle.opponent), battle.player)


func test_territory_of_each_army_is_its_own() -> void:
	var battle := BattleKit.battle()
	assert_eq(battle.territory_of(battle.player), battle.player_territory)
	assert_eq(battle.territory_of(battle.opponent), battle.opponent_territory)


func test_enemy_territory_of_each_army_is_the_others() -> void:
	var battle := BattleKit.battle()
	assert_eq(battle.enemy_territory_of(battle.player), battle.opponent_territory)
	assert_eq(battle.enemy_territory_of(battle.opponent), battle.player_territory)
