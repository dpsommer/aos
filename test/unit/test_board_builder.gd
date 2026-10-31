extends GutTest
## Unit tests for building the battlefield's board, territories and objectives
## (scripts/battle/map/board_builder.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")


func _polygons(count: int) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for i in count:
		result.append(BattleKit.rect_polygon(i * 15, 0, 10, 10))
	return result


func _meshes_of_type(root: Node, mesh_class: Variant) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D and is_instance_of(child.mesh, mesh_class):
			result.append(child)
	return result


# board

func test_board_is_as_big_as_a_matched_play_battlefield() -> void:
	var board := autofree(BoardBuilder.board(Battle.MATCHED_PLAY_BATTLEFIELD)) as MeshInstance3D
	var size := (board.mesh as BoxMesh).size
	assert_eq(Vector2(size.x, size.z), Battle.MATCHED_PLAY_BATTLEFIELD)


func test_board_is_as_big_as_a_spearhead_battlefield() -> void:
	var board := autofree(BoardBuilder.board(Battle.SPEARHEAD_BATTLEFIELD)) as MeshInstance3D
	var size := (board.mesh as BoxMesh).size
	assert_eq(Vector2(size.x, size.z), Battle.SPEARHEAD_BATTLEFIELD)


func test_board_covers_from_the_north_west_corner() -> void:
	var board := autofree(BoardBuilder.board(Vector2(30, 22))) as MeshInstance3D
	var half := (board.mesh as BoxMesh).size / 2
	assert_almost_eq(board.position.x - half.x, 0.0, 0.001)
	assert_almost_eq(board.position.z - half.z, 0.0, 0.001)


func test_board_top_is_at_ground_level() -> void:
	var board := autofree(BoardBuilder.board(Vector2(30, 22))) as MeshInstance3D
	assert_almost_eq(board.position.y + (board.mesh as BoxMesh).size.y / 2, 0.0, 0.001)


# territory

func test_territory_has_a_fill_and_an_outline_per_polygon() -> void:
	var root := autofree(BoardBuilder.territory(_polygons(2), true)) as Node3D
	assert_eq(root.get_child_count(), 4)


func test_territory_fills_are_array_meshes_with_triangles() -> void:
	var root := autofree(BoardBuilder.territory(_polygons(3), true)) as Node3D
	assert_eq(_meshes_of_type(root, ArrayMesh).size(), 6)
	var fills := 0
	for child: MeshInstance3D in _meshes_of_type(root, ArrayMesh):
		if (child.mesh as ArrayMesh).surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES:
			fills += 1
	assert_eq(fills, 3)


func test_territory_polygon_that_cannot_be_filled_is_still_outlined() -> void:
	var line: Array[PackedVector2Array] = [PackedVector2Array([Vector2(0, 0), Vector2(10, 0)])]
	var root := autofree(BoardBuilder.territory(line, false)) as Node3D
	assert_eq(root.get_child_count(), 1)


func test_territory_without_polygons_is_empty() -> void:
	var root := autofree(BoardBuilder.territory([] as Array[PackedVector2Array], true)) as Node3D
	assert_eq(root.get_child_count(), 0)


func test_each_side_has_its_own_territory_name() -> void:
	var player := autofree(BoardBuilder.territory(_polygons(1), true)) as Node3D
	var opponent := autofree(BoardBuilder.territory(_polygons(1), false)) as Node3D
	assert_ne(player.name, opponent.name)


func test_each_side_has_its_own_territory_colour() -> void:
	var player := autofree(BoardBuilder.territory(_polygons(1), true)) as Node3D
	var opponent := autofree(BoardBuilder.territory(_polygons(1), false)) as Node3D
	var a: ShaderMaterial = player.get_child(0).material_override
	var b: ShaderMaterial = opponent.get_child(0).material_override
	assert_ne(a.get_shader_parameter("stripe_color"), b.get_shader_parameter("stripe_color"))


# roads

func test_roads_have_a_fill_per_road() -> void:
	var root := autofree(BoardBuilder.roads(_polygons(2))) as Node3D
	assert_eq(root.get_child_count(), 2)


# objectives

func test_circular_objective_is_placed_at_its_position() -> void:
	var root := autofree(BoardBuilder.objective(BattleKit.feature("Obj", Vector2(12, 7)), 3.0)) as Node3D
	assert_eq(root.position, ModelPlaceholder.to_world(Vector2(12, 7)))


func test_circular_objective_zone_has_the_given_radius() -> void:
	var root := autofree(BoardBuilder.objective(BattleKit.feature("Obj", Vector2.ZERO), 3.0)) as Node3D
	var zone: MeshInstance3D = null
	for child in _meshes_of_type(root, CylinderMesh):
		if child.material_override == BoardBuilder.OBJECTIVE_ZONE:
			zone = child
	assert_not_null(zone)
	assert_eq((zone.mesh as CylinderMesh).top_radius, 3.0)


func test_rectangular_objective_zone_is_a_filled_polygon_not_a_disc() -> void:
	var feature := BattleKit.feature("Obj", Vector2(10, 10))
	feature.extent = Vector2(6, 4)
	var root := autofree(BoardBuilder.objective(feature, 3.0)) as Node3D
	var zones := 0
	for child in _meshes_of_type(root, ArrayMesh):
		if child.material_override == BoardBuilder.OBJECTIVE_ZONE:
			zones += 1
	assert_eq(zones, 1)
	for child in _meshes_of_type(root, CylinderMesh):
		assert_ne(child.material_override, BoardBuilder.OBJECTIVE_ZONE)


func test_objective_has_a_marker_and_a_label_with_its_name() -> void:
	var root := autofree(BoardBuilder.objective(BattleKit.feature("Sun Seekers", Vector2.ZERO), 3.0)) as Node3D
	var labels := root.get_children().filter(func(child: Node) -> bool: return child is Label3D)
	assert_eq(labels.size(), 1)
	assert_eq(labels[0].text, "Sun Seekers")
	var marker: MeshInstance3D = null
	for child in _meshes_of_type(root, CylinderMesh):
		if child.material_override == BoardBuilder.OBJECTIVE:
			marker = child
	assert_not_null(marker)


# shapes

func test_flat_polygon_of_a_line_is_null() -> void:
	assert_null(BoardBuilder.flat_polygon(PackedVector2Array([Vector2(0, 0), Vector2(10, 0)]), 0.0))


func test_flat_polygon_lies_at_the_given_height() -> void:
	var fill := autofree(BoardBuilder.flat_polygon(BattleKit.rect_polygon(0, 0, 4, 4), 0.5)) as MeshInstance3D
	for vertex in (fill.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		assert_eq(vertex.y, 0.5)


func test_outline_has_a_segment_per_edge() -> void:
	var line := autofree(BoardBuilder.outline(BattleKit.rect_polygon(0, 0, 4, 4), 0.0, Color.WHITE)) as MeshInstance3D
	assert_eq((line.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), 8)


func test_circle_points_are_a_radius_from_the_centre() -> void:
	for point in BoardBuilder.circle(Vector2(5, 5), 3.0, 16):
		assert_almost_eq(point.distance_to(Vector2(5, 5)), 3.0, 0.001)
