extends GutTest
## Unit tests for the battlefield camera (scripts/battle/battle_camera.gd).


func _camera() -> BattleCamera:
	var camera := BattleCamera.new()
	add_child_autofree(camera)
	camera.bounds = Rect2(0, 0, 60, 44)
	camera.target = Vector3(30, 0, 22)
	camera.yaw = 0.0
	return camera


# pan

func test_panning_right_moves_the_target_east() -> void:
	var camera := _camera()
	camera.pan(Vector2(5, 0))
	assert_almost_eq(camera.target, Vector3(35, 0, 22), Vector3(0.001, 0.001, 0.001))


func test_panning_forward_moves_the_target_north_when_looking_north() -> void:
	var camera := _camera()
	camera.pan(Vector2(0, 5))
	assert_almost_eq(camera.target, Vector3(30, 0, 17), Vector3(0.001, 0.001, 0.001))


func test_panning_follows_the_views_turn() -> void:
	var camera := _camera()
	camera.yaw = PI / 2
	camera.pan(Vector2(0, 5))
	assert_almost_eq(camera.target.x, 25.0, 0.001)
	assert_almost_eq(camera.target.z, 22.0, 0.001)


func test_pan_cannot_leave_the_battlefield() -> void:
	var camera := _camera()
	camera.pan(Vector2(500, -500))
	assert_eq(Vector2(camera.target.x, camera.target.z), Vector2(60, 44))
	camera.pan(Vector2(-500, 500))
	assert_eq(Vector2(camera.target.x, camera.target.z), Vector2(0, 0))


func test_pan_keeps_the_target_on_the_board() -> void:
	var camera := _camera()
	camera.target.y = 5.0
	camera.pan(Vector2(1, 1))
	assert_eq(camera.target.y, 0.0)


func test_pan_respects_other_bounds() -> void:
	var camera := _camera()
	camera.bounds = Rect2(0, 0, 30, 22)
	camera.pan(Vector2(100, 0))
	assert_eq(camera.target.x, 30.0)


# zoom

func test_zooming_in_gets_closer() -> void:
	var camera := _camera()
	var before := camera.distance
	camera.zoom(1.0)
	assert_lt(camera.distance, before)


func test_zooming_out_gets_further() -> void:
	var camera := _camera()
	var before := camera.distance
	camera.zoom(-1.0)
	assert_gt(camera.distance, before)


func test_zoom_has_a_closest_distance() -> void:
	var camera := _camera()
	camera.zoom(1000.0)
	assert_eq(camera.distance, BattleCamera.MIN_DISTANCE)


func test_zoom_has_a_furthest_distance() -> void:
	var camera := _camera()
	camera.zoom(-1000.0)
	assert_eq(camera.distance, BattleCamera.MAX_DISTANCE)


func test_the_wheel_zooms() -> void:
	var camera := _camera()
	var before := camera.distance
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	camera._unhandled_input(event)
	assert_lt(camera.distance, before)


# turn

func test_turning_changes_the_yaw() -> void:
	var camera := _camera()
	camera.turn(0.5)
	assert_almost_eq(camera.yaw, 0.5, 0.001)


func test_yaw_wraps_around() -> void:
	var camera := _camera()
	camera.turn(PI * 1.5)
	assert_between(camera.yaw, -PI, PI)
	assert_almost_eq(camera.yaw, -PI / 2, 0.001)


func test_pitch_cannot_go_below_its_minimum() -> void:
	var camera := _camera()
	camera.turn(0.0, -10.0)
	assert_eq(camera.pitch, BattleCamera.MIN_PITCH)


func test_pitch_cannot_go_above_its_maximum() -> void:
	var camera := _camera()
	camera.turn(0.0, 10.0)
	assert_eq(camera.pitch, BattleCamera.MAX_PITCH)


func test_turning_does_not_move_the_target() -> void:
	var camera := _camera()
	camera.turn(1.0, 0.1)
	assert_eq(camera.target, Vector3(30, 0, 22))


func test_the_camera_looks_at_the_target() -> void:
	var camera := _camera()
	camera.turn(0.7, 0.1)
	var ahead := -camera.camera.transform.basis.z
	var to_target := (camera.target - camera.camera.position).normalized()
	assert_almost_eq(ahead, to_target, Vector3(0.001, 0.001, 0.001))


# frame

func test_frame_looks_at_the_middle_of_the_area() -> void:
	var camera := _camera()
	camera.frame(Rect2(10, 4, 20, 10), 0.0)
	assert_almost_eq(camera.target, Vector3(20, 0, 9), Vector3(0.001, 0.001, 0.001))


func test_frame_keeps_the_target_in_bounds() -> void:
	var camera := _camera()
	camera.frame(Rect2(200, 200, 10, 10), 0.0)
	assert_eq(Vector2(camera.target.x, camera.target.z), Vector2(60, 44))


func test_frame_stands_behind_an_army_facing_east() -> void:
	var camera := _camera()
	camera.frame(Rect2(0, 0, 10, 10), 0.0)
	assert_lt(camera.camera.position.x, camera.target.x)


func test_frame_stands_behind_an_army_facing_west() -> void:
	var camera := _camera()
	camera.frame(Rect2(0, 0, 10, 10), PI)
	assert_gt(camera.camera.position.x, camera.target.x)


func test_frame_stands_behind_an_army_facing_north() -> void:
	var camera := _camera()
	camera.frame(Rect2(0, 0, 10, 10), -PI / 2)
	assert_gt(camera.camera.position.z, camera.target.z)


func test_frame_of_a_bigger_area_is_further_away() -> void:
	var camera := _camera()
	camera.frame(Rect2(0, 0, 10, 10), 0.0)
	var small := camera.distance
	camera.frame(Rect2(0, 0, 40, 40), 0.0)
	assert_gt(camera.distance, small)


func test_frame_stays_within_the_zoom_limits() -> void:
	var camera := _camera()
	camera.frame(Rect2(0, 0, 100000, 100000), 0.0)
	assert_lte(camera.distance, BattleCamera.MAX_DISTANCE)
	camera.frame(Rect2(0, 0, 0.01, 0.01), 0.0)
	assert_gte(camera.distance, BattleCamera.MIN_DISTANCE)
