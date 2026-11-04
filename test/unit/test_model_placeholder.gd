extends GutTest
## Unit tests for the placeholder models (scripts/battle/map/model_placeholder.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
const ModelKit := preload("res://test/support/model_kit.gd")

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


## How many models each of [param instances] draws, in order.
func _instance_counts(instances: Array[MultiMeshInstance3D]) -> Array:
	return instances.map(func(instance: MultiMeshInstance3D) -> int: return instance.multimesh.instance_count)


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
	var root := _built(_unit_with_positions([base, base, base] as Array[BaseSize]))
	assert_eq(_multimeshes(root).size(), 1)


func test_multimesh_has_an_instance_per_model() -> void:
	var base := BaseSize.round_base(32)
	var root := _built(_unit_with_positions([base, base, base] as Array[BaseSize]))
	assert_eq(_multimeshes(root)[0].multimesh.instance_count, 3)


func test_each_kind_of_base_makes_its_own_multimesh() -> void:
	var small := BaseSize.round_base(25)
	var big := BaseSize.round_base(50)
	var bases: Array[BaseSize] = [small, big, small, small, big]
	var counts := _instance_counts(_multimeshes(_built(_unit_with_positions(bases))))
	counts.sort()
	assert_eq(counts, [2, 3])


func test_oval_and_round_bases_are_separate_multimeshes() -> void:
	var bases: Array[BaseSize] = [BaseSize.round_base(50), BaseSize.oval(50, 25)]
	var root := _built(_unit_with_positions(bases))
	assert_eq(_multimeshes(root).size(), 2)


func test_models_without_a_base_use_a_different_mesh_to_round_bases() -> void:
	var bases: Array[BaseSize] = [BaseSize.round_base(50), BaseSize.model()]
	var root := _built(_unit_with_positions(bases))
	var meshes := _multimeshes(root).map(func(instance: MultiMeshInstance3D) -> Mesh: return instance.multimesh.mesh)
	assert_ne(meshes[0], meshes[1])


func test_unit_has_a_label_with_its_name() -> void:
	var base := BaseSize.round_base(32)
	var root := _built(_unit_with_positions([base] as Array[BaseSize]))
	var labels := root.get_children().filter(func(child: Node) -> bool: return child is Label3D)
	assert_eq(labels.size(), 1)
	assert_eq(labels[0].text, "Test Unit")


func test_unit_name_starts_hidden() -> void:
	var root := _built(_unit_with_positions([BaseSize.round_base(32)] as Array[BaseSize]))
	assert_false((root.get_node(ModelPlaceholder.HOVER_LABEL) as Label3D).visible)


func test_a_hover_label_is_hidden_and_a_plain_label_is_shown() -> void:
	var hover := ModelPlaceholder.hover_label("A", Vector3.ZERO)
	var plain := ModelPlaceholder.label("A", Vector3.ZERO)
	autofree(hover)
	autofree(plain)
	assert_false(hover.visible)
	assert_true(plain.visible)


func test_a_hover_label_is_found_by_the_hover_name() -> void:
	var hover := autofree(ModelPlaceholder.hover_label("A", Vector3.ZERO)) as Label3D
	assert_eq(hover.name, ModelPlaceholder.HOVER_LABEL)


func test_a_hover_label_shows_through_things_in_front() -> void:
	var hover := autofree(ModelPlaceholder.hover_label("A", Vector3.ZERO)) as Label3D
	assert_true(hover.no_depth_test)


func test_labels_are_drawn_with_a_distance_field_font() -> void:
	for label: Label3D in [ModelPlaceholder.label("A", Vector3.ZERO), ModelPlaceholder.hover_label("A", Vector3.ZERO)]:
		autofree(label)
		assert_true((label.font as FontFile).multichannel_signed_distance_field)


func test_label_outline_fits_in_the_fonts_distance_field() -> void:
	var label := autofree(ModelPlaceholder.label("A", Vector3.ZERO)) as Label3D
	var font := label.font as FontFile
	assert_gte(font.msdf_pixel_range, label.outline_size * 2)


func test_undeployed_unit_has_no_models_or_label() -> void:
	var unit := BattleKit.unit("U", 3)
	var root := _built(unit)
	assert_eq(root.get_child_count(), 0)


func test_models_without_positions_are_skipped() -> void:
	var base := BaseSize.round_base(32)
	var unit := _unit_with_positions([base, base, base] as Array[BaseSize])
	unit.positions.resize(2)
	var root := _built(unit)
	assert_eq(_multimeshes(root)[0].multimesh.instance_count, 2)


func test_the_two_sides_use_different_materials() -> void:
	var base := BaseSize.round_base(32)
	var unit := _unit_with_positions([base] as Array[BaseSize])
	var mine := _built(unit)
	var theirs := _built(unit, false)
	assert_ne(_multimeshes(mine)[0].material_override, _multimeshes(theirs)[0].material_override)


func test_unit_node_is_named_after_the_unit() -> void:
	var unit := BattleKit.unit("Stormcast", 1)
	assert_eq(_built(unit).name, &"Stormcast")


func test_unnamed_unit_still_has_a_node_name() -> void:
	var unit := BattleKit.unit("", 1)
	assert_false(_built(unit).name.is_empty())


# model_transform

func _mesh(model_name: String) -> Mesh:
	return ModelKit.library().meshes_for(PackedStringArray([model_name]))[0]


func _models(root: Node) -> Array[MultiMeshInstance3D]:
	var result: Array[MultiMeshInstance3D] = []
	for child in root.get_children():
		if child is MultiMeshInstance3D and child.multimesh.mesh is ArrayMesh:
			result.append(child)
	return result


## [param unit]'s models, built from [param library] (the untextured fixture models by default)
## and freed after the test.
func _built(unit: BattleUnit, is_player := true, library: ModelLibrary = ModelKit.library()) -> Node3D:
	return autofree(ModelPlaceholder.build_unit(unit, 0.0, is_player, library)) as Node3D


func _unit_named(unit_name: String, count: int, warscroll_name := "") -> BattleUnit:
	var unit := BattleKit.unit(unit_name, count)
	if not warscroll_name.is_empty():
		unit.warscroll.name = warscroll_name
	for i in count:
		unit.positions.append(Vector2(i * 3, 2))
	return unit


func test_model_lowest_point_rests_on_top_of_the_base() -> void:
	var mesh := _mesh("Lone Statue")
	var transform := ModelPlaceholder.model_transform(mesh, Vector2.ZERO, 0.0)
	assert_almost_eq((transform * mesh.get_aabb().position).y, ModelPlaceholder.BASE_HEIGHT, 0.001)


func test_model_resting_on_the_base_does_not_depend_on_its_origin_height() -> void:
	var raised := _mesh("Plain Guard")
	var sunk := _mesh("Lone Statue")
	var raised_low := ModelPlaceholder.model_transform(raised, Vector2.ZERO, 0.0) * raised.get_aabb().position
	var sunk_low := ModelPlaceholder.model_transform(sunk, Vector2.ZERO, 0.0) * sunk.get_aabb().position
	assert_almost_eq(raised_low.y, sunk_low.y, 0.001)


func test_model_stands_over_its_position() -> void:
	var transform := ModelPlaceholder.model_transform(_mesh("Lone Statue"), Vector2(12, 7), 0.0)
	assert_eq([transform.origin.x, transform.origin.z], [12.0, 7.0])


func test_model_is_not_scaled() -> void:
	var basis := ModelPlaceholder.model_transform(_mesh("Lone Statue"), Vector2.ZERO, 1.2).basis
	assert_almost_eq(basis.get_scale(), Vector3.ONE, Vector3(0.001, 0.001, 0.001))


func test_model_facing_east_has_its_front_to_the_east() -> void:
	var basis := ModelPlaceholder.model_transform(_mesh("Lone Statue"), Vector2.ZERO, 0.0).basis
	assert_almost_eq(basis * Vector3.FORWARD, Vector3.RIGHT, Vector3(0.001, 0.001, 0.001))


func test_model_facing_south_has_its_front_to_the_south() -> void:
	var basis := ModelPlaceholder.model_transform(_mesh("Lone Statue"), Vector2.ZERO, PI / 2).basis
	assert_almost_eq(basis * Vector3.FORWARD, Vector3.BACK, Vector3(0.001, 0.001, 0.001))


func test_model_facing_west_has_its_front_to_the_west() -> void:
	var basis := ModelPlaceholder.model_transform(_mesh("Lone Statue"), Vector2.ZERO, PI).basis
	assert_almost_eq(basis * Vector3.FORWARD, Vector3.LEFT, Vector3(0.001, 0.001, 0.001))


func test_model_stays_upright() -> void:
	var basis := ModelPlaceholder.model_transform(_mesh("Lone Statue"), Vector2.ZERO, 0.9).basis
	assert_almost_eq(basis * Vector3.UP, Vector3.UP, Vector3(0.001, 0.001, 0.001))


# model_names

func test_model_names_are_the_unit_name() -> void:
	var unit := BattleKit.unit("Lone Statue", 1)
	assert_eq(ModelPlaceholder.model_names(unit), PackedStringArray(["Lone Statue"]))


func test_model_names_add_the_warscroll_name_when_it_differs() -> void:
	var unit := _unit_named("Spearhead Guard", 1, "Plain Guard")
	assert_eq(ModelPlaceholder.model_names(unit), PackedStringArray(["Spearhead Guard", "Plain Guard"]))


func test_model_names_without_a_warscroll_are_just_the_unit_name() -> void:
	var unit := BattleUnit.new()
	unit.name = "Lone Statue"
	assert_eq(ModelPlaceholder.model_names(unit), PackedStringArray(["Lone Statue"]))


# build_unit with models

func test_a_unit_with_a_model_adds_a_model_multimesh() -> void:
	var root := _built(_unit_named("Lone Statue", 3))
	assert_eq(_models(root).size(), 1)


func test_the_model_multimesh_has_an_instance_per_model() -> void:
	var root := _built(_unit_named("Lone Statue", 3))
	assert_eq(_models(root)[0].multimesh.instance_count, 3)


func test_a_unit_keeps_its_bases_under_its_models() -> void:
	var root := _built(_unit_named("Lone Statue", 3))
	assert_eq(_multimeshes(root).size() - _models(root).size(), 1)


func test_the_model_is_found_by_the_warscroll_name() -> void:
	var unit := _unit_named("Spearhead Guard", 2, "Lone Statue")
	var root := _built(unit)
	assert_eq(_models(root).size(), 1)


func test_variants_get_a_multimesh_each() -> void:
	var root := _built(_unit_named("Twin Raiders", 4))
	assert_eq(_models(root).size(), 2)


func test_variants_are_dealt_to_models_in_turn() -> void:
	assert_eq(_instance_counts(_models(_built(_unit_named("Twin Raiders", 5)))), [3, 2])


func test_fewer_models_than_variants_skips_the_spare_variants() -> void:
	var root := _built(_unit_named("Twin Raiders", 1))
	assert_eq(_models(root).size(), 1)


func test_models_without_positions_get_no_model() -> void:
	var unit := _unit_named("Lone Statue", 3)
	unit.positions.resize(2)
	var root := _built(unit)
	assert_eq(_models(root)[0].multimesh.instance_count, 2)


func test_the_two_sides_use_different_model_materials() -> void:
	var unit := _unit_named("Lone Statue", 1)
	var mine := _built(unit)
	var theirs := _built(unit, false)
	assert_ne(_models(mine)[0].material_override, _models(theirs)[0].material_override)


func test_a_null_library_gives_bases_only() -> void:
	var root := _built(_unit_named("Lone Statue", 3), true, null)
	assert_eq(_models(root).size(), 0)
	assert_eq(_multimeshes(root).size(), 1)


func test_a_unit_without_a_model_gives_bases_only() -> void:
	var root := _built(_unit_named("Nobody", 3))
	assert_eq(_models(root).size(), 0)
	assert_eq(_multimeshes(root).size(), 1)


func _label(root: Node) -> Label3D:
	return root.get_children().filter(func(child: Node) -> bool: return child is Label3D)[0]


func test_the_label_floats_above_the_tallest_model() -> void:
	var root := _built(_unit_named("Twin Raiders", 2))
	var variants := ModelKit.library().meshes_for(PackedStringArray(["Twin Raiders"]))
	assert_gt(_label(root).position.y, ModelPlaceholder.BASE_HEIGHT + variants[0].get_aabb().size.y)
	assert_gt(_label(root).position.y, ModelPlaceholder.BASE_HEIGHT + variants[1].get_aabb().size.y)


func test_a_tall_model_lifts_the_label_above_that_of_a_bare_unit() -> void:
	var tall := _built(_unit_named("Twin Raiders", 2))
	var bare := _built(_unit_named("Nobody", 2))
	assert_gt(_label(tall).position.y, _label(bare).position.y)


# textured models

func test_a_textured_model_keeps_its_own_materials() -> void:
	var root := _built(_unit_named("Painted Guard", 2), true, ModelKit.textured_library())
	assert_null(_models(root)[0].material_override)


func test_a_textured_model_keeps_its_own_materials_for_the_opponent() -> void:
	var root := _built(_unit_named("Painted Guard", 2), false, ModelKit.textured_library())
	assert_null(_models(root)[0].material_override)


func test_an_untextured_model_still_gets_the_side_material() -> void:
	var root := _built(_unit_named("Lone Statue", 2))
	assert_not_null(_models(root)[0].material_override)


# update_unit (the instances' transforms and colours live in the rendering server, which a headless
# run doesn't have, so these check what the nodes can tell)

func test_update_unit_moves_the_name_label_over_the_unit() -> void:
	var unit := _unit_named("Plain Guard", 2)
	var root := _built(unit)
	unit.positions = PackedVector2Array([Vector2(40, 30), Vector2(42, 30)])
	ModelPlaceholder.update_unit(root, unit)
	var label := root.get_node("Label") as Label3D
	assert_eq([label.position.x, label.position.z], [41.0, 30.0])


func test_update_unit_keeps_the_label_height() -> void:
	var unit := _unit_named("Plain Guard", 2)
	var root := _built(unit)
	var height := (root.get_node("Label") as Label3D).position.y
	unit.positions[0] = Vector2(5, 5)
	ModelPlaceholder.update_unit(root, unit)
	assert_eq((root.get_node("Label") as Label3D).position.y, height)


func test_update_unit_ignores_models_that_lost_their_positions() -> void:
	var unit := _unit_named("Plain Guard", 3)
	var root := _built(unit)
	unit.positions.resize(2)
	ModelPlaceholder.update_unit(root, unit)
	assert_eq((root.get_node("Label") as Label3D).position.x, 1.5)


# show_rings

func _rings(root: Node3D) -> MultiMeshInstance3D:
	return root.get_node_or_null("Rings") as MultiMeshInstance3D


func test_show_rings_adds_a_ring_per_model() -> void:
	var unit := _unit_named("Plain Guard", 3)
	var root := _built(unit)
	ModelPlaceholder.show_rings(root, unit, PackedInt32Array())
	assert_eq(_rings(root).multimesh.instance_count, 3)


func test_showing_the_rings_again_keeps_one_ring_set() -> void:
	var unit := _unit_named("Plain Guard", 2)
	var root := _built(unit)
	ModelPlaceholder.show_rings(root, unit, PackedInt32Array())
	ModelPlaceholder.show_rings(root, unit, PackedInt32Array([0]))
	var sets := root.get_children().filter(func(n: Node) -> bool: return n.name == "Rings")
	assert_eq(sets.size(), 1)


func test_hiding_the_rings_removes_them() -> void:
	var unit := _unit_named("Plain Guard", 2)
	var root := _built(unit)
	ModelPlaceholder.show_rings(root, unit, PackedInt32Array())
	ModelPlaceholder.show_rings(root, unit, PackedInt32Array(), false)
	assert_null(_rings(root))


func test_hiding_rings_that_are_not_shown_does_nothing() -> void:
	var unit := _unit_named("Plain Guard", 2)
	var root := _built(unit)
	ModelPlaceholder.show_rings(root, unit, PackedInt32Array(), false)
	assert_null(_rings(root))


func test_rings_do_not_cast_shadows() -> void:
	var unit := _unit_named("Plain Guard", 2)
	var root := _built(unit)
	ModelPlaceholder.show_rings(root, unit, PackedInt32Array())
	assert_eq(_rings(root).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_rings_are_hidden_behind_models_in_front_of_them() -> void:
	var unit := _unit_named("Plain Guard", 2)
	var root := _built(unit)
	ModelPlaceholder.show_rings(root, unit, PackedInt32Array())
	assert_false((_rings(root).material_override as StandardMaterial3D).no_depth_test)


func test_showing_the_rings_for_a_smaller_unit_resizes_them() -> void:
	var unit := _unit_named("Plain Guard", 3)
	var root := _built(unit)
	ModelPlaceholder.show_rings(root, unit, PackedInt32Array())
	unit.positions.resize(2)
	ModelPlaceholder.show_rings(root, unit, PackedInt32Array())
	assert_eq(_rings(root).multimesh.instance_count, 2)


# ring_colour

func test_an_invalid_ring_differs_from_a_valid_one() -> void:
	assert_ne(ModelPlaceholder.ring_colour(false, false), ModelPlaceholder.ring_colour(true, false))


func test_an_invalid_ring_is_the_same_held_or_not() -> void:
	assert_eq(ModelPlaceholder.ring_colour(false, true), ModelPlaceholder.ring_colour(false, false))


func test_a_held_ring_differs_from_one_put_down() -> void:
	assert_ne(ModelPlaceholder.ring_colour(true, true), ModelPlaceholder.ring_colour(true, false))


func test_a_held_ring_differs_from_an_invalid_one() -> void:
	assert_ne(ModelPlaceholder.ring_colour(true, true), ModelPlaceholder.ring_colour(false, true))


# outline_mesh

func test_an_outline_mesh_has_one_surface() -> void:
	var outline := DeploymentRules.terrain_outline(BattleKit.terrain(), Vector2.ZERO, 0.0)
	assert_eq(ModelPlaceholder.outline_mesh(outline, 0.1).get_surface_count(), 1)


func test_an_outline_mesh_has_vertices_all_round_the_outline() -> void:
	var outline := DeploymentRules.terrain_outline(BattleKit.terrain(), Vector2.ZERO, 0.0)
	var arrays := ModelPlaceholder.outline_mesh(outline, 0.1).surface_get_arrays(0)
	assert_gte(arrays[Mesh.ARRAY_VERTEX].size(), outline.size() * 2)


func test_an_outline_mesh_sits_at_the_height_given() -> void:
	var outline := DeploymentRules.terrain_outline(BattleKit.terrain(), Vector2.ZERO, 0.0)
	var low := ModelPlaceholder.outline_mesh(outline, 0.1).get_aabb()
	var high := ModelPlaceholder.outline_mesh(outline, 0.6).get_aabb()
	assert_gt(high.position.y, low.position.y)


# flash_colour

func test_a_flash_starts_as_plain_red() -> void:
	assert_eq(ModelPlaceholder.flash_colour(0.0), ModelPlaceholder.ring_colour(false, false))


func test_a_flash_differs_from_plain_red_half_way_through_a_pulse() -> void:
	assert_ne(ModelPlaceholder.flash_colour(ModelPlaceholder.FLASH_PULSE / 2), ModelPlaceholder.ring_colour(false, false))


func test_a_flash_is_plain_red_again_after_each_pulse() -> void:
	var colour := ModelPlaceholder.flash_colour(ModelPlaceholder.FLASH_PULSE * 2)
	assert_true(colour.is_equal_approx(ModelPlaceholder.ring_colour(false, false)))
