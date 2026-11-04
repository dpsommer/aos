extends GutTest
## Unit tests for the placeholder terrain (scripts/battle/map/terrain_placeholder.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
const ModelKit := preload("res://test/support/model_kit.gd")

## How long the Long Ruin fixture model is before it's scaled.
const LONG_RUIN_LENGTH := 6.0
## How many times taller the Twin Ruin fixture's second variant is than its first.
const TWIN_RUIN_HEIGHT_RATIO := 3.0


## [param feature]'s terrain, built from [param library] (the untextured fixture models by
## default) and freed after the test.
func _built(feature: BattleTerrain, library: ModelLibrary = ModelKit.library()) -> Node3D:
	return autofree(TerrainPlaceholder.build(feature, library)) as Node3D


## The feature's block or model.
func _block(root: Node3D) -> MeshInstance3D:
	return root.get_children().filter(func(child: Node) -> bool: return child is MeshInstance3D)[0]


func _labels(root: Node3D) -> Array[Node]:
	return root.get_children().filter(func(child: Node) -> bool: return child is Label3D)


## The feature's name, for a feature that has one.
func _name_label(root: Node3D) -> Label3D:
	return _labels(root)[0] as Label3D


## [param feature]'s model from the untextured fixture models.
func _model_of(feature: BattleTerrain) -> Mesh:
	return TerrainPlaceholder.model_of(feature, ModelKit.library())


## Faction terrain on a round base, named [param shrine_name] (a fixture model by default).
func _shrine(shrine_name := "Test Shrine") -> BattleTerrain:
	return BattleTerrain.from_warscroll(BattleKit.warscroll(shrine_name, 1, 60.0))


func test_block_is_the_size_of_the_footprint() -> void:
	var feature := BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 6.0)
	feature.footprint = Vector2(6, 4)
	var block := _block(_built(feature))
	assert_eq([block.scale.x, block.scale.z], [6.0, 4.0])


func test_block_height_depends_on_the_kind() -> void:
	var obscuring := _block(_built(BattleKit.terrain(BattleTerrain.Kind.OBSCURING)))
	var area := _block(_built(BattleKit.terrain(BattleTerrain.Kind.AREA_OR_OBSTACLE)))
	assert_gt(obscuring.scale.y, area.scale.y)


func test_block_stands_on_the_ground() -> void:
	var block := _block(_built(BattleKit.terrain()))
	assert_almost_eq(block.position.y, block.scale.y / 2, 0.001)


func test_terrain_is_placed_at_its_position() -> void:
	var root := _built(BattleKit.terrain(BattleTerrain.Kind.AREA_OR_OBSTACLE, 4.0, Vector2(9, 5)))
	assert_eq(root.position, Vector3(9, 0, 5))


func test_terrain_is_turned_to_its_rotation() -> void:
	var feature := BattleKit.terrain()
	feature.rotation = 0.5
	var root := _built(feature)
	assert_almost_eq(root.rotation.y, ModelPlaceholder.yaw(0.5), 0.001)


func test_area_terrain_is_a_box() -> void:
	assert_is(_block(_built(BattleKit.terrain())).mesh, BoxMesh)


func test_place_of_power_is_a_disc() -> void:
	var block := _block(_built(BattleKit.terrain(BattleTerrain.Kind.PLACE_OF_POWER)))
	assert_is(block.mesh, CylinderMesh)


func test_faction_terrain_on_a_round_base_is_round() -> void:
	assert_true(TerrainPlaceholder.is_round(_shrine("Shrine")))


func test_faction_terrain_without_a_base_is_not_round() -> void:
	var feature := BattleTerrain.from_warscroll(BattleKit.warscroll("Shrine", 1, 0.0))
	assert_false(TerrainPlaceholder.is_round(feature))


func test_battleplan_terrain_other_than_a_place_of_power_is_not_round() -> void:
	assert_false(TerrainPlaceholder.is_round(BattleKit.terrain(BattleTerrain.Kind.OBSCURING)))


func _material(kind: BattleTerrain.Kind) -> Material:
	return TerrainPlaceholder.material_of(BattleKit.terrain(kind))


## How many different values [param values] has.
func _distinct(values: Array) -> int:
	var seen := {}
	for value: Variant in values:
		seen[value] = true
	return seen.size()


func test_each_kind_has_its_own_material() -> void:
	var materials := [_material(BattleTerrain.Kind.AREA_OR_OBSTACLE), _material(BattleTerrain.Kind.OBSCURING),
			_material(BattleTerrain.Kind.PLACE_OF_POWER), _material(BattleTerrain.Kind.FACTION)]
	assert_eq(_distinct(materials), 4)


func test_small_spearhead_feature_is_lower_than_a_large_one() -> void:
	var small := BattleTerrain.from_spearhead(BattleKit.terrain_feature("A", "small"))
	var large := BattleTerrain.from_spearhead(BattleKit.terrain_feature("B", "large"))
	assert_lt(TerrainPlaceholder.height_of(small), TerrainPlaceholder.height_of(large))


func test_faction_terrain_has_a_name_label() -> void:
	var labels := _labels(_built(_shrine("Shrine")))
	assert_eq(labels.size(), 1)
	assert_eq(labels[0].text, "Shrine")


func test_terrain_name_starts_hidden() -> void:
	assert_false(_name_label(_built(_shrine())).visible)


func test_terrain_name_is_found_by_the_hover_name() -> void:
	assert_eq(_name_label(_built(_shrine())).name, ModelPlaceholder.HOVER_LABEL)


func test_terrain_name_is_drawn_with_a_distance_field_font() -> void:
	assert_true((_name_label(_built(_shrine())).font as FontFile).multichannel_signed_distance_field)


func test_battleplan_terrain_has_no_label() -> void:
	assert_eq(_labels(_built(BattleKit.terrain(BattleTerrain.Kind.OBSCURING))).size(), 0)


func test_unnamed_terrain_still_has_a_node_name() -> void:
	var feature := BattleKit.terrain()
	feature.name = ""
	assert_false(_built(feature).name.is_empty())


# models

func test_faction_terrain_has_its_model_by_name() -> void:
	assert_not_null(_model_of(_shrine()))


func test_faction_terrain_falls_back_to_its_warscroll_name() -> void:
	var feature := _shrine("Lone Statue")
	feature.name = "Renamed Feature"
	assert_not_null(_model_of(feature))


func test_faction_terrain_without_a_model_has_none() -> void:
	assert_null(_model_of(_shrine("Nobody")))


func test_terrain_of_another_kind_has_no_model_even_when_one_matches() -> void:
	var feature := BattleKit.terrain(BattleTerrain.Kind.OBSCURING)
	feature.name = "Test Shrine"
	assert_null(_model_of(feature))


func test_no_library_means_no_model() -> void:
	assert_null(TerrainPlaceholder.model_of(_shrine(), null))


func test_a_model_replaces_the_block() -> void:
	assert_eq(_block(_built(_shrine())).mesh, _model_of(_shrine()))


func test_a_model_is_not_stretched_to_the_footprint() -> void:
	assert_eq(_block(_built(_shrine())).scale, Vector3.ONE)


func test_a_model_stands_on_the_ground() -> void:
	var instance := _block(_built(_shrine()))
	assert_almost_eq((instance.transform * instance.mesh.get_aabb().position).y, 0.0, 0.001)


func test_a_model_has_the_model_material() -> void:
	assert_eq(_block(_built(_shrine())).material_override, TerrainPlaceholder.MODEL)


func test_a_model_has_a_name_label_above_it() -> void:
	var root := _built(_shrine())
	assert_gt(_name_label(root).position.y, _block(root).mesh.get_aabb().size.y)


func test_a_model_is_placed_at_its_position() -> void:
	var feature := _shrine()
	feature.position = Vector2(9, 5)
	assert_eq(_built(feature).position, Vector3(9, 0, 5))


func test_terrain_without_a_model_is_still_a_block_with_a_library() -> void:
	assert_is(_block(_built(_shrine("Nobody"))).mesh, CylinderMesh)


func test_a_null_library_builds_the_block() -> void:
	assert_is(_block(_built(_shrine(), null)).mesh, CylinderMesh)


func test_a_textured_model_keeps_its_own_materials() -> void:
	var root := _built(_shrine("Painted Guard"), ModelKit.textured_library())
	assert_null(_block(root).material_override)


# Spearhead terrain

## A Spearhead feature named [param feature_name] with the footprint [param footprint].
func _spearhead(feature_name: String, footprint: Vector2, variant := 0) -> BattleTerrain:
	var feature := BattleTerrain.from_spearhead(BattleKit.terrain_feature(feature_name, "large"))
	feature.footprint = footprint
	feature.variant = variant
	return feature


## The fixture model with two variants, as a Spearhead feature using [param variant].
func _twin_ruin(variant: int) -> BattleTerrain:
	return _spearhead("Twin Ruin", Vector2(6, 3), variant)


## The bounds of the fixture model [constant LONG_RUIN_LENGTH] long, fitted to [param footprint].
func _long_ruin_bounds(footprint: Vector2) -> AABB:
	return _bounds(_built(_spearhead("Long Ruin", footprint)))


## The built model's bounds in the feature's frame, after its instance's transform.
func _bounds(root: Node3D) -> AABB:
	var instance := _block(root)
	return instance.transform * instance.mesh.get_aabb()


func test_spearhead_feature_has_its_model_by_name() -> void:
	assert_not_null(_model_of(_spearhead("Long Ruin", Vector2(6, 3))))


func test_spearhead_feature_without_a_model_has_none() -> void:
	assert_null(_model_of(_spearhead("Nobody", Vector2(6, 3))))


func test_spearhead_feature_uses_the_variant_for_its_model() -> void:
	assert_ne(_model_of(_twin_ruin(0)), _model_of(_twin_ruin(1)))


func test_spearhead_variant_wraps_around_the_models() -> void:
	assert_same(_model_of(_twin_ruin(0)), _model_of(_twin_ruin(2)))


func test_spearhead_negative_variant_wraps_around_the_models() -> void:
	assert_same(_model_of(_twin_ruin(1)), _model_of(_twin_ruin(-1)))


func test_spearhead_model_is_drawn_for_the_variant() -> void:
	var feature := _spearhead("Twin Ruin", Vector2(20, 20), 1)
	assert_eq(_block(_built(feature)).mesh, _model_of(feature))


func test_spearhead_model_has_the_models_height_ratio_when_scaled() -> void:
	var tall := _bounds(_built(_spearhead("Twin Ruin", Vector2(2, 2), 1)))
	var short := _bounds(_built(_spearhead("Twin Ruin", Vector2(2, 2), 0)))
	assert_almost_eq(tall.size.y / short.size.y, TWIN_RUIN_HEIGHT_RATIO, 0.001)


func test_spearhead_model_fits_inside_the_footprint() -> void:
	var bounds := _long_ruin_bounds(Vector2(5, 2))
	assert_lte(bounds.size.x, 5.0 + 0.001)
	assert_lte(bounds.size.z, 2.0 + 0.001)


func test_spearhead_model_long_along_z_is_laid_along_x() -> void:
	var bounds := _long_ruin_bounds(Vector2(20, 20))
	assert_gt(bounds.size.x, bounds.size.z)


func test_spearhead_model_fills_a_footprint_its_length_limits() -> void:
	assert_almost_eq(_long_ruin_bounds(Vector2(6, 20)).size.x, 6.0, 0.001)


func test_spearhead_model_fills_a_footprint_its_width_limits() -> void:
	assert_almost_eq(_long_ruin_bounds(Vector2(20, 1)).size.z, 1.0, 0.001)


func test_spearhead_model_keeps_its_proportions() -> void:
	var small := _long_ruin_bounds(Vector2(3, 3))
	var large := _long_ruin_bounds(Vector2(12, 12))
	assert_almost_eq(large.size.x / small.size.x, large.size.y / small.size.y, 0.001)
	assert_almost_eq(large.size.x / small.size.x, large.size.z / small.size.z, 0.001)


func test_spearhead_model_can_be_scaled_up() -> void:
	assert_gt(_long_ruin_bounds(Vector2(60, 60)).size.x, LONG_RUIN_LENGTH)


func test_spearhead_model_stands_on_the_ground() -> void:
	assert_almost_eq(_long_ruin_bounds(Vector2(5, 2)).position.y, 0.0, 0.001)


func test_spearhead_model_is_centred_on_the_feature() -> void:
	var bounds := _long_ruin_bounds(Vector2(5, 2))
	assert_almost_eq(bounds.get_center().x, 0.0, 0.001)
	assert_almost_eq(bounds.get_center().z, 0.0, 0.001)


func test_spearhead_label_floats_above_the_scaled_model() -> void:
	var root := _built(_spearhead("Long Ruin", Vector2(5, 2)))
	assert_gt(_name_label(root).position.y, _bounds(root).end.y)


func test_spearhead_label_rises_as_far_as_the_model_does_when_scaled() -> void:
	var small := _built(_spearhead("Long Ruin", Vector2(5, 2)))
	var large := _built(_spearhead("Long Ruin", Vector2(60, 60)))
	var label_rise := _name_label(large).position.y - _name_label(small).position.y
	assert_almost_eq(label_rise, _bounds(large).end.y - _bounds(small).end.y, 0.001)


func test_spearhead_feature_without_a_model_is_a_block_its_footprint_across() -> void:
	var block := _block(_built(_spearhead("Nobody", Vector2(6, 3))))
	assert_eq([block.scale.x, block.scale.z], [6.0, 3.0])


func test_spearhead_model_with_an_empty_footprint_is_not_scaled() -> void:
	var instance := _block(_built(_spearhead("Long Ruin", Vector2.ZERO)))
	assert_almost_eq(instance.scale.x, 1.0, 0.001)


func test_faction_model_is_not_fitted_to_its_footprint() -> void:
	var feature := _shrine()
	feature.footprint = Vector2(50, 50)
	assert_eq(_block(_built(feature)).scale, Vector3.ONE)
