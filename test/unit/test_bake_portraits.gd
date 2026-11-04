extends GutTest
## Unit tests for the pure helpers of the portrait baking tool (tools/portraits/bake_portraits.gd).

const Bake := preload("res://tools/portraits/bake_portraits.gd")


# framing

func test_framing_is_as_wide_as_a_model_of_middling_width() -> void:
	assert_almost_eq(Bake.framing(AABB(Vector3.ZERO, Vector3(6, 10, 1))).size, 6.0, 0.0001)


func test_framing_zooms_in_on_the_top_half_of_a_narrow_model() -> void:
	assert_almost_eq(Bake.framing(AABB(Vector3.ZERO, Vector3(1, 10, 1))).size, 5.0, 0.0001)


func test_framing_cuts_off_the_sides_of_a_wide_model() -> void:
	assert_almost_eq(Bake.framing(AABB(Vector3.ZERO, Vector3(20, 10, 1))).size, 7.5, 0.0001)


func test_framing_leaves_out_the_bottom_quarter_where_the_base_is() -> void:
	for width in [1, 6, 20]:
		var framing := Bake.framing(AABB(Vector3.ZERO, Vector3(width, 10, 1)))
		assert_gt(framing.center.y - framing.size / 2.0, 2.5, "width %d" % width)


func test_framing_keeps_the_top_of_the_model_in_view() -> void:
	for width in [1, 6, 20]:
		var framing := Bake.framing(AABB(Vector3(0, 2, 0), Vector3(width, 10, 1)))
		assert_gt(framing.center.y + framing.size / 2.0, 12.0, "width %d" % width)


func test_framing_is_centred_across_the_model() -> void:
	var framing := Bake.framing(AABB(Vector3(2, 4, 6), Vector3(2, 2, 2)))
	assert_eq(framing.center.x, 3.0)
	assert_eq(framing.center.z, 7.0)


func test_framing_ignores_depth() -> void:
	var shallow: float = Bake.framing(AABB(Vector3.ZERO, Vector3(2, 3, 1))).size
	var deep: float = Bake.framing(AABB(Vector3.ZERO, Vector3(2, 3, 100))).size
	assert_almost_eq(shallow, deep, 0.0001)


func test_framing_grows_with_the_model() -> void:
	var small: float = Bake.framing(AABB(Vector3.ZERO, Vector3(1, 1, 1))).size
	var big: float = Bake.framing(AABB(Vector3.ZERO, Vector3(2, 2, 2))).size
	assert_almost_eq(big, small * 2.0, 0.0001)


# framing with a head

func _head(top: float, width: float, x := 0.0) -> Dictionary:
	return {"top": top, "x": x, "width": width}


func test_framing_with_a_head_is_centred_on_the_head() -> void:
	var framing := Bake.framing(AABB(Vector3.ZERO, Vector3(20, 10, 1)), _head(8.0, 5.0, 3.0))
	assert_almost_eq(framing.center.x, 3.0, 0.0001)


func test_framing_with_a_head_is_as_wide_as_the_head_when_that_is_middling() -> void:
	var framing := Bake.framing(AABB(Vector3.ZERO, Vector3(20, 10, 1)), _head(8.0, 5.0))
	assert_almost_eq(framing.size, 5.0, 0.0001)


func test_framing_with_a_head_shows_at_least_half_the_height_below_the_head() -> void:
	var framing := Bake.framing(AABB(Vector3.ZERO, Vector3(20, 10, 1)), _head(8.0, 0.5))
	assert_almost_eq(framing.size, 8.0 * 0.5, 0.0001)


func test_framing_with_a_head_shows_at_most_three_quarters_of_the_height_below_the_head() -> void:
	var framing := Bake.framing(AABB(Vector3.ZERO, Vector3(20, 10, 1)), _head(8.0, 50.0))
	assert_almost_eq(framing.size, 8.0 * 0.75, 0.0001)


func test_framing_with_a_head_measures_the_height_from_the_bottom_of_the_bounds() -> void:
	var low := Bake.framing(AABB(Vector3.ZERO, Vector3(20, 100, 1)), _head(40.0, 500.0))
	var raised := Bake.framing(AABB(Vector3(0, 20, 0), Vector3(20, 80, 1)), _head(40.0, 500.0))
	assert_almost_eq(raised.size, low.size / 2.0, 0.0001)


func test_framing_with_a_head_puts_the_head_in_the_top_fifth_when_parts_rise_far_above_it() -> void:
	var framing := Bake.framing(AABB(Vector3.ZERO, Vector3(20, 100, 1)), _head(40.0, 20.0))
	var view_top: float = framing.center.y + framing.size / 2.0
	assert_gte(view_top, 40.0, "the head is in view")
	assert_lte(view_top - 40.0, framing.size * 0.2, "the head is in the top fifth")


func test_framing_with_a_head_does_not_leave_much_room_above_a_model_with_nothing_above_the_head() -> void:
	var framing := Bake.framing(AABB(Vector3.ZERO, Vector3(20, 10, 1)), _head(9.0, 5.0))
	var view_top: float = framing.center.y + framing.size / 2.0
	assert_lte(view_top, 10.0 + framing.size * 0.1)


func test_framing_with_a_head_keeps_the_bottom_of_the_view_above_the_bounds() -> void:
	for width in [0.5, 5.0, 50.0]:
		for height in [10.0, 100.0]:
			var bounds := AABB(Vector3(0, 2, 0), Vector3(20, height, 1))
			var framing := Bake.framing(bounds, _head(2.0 + height * 0.8, width))
			assert_gte(framing.center.y - framing.size / 2.0, 2.0, "width %s height %s" % [width, height])


# silhouette_framing

func test_silhouette_framing_is_centred_on_the_bounds() -> void:
	var framing := Bake.silhouette_framing(AABB(Vector3(2, 4, 6), Vector3(4, 10, 8)))
	assert_almost_eq(framing.center.x, 4.0, 0.0001)
	assert_almost_eq(framing.center.y, 9.0, 0.0001)


func test_silhouette_framing_is_as_big_as_the_height_of_a_tall_model() -> void:
	assert_almost_eq(Bake.silhouette_framing(AABB(Vector3.ZERO, Vector3(4, 10, 1))).size, 10.0, 0.0001)


func test_silhouette_framing_is_as_big_as_the_width_of_a_wide_model() -> void:
	assert_almost_eq(Bake.silhouette_framing(AABB(Vector3.ZERO, Vector3(14, 10, 1))).size, 14.0, 0.0001)


func test_silhouette_framing_ignores_depth() -> void:
	var shallow: float = Bake.silhouette_framing(AABB(Vector3.ZERO, Vector3(4, 10, 1))).size
	var deep: float = Bake.silhouette_framing(AABB(Vector3.ZERO, Vector3(4, 10, 100))).size
	assert_almost_eq(shallow, deep, 0.0001)


# find_head
# The bounds are 128 square, so a pixel of the probe is one world unit. The picture's column c is at
# world x = 64 - (c + 0.5), as its right is the model's -X, and its row r is at y = 128 - r.

const BODY_DEPTH := 100
const BACK_DEPTH := 200

var _bounds := AABB(Vector3(-64, 0, -5), Vector3(128, 128, 10))


func _blank(size := 128) -> Image:
	return Image.create_empty(size, size, false, Image.FORMAT_RGBA8)


## Fills [param rect], given in 128 pixel units, with a model of [param depth] (0 to 255), scaled up for a bigger image.
func _paint(image: Image, rect: Rect2i, depth := BODY_DEPTH) -> void:
	var scale := image.get_width() / 128
	var scaled := Rect2i(rect.position * scale, rect.size * scale)
	image.fill_rect(scaled, Color8(depth, 0, 0, 255))


## A body 40 wide from row 60 down, with a head 20 wide on top of it from row 20, [param shift] columns to the right.
func _person(shift := 0, size := 128) -> Image:
	var image := _blank(size)
	_paint(image, Rect2i(44 + shift, 60, 40, 68))
	_paint(image, Rect2i(54 + shift, 20, 20, 40))
	return image


func test_find_head_finds_the_top_of_the_head() -> void:
	var head := Bake.find_head(_bounds, _person())
	assert_almost_eq(head.top, 128.0 - 20.0, 1.5)


func test_find_head_ignores_a_thin_spear_above_the_head() -> void:
	var image := _person()
	_paint(image, Rect2i(63, 2, 2, 18))
	assert_almost_eq(Bake.find_head(_bounds, image).top, 128.0 - 20.0, 1.5)


func test_find_head_ignores_a_pack_behind_the_body_rising_above_the_head() -> void:
	var image := _blank()
	_paint(image, Rect2i(44, 10, 40, 50), BACK_DEPTH)
	_paint(image, Rect2i(44, 60, 40, 68))
	_paint(image, Rect2i(54, 20, 20, 40))
	assert_almost_eq(Bake.find_head(_bounds, image).top, 128.0 - 20.0, 1.5)


func test_find_head_ignores_a_wide_weapon_far_to_one_side_rising_above_the_head() -> void:
	var image := _person()
	_paint(image, Rect2i(108, 5, 6, 66))
	assert_almost_eq(Bake.find_head(_bounds, image).top, 128.0 - 20.0, 1.5)


func test_find_head_puts_a_centred_body_in_the_middle() -> void:
	assert_almost_eq(Bake.find_head(_bounds, _person()).x, 0.0, 2.0)


func test_find_head_puts_a_body_on_the_left_of_the_picture_at_positive_x() -> void:
	var head := Bake.find_head(_bounds, _person(-34))
	# The body's middle is column 30, which is at x = 33.5.
	assert_gt(head.x, 0.0)
	assert_almost_eq(head.x, 33.5, 3.0)


func test_find_head_puts_a_body_on_the_right_of_the_picture_at_negative_x() -> void:
	var head := Bake.find_head(_bounds, _person(34))
	assert_lt(head.x, 0.0)
	assert_almost_eq(head.x, -34.5, 3.0)


func test_find_head_is_as_wide_as_the_body_when_nothing_sticks_out() -> void:
	assert_almost_eq(Bake.find_head(_bounds, _person()).width, 40.0, 1.5)


func test_find_head_is_wide_enough_for_a_weapon_below_the_head_row() -> void:
	var image := _person()
	_paint(image, Rect2i(100, 40, 12, 60))
	# From the body's left edge at column 44 to the weapon's right edge at column 112.
	assert_almost_eq(Bake.find_head(_bounds, image).width, 68.0, 1.5)


func test_find_head_is_not_wider_for_a_weapon_above_the_head_row() -> void:
	var image := _person()
	_paint(image, Rect2i(108, 2, 6, 15))
	assert_almost_eq(Bake.find_head(_bounds, image).width, 40.0, 1.5)


func test_find_head_returns_nothing_for_an_empty_picture() -> void:
	assert_true(Bake.find_head(_bounds, _blank()).is_empty())


func test_find_head_returns_nothing_for_a_see_through_picture_with_colour() -> void:
	var image := _blank()
	image.fill(Color8(100, 0, 0, 0))
	assert_true(Bake.find_head(_bounds, image).is_empty())


func test_find_head_gives_the_same_answer_for_a_bigger_picture() -> void:
	var small := Bake.find_head(_bounds, _person())
	var big := Bake.find_head(_bounds, _person(0, 256))
	assert_almost_eq(big.top, small.top, 0.0001)
	assert_almost_eq(big.x, small.x, 0.0001)
	assert_almost_eq(big.width, small.width, 0.0001)


func test_find_head_does_not_change_the_picture() -> void:
	var image := _person(0, 256)
	Bake.find_head(_bounds, image)
	assert_eq(image.get_size(), Vector2i(256, 256))


# is_first_variant

func test_a_name_without_a_number_is_a_first_variant() -> void:
	assert_true(Bake.is_first_variant("x"))


func test_a_name_with_underscores_but_no_number_is_a_first_variant() -> void:
	assert_true(Bake.is_first_variant("vulkite_berzerkers"))


func test_variant_one_is_a_first_variant() -> void:
	assert_true(Bake.is_first_variant("x_1"))


func test_variant_two_is_not_a_first_variant() -> void:
	assert_false(Bake.is_first_variant("x_2"))


func test_variant_ten_is_not_a_first_variant() -> void:
	assert_false(Bake.is_first_variant("x_10"))


func test_variant_one_of_a_name_with_underscores_is_a_first_variant() -> void:
	assert_true(Bake.is_first_variant("vulkite_berzerkers_1"))


func test_a_later_variant_of_a_name_with_underscores_is_not_a_first_variant() -> void:
	assert_false(Bake.is_first_variant("vulkite_berzerkers_3"))


# side_framing

func test_side_framing_is_as_big_as_the_length_of_a_model_of_middling_length() -> void:
	assert_almost_eq(Bake.side_framing(AABB(Vector3.ZERO, Vector3(1, 10, 8))).size, 8.0, 0.0001)


func test_side_framing_is_capped_at_one_and_a_half_times_the_height_for_a_long_low_model() -> void:
	assert_almost_eq(Bake.side_framing(AABB(Vector3.ZERO, Vector3(1, 10, 100))).size, 15.0, 0.0001)


func test_side_framing_shows_at_least_half_the_height_of_a_short_model() -> void:
	assert_almost_eq(Bake.side_framing(AABB(Vector3.ZERO, Vector3(1, 10, 1))).size, 5.0, 0.0001)


func test_side_framing_ignores_width() -> void:
	var narrow: float = Bake.side_framing(AABB(Vector3.ZERO, Vector3(1, 10, 8))).size
	var wide: float = Bake.side_framing(AABB(Vector3.ZERO, Vector3(100, 10, 8))).size
	assert_almost_eq(narrow, wide, 0.0001)


func test_side_framing_is_centred_across_the_model() -> void:
	var framing := Bake.side_framing(AABB(Vector3(2, 4, 6), Vector3(2, 2, 2)))
	assert_eq(framing.center.x, 3.0)
	assert_eq(framing.center.z, 7.0)


func test_side_framing_leaves_out_the_bottom_where_the_base_is() -> void:
	for length in [1, 10, 100]:
		var framing := Bake.side_framing(AABB(Vector3(0, 3, 0), Vector3(1, 10, length)))
		# The bottom 15% of the height is 1.5 above the model's lowest point.
		assert_gte(framing.center.y - framing.size / 2.0, 3.0 + 1.5 - 0.0001, "length %d" % length)


func test_side_framing_grows_with_the_model() -> void:
	var small: float = Bake.side_framing(AABB(Vector3.ZERO, Vector3(1, 1, 1))).size
	var big: float = Bake.side_framing(AABB(Vector3.ZERO, Vector3(2, 2, 2))).size
	assert_almost_eq(big, small * 2.0, 0.0001)


# is_side_on_keywords

func test_a_war_machine_is_side_on() -> void:
	assert_true(Bake.is_side_on_keywords(["WAR MACHINE", "ORDER"]))


func test_a_monster_is_side_on() -> void:
	assert_true(Bake.is_side_on_keywords(["MONSTER"]))


func test_a_monster_hero_is_not_side_on() -> void:
	assert_false(Bake.is_side_on_keywords(["MONSTER", "HERO"]))


func test_a_war_machine_hero_is_not_side_on() -> void:
	assert_false(Bake.is_side_on_keywords(["HERO", "WAR MACHINE"]))


func test_infantry_is_not_side_on() -> void:
	assert_false(Bake.is_side_on_keywords(["INFANTRY"]))


func test_no_keywords_is_not_side_on() -> void:
	assert_false(Bake.is_side_on_keywords([]))


# is_long

func test_a_long_narrow_model_is_long() -> void:
	assert_true(Bake.is_long(AABB(Vector3.ZERO, Vector3(2, 5, 10))))


func test_a_short_model_is_not_long() -> void:
	assert_false(Bake.is_long(AABB(Vector3.ZERO, Vector3(0.5, 5, 3))))


func test_a_model_just_under_the_least_length_is_not_long() -> void:
	assert_false(Bake.is_long(AABB(Vector3.ZERO, Vector3(1, 5, 4.4))))


func test_a_model_of_exactly_the_least_length_is_long() -> void:
	assert_true(Bake.is_long(AABB(Vector3.ZERO, Vector3(1, 5, 4.5))))


func test_a_model_not_much_longer_than_wide_is_not_long() -> void:
	assert_false(Bake.is_long(AABB(Vector3.ZERO, Vector3(9, 5, 10))))


func test_a_model_exactly_one_and_a_quarter_times_longer_than_wide_is_long() -> void:
	assert_true(Bake.is_long(AABB(Vector3.ZERO, Vector3(4, 5, 5))))


func test_a_model_just_under_one_and_a_quarter_times_longer_than_wide_is_not_long() -> void:
	assert_false(Bake.is_long(AABB(Vector3.ZERO, Vector3(4, 5, 4.99))))


func test_a_wider_than_long_model_is_not_long() -> void:
	assert_false(Bake.is_long(AABB(Vector3.ZERO, Vector3(10, 5, 6))))


# unit_stem

func test_a_stem_without_a_number_is_kept() -> void:
	assert_eq(Bake.unit_stem("x"), "x")


func test_variant_one_is_removed_from_a_stem() -> void:
	assert_eq(Bake.unit_stem("x_1"), "x")


func test_a_two_digit_variant_is_removed_from_a_stem() -> void:
	assert_eq(Bake.unit_stem("x_12"), "x")


func test_a_stem_with_underscores_but_no_number_is_kept_whole() -> void:
	assert_eq(Bake.unit_stem("vulkite_berzerkers"), "vulkite_berzerkers")


func test_a_variant_is_removed_from_a_stem_with_underscores() -> void:
	assert_eq(Bake.unit_stem("vulkite_berzerkers_3"), "vulkite_berzerkers")


# collect_side_on_names

func _collect(data: Variant) -> Dictionary:
	var names := {}
	Bake.collect_side_on_names(data, names)
	return names


func test_collect_finds_a_warscroll_as_a_slug() -> void:
	var names := _collect({"name": "Stone Golem", "keywords": ["MONSTER"]})
	assert_eq(names.keys(), [ModelLibrary.slug("Stone Golem")])


func test_collect_finds_warscrolls_nested_in_dictionaries_and_arrays() -> void:
	var names := _collect({"factions": [{"units": {"list": [
		{"name": "Big Beast", "keywords": ["MONSTER"]},
		[{"name": "Cannon", "keywords": ["WAR MACHINE"]}],
	]}}]})
	assert_true(names.has(ModelLibrary.slug("Big Beast")))
	assert_true(names.has(ModelLibrary.slug("Cannon")))


func test_collect_skips_heroes() -> void:
	assert_true(_collect({"name": "Big Boss", "keywords": ["MONSTER", "HERO"]}).is_empty())


func test_collect_skips_infantry() -> void:
	assert_true(_collect({"name": "Spearmen", "keywords": ["INFANTRY"]}).is_empty())


func test_collect_adds_both_names_of_a_warscroll_with_a_companion() -> void:
	var names := _collect({"name": "Rhino with Rider", "keywords": ["MONSTER"]})
	assert_true(names.has(ModelLibrary.slug("Rhino with Rider")))
	assert_true(names.has(ModelLibrary.slug("Rhino")))


func test_collect_ignores_a_dictionary_without_a_name() -> void:
	assert_true(_collect({"keywords": ["MONSTER"]}).is_empty())


func test_collect_ignores_keywords_that_are_not_an_array() -> void:
	assert_true(_collect({"name": "Odd", "keywords": "MONSTER"}).is_empty())


func test_collect_keeps_what_was_already_collected() -> void:
	var names := {"earlier": true}
	Bake.collect_side_on_names({"name": "Cannon", "keywords": ["WAR MACHINE"]}, names)
	assert_true(names.has("earlier"))
	assert_true(names.has(ModelLibrary.slug("Cannon")))


func test_collect_does_not_crash_on_scalars() -> void:
	for scalar: Variant in [1, "text", null, 2.5, true]:
		assert_true(_collect(scalar).is_empty())
