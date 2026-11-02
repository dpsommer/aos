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


# kinds_for

func test_no_formations_for_a_single_model() -> void:
	assert_eq(Formations.kinds_for(1).size(), 0)


func test_every_formation_is_offered_for_several_models() -> void:
	assert_eq(Formations.kinds_for(5).size(), ALL_KINDS.size())


func test_names_and_shapes_cover_every_kind() -> void:
	assert_eq(Formations.NAMES.size(), ALL_KINDS.size())
	assert_eq(Formations.SHAPES.size(), ALL_KINDS.size())
