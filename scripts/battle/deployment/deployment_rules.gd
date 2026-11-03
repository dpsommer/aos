class_name DeploymentRules
extends RefCounted
## Where units and terrain features can be set up during deployment, as geometry: each side's
## deployable zone, base and terrain outlines, overlaps and the gaps the rules ask for. Positions
## are in inches from the battlefield's north-west corner. See docs/gameplay/deployment.md.

## Units are set up more than this far from enemy territory: 'Deploy Unit' (Core Rules).
const MATCHED_PLAY_GAP := 9.0
## Spearhead units are set up more than this far from enemy territory (Spearhead: Deployment).
const SPEARHEAD_GAP := 6.0
## Faction terrain goes more than this far from objectives and other terrain: 'Deploy Faction
## Terrain' (Core Rules).
const FACTION_TERRAIN_GAP := 3.0
## Spearhead terrain goes more than this far from other terrain features (Pre-battle Sequence).
const SPEARHEAD_TERRAIN_GAP := 6.0
## Spearhead terrain goes more than this far from the long battlefield edges and enemy territory.
const SPEARHEAD_EDGE_GAP := 3.0
## Points around a base or round feature's outline.
const OUTLINE_POINTS := 24
## Slack for points that sit exactly on an edge.
const EPSILON := 0.001


## [param own] territory less everything within [param gap] of [param enemy] territory: where a base
## can be set up wholly within friendly territory and more than [param gap] from enemy territory.
static func zone(own: Array[PackedVector2Array], enemy: Array[PackedVector2Array], gap: float) -> Array[PackedVector2Array]:
	var cutters: Array[PackedVector2Array] = []
	for polygon in enemy:
		for grown in Geometry2D.offset_polygon(polygon, gap, Geometry2D.JOIN_ROUND):
			if not Geometry2D.is_polygon_clockwise(grown) == Geometry2D.is_polygon_clockwise(polygon):
				continue
			cutters.append(grown)
	var result: Array[PackedVector2Array] = []
	for polygon in own:
		var pieces: Array[PackedVector2Array] = [polygon]
		for cutter in cutters:
			var next: Array[PackedVector2Array] = []
			for piece in pieces:
				for part in Geometry2D.clip_polygons(piece, cutter):
					# A hole runs the other way round; territories never wrap around each other.
					if Geometry2D.is_polygon_clockwise(part) == Geometry2D.is_polygon_clockwise(piece):
						next.append(part)
			pieces = next
		result.append_array(pieces)
	return result


## How far from enemy territory units are set up in [param battle]: 9" in Matched Play, 6" in
## Spearhead.
static func unit_gap(battle: Battle) -> float:
	return SPEARHEAD_GAP if battle.is_spearhead() else MATCHED_PLAY_GAP


## The deployable zone for [param army]'s units in [param battle]: more than [method unit_gap] from
## enemy territory.
static func unit_zone(battle: Battle, army: BattleArmy) -> Array[PackedVector2Array]:
	return zone(battle.territory_of(army), battle.enemy_territory_of(army), unit_gap(battle))


## Where [param army]'s terrain features can go: its territory, and in Spearhead more than 3" from
## enemy territory and the long battlefield edges.
static func terrain_zone(battle: Battle, army: BattleArmy) -> Array[PackedVector2Array]:
	var own := battle.territory_of(army)
	if not battle.is_spearhead():
		return own
	var size := battle.battlefield_size
	var edges: Array[PackedVector2Array] = []
	# The long edges are the battlefield's width.
	var long_is_x := size.x >= size.y
	if long_is_x:
		edges.append(_rect(Vector2(-1, -1), Vector2(size.x + 2, SPEARHEAD_EDGE_GAP + 1)))
		edges.append(_rect(Vector2(-1, size.y - SPEARHEAD_EDGE_GAP), Vector2(size.x + 2, SPEARHEAD_EDGE_GAP + 1)))
	else:
		edges.append(_rect(Vector2(-1, -1), Vector2(SPEARHEAD_EDGE_GAP + 1, size.y + 2)))
		edges.append(_rect(Vector2(size.x - SPEARHEAD_EDGE_GAP, -1), Vector2(SPEARHEAD_EDGE_GAP + 1, size.y + 2)))
	var away := zone(own, battle.enemy_territory_of(army), SPEARHEAD_EDGE_GAP)
	return zone(away, edges, 0.0)


static func _rect(at: Vector2, size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, Vector2(at.x + size.x, at.y), at + size, Vector2(at.x, at.y + size.y)])


## Points around a model on [param base] at [param at], facing [param facing] (radians clockwise
## from east): an ellipse for round and oval bases, its long side along the facing, and a
## rectangle for a model with no base.
static func base_outline(base: BaseSize, at: Vector2, facing: float) -> PackedVector2Array:
	var footprint := base.footprint()
	if base.shape == BaseSize.Shape.MODEL:
		return rect_outline(footprint, at, facing)
	return ellipse_outline(footprint, at, facing)


static func ellipse_outline(footprint: Vector2, at: Vector2, facing: float) -> PackedVector2Array:
	var along := Vector2.from_angle(facing)
	var across := Vector2(-along.y, along.x)
	var result := PackedVector2Array()
	for i in OUTLINE_POINTS:
		var angle := TAU * i / OUTLINE_POINTS
		result.append(at + along * cos(angle) * footprint.x / 2 + across * sin(angle) * footprint.y / 2)
	return result


static func rect_outline(footprint: Vector2, at: Vector2, facing: float) -> PackedVector2Array:
	var along := Vector2.from_angle(facing) * footprint.x / 2
	var across := Vector2.from_angle(facing + PI / 2) * footprint.y / 2
	return PackedVector2Array([at + along + across, at - along + across, at - along - across, at + along - across])


## [param feature]'s outline at [param at], turned by [param rotation].
static func terrain_outline(feature: BattleTerrain, at: Vector2, rotation: float) -> PackedVector2Array:
	if TerrainPlaceholder.is_round(feature):
		return ellipse_outline(feature.footprint, at, rotation)
	return rect_outline(feature.footprint, at, rotation)


## Whether every point of [param outline] is inside one of [param polygons], edges included.
static func is_wholly_within(polygons: Array[PackedVector2Array], outline: PackedVector2Array) -> bool:
	for polygon in polygons:
		var inside := true
		for point in outline:
			if not _contains(polygon, point):
				inside = false
				break
		if inside:
			return true
	return false


static func _contains(polygon: PackedVector2Array, point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, polygon) or edge_distance(polygon, point) <= EPSILON


## The distance from [param point] to the nearest edge of [param polygon], inside or out (INF if
## it has no points).
static func edge_distance(polygon: PackedVector2Array, point: Vector2) -> float:
	var best := INF
	for i in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])
		best = minf(best, closest.distance_to(point))
	return best


## The shortest distance between two outlines, or 0 if they overlap.
static func gap_between(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if not Geometry2D.intersect_polygons(a, b).is_empty():
		return 0.0
	return minf(_one_way_gap(a, b), _one_way_gap(b, a))


static func _one_way_gap(from: PackedVector2Array, to: PackedVector2Array) -> float:
	var best := INF
	for point in from:
		best = minf(best, edge_distance(to, point))
	return best


## The gap between two models' bases, edge to edge (0 if they overlap). Round bases are measured
## exactly; others by their outlines.
static func base_gap(base_a: BaseSize, at_a: Vector2, facing_a: float, base_b: BaseSize, at_b: Vector2, facing_b: float) -> float:
	if base_a.shape == BaseSize.Shape.ROUND and base_b.shape == BaseSize.Shape.ROUND:
		return maxf(at_a.distance_to(at_b) - base_a.footprint().x / 2 - base_b.footprint().x / 2, 0.0)
	return gap_between(base_outline(base_a, at_a, facing_a), base_outline(base_b, at_b, facing_b))


## Whether two models' bases overlap. Touching isn't overlapping.
static func bases_overlap(base_a: BaseSize, at_a: Vector2, facing_a: float, base_b: BaseSize, at_b: Vector2, facing_b: float) -> bool:
	if at_a.distance_to(at_b) >= reach_of(base_a) + reach_of(base_b):
		return false
	if base_a.shape == BaseSize.Shape.ROUND and base_b.shape == BaseSize.Shape.ROUND:
		return at_a.distance_to(at_b) < base_a.footprint().x / 2 + base_b.footprint().x / 2 - EPSILON
	return _polygons_overlap(base_outline(base_a, at_a, facing_a), base_outline(base_b, at_b, facing_b))


## Whether two outlines share more than an edge or a point.
static func _polygons_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for part in Geometry2D.intersect_polygons(a, b):
		if absf(_area(part)) > EPSILON:
			return true
	return false


static func _area(polygon: PackedVector2Array) -> float:
	var total := 0.0
	for i in polygon.size():
		total += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return total / 2


## The radius of a circle around [param base], whichever way it faces.
static func reach_of(base: BaseSize) -> float:
	var footprint := base.footprint()
	return footprint.length() / 2 if base.shape == BaseSize.Shape.MODEL else maxf(footprint.x, footprint.y) / 2


## Whether models can't be set up overlapping [param feature]: faction terrain, which is a model on
## its own base. Models can stand in and on the battlefield's terrain (ruins, woods, walls), as the
## simulator doesn't model their shape yet.
static func is_impassable(feature: BattleTerrain) -> bool:
	return feature.kind == BattleTerrain.Kind.FACTION


## What's wrong with setting up [param unit] of [param army] with its models at [param positions],
## facing [param facing], as sentences for the placing panel. Empty if it can go there.
## [param zone] defaults to the army's deployable zone. [param staged] are units set out but not yet
## deployed (a Spearhead army being arranged), whose models it mustn't overlap either.
static func unit_problems(battle: Battle, army: BattleArmy, unit: BattleUnit, positions: PackedVector2Array,
		facing: float, zone_polygons: Array[PackedVector2Array] = [], staged: Array[BattleUnit] = []) -> PackedStringArray:
	var bad := invalid_models(battle, army, unit, positions, facing, zone_polygons, staged)
	var problems := PackedStringArray()
	if bad.outside.size() > 0:
		problems.append("%s outside your deployable zone: wholly within your territory and more than %d\" from enemy territory." \
				% [_models(bad.outside.size()), int(unit_gap(battle))])
	if bad.overlapping.size() > 0:
		problems.append("%s overlapping other models or terrain." % _models(bad.overlapping.size()))
	if bad.incoherent.size() > 0:
		var needed := "2 other models" if positions.size() >= Coherency.LARGE_UNIT else "another model"
		problems.append("%s out of coherency: each must be within ½\" of %s, in one group." % [_models(bad.incoherent.size()), needed])
	return problems


static func _models(count: int) -> String:
	return "1 model is" if count == 1 else "%d models are" % count


## The models of [param unit] that can't go where [param positions] puts them, by reason:
## [code]outside[/code] the zone, [code]overlapping[/code] other models or impassable terrain, and
## [code]incoherent[/code]. Each is a [PackedInt32Array] of model indices. [param staged] as in
## [method unit_problems].
static func invalid_models(battle: Battle, army: BattleArmy, unit: BattleUnit, positions: PackedVector2Array,
		facing: float, zone_polygons: Array[PackedVector2Array] = [], staged: Array[BattleUnit] = []) -> Dictionary:
	if zone_polygons.is_empty():
		zone_polygons = unit_zone(battle, army)
	var outside := PackedInt32Array()
	var overlapping := PackedInt32Array()
	var others := _other_models(battle, unit, staged)
	var blocks: Array[BattleTerrain] = []
	for feature in battle.all_terrain():
		if feature.placed and is_impassable(feature):
			blocks.append(feature)
	for i in positions.size():
		var base := unit.bases[i]
		var outline := base_outline(base, positions[i], facing)
		if not is_wholly_within(zone_polygons, outline):
			outside.append(i)
		if _overlaps(base, positions[i], facing, outline, others, blocks):
			overlapping.append(i)
	for j in positions.size():
		for k in range(j + 1, positions.size()):
			if bases_overlap(unit.bases[j], positions[j], facing, unit.bases[k], positions[k], facing):
				for i in [j, k]:
					if not i in overlapping:
						overlapping.append(i)
	return {
		"outside": outside,
		"overlapping": overlapping,
		"incoherent": Coherency.failing(positions, unit.bases, facing),
	}


## Every deployed model on the battlefield but [param unit]'s, and those of [param staged], as
## [unit, index] pairs.
static func _other_models(battle: Battle, unit: BattleUnit, staged: Array[BattleUnit] = []) -> Array:
	var result := []
	for other in staged:
		if other != unit and not other.deployed:
			for i in other.positions.size():
				result.append([other, i])
	for army in [battle.player, battle.opponent]:
		if army == null:
			continue
		for other: BattleUnit in army.units:
			if other == unit or not other.is_on_battlefield():
				continue
			for i in other.positions.size():
				result.append([other, i])
	return result


static func _overlaps(base: BaseSize, at: Vector2, facing: float, outline: PackedVector2Array, others: Array, blocks: Array[BattleTerrain]) -> bool:
	var reach := reach_of(base)
	for pair: Array in others:
		var other: BattleUnit = pair[0]
		var i: int = pair[1]
		if bases_overlap(base, at, facing, other.bases[i], other.positions[i], other.facing):
			return true
	for feature in blocks:
		if at.distance_to(feature.position) >= reach + feature.reach():
			continue
		if _polygons_overlap(outline, terrain_outline(feature, feature.position, feature.rotation)):
			return true
	return false


## What's wrong with setting up [param feature] of [param army] at [param at], turned by
## [param rotation]. Empty if it can go there. [param terrain_gap] overrides how far it must be from
## other terrain (for the AI when nowhere meets the rules); negative uses the rules'.
## [param zone_polygons] is [method terrain_zone], worked out once by callers that check many spots.
static func terrain_problems(battle: Battle, army: BattleArmy, feature: BattleTerrain, at: Vector2, rotation: float,
		terrain_gap := -1.0, zone_polygons: Array[PackedVector2Array] = []) -> PackedStringArray:
	var problems := PackedStringArray()
	var outline := terrain_outline(feature, at, rotation)
	if zone_polygons.is_empty():
		zone_polygons = terrain_zone(battle, army)
	if not is_wholly_within(zone_polygons, outline):
		if battle.is_spearhead():
			problems.append("It must be wholly within your territory, more than 3\" from enemy territory and the long battlefield edges.")
		else:
			problems.append("It must be wholly within your territory.")
	if terrain_gap < 0.0:
		terrain_gap = SPEARHEAD_TERRAIN_GAP if battle.is_spearhead() else FACTION_TERRAIN_GAP
	for other in battle.all_terrain():
		if other == feature or not other.placed:
			continue
		if gap_between(outline, terrain_outline(other, other.position, other.rotation)) <= terrain_gap:
			problems.append("It must be more than %d\" from other terrain features." % int(terrain_gap))
			break
	for objective in battle.objectives:
		if battle.is_spearhead():
			if _covers_objective(battle, objective, outline):
				problems.append("It can't be set up on top of an objective.")
				break
		elif _distance_to_point(outline, objective.position) - Battle.OBJECTIVE_MARKER / 2 <= FACTION_TERRAIN_GAP:
			problems.append("It must be more than 3\" from all objectives.")
			break
	if _overlaps_models(battle, outline):
		problems.append("It can't overlap models.")
	return problems


static func _covers_objective(battle: Battle, objective: MapFeature, outline: PackedVector2Array) -> bool:
	if objective.is_rectangle():
		return _polygons_overlap(outline, objective.corners())
	return _distance_to_point(outline, objective.position) < battle.objective_radius(objective)


static func _distance_to_point(outline: PackedVector2Array, point: Vector2) -> float:
	if Geometry2D.is_point_in_polygon(point, outline):
		return 0.0
	return edge_distance(outline, point)


static func _overlaps_models(battle: Battle, outline: PackedVector2Array) -> bool:
	for pair: Array in _other_models(battle, null):
		var unit: BattleUnit = pair[0]
		var i: int = pair[1]
		if _polygons_overlap(outline, base_outline(unit.bases[i], unit.positions[i], unit.facing)):
			return true
	return false
