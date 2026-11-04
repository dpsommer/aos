extends GutTest
## Unit tests for showing the name of what the mouse is over (scripts/battle/map/map_hover.gd).

const ABOVE := Vector3(0, 10, 0)


## A node with a box of [param size] centred on [param at], and a hover label if [param named].
func _thing(size: Vector3, at := Vector3.ZERO, named := true) -> Node3D:
	var root := Node3D.new()
	root.add_child(_box(size, at))
	if named:
		root.add_child(ModelPlaceholder.hover_label("Name", Vector3.ZERO))
	return root


func _box(size: Vector3, at := Vector3.ZERO) -> MeshInstance3D:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.position = at
	return box


## [param root] in the tree, so its children have world transforms.
func _in_tree(root: Node3D) -> Node3D:
	add_child_autofree(root)
	return root


# hit_distance

func test_a_ray_at_a_block_hits_its_near_face() -> void:
	var root := _in_tree(_thing(Vector3(2, 2, 2)))
	assert_almost_eq(MapHover.hit_distance(root, ABOVE, Vector3.DOWN), 9.0, 0.001)


func test_a_ray_beside_a_block_misses() -> void:
	var root := _in_tree(_thing(Vector3(2, 2, 2)))
	assert_eq(MapHover.hit_distance(root, ABOVE + Vector3(5, 0, 0), Vector3.DOWN), INF)


func test_a_ray_pointing_away_from_a_block_misses() -> void:
	var root := _in_tree(_thing(Vector3(2, 2, 2)))
	assert_eq(MapHover.hit_distance(root, ABOVE, Vector3.UP), INF)


func test_a_turned_block_is_hit_where_it_has_turned_to() -> void:
	var root := _thing(Vector3(6, 1, 1))
	root.rotation.y = PI / 2
	_in_tree(root)
	# Long along x unturned, so now long along z.
	assert_lt(MapHover.hit_distance(root, ABOVE + Vector3(0, 0, 2.5), Vector3.DOWN), INF)


func test_a_turned_block_is_missed_where_it_was() -> void:
	var root := _thing(Vector3(6, 1, 1))
	root.rotation.y = PI / 2
	_in_tree(root)
	assert_eq(MapHover.hit_distance(root, ABOVE + Vector3(2.5, 0, 0), Vector3.DOWN), INF)


func test_a_moved_block_is_hit_where_it_is() -> void:
	var root := _thing(Vector3(2, 2, 2))
	root.position = Vector3(20, 0, 0)
	_in_tree(root)
	assert_lt(MapHover.hit_distance(root, ABOVE + Vector3(20, 0, 0), Vector3.DOWN), INF)
	assert_eq(MapHover.hit_distance(root, ABOVE, Vector3.DOWN), INF)


func test_a_hidden_child_is_ignored() -> void:
	var root := _thing(Vector3(2, 2, 2))
	root.get_child(0).visible = false
	_in_tree(root)
	assert_eq(MapHover.hit_distance(root, ABOVE, Vector3.DOWN), INF)


func test_a_child_of_a_hidden_root_is_ignored() -> void:
	var root := _thing(Vector3(2, 2, 2))
	root.visible = false
	_in_tree(root)
	assert_eq(MapHover.hit_distance(root, ABOVE, Vector3.DOWN), INF)


func test_the_nearest_of_two_children_is_the_distance() -> void:
	var root := _thing(Vector3(2, 2, 2))
	root.add_child(_box(Vector3(2, 2, 2), Vector3(0, 4, 0)))
	_in_tree(root)
	assert_almost_eq(MapHover.hit_distance(root, ABOVE, Vector3.DOWN), 5.0, 0.001)


func test_a_mesh_less_child_is_ignored() -> void:
	var root := Node3D.new()
	root.add_child(MeshInstance3D.new())
	_in_tree(root)
	assert_eq(MapHover.hit_distance(root, ABOVE, Vector3.DOWN), INF)


func test_a_multimesh_without_indices_is_not_the_thing() -> void:
	var root := Node3D.new()
	var ring := MultiMeshInstance3D.new()
	ring.multimesh = MultiMesh.new()
	ring.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	ring.multimesh.mesh = BoxMesh.new()
	ring.multimesh.instance_count = 1
	root.add_child(ring)
	_in_tree(root)
	assert_eq(MapHover.hit_distance(root, ABOVE, Vector3.DOWN), INF)


# label_at

## A camera looking down on the middle of the board, and a hover over [param groups].
func _hover(groups: Array[Node3D]) -> MapHover:
	var camera := BattleCamera.new()
	add_child_autofree(camera)
	camera.bounds = Rect2(0, 0, 60, 44)
	camera.target = Vector3(30, 0, 22)
	camera.yaw = 0.0
	camera.distance = 40.0
	camera.pan(Vector2.ZERO)
	var hover := MapHover.new(camera, groups)
	add_child_autofree(hover)
	return hover


func _centre(hover: MapHover) -> Vector2:
	return hover.get_viewport().get_visible_rect().size / 2


## A group in the tree holding [param things], each put at the middle of the camera's view.
func _group(things: Array[Node3D]) -> Node3D:
	var group := Node3D.new()
	add_child_autofree(group)
	for thing in things:
		thing.position = Vector3(30, 0, 22)
		group.add_child(thing)
	return group


func test_the_name_of_the_thing_under_the_mouse_is_found() -> void:
	var thing := _thing(Vector3(2, 2, 2))
	var hover := _hover([_group([thing])] as Array[Node3D])
	assert_eq(hover.label_at(_centre(hover)), thing.get_node(ModelPlaceholder.HOVER_LABEL))


func test_nothing_under_the_mouse_gives_no_name() -> void:
	var hover := _hover([_group([_thing(Vector3(2, 2, 2))])] as Array[Node3D])
	assert_null(hover.label_at(Vector2(0, 0)))


func test_no_things_gives_no_name() -> void:
	var hover := _hover([_group([])] as Array[Node3D])
	assert_null(hover.label_at(_centre(hover)))


func test_the_nearer_of_two_things_wins() -> void:
	var block := _thing(Vector3(2, 4, 2), Vector3(0, 2, 0))
	var objective := _thing(Vector3(2, 0.1, 2))
	# The objective is listed first, so only distance can make the block win.
	var hover := _hover([_group([objective]), _group([block])] as Array[Node3D])
	assert_eq(hover.label_at(_centre(hover)), block.get_node(ModelPlaceholder.HOVER_LABEL))


func test_the_nearer_thing_wins_whichever_group_is_first() -> void:
	var block := _thing(Vector3(2, 4, 2), Vector3(0, 2, 0))
	var objective := _thing(Vector3(2, 0.1, 2))
	var hover := _hover([_group([block]), _group([objective])] as Array[Node3D])
	assert_eq(hover.label_at(_centre(hover)), block.get_node(ModelPlaceholder.HOVER_LABEL))


func test_an_unnamed_nearer_thing_gives_no_name_rather_than_the_one_behind() -> void:
	var block := _thing(Vector3(2, 4, 2), Vector3(0, 2, 0), false)
	var objective := _thing(Vector3(2, 0.1, 2))
	var hover := _hover([_group([block, objective])] as Array[Node3D])
	assert_null(hover.label_at(_centre(hover)))
