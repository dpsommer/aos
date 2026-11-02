extends GutTest
## Unit tests for the placeholder terrain (scripts/battle/map/terrain_placeholder.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")


func _block(root: Node3D) -> MeshInstance3D:
	return root.get_child(0)


func test_block_is_the_size_of_the_footprint() -> void:
	var feature := BattleKit.terrain(BattleTerrain.Kind.OBSCURING, 6.0)
	feature.footprint = Vector2(6, 4)
	var block := _block(autofree(TerrainPlaceholder.build(feature)))
	assert_eq([block.scale.x, block.scale.z], [6.0, 4.0])


func test_block_height_depends_on_the_kind() -> void:
	var obscuring := _block(autofree(TerrainPlaceholder.build(BattleKit.terrain(BattleTerrain.Kind.OBSCURING))))
	var area := _block(autofree(TerrainPlaceholder.build(BattleKit.terrain(BattleTerrain.Kind.AREA_OR_OBSTACLE))))
	assert_gt(obscuring.scale.y, area.scale.y)


func test_block_stands_on_the_ground() -> void:
	var block := _block(autofree(TerrainPlaceholder.build(BattleKit.terrain())))
	assert_almost_eq(block.position.y, block.scale.y / 2, 0.001)


func test_terrain_is_placed_at_its_position() -> void:
	var root := autofree(TerrainPlaceholder.build(BattleKit.terrain(BattleTerrain.Kind.AREA_OR_OBSTACLE, 4.0, Vector2(9, 5)))) as Node3D
	assert_eq(root.position, Vector3(9, 0, 5))


func test_terrain_is_turned_to_its_rotation() -> void:
	var feature := BattleKit.terrain()
	feature.rotation = 0.5
	var root := autofree(TerrainPlaceholder.build(feature)) as Node3D
	assert_almost_eq(root.rotation.y, ModelPlaceholder.yaw(0.5), 0.001)


func test_area_terrain_is_a_box() -> void:
	assert_is(_block(autofree(TerrainPlaceholder.build(BattleKit.terrain()))).mesh, BoxMesh)


func test_place_of_power_is_a_disc() -> void:
	var block := _block(autofree(TerrainPlaceholder.build(BattleKit.terrain(BattleTerrain.Kind.PLACE_OF_POWER))))
	assert_is(block.mesh, CylinderMesh)


func test_faction_terrain_on_a_round_base_is_a_disc() -> void:
	var feature := BattleTerrain.from_warscroll(BattleKit.warscroll("Shrine", 1, 60.0))
	assert_true(TerrainPlaceholder.is_round(feature))


func test_faction_terrain_without_a_base_is_a_box() -> void:
	var feature := BattleTerrain.from_warscroll(BattleKit.warscroll("Shrine", 1, 0.0))
	assert_false(TerrainPlaceholder.is_round(feature))


func test_battleplan_terrain_other_than_a_place_of_power_is_not_round() -> void:
	assert_false(TerrainPlaceholder.is_round(BattleKit.terrain(BattleTerrain.Kind.OBSCURING)))


func test_each_kind_has_its_own_material() -> void:
	var materials := {}
	for kind: BattleTerrain.Kind in [BattleTerrain.Kind.AREA_OR_OBSTACLE, BattleTerrain.Kind.OBSCURING,
			BattleTerrain.Kind.PLACE_OF_POWER, BattleTerrain.Kind.FACTION]:
		materials[TerrainPlaceholder.material_of(BattleKit.terrain(kind))] = true
	assert_eq(materials.size(), 4)


func test_small_spearhead_feature_is_lower_than_a_large_one() -> void:
	var small := BattleTerrain.from_spearhead(BattleKit.terrain_feature("A", "small"))
	var large := BattleTerrain.from_spearhead(BattleKit.terrain_feature("B", "large"))
	assert_lt(TerrainPlaceholder.height_of(small), TerrainPlaceholder.height_of(large))


func test_faction_terrain_has_a_name_label() -> void:
	var feature := BattleTerrain.from_warscroll(BattleKit.warscroll("Shrine", 1, 60.0))
	var root := autofree(TerrainPlaceholder.build(feature)) as Node3D
	var labels := root.get_children().filter(func(child: Node) -> bool: return child is Label3D)
	assert_eq(labels[0].text, "Shrine")


func test_battleplan_terrain_has_no_label() -> void:
	var root := autofree(TerrainPlaceholder.build(BattleKit.terrain(BattleTerrain.Kind.OBSCURING))) as Node3D
	assert_eq(root.get_child_count(), 1)


func test_unnamed_terrain_still_has_a_node_name() -> void:
	var feature := BattleKit.terrain()
	feature.name = ""
	assert_false(autofree(TerrainPlaceholder.build(feature)).name.is_empty())


# models

const MODELS := "res://test/fixtures/models"


func _library() -> ModelLibrary:
	return ModelLibrary.new(MODELS)


func _shrine(shrine_name := "Test Shrine") -> BattleTerrain:
	return BattleTerrain.from_warscroll(BattleKit.warscroll(shrine_name, 1, 60.0))


func test_faction_terrain_has_its_model_by_name() -> void:
	assert_not_null(TerrainPlaceholder.model_of(_shrine(), _library()))


func test_faction_terrain_falls_back_to_its_warscroll_name() -> void:
	var feature := _shrine("Lone Statue")
	feature.name = "Renamed Feature"
	assert_not_null(TerrainPlaceholder.model_of(feature, _library()))


func test_faction_terrain_without_a_model_has_none() -> void:
	assert_null(TerrainPlaceholder.model_of(_shrine("Nobody"), _library()))


func test_terrain_of_another_kind_has_no_model_even_when_one_matches() -> void:
	var feature := BattleKit.terrain(BattleTerrain.Kind.OBSCURING)
	feature.name = "Test Shrine"
	assert_null(TerrainPlaceholder.model_of(feature, _library()))


func test_no_library_means_no_model() -> void:
	assert_null(TerrainPlaceholder.model_of(_shrine(), null))


func test_a_model_replaces_the_block() -> void:
	var root := autofree(TerrainPlaceholder.build(_shrine(), _library())) as Node3D
	var instance := root.get_child(0) as MeshInstance3D
	assert_eq(instance.mesh, TerrainPlaceholder.model_of(_shrine(), _library()))


func test_a_model_is_not_stretched_to_the_footprint() -> void:
	var root := autofree(TerrainPlaceholder.build(_shrine(), _library())) as Node3D
	assert_eq((root.get_child(0) as MeshInstance3D).scale, Vector3.ONE)


func test_a_model_stands_on_the_ground() -> void:
	var root := autofree(TerrainPlaceholder.build(_shrine(), _library())) as Node3D
	var instance := root.get_child(0) as MeshInstance3D
	assert_almost_eq((instance.transform * instance.mesh.get_aabb().position).y, 0.0, 0.001)


func test_a_model_has_the_model_material() -> void:
	var root := autofree(TerrainPlaceholder.build(_shrine(), _library())) as Node3D
	assert_eq((root.get_child(0) as MeshInstance3D).material_override, TerrainPlaceholder.MODEL)


func test_a_model_has_a_name_label_above_it() -> void:
	var root := autofree(TerrainPlaceholder.build(_shrine(), _library())) as Node3D
	var label := root.get_children().filter(func(child: Node) -> bool: return child is Label3D)[0] as Label3D
	var model := root.get_child(0) as MeshInstance3D
	assert_gt(label.position.y, model.mesh.get_aabb().size.y)


func test_a_model_is_placed_at_its_position() -> void:
	var feature := _shrine()
	feature.position = Vector2(9, 5)
	var root := autofree(TerrainPlaceholder.build(feature, _library())) as Node3D
	assert_eq(root.position, Vector3(9, 0, 5))


func test_terrain_without_a_model_is_still_a_block_with_a_library() -> void:
	var root := autofree(TerrainPlaceholder.build(_shrine("Nobody"), _library())) as Node3D
	assert_is((root.get_child(0) as MeshInstance3D).mesh, CylinderMesh)


func test_a_null_library_builds_the_block() -> void:
	var root := autofree(TerrainPlaceholder.build(_shrine(), null)) as Node3D
	assert_is((root.get_child(0) as MeshInstance3D).mesh, CylinderMesh)


func test_a_textured_model_keeps_its_own_materials() -> void:
	var library := ModelLibrary.new("res://test/fixtures/models_textured")
	var root := autofree(TerrainPlaceholder.build(_shrine("Painted Guard"), library)) as Node3D
	assert_null((root.get_child(0) as MeshInstance3D).material_override)
