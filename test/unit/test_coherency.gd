extends GutTest
## Unit tests for unit coherency (scripts/battle/deployment/coherency.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")

## A 1" round base (25.4mm), so edges are easy to place.
const INCH := 25.4


func _bases(count: int, mm := INCH) -> Array[BaseSize]:
	var result: Array[BaseSize] = []
	for i in count:
		result.append(BaseSize.round_base(mm))
	return result


## [param count] 1" models in a row, their edges [param gap] apart.
func _row(count: int, gap: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in count:
		result.append(Vector2(i * (1.0 + gap), 0))
	return result


# neighbours_needed

func test_small_units_need_one_neighbour() -> void:
	assert_eq(Coherency.neighbours_needed(Coherency.LARGE_UNIT - 1), 1)


func test_large_units_need_two_neighbours() -> void:
	assert_eq(Coherency.neighbours_needed(Coherency.LARGE_UNIT), 2)


# failing

func test_single_model_is_coherent() -> void:
	assert_true(Coherency.is_coherent(PackedVector2Array([Vector2(5, 5)]), _bases(1), 0.0))


func test_no_models_is_coherent() -> void:
	assert_true(Coherency.is_coherent(PackedVector2Array(), _bases(0), 0.0))


func test_models_within_the_gap_are_coherent() -> void:
	assert_true(Coherency.is_coherent(_row(3, 0.4), _bases(3), 0.0))


func test_touching_models_are_coherent() -> void:
	assert_true(Coherency.is_coherent(_row(3, 0.0), _bases(3), 0.0))


func test_models_exactly_at_the_gap_are_coherent() -> void:
	assert_true(Coherency.is_coherent(_row(2, Coherency.MAX_GAP), _bases(2), 0.0))


func test_models_beyond_the_gap_fail() -> void:
	assert_eq(Coherency.failing(_row(2, Coherency.MAX_GAP + 0.1), _bases(2), 0.0), PackedInt32Array([0, 1]))


func test_gap_is_measured_between_edges_not_centres() -> void:
	# Centres 1.9" apart: big bases leave no gap between edges, small ones 0.9".
	var positions := PackedVector2Array([Vector2(0, 0), Vector2(1.9, 0)])
	assert_true(Coherency.is_coherent(positions, _bases(2, 1.5 * INCH), 0.0))
	assert_false(Coherency.is_coherent(positions, _bases(2, 1.0 * INCH), 0.0))


func test_only_the_stray_model_fails_in_a_small_unit() -> void:
	var positions := _row(3, 0.2)
	positions.append(Vector2(20, 0))
	assert_eq(Coherency.failing(positions, _bases(4), 0.0), PackedInt32Array([3]))


func test_two_separate_groups_fail_the_smaller_one() -> void:
	# Pairs of models, the second pair far from the first: the largest group is the first by order,
	# so exactly one pair fails.
	var positions := PackedVector2Array([Vector2(0, 0), Vector2(1.2, 0), Vector2(20, 0), Vector2(21.2, 0)])
	assert_eq(Coherency.failing(positions, _bases(4), 0.0).size(), 2)


func test_chain_of_models_is_one_group() -> void:
	assert_true(Coherency.is_coherent(_row(6, 0.4), _bases(6), 0.0))


func test_large_unit_in_a_row_fails_its_end_models() -> void:
	# In a single row each end model has only one neighbour but 7+ models need two.
	assert_eq(Coherency.failing(_row(7, 0.2), _bases(7), 0.0), PackedInt32Array([0, 6]))


func test_large_unit_in_a_grid_is_coherent() -> void:
	var positions := PackedVector2Array()
	for i in 8:
		@warning_ignore("integer_division")
		positions.append(Vector2((i % 4) * 1.2, (i / 4) * 1.2))
	assert_true(Coherency.is_coherent(positions, _bases(8), 0.0))
