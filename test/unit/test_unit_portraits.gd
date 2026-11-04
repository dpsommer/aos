extends GutTest
## Unit tests for the unit portrait finder (scripts/ui/common/unit_portraits.gd), against the fixture
## models in test/fixtures/models/ and the tiny portraits in test/fixtures/portraits/.

const ModelKit := preload("res://test/support/model_kit.gd")
const PORTRAITS := "res://test/fixtures/portraits"

const RED := Color.RED
const GREEN := Color.GREEN


func after_each() -> void:
	UnitPortraits.end()


func _portraits() -> UnitPortraits:
	return UnitPortraits.new(ModelKit.library(), PORTRAITS)


func _names(names: Array[String]) -> PackedStringArray:
	return PackedStringArray(names)


func _colour(texture: Texture2D) -> Color:
	return texture.get_image().get_pixel(0, 0)


# texture_for

func test_finds_a_single_model_units_portrait() -> void:
	var texture := _portraits().texture_for(_names(["Plain Guard"]))
	assert_not_null(texture)
	assert_eq(_colour(texture), RED)


func test_a_unit_with_variants_uses_the_first_variants_portrait() -> void:
	var texture := _portraits().texture_for(_names(["Twin Raiders"]))
	assert_not_null(texture)
	assert_eq(_colour(texture), GREEN)


func test_a_name_with_a_weapon_option_falls_back_to_the_name_before_with() -> void:
	var texture := _portraits().texture_for(_names(["Plain Guard with Shields"]))
	assert_not_null(texture)
	assert_eq(_colour(texture), RED)


func test_the_first_name_with_a_model_is_used() -> void:
	var texture := _portraits().texture_for(_names(["No Such Unit", "Plain Guard"]))
	assert_eq(_colour(texture), RED)


func test_no_portrait_for_a_unit_without_a_model() -> void:
	assert_null(_portraits().texture_for(_names(["No Such Unit"])))


func test_no_portrait_for_no_names() -> void:
	assert_null(_portraits().texture_for(PackedStringArray()))


func test_no_portrait_for_a_model_that_has_not_been_baked() -> void:
	assert_null(_portraits().texture_for(_names(["Test Shrine"])))


func test_no_portrait_for_a_portrait_godot_failed_to_import() -> void:
	assert_null(_portraits().texture_for(_names(["Lone Statue"])))


func test_no_portrait_when_the_root_has_no_portraits() -> void:
	var portraits := UnitPortraits.new(ModelKit.library(), "res://test/fixtures/no_such_folder")
	assert_null(portraits.texture_for(_names(["Plain Guard"])))


# portrait_path

func test_portrait_path_mirrors_the_model_path_under_the_root() -> void:
	var path := _portraits().portrait_path(ModelKit.MODELS + "/order/faction_a/plain_guard.obj")
	assert_eq(path, PORTRAITS + "/order/faction_a/plain_guard.png")


func test_portrait_path_keeps_a_variants_number() -> void:
	var path := _portraits().portrait_path(ModelKit.MODELS + "/chaos/faction_b/twin_raiders_1.obj")
	assert_eq(path, PORTRAITS + "/chaos/faction_b/twin_raiders_1.png")


func test_portrait_path_ignores_the_model_file_extension() -> void:
	var path := _portraits().portrait_path(ModelKit.MODELS + "/order/faction_a/plain_guard.glb")
	assert_eq(path, PORTRAITS + "/order/faction_a/plain_guard.png")


func test_portrait_path_is_relative_to_the_libraries_own_root() -> void:
	var portraits := UnitPortraits.new(ModelKit.textured_library(), "res://somewhere")
	assert_eq(portraits.portrait_path(ModelKit.TEXTURED + "/a/b.obj"), "res://somewhere/a/b.png")


# shared, use, end

func test_use_makes_shared_return_the_given_portraits() -> void:
	var portraits := _portraits()
	UnitPortraits.use(portraits)
	assert_same(UnitPortraits.shared(), portraits)


func test_shared_returns_the_same_portraits_each_time() -> void:
	assert_same(UnitPortraits.shared(), UnitPortraits.shared())


func test_end_stops_shared_returning_the_given_portraits() -> void:
	var portraits := _portraits()
	UnitPortraits.use(portraits)
	UnitPortraits.end()
	assert_ne(UnitPortraits.shared(), portraits)


func test_shared_looks_in_the_game_portraits_by_default() -> void:
	UnitPortraits.end()
	assert_eq(UnitPortraits.shared().root, UnitPortraits.ROOT)
