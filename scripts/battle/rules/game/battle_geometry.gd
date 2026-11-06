class_name BattleGeometry
extends RefCounted
## Distances between units on the battlefield, base edge to base edge, built on [DeploymentRules].
## Positions are in inches from the north-west corner. The simulator has no terrain height, so
## anything is visible unless a rule says otherwise. See docs/gameplay/battle-rounds.md.

## A unit's combat range (Core Rules 7.0).
const COMBAT_RANGE := 3.0
## How near a charge has to end (14.3).
const CHARGE_REACH := 0.5
const EPSILON := 0.001


## The shortest gap between any model of [param a] and any of [param b], or INF if either isn't on
## the battlefield.
static func unit_gap(a: BattleUnit, b: BattleUnit) -> float:
	var best := INF
	for i in a.positions.size():
		best = minf(best, model_gap(a, i, b))
	return best


## The gap from model [param index] of [param unit] to the nearest model of [param other].
static func model_gap(unit: BattleUnit, index: int, other: BattleUnit) -> float:
	return model_gap_at(unit.bases[index], unit.positions[index], unit.facing, other)


## The gap from a model on [param base] at [param at] to the nearest model of [param other].
static func model_gap_at(base: BaseSize, at: Vector2, facing: float, other: BattleUnit) -> float:
	var best := INF
	var reach := DeploymentRules.reach_of(base)
	for j in other.positions.size():
		# The bases can't be nearer than this, so don't work the exact gap out for ones far away.
		if at.distance_to(other.positions[j]) - reach - DeploymentRules.reach_of(other.bases[j]) >= best:
			continue
		best = minf(best, DeploymentRules.base_gap(base, at, facing, other.bases[j], other.positions[j], other.facing))
	return best


## How many of [param unit]'s models are within [param distance] of [param other].
static func models_within(unit: BattleUnit, other: BattleUnit, distance: float) -> int:
	var total := 0
	for i in unit.positions.size():
		if model_gap(unit, i, other) <= distance + EPSILON:
			total += 1
	return total


static func is_within(a: BattleUnit, b: BattleUnit, distance: float) -> bool:
	return unit_gap(a, b) <= distance + EPSILON


## Whether every model of [param unit] is wholly within [param distance] of [param other]: its whole
## base, so the far side of its base is in range too.
static func is_wholly_within(unit: BattleUnit, other: BattleUnit, distance: float) -> bool:
	if unit.positions.is_empty() or other.positions.is_empty():
		return false
	for i in unit.positions.size():
		if model_gap(unit, i, other) + DeploymentRules.reach_of(unit.bases[i]) * 2 > distance + EPSILON:
			return false
	return true


## Whether two units from opposing armies are in combat with each other.
static func in_combat_with(a: BattleUnit, b: BattleUnit) -> bool:
	return is_within(a, b, COMBAT_RANGE)


## Whether model [param index] of [param unit] is on the circle of [param radius] at [param centre].
static func model_touches_circle(unit: BattleUnit, index: int, centre: Vector2, radius: float) -> bool:
	var outline := DeploymentRules.base_outline(unit.bases[index], unit.positions[index], unit.facing)
	if Geometry2D.is_point_in_polygon(centre, outline):
		return true
	return DeploymentRules.edge_distance(outline, centre) <= radius + EPSILON


## The middle of [param unit]'s models.
static func middle(unit: BattleUnit) -> Vector2:
	var total := Vector2.ZERO
	for position in unit.positions:
		total += position
	return total / maxi(unit.positions.size(), 1)


## Whether every model of [param unit] stands wholly on [param feature] (Terrain 1.1).
static func is_wholly_on(unit: BattleUnit, feature: BattleTerrain) -> bool:
	if unit.positions.is_empty():
		return false
	var outline := DeploymentRules.terrain_outline(feature, feature.position, feature.rotation)
	var polygons: Array[PackedVector2Array] = [outline]
	for i in unit.positions.size():
		if not DeploymentRules.is_wholly_within(polygons, DeploymentRules.base_outline(unit.bases[i], unit.positions[i], unit.facing)):
			return false
	return true


## Whether [param target] is behind [param feature] from [param attacker]: no straight line runs
## from a model of one to a model of the other without crossing it (Terrain 1.1). The part of the
## feature within the attacker's combat range doesn't count.
static func is_behind(attacker: BattleUnit, target: BattleUnit, feature: BattleTerrain) -> bool:
	var outline := DeploymentRules.terrain_outline(feature, feature.position, feature.rotation)
	for from in attacker.positions:
		for to in target.positions:
			if not _crosses_beyond(from, to, outline, COMBAT_RANGE):
				return false
	return not attacker.positions.is_empty() and not target.positions.is_empty()


## Whether the line from [param from] to [param to] crosses [param outline] further than
## [param ignore] from [param from].
static func _crosses_beyond(from: Vector2, to: Vector2, outline: PackedVector2Array, ignore: float) -> bool:
	for i in outline.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(from, to, outline[i], outline[(i + 1) % outline.size()])
		if hit != null and from.distance_to(hit) > ignore:
			return true
	return false


## Whether [param point] is more than nothing outside the [param size] battlefield.
static func is_on_battlefield(base: BaseSize, at: Vector2, facing: float, size: Vector2) -> bool:
	for point in DeploymentRules.base_outline(base, at, facing):
		if point.x < -EPSILON or point.y < -EPSILON or point.x > size.x + EPSILON or point.y > size.y + EPSILON:
			return false
	return true


## The distance from a point to the segment from [param from] to [param to].
static func distance_to_path(point: Vector2, from: Vector2, to: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(point, from, to).distance_to(point)
