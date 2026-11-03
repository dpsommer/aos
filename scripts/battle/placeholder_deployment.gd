class_name PlaceholderDeployment
extends RefCounted
## Automatic deployment: sets terrain features and units up in a territory without asking, units in
## blocks filling it from the edge farthest from the enemy. The AI uses it for whatever it can't
## mirror from the player ([MirrorDeployer]) until it has a deployment AI of its own. Every base
## is wholly within the zone and clear of terrain and other units. Positions are in inches. See
## docs/gameplay/deployment.md.

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
## How many turns a terrain feature is tried at, over half a turn (it's symmetrical).
const TERRAIN_TURNS := 8
## How many different spots are tried for a terrain feature to leave room for the next one.
const LOOKAHEAD := 24
## Spots tried for a terrain feature are at least this far apart.
const SPREAD := 2.0


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
			unit.facing = army.facing
			unit.deployed = true


## Where [param unit] of [param army] could be set up: its models' positions in a block wholly
## within [param zone] (the army's deployable zone if empty), clear of terrain, other models and the
## models of [param staged] (units set out but not yet deployed), or an empty array if there's no
## room. Doesn't set the unit up. [param packed] packs it in tight instead, for a cramped zone: from
## one end of the back rank along, as near other units as it will go (see [method spots_for_army]).
static func spot_for_unit(battle: Battle, army: BattleArmy, unit: BattleUnit,
		zone: Array[PackedVector2Array] = [], staged: Array[BattleUnit] = [], packed := false) -> PackedVector2Array:
	if zone.is_empty():
		zone = DeploymentRules.unit_zone(battle, army)
	# Packed in, models may stand in the battlefield's terrain, as the rules allow.
	var space := space_of(battle, staged, not packed)
	var back := -Vector2.from_angle(army.facing)
	var shapes := _shapes(unit, back, army.facing)
	if packed:
		var spots := _packed_spots(zone, back)
		for gap: float in [MODEL_GAP, 0.05]:
			for spot in spots:
				for offsets in shapes:
					var positions := _try(unit, spot, offsets, zone, space, gap, army.facing)
					if not positions.is_empty():
						return positions
		return PackedVector2Array()
	var spots := _spots(zone, back)
	# The rules' gap between units first, then tighter ones if the zone is too cramped for it.
	for gap: float in [UNIT_GAP, MODEL_GAP, 0.05]:
		for offsets in shapes:
			for spot in spots:
				var positions := _try(unit, spot, offsets, zone, space, gap)
				if not positions.is_empty():
					return positions
	return PackedVector2Array()


## Spots for every one of [param units] of [param army] at once, by unit, each clear of the others
## and of [param staged]: the biggest first, spread out as [method spot_for_unit] does if they all
## fit, else packed in tight from one end. A unit with no room at all gets an empty array.
static func spots_for_army(battle: Battle, army: BattleArmy, units: Array[BattleUnit],
		staged: Array[BattleUnit] = []) -> Dictionary:
	var zone := DeploymentRules.unit_zone(battle, army)
	var order := units.duplicate()
	order.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return _area(a) > _area(b))
	var result := {}
	for packed in [false, true]:
		result = _army_spots(battle, army, order, zone, staged, packed)
		if result.values().all(func(positions: PackedVector2Array) -> bool: return not positions.is_empty()):
			break
	return result


static func _army_spots(battle: Battle, army: BattleArmy, units: Array, zone: Array[PackedVector2Array],
		staged: Array[BattleUnit], packed: bool) -> Dictionary:
	var result := {}
	var taken := staged.duplicate()
	var saved := {}
	for unit: BattleUnit in units:
		saved[unit] = [unit.positions, unit.facing]
	for unit: BattleUnit in units:
		unit.facing = army.facing
		var positions := spot_for_unit(battle, army, unit, zone, taken, packed)
		result[unit] = positions
		# Counted as set out while the rest are placed, then put back as they were.
		unit.positions = positions
		taken.append(unit)
	for unit: BattleUnit in units:
		unit.positions = saved[unit][0]
		unit.facing = saved[unit][1]
	return result


## The ground [param unit]'s bases cover.
static func _area(unit: BattleUnit) -> float:
	var total := 0.0
	for base in unit.bases:
		total += base.footprint().x * base.footprint().y
	return total


## The arrangements to try for [param unit], as offsets: blocks filling from the back rank, then
## narrower and wider formations; only those in coherency, so the unit can be set up there.
static func _shapes(unit: BattleUnit, back: Vector2, facing: float) -> Array[PackedVector2Array]:
	var shapes: Array[PackedVector2Array] = []
	var tries: Array[PackedVector2Array] = [_block_formation(unit, back)]
	for kind in [Formations.Kind.NARROW_BLOCK, Formations.Kind.WIDE_BLOCK, Formations.Kind.LINE, Formations.Kind.WEDGE]:
		tries.append(Formations.arrange(kind, unit.bases, Vector2.ZERO, facing))
	for offsets in tries:
		if Coherency.is_coherent(offsets, unit.bases, facing):
			shapes.append(offsets)
	return shapes


## [param unit]'s models in [param offsets] from [param spot], if they're all wholly within
## [param zone] and [param gap] clear of everything in [param space]; else empty. With
## [param facing], bases are checked by their real shape, so ovals pack closer; without, as
## circles.
static func _try(unit: BattleUnit, spot: Vector2, offsets: PackedVector2Array, zone: Array[PackedVector2Array],
		space: Space, gap: float, facing := NAN) -> PackedVector2Array:
	var positions := PackedVector2Array()
	for i in offsets.size():
		var at := spot + offsets[i]
		var base := unit.bases[i]
		var radius := DeploymentRules.reach_of(base)
		var within := is_wholly_within(zone, at, radius) if is_nan(facing) \
				else DeploymentRules.is_wholly_within(zone, DeploymentRules.base_outline(base, at, facing))
		if not within:
			return PackedVector2Array()
		var clear := space.is_clear(at, radius + gap) if is_nan(facing) else space.is_clear_of(at, base, facing, gap)
		if not clear:
			return PackedVector2Array()
		positions.append(at)
	return positions


## Where [param feature] of [param army] could be set up within the deployment rules
## ([method DeploymentRules.terrain_problems]), nearest the middle of its territory, as
## [code]{"at": Vector2, "rotation": float}[/code], or an empty dictionary if nowhere will do.
## [param relaxed] lets it go nearer other terrain than the rules allow, as long as it doesn't touch.
static func spot_for_terrain(battle: Battle, army: BattleArmy, feature: BattleTerrain, relaxed := false) -> Dictionary:
	# A coarse grid first, as it's much quicker; a fine one only if that finds nothing.
	var candidates := _terrain_spots(battle, army, feature, relaxed, STEP)
	if candidates.is_empty():
		candidates = _terrain_spots(battle, army, feature, relaxed, STEP / 2)
	var next := _next_unplaced(army, feature)
	if next == null or relaxed or candidates.is_empty():
		return candidates[0] if not candidates.is_empty() else {}
	# Leave room for the army's next feature: the best spot that still has one for it.
	for i in mini(candidates.size(), LOOKAHEAD):
		var candidate: Dictionary = candidates[i]
		feature.position = candidate.at
		feature.rotation = candidate.rotation
		feature.placed = true
		var room := not _terrain_spots(battle, army, next, false, STEP, true).is_empty()
		feature.placed = false
		if room:
			return candidate
	return candidates[0]


## [param army]'s first terrain feature not yet set up other than [param feature], or null.
static func _next_unplaced(army: BattleArmy, feature: BattleTerrain) -> BattleTerrain:
	for other in army.unplaced_terrain():
		if other != feature:
			return other
	return null


## A good spot for [param feature], without leaving room for the army's next one: quick, for a
## suggestion to the player. Empty if there's none.
static func first_terrain_spot(battle: Battle, army: BattleArmy, feature: BattleTerrain, relaxed := false) -> Dictionary:
	var spots := _terrain_spots(battle, army, feature, relaxed, STEP / 2)
	return spots[0] if not spots.is_empty() else {}


## Whether [param feature] has any spot that meets the deployment rules in full.
static func has_terrain_spot(battle: Battle, army: BattleArmy, feature: BattleTerrain) -> bool:
	return not _terrain_spots(battle, army, feature, false, STEP, true).is_empty() \
			or not _terrain_spots(battle, army, feature, false, STEP / 2, true).is_empty()


## Valid spots for [param feature] on a grid [param step] apart, best first (see
## [method _clearance]); just the first valid one if [param any].
static func _terrain_spots(battle: Battle, army: BattleArmy, feature: BattleTerrain, relaxed: bool, step: float, any := false) -> Array[Dictionary]:
	var zone := DeploymentRules.terrain_zone(battle, army)
	var middle := centroid(battle.territory_of(army))
	var others: Array[PackedVector2Array] = []
	for other in battle.all_terrain():
		if other != feature and other.placed:
			others.append(DeploymentRules.terrain_outline(other, other.position, other.rotation))
	# Relaxed, it only has to keep off other terrain, not the rules' gap from it.
	var gap := 0.0 if relaxed else -1.0
	var found: Array[Dictionary] = []
	for turn in TERRAIN_TURNS:
		var rotation := army.facing + PI / 2 + turn * PI / TERRAIN_TURNS
		for spot in _grid(zone, step):
			if not DeploymentRules.terrain_problems(battle, army, feature, spot, rotation, gap, zone).is_empty():
				continue
			found.append({"at": spot, "rotation": rotation,
					"score": _clearance(DeploymentRules.terrain_outline(feature, spot, rotation), others, spot, middle)})
			if any:
				return found
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	return _spread_out(found)


## The best of [param candidates] (best first) in each area: none within [constant SPREAD] of a
## better one, so the lookahead tries different places.
static func _spread_out(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var spread: Array[Dictionary] = []
	for candidate in candidates:
		if not spread.any(func(kept: Dictionary) -> bool: return kept.at.distance_to(candidate.at) < SPREAD):
			spread.append(candidate)
	return spread


## How well a feature with [param outline] at [param spot] leaves room for others: its gap to the
## nearest other terrain, then, with none yet, how far it is from the territory's [param middle],
## so the first feature goes to a corner and leaves the middle free.
static func _clearance(outline: PackedVector2Array, others: Array[PackedVector2Array], spot: Vector2, middle: Vector2) -> float:
	var nearest := INF
	for other in others:
		nearest = minf(nearest, DeploymentRules.gap_between(outline, other))
	var spread := spot.distance_to(middle) / 100.0
	return (nearest if nearest < INF else 1000.0) + spread


## Everything already on [param battle]'s battlefield as circles: placed terrain features (only
## those models can't stand in, unless [param all_terrain]), deployed models and the models of
## [param staged].
static func space_of(battle: Battle, staged: Array[BattleUnit] = [], all_terrain := true) -> Space:
	var space := Space.new()
	for unit in staged:
		if not unit.deployed:
			space.add_unit(unit)
	for feature in battle.all_terrain():
		if feature.placed and (all_terrain or DeploymentRules.is_impassable(feature)):
			space.add(feature.position, feature.reach())
	for army in [battle.player, battle.opponent]:
		if army == null:
			continue
		for unit: BattleUnit in army.units:
			if unit.is_on_battlefield():
				space.add_unit(unit)
	return space


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
		if Geometry2D.is_point_in_polygon(point, polygon) and DeploymentRules.edge_distance(polygon, point) >= radius - 0.001:
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


## [param unit]'s models in a [method formation], spaced for its widest base.
static func _block_formation(unit: BattleUnit, back: Vector2) -> PackedVector2Array:
	var widest := 0.0
	for base in unit.bases:
		widest = maxf(widest, base.footprint().x)
	return formation(unit.model_count(), widest + MODEL_GAP, back)


static func _place_unit(unit: BattleUnit, own: Array[PackedVector2Array], back: Vector2, spots: PackedVector2Array, space: Space) -> void:
	var offsets := _block_formation(unit, back)
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
	return _by_rank(_grid(own), back, func(spot: Vector2) -> float: return absf((spot - middle).dot(across)))


## Spots to try for units packed in tight: back rank first, from one end of each rank to the other.
static func _packed_spots(own: Array[PackedVector2Array], back: Vector2) -> PackedVector2Array:
	var across := Vector2(-back.y, back.x)
	# Fine enough for a big base that only just fits the zone's depth.
	return _by_rank(_grid(own, STEP / 4), back, func(spot: Vector2) -> float: return spot.dot(across))


## [param spots] in ranks [constant STEP] deep across [param back], the back rank first, each rank
## in order of [param along] (lowest first).
static func _by_rank(spots: PackedVector2Array, back: Vector2, along: Callable) -> PackedVector2Array:
	var sorted := Array(spots)
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var rank_a := roundf(a.dot(back) / STEP)
		var rank_b := roundf(b.dot(back) / STEP)
		if rank_a != rank_b:
			return rank_a > rank_b
		return along.call(a) < along.call(b))
	return PackedVector2Array(sorted)


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
	## The models added with [method add_model], by their Vector3 in [member _cells]: [base, facing].
	var _models := {}
	var _largest := 0.0

	func add(point: Vector2, radius: float) -> void:
		var cell := Vector2i((point / CELL).floor())
		if not _cells.has(cell):
			_cells[cell] = []
		_cells[cell].append(Vector3(point.x, point.y, radius))
		_largest = maxf(_largest, radius)

	## Adds a model on [param base] at [param point], facing [param facing]: a circle round it, and
	## its real shape for [method is_clear_of].
	func add_model(point: Vector2, base: BaseSize, facing: float) -> void:
		var radius := DeploymentRules.reach_of(base)
		add(point, radius)
		_models[Vector3(point.x, point.y, radius)] = [base, facing]

	## Adds every model of [param unit] where it stands ([method add_model]).
	func add_unit(unit: BattleUnit) -> void:
		for i in unit.positions.size():
			add_model(unit.positions[i], unit.bases[i], unit.facing)

	## Whether a model on [param base] at [param point], facing [param facing], is at least
	## [param gap] from everything added so far: models by their real shape, the rest as circles.
	func is_clear_of(point: Vector2, base: BaseSize, facing: float, gap: float) -> bool:
		var radius := DeploymentRules.reach_of(base)
		var reach := ceili((radius + gap + _largest) / CELL)
		var cell := Vector2i((point / CELL).floor())
		for dx in range(-reach, reach + 1):
			for dy in range(-reach, reach + 1):
				for circle: Vector3 in _cells.get(cell + Vector2i(dx, dy), []):
					var at := Vector2(circle.x, circle.y)
					if point.distance_to(at) >= radius + circle.z + gap:
						continue
					var model: Array = _models.get(circle, [])
					if model.is_empty():
						return false
					if DeploymentRules.bases_overlap(base, point, facing, model[0], at, model[1]) \
							or DeploymentRules.base_gap(base, point, facing, model[0], at, model[1]) < gap:
						return false
		return true

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
