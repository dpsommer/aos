class_name PlaceholderDeployment
extends RefCounted
## Sets both armies up in their territories until the deployment screens exist: each side's
## terrain features first, then its units in blocks, filling its territory from the edge farthest
## from the enemy. Every base is wholly within its territory and clear of terrain and other units.
## Positions are in inches. See docs/design/battle.md.

## Gap between a unit's models: coherency is 1/2".
const MODEL_GAP := 0.5
## Gap between units, and between models and terrain.
const UNIT_GAP := 1.0
## Faction and Spearhead terrain goes more than this far from objectives and other terrain.
const TERRAIN_GAP := 3.0
## Spacing of the spots tried for a unit or a terrain feature.
const STEP := 1.0
## Most models in a unit's front rank.
const MAX_RANK := 10


## Sets up [param battle]'s armies: fills in [member BattleTerrain.position] for each army's
## terrain, [member BattleUnit.positions] and each army's [member BattleArmy.facing].
static func deploy(battle: Battle) -> void:
	var space := Space.new()
	for feature in battle.terrain:
		space.add(feature.position, feature.reach())
	for side in [[battle.player, battle.player_territory, battle.opponent_territory],
			[battle.opponent, battle.opponent_territory, battle.player_territory]]:
		var army: BattleArmy = side[0]
		var own: Array[PackedVector2Array] = side[1]
		var enemy: Array[PackedVector2Array] = side[2]
		var back := centroid(own) - centroid(enemy)
		back = back.normalized() if back.length() > 0.001 else Vector2.DOWN
		army.facing = (-back).angle()
		for feature in army.terrain:
			_place_terrain(feature, own, battle, space, back)
	for side in [[battle.player, battle.player_territory], [battle.opponent, battle.opponent_territory]]:
		var army: BattleArmy = side[0]
		var own: Array[PackedVector2Array] = side[1]
		var back := -Vector2.from_angle(army.facing)
		var spots := _spots(own, back)
		for unit in army.units:
			_place_unit(unit, own, back, spots, space)


## Each unit's models in ranks: the front rank (up to [constant MAX_RANK], two ranks for 6 or more
## models) across [param back], later ranks towards the enemy, [param step] apart. Offsets from
## the middle of the back rank.
static func formation(model_count: int, step: float, back: Vector2) -> PackedVector2Array:
	var across := Vector2(-back.y, back.x)
	var columns := model_count if model_count <= 5 else mini(ceili(model_count / 2.0), MAX_RANK)
	var result := PackedVector2Array()
	for i in model_count:
		@warning_ignore("integer_division")
		var rank := i / columns
		var column := i % columns
		result.append(across * (column - (columns - 1) / 2.0) * step - back * rank * step)
	return result


## The middle of [param polygons]: the average of their corners.
static func centroid(polygons: Array[PackedVector2Array]) -> Vector2:
	var total := Vector2.ZERO
	var count := 0
	for polygon in polygons:
		for point in polygon:
			total += point
			count += 1
	return total / count if count > 0 else Vector2.ZERO


## Whether a circle of [param radius] at [param point] is wholly within one of [param polygons].
static func is_wholly_within(polygons: Array[PackedVector2Array], point: Vector2, radius: float) -> bool:
	for polygon in polygons:
		if not Geometry2D.is_point_in_polygon(point, polygon):
			continue
		var clear := true
		for i in polygon.size():
			var closest := Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])
			if closest.distance_to(point) < radius - 0.001:
				clear = false
				break
		if clear:
			return true
	return false


## Tries the rules' gap first, then smaller ones if the territory is too cramped for it.
static func _place_terrain(feature: BattleTerrain, own: Array[PackedVector2Array], battle: Battle, space: Space, back: Vector2) -> void:
	var middle := centroid(own)
	var spots := Array(_grid(own, STEP / 2))
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(middle) < b.distance_squared_to(middle))
	var reach := feature.reach()
	for gap: float in [TERRAIN_GAP, UNIT_GAP, 0.0]:
		for spot: Vector2 in spots:
			if _terrain_fits(spot, reach, gap, own, battle, space):
				feature.position = spot
				feature.rotation = Vector2(-back.y, back.x).angle()
				feature.placed = true
				space.add(spot, reach)
				return


static func _terrain_fits(spot: Vector2, reach: float, gap: float, own: Array[PackedVector2Array], battle: Battle, space: Space) -> bool:
	if not is_wholly_within(own, spot, reach) or not space.is_clear(spot, reach + gap):
		return false
	for objective in battle.objectives:
		if spot.distance_to(objective.position) < reach + gap + Battle.OBJECTIVE_MARKER / 2:
			return false
	return true


static func _place_unit(unit: BattleUnit, own: Array[PackedVector2Array], back: Vector2, spots: PackedVector2Array, space: Space) -> void:
	var widest := 0.0
	for base in unit.bases:
		widest = maxf(widest, base.footprint().x)
	var offsets := formation(unit.model_count(), widest + MODEL_GAP, back)
	for spot in spots:
		var positions := PackedVector2Array()
		for i in offsets.size():
			var at := spot + offsets[i]
			var radius := unit.bases[i].footprint().x / 2
			if not is_wholly_within(own, at, radius) or not space.is_clear(at, radius + UNIT_GAP):
				break
			positions.append(at)
		if positions.size() == offsets.size():
			unit.positions = positions
			for i in positions.size():
				space.add(positions[i], unit.bases[i].footprint().x / 2)
			return
	# No room for a block: each model wherever it fits.
	unit.positions = PackedVector2Array()
	for base in unit.bases:
		var radius := base.footprint().x / 2
		var at := centroid(own)
		for spot in _grid(own, STEP / 2):
			if is_wholly_within(own, spot, radius) and space.is_clear(spot, radius + MODEL_GAP):
				at = spot
				break
		unit.positions.append(at)
		space.add(at, radius)


## Spots to try for units, back rank first, from the middle outwards along each rank.
static func _spots(own: Array[PackedVector2Array], back: Vector2) -> PackedVector2Array:
	var across := Vector2(-back.y, back.x)
	var middle := centroid(own)
	var spots := Array(_grid(own))
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var rank_a := roundf(a.dot(back) / STEP)
		var rank_b := roundf(b.dot(back) / STEP)
		if rank_a != rank_b:
			return rank_a > rank_b
		return absf((a - middle).dot(across)) < absf((b - middle).dot(across)))
	return PackedVector2Array(spots)


## Points [param step] apart across the territory's bounds that are in the territory.
static func _grid(own: Array[PackedVector2Array], step := STEP) -> PackedVector2Array:
	var result := PackedVector2Array()
	for polygon in own:
		if polygon.is_empty():
			continue
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			bounds = bounds.expand(point)
		var y := bounds.position.y + step / 2
		while y < bounds.end.y:
			var x := bounds.position.x + step / 2
			while x < bounds.end.x:
				var point := Vector2(x, y)
				if Geometry2D.is_point_in_polygon(point, polygon):
					result.append(point)
				x += step
			y += step
	return result


## Circles already on the battlefield, bucketed by area so checks stay fast with big armies.
class Space:
	const CELL := 4.0
	## Vector2i cell -> Array of Vector3(x, y, radius).
	var _cells := {}
	var _largest := 0.0

	func add(point: Vector2, radius: float) -> void:
		var cell := Vector2i((point / CELL).floor())
		if not _cells.has(cell):
			_cells[cell] = []
		_cells[cell].append(Vector3(point.x, point.y, radius))
		_largest = maxf(_largest, radius)

	## Whether a circle of [param radius] at [param point] overlaps nothing added so far.
	func is_clear(point: Vector2, radius: float) -> bool:
		var reach := ceili((radius + _largest) / CELL)
		var cell := Vector2i((point / CELL).floor())
		for dx in range(-reach, reach + 1):
			for dy in range(-reach, reach + 1):
				for circle: Vector3 in _cells.get(cell + Vector2i(dx, dy), []):
					if point.distance_to(Vector2(circle.x, circle.y)) < radius + circle.z:
						return false
		return true
