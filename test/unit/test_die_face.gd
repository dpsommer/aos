extends GutTest
## Unit tests for the roll-off's dice (scripts/ui/battle/die_face.gd).


func _die() -> DieFace:
	var die := DieFace.new(100, Color.RED)
	add_child_autofree(die)
	return die


func test_a_die_takes_its_size_from_its_argument() -> void:
	assert_eq(autofree(DieFace.new(80, Color.RED)).custom_minimum_size, Vector2(80, 80))


func test_a_die_does_not_block_the_mouse() -> void:
	assert_eq(_die().mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_value_cannot_go_above_six() -> void:
	var die := _die()
	die.value = 9
	assert_eq(die.value, 6)


func test_value_cannot_go_below_one() -> void:
	var die := _die()
	die.value = -3
	assert_eq(die.value, 1)


func test_every_face_has_as_many_pips_as_its_value() -> void:
	for face in range(1, 7):
		assert_eq(DieFace.PIPS[face].size(), face)


func test_every_pip_is_inside_the_face() -> void:
	for face in range(1, 7):
		for pip: Vector2 in DieFace.PIPS[face]:
			assert_between(pip.x, 0.0, 1.0)
			assert_between(pip.y, 0.0, 1.0)


func test_a_resting_die_is_not_turned() -> void:
	var die := _die()
	die.rotation = 0.3
	die._process(0.5)
	assert_eq(die.rotation, 0.0)


func test_a_tumbling_die_shows_a_valid_face_after_a_step() -> void:
	var die := _die()
	die.tumbling = true
	die._process(DieFace.TUMBLE_STEP * 2)
	assert_between(die.value, 1, 6)


func test_a_tumbling_die_wobbles() -> void:
	var die := _die()
	die.tumbling = true
	var turned := false
	for i in 20:
		die._process(DieFace.TUMBLE_STEP * 2)
		turned = turned or not is_zero_approx(die.rotation)
	assert_true(turned)


func test_a_tumbling_die_waits_between_faces() -> void:
	var die := _die()
	die.tumbling = true
	die.rotation = 0.0
	die._process(DieFace.TUMBLE_STEP / 10.0)
	assert_eq(die.rotation, 0.0)
