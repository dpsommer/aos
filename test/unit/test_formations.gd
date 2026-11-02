extends GutTest
## Unit tests for formation presets (scripts/battle/deployment/formations.gd).

const ALL_KINDS: Array[Formations.Kind] = [Formations.Kind.LINE, Formations.Kind.WIDE_BLOCK,
		Formations.Kind.NARROW_BLOCK, Formations.Kind.LOOSE, Formations.Kind.WEDGE]


func _bases(count: int, mm := 32.0) -> Array[BaseSize]:
	var result: Array[BaseSize] = []
	for i in count:
		result.append(BaseSize.round_base(mm))
	return result


func _centre(positions: PackedVector2Array) -> Vector2:
	var total := Vector2.ZERO
	for position in positions:
		total += position
	return total / positions.size()


# arrange

func test_every_formation_is_coherent_for_small_units() -> void:
	for kind in ALL_KINDS:
		for count in [2, 3, 5, 6]:
			var bases := _bases(count)
			var positions := Formations.arrange(kind, bases, Vector2(15, 11), 0.0)
			assert_true(Coherency.is_coherent(positions, bases, 0.0), "%s x%d" % [Formations.NAMES[kind], count])


func test_every_formation_is_coherent_for_large_units() -> void:
	for kind in ALL_KINDS:
		for count in [7, 8, 10, 13, 20, 30]:
			var bases := _bases(count)
			var positions := Formations.arrange(kind, bases, Vector2(15, 11), 0.0)
			assert_true(Coherency.is_coherent(positions, bases, 0.0), "%s x%d" % [Formations.NAMES[kind], count])


func test_every_formation_is_coherent_whichever_way_it_faces() -> void:
	for kind in ALL_KINDS:
		for facing in [0.0, 1.0, PI, -2.0]:
			var bases := _bases(12)
			var positions := Formations.arrange(kind, bases, Vector2(15, 11), facing)
			assert_true(Coherency.is_coherent(positions, bases, facing), "%s facing %f" % [Formations.NAMES[kind], facing])


func test_no_formation_overlaps_bases() -> void:
	for kind in ALL_KINDS:
		var bases := _bases(14)
		var positions := Formations.arrange(kind, bases, Vector2(15, 11), 0.3)
		for i in positions.size():
			for j in range(i + 1, positions.size()):
				assert_false(DeploymentRules.bases_overlap(bases[i], positions[i], 0.3, bases[j], positions[j], 0.3),
						"%s %d/%d" % [Formations.NAMES[kind], i, j])


func test_gives_one_position_per_model() -> void:
	for kind in ALL_KINDS:
		assert_eq(Formations.arrange(kind, _bases(9), Vector2.ZERO, 0.0).size(), 9)


func test_no_models_gives_no_positions() -> void:
	assert_eq(Formations.arrange(Formations.Kind.LINE, _bases(0), Vector2.ZERO, 0.0).size(), 0)


func test_single_model_stands_on_the_anchor() -> void:
	for kind in ALL_KINDS:
		assert_eq(Formations.arrange(kind, _bases(1), Vector2(4, 7), 1.0), PackedVector2Array([Vector2(4, 7)]))


func test_wide_block_is_centred_on_the_anchor() -> void:
	var positions := Formations.arrange(Formations.Kind.WIDE_BLOCK, _bases(10), Vector2(15, 11), 0.5)
	assert_almost_eq(_centre(positions), Vector2(15, 11), Vector2(0.01, 0.01))


func test_line_is_centred_on_the_anchor() -> void:
	var positions := Formations.arrange(Formations.Kind.LINE, _bases(5), Vector2(3, 9), 0.0)
	assert_almost_eq(_centre(positions), Vector2(3, 9), Vector2(0.01, 0.01))


func test_line_of_a_small_unit_is_a_single_rank_across_the_facing() -> void:
	# Facing east: the rank runs north to south, so every model shares an x.
	var positions := Formations.arrange(Formations.Kind.LINE, _bases(5), Vector2(15, 11), 0.0)
	for position in positions:
		assert_almost_eq(position.x, 15.0, 0.01)


func test_front_models_are_towards_the_facing() -> void:
	# Facing east, a block's first rank is the easternmost: its models have the greatest x.
	var positions := Formations.arrange(Formations.Kind.WIDE_BLOCK, _bases(10), Vector2(15, 11), 0.0)
	assert_gt(positions[0].x, _centre(positions).x)
	assert_lt(positions[positions.size() - 1].x, _centre(positions).x)


func test_front_follows_the_facing_when_turned() -> void:
	# Facing south (clockwise a quarter turn from east, y down).
	var positions := Formations.arrange(Formations.Kind.WIDE_BLOCK, _bases(10), Vector2(15, 11), PI / 2)
	assert_gt(positions[0].y, _centre(positions).y)


func test_wedge_has_a_single_point_model_at_the_front() -> void:
	var positions := Formations.arrange(Formations.Kind.WEDGE, _bases(6), Vector2(15, 11), 0.0)
	var front := 0
	for position in positions:
		if is_equal_approx(position.x, positions[0].x):
			front += 1
	assert_eq(front, 1)


func test_loose_formation_leaves_wider_gaps_than_a_block() -> void:
	var bases := _bases(10)
	var loose := Formations.arrange(Formations.Kind.LOOSE, bases, Vector2.ZERO, 0.0)
	var block := Formations.arrange(Formations.Kind.WIDE_BLOCK, bases, Vector2.ZERO, 0.0)
	assert_gt(_closest_pair(loose), _closest_pair(block))


func test_narrow_block_is_deeper_than_a_wide_block() -> void:
	var bases := _bases(12)
	var wide := Formations.arrange(Formations.Kind.WIDE_BLOCK, bases, Vector2.ZERO, 0.0)
	var narrow := Formations.arrange(Formations.Kind.NARROW_BLOCK, bases, Vector2.ZERO, 0.0)
	assert_gt(_depth(narrow), _depth(wide))


func test_larger_bases_space_models_further_apart() -> void:
	var small := Formations.arrange(Formations.Kind.LINE, _bases(3, 25.0), Vector2.ZERO, 0.0)
	var big := Formations.arrange(Formations.Kind.LINE, _bases(3, 60.0), Vector2.ZERO, 0.0)
	assert_gt(big[0].distance_to(big[1]), small[0].distance_to(small[1]))


func test_oval_bases_are_coherent_in_every_formation() -> void:
	var bases: Array[BaseSize] = []
	for i in 9:
		bases.append(BaseSize.oval(60, 35))
	for kind in ALL_KINDS:
		var positions := Formations.arrange(kind, bases, Vector2.ZERO, 0.0)
		assert_true(Coherency.is_coherent(positions, bases, 0.0), Formations.NAMES[kind])


func _closest_pair(positions: PackedVector2Array) -> float:
	var closest := INF
	for i in positions.size():
		for j in range(i + 1, positions.size()):
			closest = minf(closest, positions[i].distance_to(positions[j]))
	return closest


## How far apart the models are along the facing (east).
func _depth(positions: PackedVector2Array) -> float:
	var low := INF
	var high := -INF
	for position in positions:
		low = minf(low, position.x)
		high = maxf(high, position.x)
	return high - low


## Bases for groups of `[count, diameter_mm]` (or `[count, length_mm, width_mm]` for an oval).
func _mixed(groups: Array) -> Array[BaseSize]:
	var result: Array[BaseSize] = []
	for entry: Array in groups:
		for i in entry[0]:
			result.append(BaseSize.round_base(entry[1]) if entry.size() == 2 else BaseSize.oval(entry[1], entry[2]))
	return result


## Mixes of base sizes, by name: the Wildercorps Hunters', a small two-size unit and one with an oval.
func _mixes() -> Dictionary:
	return {
		"wildercorps": _mixed([[2, 40.0], [3, 28.5], [6, 25.0]]),
		"two sizes": _mixed([[2, 40.0], [3, 25.0]]),
		"with an oval": _mixed([[1, 60.0, 35.0], [4, 32.0], [3, 25.0]]),
		"large": _mixed([[3, 40.0], [10, 25.0], [8, 32.0]]),
	}


func _overlapping_pairs(positions: PackedVector2Array, bases: Array[BaseSize], facing: float) -> int:
	var count := 0
	for i in positions.size():
		for j in range(i + 1, positions.size()):
			if DeploymentRules.bases_overlap(bases[i], positions[i], facing, bases[j], positions[j], facing):
				count += 1
	return count


# arrange: mixed bases

func test_every_formation_is_coherent_for_mixed_bases() -> void:
	var mixes := _mixes()
	for mix in mixes:
		for kind in ALL_KINDS:
			var positions := Formations.arrange(kind, mixes[mix], Vector2(15, 11), 0.0)
			assert_true(Coherency.is_coherent(positions, mixes[mix], 0.0), "%s %s" % [Formations.NAMES[kind], mix])


func test_a_loose_formation_of_mixed_bases_with_an_oval_is_coherent() -> void:
	var bases: Array[BaseSize] = _mixes()["with an oval"]
	for facing in [0.0, 1.0, PI, -2.0]:
		var positions := Formations.arrange(Formations.Kind.LOOSE, bases, Vector2(15, 11), facing)
		assert_true(Coherency.is_coherent(positions, bases, facing), "facing %f" % facing)


func test_mixed_bases_are_coherent_whichever_way_they_face() -> void:
	var bases: Array[BaseSize] = _mixes()["wildercorps"]
	for kind in ALL_KINDS:
		for facing in [0.0, 1.0, PI, -2.0]:
			var positions := Formations.arrange(kind, bases, Vector2(15, 11), facing)
			assert_true(Coherency.is_coherent(positions, bases, facing), "%s facing %f" % [Formations.NAMES[kind], facing])


func test_mixed_bases_do_not_overlap() -> void:
	var mixes := _mixes()
	for mix in mixes:
		for kind in ALL_KINDS:
			for facing in [0.0, 1.0]:
				var positions := Formations.arrange(kind, mixes[mix], Vector2(15, 11), facing)
				assert_eq(_overlapping_pairs(positions, mixes[mix], facing), 0, "%s %s facing %f" % [Formations.NAMES[kind], mix, facing])


func test_mixed_bases_get_one_position_each() -> void:
	var mixes := _mixes()
	for mix in mixes:
		for kind in ALL_KINDS:
			assert_eq(Formations.arrange(kind, mixes[mix], Vector2(15, 11), 0.0).size(), mixes[mix].size(), "%s %s" % [Formations.NAMES[kind], mix])


func test_mixed_bases_are_roughly_centred_on_the_anchor() -> void:
	var bases: Array[BaseSize] = _mixes()["wildercorps"]
	var anchor := Vector2(15, 11)
	for kind in ALL_KINDS:
		var positions := Formations.arrange(kind, bases, anchor, 0.0)
		assert_lt(_centre(positions).distance_to(anchor), 2.0, Formations.NAMES[kind])


func test_mixed_bases_are_packed_closer_than_the_largest_base_would_be() -> void:
	var mixed: Array[BaseSize] = _mixes()["wildercorps"]
	var all_largest := _bases(mixed.size(), 40.0)
	var packed := Formations.arrange(Formations.Kind.LINE, mixed, Vector2.ZERO, 0.0)
	var spread := Formations.arrange(Formations.Kind.LINE, all_largest, Vector2.ZERO, 0.0)
	assert_lt(_extent(packed), _extent(spread))


func test_mixed_bases_nearly_equal_to_one_another_stay_coherent() -> void:
	var bases := _mixed([[5, 32.0], [5, 32.5]])
	for kind in ALL_KINDS:
		var positions := Formations.arrange(kind, bases, Vector2(15, 11), 0.0)
		assert_true(Coherency.is_coherent(positions, bases, 0.0), Formations.NAMES[kind])


func test_uniform_bases_keep_their_spacing() -> void:
	var bases := _bases(5, 40.0)
	var positions := Formations.arrange(Formations.Kind.LINE, bases, Vector2.ZERO, 0.0)
	var diameter := bases[0].footprint().x
	assert_almost_eq(_closest_pair(positions), diameter + Formations.CLOSE_GAP, 0.01)


## How far apart the models are across the whole formation, in either direction.
func _extent(positions: PackedVector2Array) -> float:
	var farthest := 0.0
	for a in positions:
		for b in positions:
			farthest = maxf(farthest, a.distance_to(b))
	return farthest


# kinds_for

func test_no_formations_for_a_single_model() -> void:
	assert_eq(Formations.kinds_for(1).size(), 0)


func test_every_formation_is_offered_for_several_models() -> void:
	assert_eq(Formations.kinds_for(5).size(), ALL_KINDS.size())


func test_names_and_shapes_cover_every_kind() -> void:
	assert_eq(Formations.NAMES.size(), ALL_KINDS.size())
	assert_eq(Formations.SHAPES.size(), ALL_KINDS.size())


# spread

const SPREAD_COUNTS: Array[int] = [2, 5, 6, 7, 11, 20]
const SPREAD_FACINGS: Array[float] = [0.0, -PI / 2, 1.1, PI]


func _base() -> BaseSize:
	return BaseSize.round_base(32.0)


func _mixed_bases() -> Array[BaseSize]:
	var result: Array[BaseSize] = []
	for mm in [40.0, 40.0, 28.5, 28.5, 28.5, 25.0, 25.0, 25.0, 25.0]:
		result.append(BaseSize.round_base(mm))
	return result


## The widths from nothing to well past the widest line, for [param count] models.
func _widths(count: int) -> Array[float]:
	var widest := Formations.max_width(count, _base())
	var result: Array[float] = [0.0, 0.5, widest / 3, widest / 2, widest * 0.8, widest, widest * 3]
	return result


## How far across the unit's right the models' spread is.
func _front_span(positions: PackedVector2Array, facing: float) -> float:
	var forward := Vector2.from_angle(facing)
	var right := Vector2(-forward.y, forward.x)
	var low := INF
	var high := -INF
	for position in positions:
		low = minf(low, position.dot(right))
		high = maxf(high, position.dot(right))
	return high - low


## How many ranks (rows of models at distinct depths) there are.
func _ranks(positions: PackedVector2Array, facing: float) -> int:
	var forward := Vector2.from_angle(facing)
	var depths: Array[float] = []
	for position in positions:
		var depth := position.dot(forward)
		if not depths.any(func(d: float) -> bool: return absf(d - depth) < 0.3):
			depths.append(depth)
	return depths.size()


func _overlaps(bases: Array[BaseSize], positions: PackedVector2Array, facing: float) -> bool:
	for i in positions.size():
		for j in range(i + 1, positions.size()):
			if DeploymentRules.bases_overlap(bases[i], positions[i], facing, bases[j], positions[j], facing):
				return true
	return false


func test_spread_is_coherent_at_every_width() -> void:
	for count in SPREAD_COUNTS:
		var bases := _bases(count)
		for width in _widths(count):
			var positions := Formations.spread(bases, Vector2(10, 10), 0.4, width)
			assert_true(Coherency.is_coherent(positions, bases, 0.4), "x%d width %.2f" % [count, width])


func test_spread_does_not_overlap_bases_at_any_width() -> void:
	for count in SPREAD_COUNTS:
		var bases := _bases(count)
		for width in _widths(count):
			var positions := Formations.spread(bases, Vector2(10, 10), 0.4, width)
			assert_false(_overlaps(bases, positions, 0.4), "x%d width %.2f" % [count, width])


func test_spread_is_coherent_whichever_way_it_faces() -> void:
	for facing in SPREAD_FACINGS:
		var bases := _bases(11)
		var positions := Formations.spread(bases, Vector2(10, 10), facing, 8.0)
		assert_true(Coherency.is_coherent(positions, bases, facing), "facing %.2f" % facing)


func test_spread_gives_one_position_per_model() -> void:
	for count in SPREAD_COUNTS:
		assert_eq(Formations.spread(_bases(count), Vector2.ZERO, 0.0, 6.0).size(), count)


func test_spread_of_mixed_bases_is_coherent_at_every_width() -> void:
	var bases := _mixed_bases()
	for width in [0.0, 3.0, 6.0, 10.0, 40.0]:
		var positions := Formations.spread(bases, Vector2(10, 10), 0.4, width)
		assert_true(Coherency.is_coherent(positions, bases, 0.4), "width %.1f" % width)


func test_spread_of_mixed_bases_does_not_overlap() -> void:
	var bases := _mixed_bases()
	for width in [0.0, 3.0, 6.0, 10.0, 40.0]:
		var positions := Formations.spread(bases, Vector2(10, 10), 0.4, width)
		assert_false(_overlaps(bases, positions, 0.4), "width %.1f" % width)


func test_spread_puts_the_front_left_model_at_the_point() -> void:
	var at := Vector2(13, -4)
	for count in SPREAD_COUNTS:
		for width in _widths(count):
			var positions := Formations.spread(_bases(count), at, 0.9, width)
			assert_true(positions[0].is_equal_approx(at), "x%d width %.2f" % [count, width])


func test_spread_of_one_model_is_the_point() -> void:
	var positions := Formations.spread(_bases(1), Vector2(3, 4), 1.0, 9.0)
	assert_eq(positions, PackedVector2Array([Vector2(3, 4)]))


func test_spread_of_no_models_is_empty() -> void:
	assert_eq(Formations.spread(_bases(0), Vector2(3, 4), 1.0, 9.0).size(), 0)


func test_the_front_rank_runs_along_the_facings_right() -> void:
	for facing in SPREAD_FACINGS:
		var forward := Vector2.from_angle(facing)
		var right := Vector2(-forward.y, forward.x)
		var positions := Formations.spread(_bases(5), Vector2.ZERO, facing, 100.0)
		assert_gt(positions[4].dot(right), positions[0].dot(right), "facing %.2f" % facing)
		assert_almost_eq(positions[4].dot(forward), positions[0].dot(forward), 0.01, "facing %.2f" % facing)


func test_no_model_stands_in_front_of_the_front_rank() -> void:
	var forward := Vector2.from_angle(0.7)
	var positions := Formations.spread(_bases(11), Vector2(2, 2), 0.7, 5.0)
	for position in positions:
		assert_lt(position.dot(forward), (Vector2(2, 2)).dot(forward) + 0.01)


func test_a_wider_drag_never_makes_the_front_narrower() -> void:
	for count in SPREAD_COUNTS:
		var bases := _bases(count)
		var last := -1.0
		for step in 40:
			var width := step * Formations.max_width(count, _base()) / 30.0
			var span := _front_span(Formations.spread(bases, Vector2.ZERO, 0.3, width), 0.3)
			assert_gte(span, last - 0.001, "x%d width %.2f" % [count, width])
			last = span


func test_a_drag_past_the_widest_line_gives_no_more_width() -> void:
	for count in SPREAD_COUNTS:
		var widest := Formations.max_width(count, _base())
		var at_max := _front_span(Formations.spread(_bases(count), Vector2.ZERO, 0.0, widest), 0.0)
		var past := _front_span(Formations.spread(_bases(count), Vector2.ZERO, 0.0, widest * 4), 0.0)
		assert_almost_eq(past, at_max, 0.01, "x%d" % count)


func test_the_front_never_spans_more_than_the_widest() -> void:
	for count in SPREAD_COUNTS:
		var widest := Formations.max_width(count, _base())
		for width in _widths(count):
			var span := _front_span(Formations.spread(_bases(count), Vector2.ZERO, 0.0, width), 0.0)
			assert_lte(span, widest + 0.01, "x%d width %.2f" % [count, width])


func test_a_narrow_drag_gives_more_ranks_than_a_wide_one() -> void:
	for count in [5, 7, 11, 20]:
		var narrow := Formations.spread(_bases(count), Vector2.ZERO, 0.0, 0.0)
		var wide := Formations.spread(_bases(count), Vector2.ZERO, 0.0, Formations.max_width(count, _base()))
		assert_gt(_ranks(narrow, 0.0), _ranks(wide, 0.0), "x%d" % count)


func test_a_narrow_drag_gives_a_column_narrower_than_the_widest_line() -> void:
	var narrow := Formations.spread(_bases(11), Vector2.ZERO, 0.0, 0.0)
	assert_lt(_front_span(narrow, 0.0), Formations.max_width(11, _base()) / 2)


func test_a_small_unit_at_the_widest_is_a_single_rank() -> void:
	for count in [2, 3, 5, 6]:
		var positions := Formations.spread(_bases(count), Vector2.ZERO, 0.0, Formations.max_width(count, _base()))
		assert_eq(_ranks(positions, 0.0), 1, "x%d" % count)


func test_a_large_unit_at_the_widest_has_a_rank_and_two_tucked_models() -> void:
	for count in [7, 11, 20]:
		var positions := Formations.spread(_bases(count), Vector2.ZERO, 0.0, Formations.max_width(count, _base()))
		var forward := Vector2.from_angle(0.0)
		var back := 0
		for position in positions:
			if absf(position.dot(forward) - positions[0].dot(forward)) > 0.1:
				back += 1
		assert_eq(back, 2, "x%d" % count)


func test_every_model_of_a_widest_large_unit_has_two_neighbours() -> void:
	for count in [7, 11, 20]:
		var bases := _bases(count)
		var positions := Formations.spread(bases, Vector2.ZERO, 0.0, Formations.max_width(count, _base()))
		for i in count:
			var near := 0
			for j in count:
				if i != j and DeploymentRules.base_gap(bases[i], positions[i], 0.0, bases[j], positions[j], 0.0) <= Coherency.MAX_GAP:
					near += 1
			assert_gte(near, 2, "x%d model %d" % [count, i])


func test_the_widest_line_is_wider_for_more_models() -> void:
	assert_gt(Formations.max_width(11, _base()), Formations.max_width(5, _base()))


func test_a_bigger_base_has_a_wider_widest_line() -> void:
	assert_gt(Formations.max_width(5, BaseSize.round_base(60.0)), Formations.max_width(5, BaseSize.round_base(25.0)))
