extends GutTest
## Unit tests for the Spearhead realm map (scripts/ui/quick_play/realm_map.gd).


func _pack(size := Vector2(30, 22)) -> SpearheadBattlepack:
	var pack := SpearheadBattlepack.new()
	pack.name = "Test Pack"
	pack.battlefield_size = size
	return pack


func _realm(realm_name := "Testland") -> RealmBattlefield:
	var realm := RealmBattlefield.new()
	realm.name = realm_name
	return realm


func _deployment(deployment_name := "Test Deployment") -> DeploymentMap:
	var deployment := DeploymentMap.new()
	deployment.name = deployment_name
	return deployment


func _map(pack := _pack(), detailed := false, deployment: DeploymentMap = null) -> RealmMap:
	var map := RealmMap.new(pack, _realm(), detailed, deployment)
	add_child_autofree(map)
	return map


func test_battlefield_is_the_packs_size() -> void:
	assert_eq(_map(_pack(Vector2(44, 30))).battlefield(), Vector2(44, 30))


func test_battlefield_without_area_still_has_area() -> void:
	var battlefield := _map(_pack(Vector2.ZERO)).battlefield()
	assert_true(battlefield.x > 0 and battlefield.y > 0)


func test_battlefield_with_one_empty_side_still_has_area() -> void:
	var battlefield := _map(_pack(Vector2(30, 0))).battlefield()
	assert_true(battlefield.x > 0 and battlefield.y > 0)


func test_to_map_maps_the_origin_to_the_map_origin() -> void:
	var map := _map()
	map.size = Vector2(300, 200)
	assert_eq(map.to_map(Vector2.ZERO), Vector2.ZERO)


func test_to_map_maps_the_far_corner_to_the_map_size() -> void:
	var map := _map(_pack(Vector2(60, 40)))
	map.size = Vector2(300, 200)
	assert_eq(map.to_map(Vector2(60, 40)), Vector2(300, 200))


func test_to_map_scales_each_axis_separately() -> void:
	var map := _map(_pack(Vector2(60, 40)))
	map.size = Vector2(120, 400)
	assert_eq(map.to_map(Vector2(30, 10)), Vector2(60, 100))


func test_detailed_map_fits_its_height_to_the_battlefield_shape() -> void:
	var map := _map(_pack(Vector2(60, 30)), true)
	map.size = Vector2(240, 10)
	map.resized.emit()
	assert_eq(map.custom_minimum_size.y, 120.0)


func test_detailed_map_fits_height_using_the_fallback_shape() -> void:
	var map := _map(_pack(Vector2.ZERO), true)
	map.size = Vector2(300, 10)
	map.resized.emit()
	assert_eq(map.custom_minimum_size.y, roundf(300 * map.battlefield().y / map.battlefield().x))


func test_detailed_map_expands_to_its_container_width() -> void:
	assert_ne(_map(_pack(), true).size_flags_horizontal & Control.SIZE_EXPAND_FILL, 0)


func test_brief_map_has_a_minimum_size() -> void:
	var minimum := _map().custom_minimum_size
	assert_true(minimum.x > 0 and minimum.y > 0)


func test_ignores_the_mouse_so_the_card_gets_presses() -> void:
	assert_eq(_map().mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_detailed_map_ignores_the_mouse() -> void:
	assert_eq(_map(_pack(), true).mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_accessibility_name_names_the_realm() -> void:
	assert_string_contains(_map().accessibility_name, "Testland")


func test_accessibility_name_names_the_deployment_map() -> void:
	var map := _map(_pack(), false, _deployment("Hammer and Anvil"))
	assert_string_contains(map.accessibility_name, "Hammer and Anvil")


func test_accessibility_name_without_a_deployment_map_leaves_it_out() -> void:
	assert_false(_map().accessibility_name.contains("deployment"))


func test_keeps_the_deployment_map_it_was_given() -> void:
	var deployment := _deployment()
	assert_eq(_map(_pack(), false, deployment).deployment, deployment)


func test_has_no_deployment_map_by_default() -> void:
	assert_null(_map().deployment)


func test_draws_a_full_realm_without_error() -> void:
	var realm := _realm()
	var objective := MapFeature.new()
	objective.type = "Objective"
	objective.position = Vector2(15, 11)
	realm.objectives.append(objective)
	var rectangle := MapFeature.new()
	rectangle.type = "Bar"
	rectangle.position = Vector2(5, 5)
	rectangle.extent = Vector2(4, 2)
	realm.objectives.append(rectangle)
	realm.roads.append(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 5)]))
	var feature := MapFeature.new()
	feature.type = "Crypt"
	feature.position = Vector2(20, 10)
	realm.terrain.append(feature)
	var deployment := _deployment()
	deployment.territory_a = PackedVector2Array([Vector2(0, 0), Vector2(30, 0), Vector2(30, 11), Vector2(0, 11)])
	deployment.territory_b = PackedVector2Array([Vector2(0, 11), Vector2(30, 11), Vector2(30, 22), Vector2(0, 22)])
	var map := RealmMap.new(_pack(), realm, true, deployment)
	add_child_autofree(map)
	map.size = Vector2(300, 220)
	map.queue_redraw()
	await wait_frames(2)
	assert_not_null(map)
