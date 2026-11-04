extends GutTest
## Unit tests for the dashed rounded border (scripts/ui/common/dashed_style_box.gd).

const RECT := Rect2(10, 20, 100, 60)


func _outline(radius := 10.0) -> PackedVector2Array:
	return DashedStyleBox.outline_points(RECT, radius)


func _length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


func _perimeter(outline: PackedVector2Array) -> float:
	var closed := outline.duplicate()
	closed.append(outline[0])
	return _length(closed)


func test_outline_points_stay_within_the_rect() -> void:
	var bounds := RECT.grow(0.001)
	for point in _outline():
		assert_true(bounds.has_point(point), str(point))


func test_outline_touches_every_side_of_the_rect() -> void:
	var xs: Array[float] = []
	var ys: Array[float] = []
	for point in _outline():
		xs.append(point.x)
		ys.append(point.y)
	assert_almost_eq(xs.min(), RECT.position.x, 0.001)
	assert_almost_eq(xs.max(), RECT.end.x, 0.001)
	assert_almost_eq(ys.min(), RECT.position.y, 0.001)
	assert_almost_eq(ys.max(), RECT.end.y, 0.001)


func test_a_larger_radius_makes_a_shorter_outline() -> void:
	assert_lt(_perimeter(_outline(20.0)), _perimeter(_outline(2.0)))


func test_outline_with_no_radius_is_the_rects_perimeter() -> void:
	assert_almost_eq(_perimeter(_outline(0.0)), 2.0 * (RECT.size.x + RECT.size.y), 0.01)


func test_dashes_are_empty_for_fewer_than_two_points() -> void:
	assert_eq(DashedStyleBox.dashes(PackedVector2Array(), 5, 3).size(), 0)
	assert_eq(DashedStyleBox.dashes(PackedVector2Array([Vector2.ZERO]), 5, 3).size(), 0)


func test_dashes_are_empty_for_a_dash_length_of_zero_or_less() -> void:
	assert_eq(DashedStyleBox.dashes(_outline(), 0, 3).size(), 0)
	assert_eq(DashedStyleBox.dashes(_outline(), -2, 3).size(), 0)


func test_full_dashes_are_as_long_as_the_dash_length() -> void:
	var result := DashedStyleBox.dashes(_outline(), 6, 4)
	# The last dash may be cut short where the outline closes.
	for i in result.size() - 1:
		assert_almost_eq(_length(result[i]), 6.0, 0.05, "dash %d" % i)


func test_no_dash_is_longer_than_the_dash_length() -> void:
	for segment in DashedStyleBox.dashes(_outline(), 6, 4):
		assert_lte(_length(segment), 6.0 + 0.05)


func test_dashes_cover_dash_share_of_the_outline() -> void:
	var outline := _outline()
	var covered := 0.0
	for segment in DashedStyleBox.dashes(outline, 6, 4):
		covered += _length(segment)
	assert_almost_eq(covered / _perimeter(outline), 0.6, 0.03)


func test_without_a_gap_the_dashes_cover_the_whole_outline() -> void:
	var outline := _outline()
	var covered := 0.0
	for segment in DashedStyleBox.dashes(outline, 6, 0):
		covered += _length(segment)
	assert_almost_eq(covered, _perimeter(outline), 0.1)


func test_a_dash_longer_than_the_outline_is_one_segment() -> void:
	var outline := _outline()
	assert_eq(DashedStyleBox.dashes(outline, _perimeter(outline) * 2, 4).size(), 1)


func test_every_dash_has_at_least_two_points() -> void:
	for segment in DashedStyleBox.dashes(_outline(), 6, 4):
		assert_gte(segment.size(), 2)


func test_dashes_follow_the_outline() -> void:
	# Every dash point lies on the outline's bounding rect's edge or in a rounded corner, so within it.
	var bounds := RECT.grow(0.001)
	for segment in DashedStyleBox.dashes(_outline(), 6, 4):
		for point in segment:
			assert_true(bounds.has_point(point), str(point))


func test_init_sets_the_content_margin_on_every_side() -> void:
	var box := DashedStyleBox.new(Color.RED, 8.0, 12)
	assert_eq(box.get_margin(SIDE_LEFT), 12.0)
	assert_eq(box.get_margin(SIDE_BOTTOM), 12.0)
