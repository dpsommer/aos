extends GutTest
## Unit tests for building the battlefield's board, territories and objectives
## (scripts/battle/map/board_builder.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
## A tiny board image (Test Realm) and a Git LFS pointer Godot fails to import (Unimported Realm).
const BOARD_FIXTURES := "res://test/fixtures/boards"
## The side's whole territory in the no_deploy tests.
const TERRITORY := Rect2(0, 0, 10, 10)


func _polygons(count: int) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for i in count:
		result.append(BattleKit.rect_polygon(i * 15, 0, 10, 10))
	return result


func _rects(rects: Array[Rect2]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for rect in rects:
		result.append(BattleKit.rect_polygon(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	return result


func _meshes_of_type(root: Node, mesh_class: Variant) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D and is_instance_of(child.mesh, mesh_class):
			result.append(child)
	return result


## [param root]'s [param mesh_class] meshes drawn with [param material].
func _meshes_with(root: Node, mesh_class: Variant, material: Material) -> Array:
	return _meshes_of_type(root, mesh_class).filter(
			func(child: MeshInstance3D) -> bool: return child.material_override == material)


## [param root]'s filled polygons: array meshes of triangles (outlines are lines).
func _fills(root: Node) -> Array:
	return _meshes_of_type(root, ArrayMesh).filter(
			func(child: MeshInstance3D) -> bool: return child.mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES)


func _labels(root: Node) -> Array[Node]:
	return root.find_children("*", "Label3D", true, false)


func _board(size := Vector2(30, 22)) -> MeshInstance3D:
	return autofree(BoardBuilder.board(size)) as MeshInstance3D


func _printed_board(size := Vector2(30, 22)) -> MeshInstance3D:
	var texture := BoardBuilder.board_print("Test Realm", BOARD_FIXTURES)
	return autofree(BoardBuilder.board(size, texture)) as MeshInstance3D


func _print_of(board: MeshInstance3D) -> MeshInstance3D:
	return board.get_node("Print") as MeshInstance3D


func _territory(polygons: Array[PackedVector2Array], is_player := true) -> Node3D:
	return autofree(BoardBuilder.territory(polygons, is_player)) as Node3D


func _objective(feature: MapFeature, radius := 3.0) -> Node3D:
	return autofree(BoardBuilder.objective(feature, radius)) as Node3D


func _named_objective() -> Node3D:
	return _objective(BattleKit.feature("Sun Seekers", Vector2.ZERO))


func _objective_name(root: Node3D) -> Label3D:
	return root.get_node(ModelPlaceholder.HOVER_LABEL) as Label3D


## The shading of [constant TERRITORY] for the deployable [param zone], labelled [param text], with
## [param blocked] areas.
func _no_deploy(zone: Array[Rect2], text := "", blocked: Array[Rect2] = []) -> Node3D:
	return autofree(BoardBuilder.no_deploy(_rects([TERRITORY]), _rects(zone), text, -PI / 2, _rects(blocked))) as Node3D


## The bounds of all of [param meshes] together.
func _bounds_of(meshes: Array) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh in meshes:
		var box: AABB = mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


# board

func test_board_is_as_big_as_a_matched_play_battlefield() -> void:
	var size := (_board(Battle.MATCHED_PLAY_BATTLEFIELD).mesh as BoxMesh).size
	assert_eq(Vector2(size.x, size.z), Battle.MATCHED_PLAY_BATTLEFIELD)


func test_board_is_as_big_as_a_spearhead_battlefield() -> void:
	var size := (_board(Battle.SPEARHEAD_BATTLEFIELD).mesh as BoxMesh).size
	assert_eq(Vector2(size.x, size.z), Battle.SPEARHEAD_BATTLEFIELD)


func test_board_covers_from_the_north_west_corner() -> void:
	var board := _board()
	var half := (board.mesh as BoxMesh).size / 2
	assert_almost_eq(board.position.x - half.x, 0.0, 0.001)
	assert_almost_eq(board.position.z - half.z, 0.0, 0.001)


func test_board_top_is_at_ground_level() -> void:
	var board := _board()
	assert_almost_eq(board.position.y + (board.mesh as BoxMesh).size.y / 2, 0.0, 0.001)


func test_board_has_no_print_without_a_texture() -> void:
	assert_null(_board().get_node_or_null("Print"))


func test_printed_board_has_a_print() -> void:
	assert_is(_printed_board().get_node_or_null("Print"), MeshInstance3D)


func test_print_is_as_big_as_the_board() -> void:
	var size := Vector2(44, 30)
	var plane := _print_of(_printed_board(size)).mesh as PlaneMesh
	assert_eq(plane.size, size)


func test_print_is_the_texture() -> void:
	var material := _print_of(_printed_board()).material_override as StandardMaterial3D
	assert_eq(material.albedo_texture, BoardBuilder.board_print("Test Realm", BOARD_FIXTURES))


func test_print_lies_just_above_the_top_of_the_board() -> void:
	var board := _printed_board()
	var height := board.position.y + _print_of(board).position.y
	assert_between(height, 0.0001, 0.1)


func test_print_is_centred_on_the_board() -> void:
	var print := _print_of(_printed_board())
	assert_eq([print.position.x, print.position.z], [0.0, 0.0])


# board_print

func test_board_print_loads_the_realms_image() -> void:
	assert_is(BoardBuilder.board_print("Test Realm", BOARD_FIXTURES), Texture2D)


func test_board_print_finds_the_image_by_slug() -> void:
	assert_not_null(BoardBuilder.board_print("test-REALM", BOARD_FIXTURES))


func test_board_print_of_an_empty_name_is_null() -> void:
	assert_null(BoardBuilder.board_print("", BOARD_FIXTURES))


func test_board_print_without_an_image_is_null() -> void:
	assert_null(BoardBuilder.board_print("Nowhere", BOARD_FIXTURES))


func test_board_print_of_an_unimported_image_is_null() -> void:
	assert_null(BoardBuilder.board_print("Unimported Realm", BOARD_FIXTURES))


func test_board_print_without_a_folder_is_null() -> void:
	assert_null(BoardBuilder.board_print("Test Realm", BOARD_FIXTURES + "/missing"))


# territory

func test_territory_has_a_fill_and_an_outline_per_polygon() -> void:
	assert_eq(_territory(_polygons(2)).get_child_count(), 4)


func test_territory_fills_are_array_meshes_with_triangles() -> void:
	var root := _territory(_polygons(3))
	assert_eq(_meshes_of_type(root, ArrayMesh).size(), 6)
	assert_eq(_fills(root).size(), 3)


func test_territory_polygon_that_cannot_be_filled_is_still_outlined() -> void:
	var line: Array[PackedVector2Array] = [PackedVector2Array([Vector2(0, 0), Vector2(10, 0)])]
	assert_eq(_territory(line, false).get_child_count(), 1)


func test_territory_without_polygons_is_empty() -> void:
	assert_eq(_territory([] as Array[PackedVector2Array]).get_child_count(), 0)


func test_each_side_has_its_own_territory_name() -> void:
	assert_ne(_territory(_polygons(1), true).name, _territory(_polygons(1), false).name)


func test_each_side_has_its_own_territory_colour() -> void:
	var player: ShaderMaterial = _fills(_territory(_polygons(1), true))[0].material_override
	var opponent: ShaderMaterial = _fills(_territory(_polygons(1), false))[0].material_override
	assert_ne(player.get_shader_parameter("stripe_color"), opponent.get_shader_parameter("stripe_color"))


# roads

func test_roads_have_a_fill_per_road() -> void:
	var root := autofree(BoardBuilder.roads(_polygons(2))) as Node3D
	assert_eq(root.get_child_count(), 2)


# objectives

func test_circular_objective_is_placed_at_its_position() -> void:
	var root := _objective(BattleKit.feature("Obj", Vector2(12, 7)))
	assert_eq(root.position, ModelPlaceholder.to_world(Vector2(12, 7)))


func test_circular_objective_zone_has_the_given_radius() -> void:
	var root := _objective(BattleKit.feature("Obj", Vector2.ZERO), 4.5)
	var zones := _meshes_with(root, CylinderMesh, BoardBuilder.OBJECTIVE_ZONE)
	assert_eq(zones.size(), 1)
	assert_eq((zones[0].mesh as CylinderMesh).top_radius, 4.5)


func test_rectangular_objective_zone_is_a_filled_polygon_not_a_disc() -> void:
	var feature := BattleKit.feature("Obj", Vector2(10, 10))
	feature.extent = Vector2(6, 4)
	var root := _objective(feature)
	assert_eq(_meshes_with(root, ArrayMesh, BoardBuilder.OBJECTIVE_ZONE).size(), 1, "a filled polygon zone")
	assert_eq(_meshes_with(root, CylinderMesh, BoardBuilder.OBJECTIVE_ZONE).size(), 0, "no disc zone")


func test_objective_has_a_label_with_its_name() -> void:
	var labels := _named_objective().get_children().filter(func(child: Node) -> bool: return child is Label3D)
	assert_eq(labels.size(), 1)
	assert_eq(labels[0].text, "Sun Seekers")


func test_objective_name_starts_hidden() -> void:
	assert_false(_objective_name(_named_objective()).visible)


func test_objective_name_is_drawn_with_a_distance_field_font() -> void:
	assert_true((_objective_name(_named_objective()).font as FontFile).multichannel_signed_distance_field)


func test_objective_has_a_marker() -> void:
	assert_eq(_meshes_with(_named_objective(), CylinderMesh, BoardBuilder.OBJECTIVE).size(), 1)


# shapes

func test_flat_polygon_of_a_line_is_null() -> void:
	assert_null(BoardBuilder.flat_polygon(PackedVector2Array([Vector2(0, 0), Vector2(10, 0)]), 0.0))


func test_flat_polygon_lies_at_the_given_height() -> void:
	var fill := autofree(BoardBuilder.flat_polygon(BattleKit.rect_polygon(0, 0, 4, 4), 0.5)) as MeshInstance3D
	var vertices: PackedVector3Array = (fill.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(vertices.size(), 4)
	for vertex in vertices:
		assert_eq(vertex.y, 0.5)


func test_outline_has_a_segment_per_edge() -> void:
	var line := autofree(BoardBuilder.outline(BattleKit.rect_polygon(0, 0, 4, 4), 0.0, Color.WHITE)) as MeshInstance3D
	assert_eq((line.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), 8)


func test_circle_points_are_a_radius_from_the_centre() -> void:
	var points := BoardBuilder.circle(Vector2(5, 5), 3.0, 16)
	assert_eq(points.size(), 16)
	for point in points:
		assert_almost_eq(point.distance_to(Vector2(5, 5)), 3.0, 0.001)


# no_deploy

func test_no_deploy_is_named_for_its_group() -> void:
	assert_eq(_no_deploy([TERRITORY]).name, &"NoDeploy")


func test_no_deploy_is_empty_when_the_whole_territory_can_be_deployed_in() -> void:
	assert_eq(_no_deploy([TERRITORY]).get_child_count(), 0)


func test_no_deploy_shades_the_part_outside_the_zone() -> void:
	assert_gt(_meshes_of_type(_no_deploy([Rect2(0, 0, 6, 10)]), ArrayMesh).size(), 0)


func test_no_deploy_shades_everything_when_there_is_no_zone() -> void:
	assert_gt(_no_deploy([]).get_child_count(), 0)


func test_no_deploy_without_territory_is_empty() -> void:
	var root := autofree(BoardBuilder.no_deploy([] as Array[PackedVector2Array], _polygons(1))) as Node3D
	assert_eq(root.get_child_count(), 0)


func test_no_deploy_shading_stays_inside_the_territory() -> void:
	var root := _no_deploy([Rect2(0, 0, 6, 10)])
	var bounds := _bounds_of(_meshes_of_type(root, ArrayMesh))
	assert_almost_eq(bounds.position.x, 6.0, 0.01)
	assert_almost_eq(bounds.end.x, 10.0, 0.01)


func test_no_deploy_without_text_has_no_labels() -> void:
	assert_eq(_labels(_no_deploy([])).size(), 0)


func test_no_deploy_without_text_is_still_shaded() -> void:
	assert_gt(_meshes_of_type(_no_deploy([]), ArrayMesh).size(), 0)


func test_no_deploy_with_text_has_a_label() -> void:
	assert_gt(_labels(_no_deploy([], "Keep out")).size(), 0)


func test_no_deploy_shades_blocked_areas_inside_the_zone() -> void:
	assert_eq(_fills(_no_deploy([TERRITORY], "", [Rect2(2, 2, 3, 3)])).size(), 1)


func test_no_deploy_blocked_shading_is_just_the_blocked_area() -> void:
	var bounds := _bounds_of(_fills(_no_deploy([TERRITORY], "", [Rect2(2, 2, 3, 3)])))
	assert_almost_eq(bounds.position.x, 2.0, 0.01)
	assert_almost_eq(bounds.end.x, 5.0, 0.01)


func test_no_deploy_blocked_area_outside_own_territory_is_not_shaded() -> void:
	assert_eq(_no_deploy([TERRITORY], "", [Rect2(20, 0, 5, 5)]).get_child_count(), 0)


func test_no_deploy_blocked_area_straddling_the_border_is_cut_to_own_territory() -> void:
	var bounds := _bounds_of(_fills(_no_deploy([TERRITORY], "", [Rect2(8, 2, 6, 3)])))
	assert_almost_eq(bounds.position.x, 8.0, 0.01)
	assert_almost_eq(bounds.end.x, 10.0, 0.01)


func test_no_deploy_overlapping_blocked_areas_are_shaded_as_one_piece() -> void:
	var root := _no_deploy([TERRITORY], "", [Rect2(1, 1, 4, 4), Rect2(3, 3, 4, 4)])
	assert_eq(_fills(root).size(), 1)


func test_no_deploy_separate_blocked_areas_are_shaded_separately() -> void:
	var root := _no_deploy([TERRITORY], "", [Rect2(0.5, 0.5, 2, 2), Rect2(6, 6, 2, 2)])
	assert_eq(_fills(root).size(), 2)


func test_no_deploy_blocked_area_overlapping_the_out_of_zone_shade_is_merged_with_it() -> void:
	var root := _no_deploy([Rect2(0, 0, 6, 10)], "", [Rect2(4, 2, 4, 3)])
	assert_eq(_fills(root).size(), 1)


func test_no_deploy_blocked_area_beside_the_out_of_zone_shade_is_a_separate_piece() -> void:
	var root := _no_deploy([Rect2(0, 0, 6, 10)], "", [Rect2(1, 1, 2, 2)])
	assert_eq(_fills(root).size(), 2)


func test_no_deploy_blocked_areas_are_labelled_when_there_is_text() -> void:
	assert_gt(_labels(_no_deploy([TERRITORY], "Keep out", [Rect2(2, 2, 3, 3)])).size(), 0)


func test_no_deploy_without_blocked_areas_shades_as_before() -> void:
	assert_eq(_no_deploy([TERRITORY], "", []).get_child_count(), 0)


func test_no_deploy_text_is_shown() -> void:
	var labels := _labels(_no_deploy([], "No deploy"))
	assert_gt(labels.size(), 0)
	for label: Label3D in labels:
		assert_true(label.visible)


func test_no_deploy_text_is_not_a_hover_label() -> void:
	var labels := _labels(_no_deploy([], "No deploy"))
	assert_gt(labels.size(), 0)
	for label in labels:
		assert_ne(label.name, ModelPlaceholder.HOVER_LABEL)


func test_no_deploy_text_is_drawn_with_a_distance_field_font() -> void:
	var labels := _labels(_no_deploy([], "No deploy"))
	assert_gt(labels.size(), 0)
	for label: Label3D in labels:
		assert_true((label.font as FontFile).multichannel_signed_distance_field)
