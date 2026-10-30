extends GutTest
## Unit tests for the battleplan map (scripts/ui/quick_play/battleplan_map.gd).


func _plan() -> Battleplan:
	var plan := Battleplan.new()
	plan.name = "Test Plan"
	return plan


func _map(battlefield := Vector2(60, 44), detailed := false) -> BattleplanMap:
	var map := BattleplanMap.new(_plan(), battlefield, detailed)
	add_child_autofree(map)
	return map


func test_to_map_maps_the_battlefield_origin_to_the_map_origin() -> void:
	var map := _map()
	map.size = Vector2(300, 200)
	assert_eq(map.to_map(Vector2.ZERO), Vector2.ZERO)


func test_to_map_maps_the_battlefield_far_corner_to_the_map_size() -> void:
	var map := _map(Vector2(60, 40))
	map.size = Vector2(300, 200)
	assert_eq(map.to_map(Vector2(60, 40)), Vector2(300, 200))


func test_to_map_scales_each_axis_separately() -> void:
	var map := _map(Vector2(60, 40))
	map.size = Vector2(120, 400)
	assert_eq(map.to_map(Vector2(30, 10)), Vector2(60, 100))


func test_ignores_a_battlefield_without_area() -> void:
	var default := _map()
	var map := _map(Vector2.ZERO)
	assert_eq(map.battlefield, default.battlefield)


func test_uses_the_given_battlefield_size() -> void:
	var map := _map(Vector2(90, 30))
	assert_eq(map.battlefield, Vector2(90, 30))


func test_detailed_map_fits_its_height_to_the_battlefield_shape() -> void:
	var map := _map(Vector2(60, 30), true)
	map.size = Vector2(240, 10)
	map.resized.emit()
	assert_eq(map.custom_minimum_size.y, 120.0)


func test_detailed_map_height_follows_its_width() -> void:
	var map := _map(Vector2(60, 30), true)
	map.size = Vector2(120, 10)
	map.resized.emit()
	assert_eq(map.custom_minimum_size.y, 60.0)


func test_brief_map_does_not_fit_its_height_to_its_width() -> void:
	var map := _map(Vector2(60, 30))
	var before := map.custom_minimum_size
	map.size = Vector2(500, 10)
	map.resized.emit()
	assert_eq(map.custom_minimum_size, before)


func test_detailed_map_expands_to_its_container_width() -> void:
	var map := _map(Vector2(60, 44), true)
	assert_eq(map.size_flags_horizontal, Control.SIZE_EXPAND_FILL)


func test_map_ignores_the_mouse_so_the_card_gets_presses() -> void:
	var map := _map()
	assert_eq(map.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_map_is_named_for_its_battleplan() -> void:
	var map := _map()
	assert_true(map.accessibility_name.contains("Test Plan"))
