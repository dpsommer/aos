extends GutTest
## Unit tests for the placeholder models (scripts/battle/map/model_placeholder.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")

const MM_PER_INCH := BaseSize.MM_PER_INCH


func _unit_with_positions(bases: Array[BaseSize]) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.name = "Test Unit"
	unit.bases = bases
	for i in bases.size():
		unit.positions.append(Vector2(i * 3, 2))
	return unit


func _multimeshes(root: Node) -> Array[MultiMeshInstance3D]:
	var result: Array[MultiMeshInstance3D] = []
	for child in root.get_children():
		if child is MultiMeshInstance3D:
			result.append(child)
	return result


# size_of

func test_round_base_is_as_wide_and_deep_as_its_diameter() -> void:
	var size := ModelPlaceholder.size_of(BaseSize.round_base(MM_PER_INCH * 2))
	assert_almost_eq(Vector2(size.x, size.z), Vector2(2, 2), Vector2(0.001, 0.001))


func test_oval_base_is_its_length_by_its_width() -> void:
	var size := ModelPlaceholder.size_of(BaseSize.oval(MM_PER_INCH * 4, MM_PER_INCH * 2))
	assert_almost_eq(Vector2(size.x, size.z), Vector2(4, 2), Vector2(0.001, 0.001))


func test_a_model_without_a_base_is_taller_than_a_base() -> void:
	assert_gt(ModelPlaceholder.size_of(BaseSize.model()).y, ModelPlaceholder.size_of(BaseSize.round_base(32)).y)


func test_a_model_without_a_base_has_a_footprint() -> void:
	var size := ModelPlaceholder.size_of(BaseSize.model())
	assert_gt(size.x, 0.0)
	assert_gt(size.z, 0.0)


# transform_of

func test_transform_stands_on_the_battlefield_at_its_inches() -> void:
	var transform := ModelPlaceholder.transform_of(BaseSize.round_base(32), Vector2(12, 7), 0.0)
	assert_eq([transform.origin.x, transform.origin.z], [12.0, 7.0])


func test_transform_rests_on_the_board() -> void:
	var base := BaseSize.round_base(32)
	var transform := ModelPlaceholder.transform_of(base, Vector2.ZERO, 0.0)
	assert_almost_eq(transform.origin.y - ModelPlaceholder.size_of(base).y / 2, 0.0, 0.001)


func test_transform_is_scaled_to_the_footprint() -> void:
	var base := BaseSize.oval(MM_PER_INCH * 4, MM_PER_INCH * 2)
	var basis := ModelPlaceholder.transform_of(base, Vector2.ZERO, 0.7).basis
	assert_almost_eq(basis.x.length(), 4.0, 0.001)
	assert_almost_eq(basis.z.length(), 2.0, 0.001)


func test_oval_facing_east_is_long_along_east() -> void:
	var basis := ModelPlaceholder.transform_of(BaseSize.oval(100, 50), Vector2.ZERO, 0.0).basis
	assert_almost_eq(basis.x.normalized(), Vector3.RIGHT, Vector3(0.001, 0.001, 0.001))


func test_oval_facing_south_is_long_along_south() -> void:
	var basis := ModelPlaceholder.transform_of(BaseSize.oval(100, 50), Vector2.ZERO, PI / 2).basis
	assert_almost_eq(basis.x.normalized(), Vector3.BACK, Vector3(0.001, 0.001, 0.001))


func test_oval_facing_west_is_long_along_west() -> void:
	var basis := ModelPlaceholder.transform_of(BaseSize.oval(100, 50), Vector2.ZERO, PI).basis
	assert_almost_eq(basis.x.normalized(), Vector3.LEFT, Vector3(0.001, 0.001, 0.001))


func test_to_world_puts_south_on_positive_z() -> void:
	assert_eq(ModelPlaceholder.to_world(Vector2(3, 4), 1.0), Vector3(3, 1, 4))


# build_unit

func test_one_kind_of_base_makes_one_multimesh() -> void:
	var base := BaseSize.round_base(32)
	var root := autofree(ModelPlaceholder.build_unit(_unit_with_positions([base, base, base] as Array[BaseSize]), 0.0, true)) as Node3D
	assert_eq(_multimeshes(root).size(), 1)


func test_multimesh_has_an_instance_per_model() -> void:
	var base := BaseSize.round_base(32)
	var root := autofree(ModelPlaceholder.build_unit(_unit_with_positions([base, base, base] as Array[BaseSize]), 0.0, true)) as Node3D
	assert_eq(_multimeshes(root)[0].multimesh.instance_count, 3)


func test_each_kind_of_base_makes_its_own_multimesh() -> void:
	var small := BaseSize.round_base(25)
	var big := BaseSize.round_base(50)
	var bases: Array[BaseSize] = [small, big, small, small, big]
	var root := autofree(ModelPlaceholder.build_unit(_unit_with_positions(bases), 0.0, true)) as Node3D
	var counts: Array[int] = []
	for instance in _multimeshes(root):
		counts.append(instance.multimesh.instance_count)
	counts.sort()
	assert_eq(counts, [2, 3] as Array[int])


func test_oval_and_round_bases_are_separate_multimeshes() -> void:
	var bases: Array[BaseSize] = [BaseSize.round_base(50), BaseSize.oval(50, 25)]
	var root := autofree(ModelPlaceholder.build_unit(_unit_with_positions(bases), 0.0, true)) as Node3D
	assert_eq(_multimeshes(root).size(), 2)


func test_models_without_a_base_use_a_different_mesh_to_round_bases() -> void:
	var bases: Array[BaseSize] = [BaseSize.round_base(50), BaseSize.model()]
	var root := autofree(ModelPlaceholder.build_unit(_unit_with_positions(bases), 0.0, true)) as Node3D
	var meshes := _multimeshes(root).map(func(instance: MultiMeshInstance3D) -> Mesh: return instance.multimesh.mesh)
	assert_ne(meshes[0], meshes[1])


func test_unit_has_a_label_with_its_name() -> void:
	var base := BaseSize.round_base(32)
	var root := autofree(ModelPlaceholder.build_unit(_unit_with_positions([base] as Array[BaseSize]), 0.0, true)) as Node3D
	var labels := root.get_children().filter(func(child: Node) -> bool: return child is Label3D)
	assert_eq(labels.size(), 1)
	assert_eq(labels[0].text, "Test Unit")


func test_undeployed_unit_has_no_models_or_label() -> void:
	var unit := BattleKit.unit("U", 3)
	var root := autofree(ModelPlaceholder.build_unit(unit, 0.0, true)) as Node3D
	assert_eq(root.get_child_count(), 0)


func test_models_without_positions_are_skipped() -> void:
	var base := BaseSize.round_base(32)
	var unit := _unit_with_positions([base, base, base] as Array[BaseSize])
	unit.positions.resize(2)
	var root := autofree(ModelPlaceholder.build_unit(unit, 0.0, true)) as Node3D
	assert_eq(_multimeshes(root)[0].multimesh.instance_count, 2)


func test_the_two_sides_use_different_materials() -> void:
	var base := BaseSize.round_base(32)
	var unit := _unit_with_positions([base] as Array[BaseSize])
	var mine := autofree(ModelPlaceholder.build_unit(unit, 0.0, true)) as Node3D
	var theirs := autofree(ModelPlaceholder.build_unit(unit, 0.0, false)) as Node3D
	assert_ne(_multimeshes(mine)[0].material_override, _multimeshes(theirs)[0].material_override)


func test_unit_node_is_named_after_the_unit() -> void:
	var unit := BattleKit.unit("Stormcast", 1)
	assert_eq(autofree(ModelPlaceholder.build_unit(unit, 0.0, true)).name, &"Stormcast")


func test_unnamed_unit_still_has_a_node_name() -> void:
	var unit := BattleKit.unit("", 1)
	assert_false(autofree(ModelPlaceholder.build_unit(unit, 0.0, true)).name.is_empty())
