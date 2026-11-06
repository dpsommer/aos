extends GutTest
## Reading and rolling characteristics that may be random.

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 5


func _rolls(text: String, times := 300) -> Array[int]:
	var expr := DiceExpr.parse(text)
	var result: Array[int] = []
	for _i in times:
		result.append(expr.roll(_rng))
	return result


func test_a_number_is_fixed() -> void:
	var expr := DiceExpr.parse("4")
	assert_true(expr.is_fixed())
	assert_eq(expr.roll(_rng), 4)


func test_a_fixed_number_always_rolls_itself() -> void:
	for value in _rolls("7"):
		assert_eq(value, 7)


func test_one_die_has_a_count_of_one() -> void:
	var expr := DiceExpr.parse("D3")
	assert_eq(expr.count, 1)
	assert_eq(expr.sides, 3)
	assert_false(expr.is_fixed())


func test_a_count_before_the_die() -> void:
	var expr := DiceExpr.parse("2D6")
	assert_eq(expr.count, 2)
	assert_eq(expr.sides, 6)


func test_a_bonus_after_the_die() -> void:
	var expr := DiceExpr.parse("D6+3")
	assert_eq(expr.count, 1)
	assert_eq(expr.bonus, 3)


func test_a_penalty_after_the_die() -> void:
	assert_eq(DiceExpr.parse("D6-1").bonus, -1)


func test_a_dash_is_nothing() -> void:
	var expr := DiceExpr.parse("-")
	assert_true(expr.is_fixed())
	assert_eq(expr.roll(_rng), 0)


func test_text_it_cannot_read_is_nothing() -> void:
	assert_eq(DiceExpr.parse("").roll(_rng), 0)
	assert_eq(DiceExpr.parse("lots").roll(_rng), 0)


func test_case_and_inch_marks_do_not_matter() -> void:
	assert_eq(DiceExpr.parse("2d6").count, 2)
	assert_eq(DiceExpr.parse("12\"").bonus, 12)


func test_surrounding_space_does_not_matter() -> void:
	assert_eq(DiceExpr.parse("  D3 ").sides, 3)


func test_a_roll_stays_within_the_dice() -> void:
	var cases := {"D3": [1, 3], "D6": [1, 6], "2D6": [2, 12], "D6+3": [4, 9], "2D3": [2, 6]}
	for text: String in cases:
		var rolled := _rolls(text)
		assert_eq(rolled.min(), cases[text][0], "%s lowest" % text)
		assert_eq(rolled.max(), cases[text][1], "%s highest" % text)


func test_each_die_is_rolled() -> void:
	# Two dice reach totals one die can't.
	assert_gt(_rolls("2D6").max(), 6)


func test_the_same_seed_rolls_the_same() -> void:
	var first := DiceExpr.parse("3D6").roll(_rng)
	var again := RandomNumberGenerator.new()
	again.seed = 5
	assert_eq(DiceExpr.parse("3D6").roll(again), first)


func test_of_value_is_fixed() -> void:
	var expr := DiceExpr.of_value(5)
	assert_true(expr.is_fixed())
	assert_eq(expr.roll(_rng), 5)


func test_the_average_of_dice() -> void:
	assert_almost_eq(DiceExpr.parse("D6").average(), 3.5, 0.001)
	assert_almost_eq(DiceExpr.parse("2D6").average(), 7.0, 0.001)
	assert_almost_eq(DiceExpr.parse("D3+1").average(), 3.0, 0.001)
	assert_almost_eq(DiceExpr.parse("4").average(), 4.0, 0.001)


func test_it_reads_back_as_the_text_it_came_from() -> void:
	for text in ["4", "D3", "2D6", "D6+3"]:
		assert_eq(str(DiceExpr.parse(text)), text)
