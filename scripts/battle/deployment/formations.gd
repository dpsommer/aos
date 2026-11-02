class_name Formations
extends RefCounted
## Ready-made arrangements of a unit's models for deployment: a line, wide or narrow blocks, a
## loose block and a wedge. Each is coherent (see [Coherency]); a unit with bases of different
## sizes has each model packed against its neighbours, in the formation's shape. Positions
## are in inches; a unit faces [code]facing[/code] (radians clockwise from east), towards the
## enemy. See docs/gameplay/deployment.md.

enum Kind { LINE, WIDE_BLOCK, NARROW_BLOCK, LOOSE, WEDGE }

## Each formation's name and shape, for the placing panel, in [enum Kind] order.
const NAMES: PackedStringArray = ["Line", "Wide block", "Narrow block", "Loose", "Wedge"]
const SHAPES: PackedStringArray = ["1 rank", "2 ranks", "4 ranks", "½\" apart", "point forward"]
## The gap between neighbouring bases in a close formation.
const CLOSE_GAP := 0.25
## The gap in a loose formation: as wide as coherency allows.
const LOOSE_GAP := Coherency.MAX_GAP - 0.02
## Units of up to this many models stand in a single rank as a line.
const SINGLE_RANK_LINE := Coherency.LARGE_UNIT - 1

## [method _coherent_columns] by unit size and base.
static var _columns_cache := {}


## Where each of [param bases]' models stands in formation [param kind], centred on
## [param anchor] and facing [param facing].
static func arrange(kind: Kind, bases: Array[BaseSize], anchor: Vector2, facing: float) -> PackedVector2Array:
	var count := bases.size()
	if count == 0:
		return PackedVector2Array()
	if count == 1:
		return PackedVector2Array([anchor])
	var gap := LOOSE_GAP if kind == Kind.LOOSE else CLOSE_GAP
	if _is_uniform(bases):
		return _place(_offsets(kind, count, _largest_base(bases), gap), anchor, facing)
	# Mixed bases (e.g. Wildercorps Hunters' 40mm, 28.5mm and 25mm): the shape for a base of their
	# average size, each model then packed against its neighbours so it stays coherent.
	var shape := _place(_offsets(kind, count, _average_base(bases), gap), anchor, facing)
	# Tighter gaps if need be: an oval's edge isn't the same distance all round, so a gap near ½"
	# can leave it out of coherency.
	for pack_gap in [gap, CLOSE_GAP, CLOSE_GAP / 2]:
		var packed := _pack(shape, bases, facing, minf(pack_gap, gap))
		if not packed.is_empty():
			return packed
	return _place(_offsets(kind, count, _largest_base(bases), gap), anchor, facing)


## The (across, back) offsets of [param count] models in formation [param kind], spaced for
## [param base] with [param gap] between neighbours.
static func _offsets(kind: Kind, count: int, base: BaseSize, gap: float) -> Array[Vector2]:
	var size := base.footprint()
	# Models stand side by side across the facing, and ranks one behind the other.
	var across_step := size.y + gap
	var depth_step := size.x + gap
	# How far behind two neighbours a model sits, nestled between them, [param gap] from each.
	var nestle := nestle_depth(base, across_step, gap)
	var offsets: Array[Vector2] = []
	match kind:
		Kind.LINE:
			offsets = _line(count, across_step, nestle)
		Kind.WIDE_BLOCK:
			offsets = _block(count, ceili(count / 2.0), across_step, depth_step, nestle)
		Kind.NARROW_BLOCK:
			offsets = _block(count, ceili(count / 4.0), across_step, depth_step, nestle)
		Kind.LOOSE:
			offsets = _block(count, mini(count, ceili(sqrt(count * 2.0))), across_step, depth_step, nestle)
		Kind.WEDGE:
			offsets = _wedge(count, across_step, nestle)
	return offsets


## Where each of [param bases]' models stands in ranks facing [param facing], the front rank
## [param width] wide (centre to centre), running from [param front_left] (the front-left model) to
## the unit's right. A narrow width stacks the models in a deep column; the wider it is, the more
## stand in the front rank and the fewer ranks behind, and past a close-packed line the gaps open to
## just under ½", as wide as coherency allows. A unit of 7 or more stretches to a single rank with
## its two end models tucked in behind the models next to them, as each model needs two neighbours.
## Always coherent for bases of one size;
## mixed bases are packed against their neighbours as in [method arrange].
static func spread(bases: Array[BaseSize], front_left: Vector2, facing: float, width: float) -> PackedVector2Array:
	var count := bases.size()
	if count == 0:
		return PackedVector2Array()
	if count == 1:
		return PackedVector2Array([front_left])
	var uniform := _is_uniform(bases)
	var base := _largest_base(bases) if uniform else _average_base(bases)
	var offsets := _spread_offsets(count, base, width)
	var shape := PackedVector2Array()
	var forward := Vector2.from_angle(facing)
	var right := Vector2(-forward.y, forward.x)
	for offset in offsets:
		shape.append(front_left + right * offset.x - forward * offset.y)
	if uniform:
		return shape
	for gap in [CLOSE_GAP, CLOSE_GAP / 2]:
		var packed := _pack(shape, bases, facing, gap)
		if not packed.is_empty():
			return packed
	return arrange(Kind.WIDE_BLOCK, bases, _centre(shape), facing)


## The widest [param count] models on [param base] stand in coherency, centre to centre across the
## front: a line with gaps just under ½".
static func max_width(count: int, base: BaseSize) -> float:
	return _span(_spread_layout(count, count, base, LOOSE_GAP))


## The (across, back) offsets for [method spread]: the widest coherent layout whose close-packed
## front rank fits [param width] (the narrowest if none does), its gaps then opened up to fill it,
## as far as coherency allows. The front-left model is at (0, 0).
static func _spread_offsets(count: int, base: BaseSize, width: float) -> Array[Vector2]:
	var columns := 0
	var best_span := -1.0
	for candidate: int in _coherent_columns(count, base):
		var span := _span(_spread_layout(count, candidate, base, CLOSE_GAP))
		if columns == 0 or (span <= width + 0.001 and span >= best_span):
			columns = candidate
			best_span = span
	if columns == 0:
		return _spread_layout(count, count, base, CLOSE_GAP)
	var close_span := _span(_spread_layout(count, columns, base, CLOSE_GAP))
	var loose_span := _span(_spread_layout(count, columns, base, LOOSE_GAP))
	var gap := CLOSE_GAP
	if loose_span > close_span + 0.001:
		gap = lerpf(CLOSE_GAP, LOOSE_GAP, clampf((width - close_span) / (loose_span - close_span), 0.0, 1.0))
	return _spread_layout(count, columns, base, gap)


## The front-rank sizes [method _spread_layout] can use for [param count] models on [param base]
## and stay coherent, narrowest first. Worked out once for each count and base size.
static func _coherent_columns(count: int, base: BaseSize) -> Array:
	var key := "%d:%d:%v" % [count, base.shape, base.footprint()]
	if _columns_cache.has(key):
		return _columns_cache[key]
	var bases: Array[BaseSize] = []
	for i in count:
		bases.append(base)
	var result := []
	for columns in range(1, count + 1):
		if Coherency.is_coherent(_place_raw(_spread_layout(count, columns, base, CLOSE_GAP)), bases, 0.0):
			result.append(columns)
	_columns_cache[key] = result
	return result


## [param count] models on [param base] with [param columns] in the front rank, [param gap] apart:
## a block, or with [param columns] of [param count] a line ([method _wide_line]).
static func _spread_layout(count: int, columns: int, base: BaseSize, gap: float) -> Array[Vector2]:
	var size := base.footprint()
	var across_step := size.y + gap
	var nestle := nestle_depth(base, across_step, gap)
	if columns >= count:
		return _wide_line(count, across_step, nestle)
	return _block(count, columns, across_step, size.x + gap, nestle)


## The widest coherent line: one rank, or for a unit of 7 or more (each model needing two
## neighbours) one rank of all but two, the two tucked in behind the first and last pairs. The
## front rank comes first.
static func _wide_line(count: int, step: float, nestle: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if count < Coherency.LARGE_UNIT:
		for i in count:
			result.append(Vector2(i * step, 0))
		return result
	var front := count - 2
	for i in front:
		result.append(Vector2(i * step, 0))
	result.append(Vector2(step / 2, nestle))
	result.append(Vector2((front - 1.5) * step, nestle))
	return result


## How far apart the leftmost and rightmost models are, centre to centre.
static func _span(offsets: Array[Vector2]) -> float:
	var low := INF
	var high := -INF
	for offset in offsets:
		low = minf(low, offset.x)
		high = maxf(high, offset.x)
	return high - low if high >= low else 0.0


## (across, back) offsets as positions facing east, for checking coherency.
static func _place_raw(offsets: Array[Vector2]) -> PackedVector2Array:
	var result := PackedVector2Array()
	for offset in offsets:
		result.append(Vector2(-offset.y, offset.x))
	return result


static func _centre(positions: PackedVector2Array) -> Vector2:
	var total := Vector2.ZERO
	for position in positions:
		total += position
	return total / positions.size()


## The formations that make sense for [param model_count] models: none for a single model.
static func kinds_for(model_count: int) -> Array[Kind]:
	var result: Array[Kind] = []
	if model_count > 1:
		result.assign([Kind.LINE, Kind.WIDE_BLOCK, Kind.NARROW_BLOCK, Kind.LOOSE, Kind.WEDGE])
	return result


## The base with the biggest footprint.
static func _largest_base(bases: Array[BaseSize]) -> BaseSize:
	var result := bases[0]
	for base in bases:
		var footprint := base.footprint()
		var best := result.footprint()
		if footprint.x * footprint.y > best.x * best.y:
			result = base
	return result


## Whether every one of [param bases] has the same footprint and shape.
static func _is_uniform(bases: Array[BaseSize]) -> bool:
	for base in bases:
		if base.shape != bases[0].shape or not base.footprint().is_equal_approx(bases[0].footprint()):
			return false
	return true


## A round base of [param bases]' average size.
static func _average_base(bases: Array[BaseSize]) -> BaseSize:
	var total := 0.0
	for base in bases:
		total += (base.footprint().x + base.footprint().y) / 2
	return BaseSize.round_base(total / bases.size() * BaseSize.MM_PER_INCH)


## [param bases]' models packed as near as they'll go to the spots in [param shape], in order: each
## after the first is set [param gap] from one or two models already down, where it doesn't overlap
## any, so the unit is coherent however its bases differ in size. Empty if it can't be done.
static func _pack(shape: PackedVector2Array, bases: Array[BaseSize], facing: float, gap: float) -> PackedVector2Array:
	var count := bases.size()
	var needed := Coherency.neighbours_needed(count)
	var placed := PackedVector2Array([shape[0]])
	var radii := PackedFloat32Array()
	for base in bases:
		radii.append((base.footprint().x + base.footprint().y) / 4)
	for k in range(1, count):
		var best := Vector2.INF
		var best_distance := INF
		for candidate in _candidates(placed, radii, k, shape[k], gap):
			var distance := candidate.distance_to(shape[k])
			if distance < best_distance and _fits(placed, bases, facing, k, candidate, mini(needed, k)):
				best = candidate
				best_distance = distance
		if best == Vector2.INF:
			return PackedVector2Array()
		placed.append(best)
	return placed if Coherency.is_coherent(placed, bases, facing) else PackedVector2Array()


## Spots for model [param k] [param gap] from the models in [param placed]: towards
## [param target] from each, and touching each touching pair of them.
static func _candidates(placed: PackedVector2Array, radii: PackedFloat32Array, k: int, target: Vector2, gap: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in placed.size():
		var reach := radii[i] + radii[k] + gap
		var towards := (target - placed[i]).normalized() if not target.is_equal_approx(placed[i]) else Vector2.RIGHT
		result.append(placed[i] + towards * reach)
		for j in range(i + 1, placed.size()):
			var apart := placed[i].distance_to(placed[j])
			if apart > radii[i] + radii[j] + Coherency.MAX_GAP + 0.01:
				continue
			result.append_array(_circle_crossings(placed[i], reach, placed[j], radii[j] + radii[k] + gap))
	return result


## Where the circles round [param a] of radius [param ra] and round [param b] of radius
## [param rb] cross: none, or two points.
static func _circle_crossings(a: Vector2, ra: float, b: Vector2, rb: float) -> PackedVector2Array:
	var d := a.distance_to(b)
	if d < 0.0001 or d > ra + rb or d < absf(ra - rb):
		return PackedVector2Array()
	var along := (ra * ra - rb * rb + d * d) / (2 * d)
	var height := sqrt(maxf(ra * ra - along * along, 0.0))
	var direction := (b - a) / d
	var middle := a + direction * along
	var across := Vector2(-direction.y, direction.x) * height
	return PackedVector2Array([middle + across, middle - across])


## Whether model [param k] at [param at] overlaps none of [param placed] and is within coherency
## of at least [param needed] of them.
static func _fits(placed: PackedVector2Array, bases: Array[BaseSize], facing: float, k: int, at: Vector2, needed: int) -> bool:
	var near := 0
	for i in placed.size():
		var gap := DeploymentRules.base_gap(bases[i], placed[i], facing, bases[k], at, facing)
		if DeploymentRules.bases_overlap(bases[i], placed[i], facing, bases[k], at, facing) or gap < 0.01:
			return false
		if gap <= Coherency.MAX_GAP:
			near += 1
	return near >= needed


## How far back a model on [param base] sits when nestled between two others [param across_step]
## apart, so it's [param gap] from each, edge to edge: half a hexagon for round bases, measured for
## others.
static func nestle_depth(base: BaseSize, across_step: float, gap: float) -> float:
	var low := 0.0
	var high := base.footprint().x + gap
	var side := Vector2(0, across_step / 2)
	for i in 30:
		var middle := (low + high) / 2
		# In the base's own frame: x along the facing, so "back" is -x.
		if DeploymentRules.base_gap(base, Vector2.ZERO, 0.0, base, Vector2(-middle, 0) + side, 0.0) < gap:
			low = middle
		else:
			high = middle
	return low


## Offsets as (across, back): one rank, or for big units two staggered rows, so the models at
## each end still have two neighbours.
static func _line(count: int, step: float, nestle: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if count <= SINGLE_RANK_LINE:
		for i in count:
			result.append(Vector2(i * step, 0))
		return result
	for i in count:
		result.append(Vector2(i * step / 2, nestle if i % 2 == 1 else 0.0))
	return result


## Offsets in ranks of [param columns]. A part-filled last rank sits nestled between the models in
## front of it, from the middle out, so each of its models touches two of them.
static func _block(count: int, columns: int, across_step: float, depth_step: float, nestle: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	columns = maxi(columns, 1)
	@warning_ignore("integer_division")
	var full_ranks := count / columns
	for i in full_ranks * columns:
		@warning_ignore("integer_division")
		result.append(Vector2((i % columns) * across_step, (i / columns) * depth_step))
	var left_over := count - full_ranks * columns
	if left_over == 0:
		return result
	if full_ranks == 0:
		for i in left_over:
			result.append(Vector2(i * across_step, 0))
		return result
	var depth := (full_ranks - 1) * depth_step + nestle
	for slot in _middle_out(columns - 1, left_over):
		result.append(Vector2((slot + 0.5) * across_step, depth))
	return result


## [param count] of the slots 0 to [param slots] - 1, from the middle out, in order.
static func _middle_out(slots: int, count: int) -> Array[int]:
	var order: Array[int] = []
	for i in slots:
		order.append(i)
	var middle := (slots - 1) / 2.0
	order.sort_custom(func(a: int, b: int) -> bool:
		return absf(a - middle) < absf(b - middle) or (absf(a - middle) == absf(b - middle) and a < b))
	var picked := order.slice(0, count)
	picked.sort()
	return picked


## Offsets in rows of 1, 2, 3 and so on behind the point, packed so each model touches those
## beside and in front of it. A part-filled last row fills its middle first.
static func _wedge(count: int, step: float, nestle: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var row := 0
	while result.size() < count:
		var left := count - result.size()
		var slots: Array[int] = []
		if left >= row + 1:
			for j in row + 1:
				slots.append(j)
		else:
			# The middle slots touch two models in front; the end ones only one.
			for j in _middle_out(row - 1, mini(left, row - 1)):
				slots.append(j + 1)
			if left > row - 1:
				slots.append(0)
		for j in slots:
			result.append(Vector2((j - row / 2.0) * step, row * nestle))
		row += 1
	return result


## Turns (across, back) offsets into battlefield positions centred on [param anchor].
static func _place(offsets: Array[Vector2], anchor: Vector2, facing: float) -> PackedVector2Array:
	var middle := Vector2.ZERO
	for offset in offsets:
		middle += offset
	middle /= offsets.size()
	var forward := Vector2.from_angle(facing)
	var across := Vector2(-forward.y, forward.x)
	var result := PackedVector2Array()
	for offset in offsets:
		var local := offset - middle
		# The first rank is at the front, towards the enemy.
		result.append(anchor + across * local.x - forward * local.y)
	return result
