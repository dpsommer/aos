extends GutTest
## Unit tests for the 3D model finder (scripts/battle/map/model_library.gd), against the tiny models
## in test/fixtures/models/.

const ModelKit := preload("res://test/support/model_kit.gd")


func _names(names: Array[String]) -> PackedStringArray:
	return PackedStringArray(names)


# slug

func test_slug_is_lower_case() -> void:
	assert_eq(ModelLibrary.slug("Lone STATUE"), "lone_statue")


func test_slug_drops_apostrophes() -> void:
	assert_eq(ModelLibrary.slug("Skabbik's Plaguepack"), "skabbiks_plaguepack")


func test_slug_drops_curly_apostrophes() -> void:
	assert_eq(ModelLibrary.slug("Skabbik’s Plaguepack"), "skabbiks_plaguepack")


func test_slug_turns_a_run_of_other_characters_into_one_underscore() -> void:
	assert_eq(ModelLibrary.slug("Arkhan the Black,  Mortarch - of Sacrament"), "arkhan_the_black_mortarch_of_sacrament")


func test_slug_has_no_leading_or_trailing_underscore() -> void:
	assert_eq(ModelLibrary.slug("  Lone Statue! "), "lone_statue")


func test_slug_keeps_digits() -> void:
	assert_eq(ModelLibrary.slug("Unit 5"), "unit_5")


func test_slug_of_nothing_is_empty() -> void:
	assert_eq(ModelLibrary.slug(""), "")


# paths_for

func test_finds_a_model_in_a_nested_folder() -> void:
	var paths := ModelKit.library().paths_for(_names(["Lone Statue"]))
	assert_eq(paths.size(), 1)
	assert_true(paths[0].ends_with("lone_statue.obj"))


func test_finds_models_in_a_different_folder_to_each_other() -> void:
	var library := ModelKit.library()
	assert_true(library.has_model(_names(["Lone Statue"])))
	assert_true(library.has_model(_names(["Twin Raiders"])))


func test_matches_a_name_by_its_slug() -> void:
	assert_true(ModelKit.library().has_model(_names(["lone-statue"])))


func test_numbered_variants_are_found_in_order() -> void:
	var paths := ModelKit.library().paths_for(_names(["Twin Raiders"]))
	assert_eq(paths.size(), 2)
	assert_true(paths[0].ends_with("twin_raiders_1.obj"))
	assert_true(paths[1].ends_with("twin_raiders_2.obj"))


func test_unknown_name_has_no_paths() -> void:
	assert_true(ModelKit.library().paths_for(_names(["Nobody"])).is_empty())


func test_no_names_has_no_paths() -> void:
	assert_true(ModelKit.library().paths_for(PackedStringArray()).is_empty())


func test_empty_name_matches_nothing() -> void:
	assert_false(ModelKit.library().has_model(_names([""])))


func test_missing_root_has_no_models() -> void:
	var library := ModelLibrary.new("res://test/fixtures/models/does_not_exist")
	assert_false(library.has_model(_names(["Lone Statue"])))


func test_a_weapon_option_falls_back_to_the_unit_without_it() -> void:
	var paths := ModelKit.library().paths_for(_names(["Plain Guard with Spears"]))
	assert_eq(paths.size(), 1)
	assert_true(paths[0].ends_with("plain_guard.obj"))


func test_the_fallback_is_case_insensitive() -> void:
	assert_true(ModelKit.library().has_model(_names(["Plain Guard WITH Spears"])))


func test_an_alias_uses_the_models_of_the_name_it_gives() -> void:
	var library := ModelKit.library()
	library.aliases = {"other_raiders": "twin_raiders"}
	var paths := library.paths_for(_names(["Other Raiders"]))
	assert_eq(paths.size(), 2)
	assert_true(paths[0].ends_with("twin_raiders_1.obj"))


func test_a_name_with_its_own_model_ignores_its_alias() -> void:
	var library := ModelKit.library()
	library.aliases = {"plain_guard": "lone_statue"}
	var paths := library.paths_for(_names(["Plain Guard"]))
	assert_true(paths[0].ends_with("plain_guard.obj"))


func test_a_name_with_no_model_and_no_fallback_has_none() -> void:
	assert_false(ModelKit.library().has_model(_names(["Nobody with Spears"])))


func test_the_first_name_with_a_model_wins() -> void:
	var paths := ModelKit.library().paths_for(_names(["Plain Guard", "Lone Statue"]))
	assert_true(paths[0].ends_with("plain_guard.obj"))


func test_a_later_name_is_used_when_the_first_has_no_model() -> void:
	var paths := ModelKit.library().paths_for(_names(["Nobody", "Lone Statue"]))
	assert_true(paths[0].ends_with("lone_statue.obj"))


func test_an_earlier_names_fallback_beats_a_later_names_own_model() -> void:
	# The first name's fallback (Plain Guard) is tried before the second name's own model.
	var paths := ModelKit.library().paths_for(_names(["Plain Guard with Spears", "Lone Statue"]))
	assert_true(paths[0].ends_with("plain_guard.obj"))


# meshes_for

func test_meshes_are_loaded_for_the_paths() -> void:
	var meshes := ModelKit.library().meshes_for(_names(["Twin Raiders"]))
	assert_eq(meshes.size(), 2)
	assert_gt(meshes[0].get_aabb().size.y, 0.0)


func test_meshes_follow_the_variant_order() -> void:
	var meshes := ModelKit.library().meshes_for(_names(["Twin Raiders"]))
	assert_lt(meshes[0].get_aabb().size.y, meshes[1].get_aabb().size.y)


func test_no_model_has_no_meshes() -> void:
	assert_true(ModelKit.library().meshes_for(_names(["Nobody"])).is_empty())


func test_a_mesh_is_loaded_once() -> void:
	var library := ModelKit.library()
	var first := library.meshes_for(_names(["Lone Statue"]))
	var second := library.meshes_for(_names(["Lone Statue"]))
	assert_same(first[0], second[0])


# has_model

func test_has_model_when_any_name_has_one() -> void:
	assert_true(ModelKit.library().has_model(_names(["Nobody", "Lone Statue"])))


func test_has_no_model_when_no_name_has_one() -> void:
	assert_false(ModelKit.library().has_model(_names(["Nobody", "Nobody Else"])))


# is_textured and prepare

func _mesh_with(materials: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for material in materials:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


func test_a_mesh_with_every_surface_materialed_is_textured() -> void:
	assert_true(ModelLibrary.is_textured(_mesh_with([StandardMaterial3D.new(), StandardMaterial3D.new()])))


func test_a_mesh_with_an_unmaterialed_surface_is_not_textured() -> void:
	assert_false(ModelLibrary.is_textured(_mesh_with([StandardMaterial3D.new(), null])))


func test_a_mesh_with_no_materials_is_not_textured() -> void:
	assert_false(ModelLibrary.is_textured(_mesh_with([null])))


func test_a_mesh_with_no_surfaces_is_not_textured() -> void:
	assert_false(ModelLibrary.is_textured(ArrayMesh.new()))


func test_null_is_not_textured() -> void:
	assert_false(ModelLibrary.is_textured(null))


func test_prepare_draws_both_sides_of_each_face() -> void:
	var material := StandardMaterial3D.new()
	ModelLibrary.prepare(_mesh_with([material]))
	assert_eq(material.cull_mode, BaseMaterial3D.CULL_DISABLED)


func test_prepare_makes_a_cutout_material_alpha_scissor() -> void:
	var material := StandardMaterial3D.new()
	material.resource_name = "leaves_cutout"
	ModelLibrary.prepare(_mesh_with([material]))
	assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)


func test_prepare_leaves_other_materials_opaque() -> void:
	var material := StandardMaterial3D.new()
	material.resource_name = "stone"
	ModelLibrary.prepare(_mesh_with([material]))
	assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED)


func test_prepare_prepares_every_surface() -> void:
	var first := StandardMaterial3D.new()
	var second := StandardMaterial3D.new()
	ModelLibrary.prepare(_mesh_with([first, second]))
	assert_eq([first.cull_mode, second.cull_mode], [BaseMaterial3D.CULL_DISABLED, BaseMaterial3D.CULL_DISABLED])


func test_prepare_skips_a_surface_without_a_material() -> void:
	var material := StandardMaterial3D.new()
	ModelLibrary.prepare(_mesh_with([null, material]))
	assert_eq(material.cull_mode, BaseMaterial3D.CULL_DISABLED)


func test_prepare_ignores_a_material_that_is_not_a_base_material() -> void:
	var mesh := _mesh_with([ShaderMaterial.new()])
	ModelLibrary.prepare(mesh)
	assert_is(mesh.surface_get_material(0), ShaderMaterial)


func test_prepare_accepts_null() -> void:
	ModelLibrary.prepare(null)
	assert_engine_error_count(0)


func test_a_loaded_model_with_a_material_is_textured() -> void:
	var meshes := ModelKit.textured_library().meshes_for(PackedStringArray(["Painted Guard"]))
	assert_true(ModelLibrary.is_textured(meshes[0]))


func test_a_loaded_model_without_a_material_is_not_textured() -> void:
	var meshes := ModelKit.library().meshes_for(PackedStringArray(["Lone Statue"]))
	assert_false(ModelLibrary.is_textured(meshes[0]))


func test_meshes_are_prepared_when_loaded() -> void:
	var meshes := ModelKit.textured_library().meshes_for(PackedStringArray(["Painted Guard"]))
	var material := meshes[0].surface_get_material(0) as BaseMaterial3D
	assert_eq(material.cull_mode, BaseMaterial3D.CULL_DISABLED)


# is_imported and models that fail to import

const POINTER_MODEL := ModelKit.UNIMPORTED + "/order/faction_a/pointer_model.obj"


func test_a_file_whose_import_failed_is_not_imported() -> void:
	assert_false(ModelLibrary.is_imported(POINTER_MODEL))


func test_a_file_that_imported_is_imported() -> void:
	assert_true(ModelLibrary.is_imported(ModelKit.MODELS + "/order/faction_a/lone_statue.obj"))


func test_a_path_with_no_import_file_is_imported() -> void:
	assert_true(ModelLibrary.is_imported(ModelKit.MODELS + "/does_not_exist.tres"))


func test_a_model_that_failed_to_import_is_not_found() -> void:
	var library := ModelKit.unimported_library()
	var names := _names(["Pointer Model"])
	assert_true(library.paths_for(names).is_empty())
	assert_false(library.has_model(names))


func test_a_model_that_failed_to_import_has_no_meshes() -> void:
	var meshes := ModelKit.unimported_library().meshes_for(_names(["Pointer Model"]))
	assert_true(meshes.is_empty())
