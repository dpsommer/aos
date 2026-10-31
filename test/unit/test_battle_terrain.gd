extends GutTest
## Unit tests for terrain features on the battlefield (scripts/battle/battle_terrain.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")


func test_battleplan_feature_is_placed_where_the_map_shows_it() -> void:
	var terrain := BattleTerrain.from_battleplan(BattleKit.feature("obscuring", Vector2(12, 7), "small"))
	assert_true(terrain.placed)
	assert_eq(terrain.position, Vector2(12, 7))


func test_battleplan_feature_kind_comes_from_its_type() -> void:
	assert_eq(BattleTerrain.from_battleplan(BattleKit.feature("obscuring", Vector2.ZERO, "small")).kind, BattleTerrain.Kind.OBSCURING)
	assert_eq(BattleTerrain.from_battleplan(BattleKit.feature("place_of_power", Vector2.ZERO, "small")).kind, BattleTerrain.Kind.PLACE_OF_POWER)


func test_battleplan_feature_footprint_is_a_square_of_its_size() -> void:
	var small := BattleTerrain.from_battleplan(BattleKit.feature("obscuring", Vector2.ZERO, "small")).footprint
	var medium := BattleTerrain.from_battleplan(BattleKit.feature("obscuring", Vector2.ZERO, "medium")).footprint
	assert_eq(small.x, small.y)
	assert_gt(medium.x, small.x)


func test_battleplan_feature_footprint_matches_the_map_width() -> void:
	var terrain := BattleTerrain.from_battleplan(BattleKit.feature("obscuring", Vector2.ZERO, "medium"))
	assert_eq(terrain.footprint.x, MapFeature.TERRAIN_WIDTHS["medium"])


func test_battleplan_feature_of_unknown_size_is_medium() -> void:
	var terrain := BattleTerrain.from_battleplan(BattleKit.feature("obscuring", Vector2.ZERO, "huge"))
	assert_eq(terrain.footprint.x, MapFeature.TERRAIN_WIDTHS["medium"])


func test_battleplan_feature_is_named_by_type() -> void:
	var terrain := BattleTerrain.from_battleplan(BattleKit.feature("obscuring", Vector2.ZERO, "small"))
	assert_eq(terrain.name, BattleTerrain.NAMES["obscuring"])


func test_battleplan_feature_of_unknown_type_is_area_terrain() -> void:
	var terrain := BattleTerrain.from_battleplan(BattleKit.feature("swamp", Vector2.ZERO, "small"))
	assert_eq([terrain.kind, terrain.name], [BattleTerrain.Kind.AREA_OR_OBSTACLE, "Swamp"])


func test_spearhead_feature_is_not_placed() -> void:
	assert_false(BattleTerrain.from_spearhead(BattleKit.terrain_feature("Wall", "small")).placed)


func test_spearhead_feature_keeps_name_and_size() -> void:
	var terrain := BattleTerrain.from_spearhead(BattleKit.terrain_feature("Wall", "small"))
	assert_eq([terrain.kind, terrain.name, terrain.size], [BattleTerrain.Kind.SPEARHEAD, "Wall", "small"])


func test_large_spearhead_feature_is_wider_than_small() -> void:
	var small := BattleTerrain.from_spearhead(BattleKit.terrain_feature("A", "small")).footprint
	var large := BattleTerrain.from_spearhead(BattleKit.terrain_feature("B", "large")).footprint
	assert_gt(large.x, small.x)


func test_spearhead_feature_footprint_matches_the_map_width() -> void:
	var terrain := BattleTerrain.from_spearhead(BattleKit.terrain_feature("A", "small"))
	assert_eq(terrain.footprint, Vector2.ONE * SpearheadTerrain.WIDTHS["small"])


func test_warscroll_terrain_is_sized_from_its_base() -> void:
	var scroll := BattleKit.warscroll("Shrine", 1, 50.8)
	var terrain := BattleTerrain.from_warscroll(scroll)
	assert_almost_eq(terrain.footprint, scroll.base_size.footprint(), Vector2(0.001, 0.001))


func test_warscroll_terrain_is_faction_terrain_and_not_placed() -> void:
	var terrain := BattleTerrain.from_warscroll(BattleKit.warscroll("Shrine", 1, 50.0))
	assert_eq([terrain.kind, terrain.placed], [BattleTerrain.Kind.FACTION, false])


func test_warscroll_terrain_keeps_its_warscroll_and_name() -> void:
	var scroll := BattleKit.warscroll("Shrine", 1, 50.0)
	var terrain := BattleTerrain.from_warscroll(scroll)
	assert_eq([terrain.warscroll, terrain.name], [scroll, "Shrine"])


func test_warscroll_terrain_without_a_base_uses_a_model_footprint() -> void:
	var terrain := BattleTerrain.from_warscroll(BattleKit.warscroll("Shrine", 1, 0.0))
	assert_eq(terrain.base.shape, BaseSize.Shape.MODEL)
	assert_eq(terrain.footprint, BaseSize.DEFAULT_MODEL_FOOTPRINT)


func test_reach_is_the_radius_around_the_footprint() -> void:
	var terrain := BattleKit.terrain()
	terrain.footprint = Vector2(6, 8)
	assert_almost_eq(terrain.reach(), 5.0, 0.001)


func test_copy_keeps_every_property() -> void:
	var terrain := BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 5.0, Vector2(3, 4))
	terrain.rotation = 1.5
	terrain.size = "small"
	var copy := terrain.copy()
	assert_eq([copy.kind, copy.name, copy.size, copy.position, copy.placed, copy.footprint, copy.rotation],
			[terrain.kind, terrain.name, terrain.size, terrain.position, terrain.placed, terrain.footprint, terrain.rotation])


func test_copy_is_a_separate_object() -> void:
	var terrain := BattleKit.terrain()
	var copy := terrain.copy()
	copy.position = Vector2(9, 9)
	assert_ne(terrain.position, copy.position)
