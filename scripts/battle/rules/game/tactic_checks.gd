class_name TacticChecks
extends RefCounted
## Whether a battle tactic's condition is met. Each tactic's meaning is effect data:
## "tactic:<battlepack>/<tactic>" gives a check and its numbers. One with no data can't be completed,
## and is listed as not supported. See docs/technical/effect-data.md.

const NEAR_EDGE := 3.0
const NEAR_CENTRE := 3.0


static func key_of(space: String, tactic: String) -> String:
	return "tactic:%s/%s" % [space, tactic]


## Whether the tactic [param tactic] of [param space] has data the engine can check.
static func is_supported(space: String, tactic: String) -> bool:
	return not EffectCatalog.raw(key_of(space, tactic)).is_empty()


## Whether [param army] has completed the tactic now, at the end of its turn.
static func is_complete(space: String, tactic: String, army: BattleArmy, game: GameController) -> bool:
	var spec := EffectCatalog.raw(key_of(space, tactic))
	if spec.is_empty():
		return false
	var state := game.state
	var enemy := game.battle.enemy_of(army)
	var mine := game.on_battlefield(army)
	match spec.get("check", ""):
		"attrition":
			return state.turn_stat(army, &"enemy_destroyed") > 0 and state.turn_stat(army, &"enemy_destroyed") > state.turn_stat(army, &"own_destroyed")
		"lost_more":
			return state.turn_stat(army, &"own_destroyed") > state.turn_stat(army, &"enemy_destroyed")
		"raid":
			return mine.any(func(unit: BattleUnit) -> bool: return BattleGeometry.is_wholly_in(unit, game.battle.enemy_territory_of(army)) and not game.in_combat(unit))
		"flanks":
			return _near_short_edges(mine, game)
		"long_edge_enemy":
			return _near_enemy_long_edge(mine, army, game)
		"centre":
			return _near_centre(mine, game).size() >= int(spec.get("count", 1))
		"centre_not_in_combat":
			return _near_centre(mine, game).filter(func(unit: BattleUnit) -> bool: return not game.in_combat(unit)).size() >= int(spec.get("count", 1))
		"gained_unfought":
			return _gained_unfought(army, enemy, game)
		"gained_count":
			return state.objectives_gained(army, enemy).size() >= int(spec.get("count", 1))
		"cut_head":
			return state.turn_stat(army, &"general_slain") > 0 or (state.generals_slain.has(enemy) and state.turn_stat(army, &"enemy_destroyed") > 0)
		"control_named":
			return state.controls_objective_of_type(army, spec.get("name", ""))
		"fought_no_losses":
			return state.turn_stat(army, &"fought") > 0 and state.turn_stat(army, &"own_destroyed") == 0
		"large_terrain_models":
			return has_most_models_at_large_terrain(army, game.battle.territory_of(army), game)
		"control_large_terrain_own":
			return _controls_large_terrain(army, game.battle.territory_of(army), game)
		"control_outside_own":
			return _held_outside_own(army, game).size() >= int(spec.get("count", 1))
		"contested_by_enemy":
			return _held_contested_by_enemy(army, enemy, game)
		"control_all_in_enemy":
			return _controls_all_in_enemy(army, game)
		"form_a_wall":
			return _form_a_wall(mine, army, game)
		"claim":
			return _claim(mine, army, game)
		"corners":
			return _corners(mine, army, game)
	return false


## Whether any of [param unit]'s models is inside [param polygons].
static func partly_in(unit: BattleUnit, polygons: Array[PackedVector2Array]) -> bool:
	for at in unit.positions:
		if point_in(at, polygons):
			return true
	return false


static func point_in(at: Vector2, polygons: Array[PackedVector2Array]) -> bool:
	for polygon in polygons:
		if Geometry2D.is_point_in_polygon(at, polygon):
			return true
	return false


static func _edge_gap(unit: BattleUnit, coordinate: int, edge: float) -> float:
	var best := INF
	for i in unit.positions.size():
		var reach := DeploymentRules.reach_of(unit.bases[i])
		best = minf(best, absf(unit.positions[i][coordinate] - edge) - reach)
	return best


## Whether there are friendly units near each of the two short edges.
static func _near_short_edges(units: Array[BattleUnit], game: GameController) -> bool:
	var size := game.battle.battlefield_size
	var axis := 0 if size.x >= size.y else 1
	var low := false
	var high := false
	for unit in units:
		low = low or _edge_gap(unit, axis, 0.0) <= NEAR_EDGE
		high = high or _edge_gap(unit, axis, size[axis]) <= NEAR_EDGE
	return low and high


## Whether a friendly unit is near the long edge in enemy territory.
static func _near_enemy_long_edge(units: Array[BattleUnit], army: BattleArmy, game: GameController) -> bool:
	var size := game.battle.battlefield_size
	var axis := 1 if size.x >= size.y else 0
	var enemy_middle := PlaceholderDeployment.centroid(game.battle.enemy_territory_of(army))
	var edge := 0.0 if enemy_middle[axis] < size[axis] / 2 else size[axis]
	return units.any(func(unit: BattleUnit) -> bool: return _edge_gap(unit, axis, edge) <= NEAR_EDGE)


static func _near_centre(units: Array[BattleUnit], game: GameController) -> Array[BattleUnit]:
	var centre := game.battle.battlefield_size / 2
	return units.filter(func(unit: BattleUnit) -> bool: return BattleGeometry.touches_circle(unit, centre, NEAR_CENTRE))


static func _gained_unfought(army: BattleArmy, enemy: BattleArmy, game: GameController) -> bool:
	for objective in game.state.objectives_gained(army, enemy):
		var fought := false
		for unit in game.on_battlefield(army):
			if game.objectives.models_contesting(unit, objective) > 0 and game.controller_of(unit).fought_serial == game.state.turn_serial:
				fought = true
		if not fought:
			return true
	return false


## The large terrain feature in [param territory], or null.
static func large_terrain_in(territory: Array[PackedVector2Array], game: GameController) -> BattleTerrain:
	for feature in game.battle.all_terrain():
		if feature.placed and feature.size == "large" and point_in(feature.position, territory):
			return feature
	return null


## Whether [param army] has more models than its enemy contesting the large terrain in [param territory].
static func has_most_models_at_large_terrain(army: BattleArmy, territory: Array[PackedVector2Array], game: GameController) -> bool:
	var feature := large_terrain_in(territory, game)
	if feature == null:
		return false
	var mine := 0
	var theirs := 0
	for unit in game.on_battlefield(army):
		mine += BattleGeometry.models_near_terrain(unit, feature)
	for unit in game.on_battlefield(game.battle.enemy_of(army)):
		theirs += BattleGeometry.models_near_terrain(unit, feature)
	return mine > theirs


static func _controls_large_terrain(army: BattleArmy, territory: Array[PackedVector2Array], game: GameController) -> bool:
	var feature := large_terrain_in(territory, game)
	return feature != null and game.state.terrain_control.get(feature) == army


static func _held_outside_own(army: BattleArmy, game: GameController) -> Array[MapFeature]:
	var result: Array[MapFeature] = []
	for objective: MapFeature in game.state.objective_control:
		if game.state.objective_control[objective] == army and not point_in(objective.position, game.battle.territory_of(army)):
			result.append(objective)
	return result


static func _held_contested_by_enemy(army: BattleArmy, enemy: BattleArmy, game: GameController) -> bool:
	for objective: MapFeature in game.state.objective_control:
		if game.state.objective_control[objective] != army:
			continue
		for unit in game.on_battlefield(enemy):
			if game.objectives.models_contesting(unit, objective) > 0:
				return true
	return false


static func _controls_all_in_enemy(army: BattleArmy, game: GameController) -> bool:
	var any := false
	for objective in game.battle.objectives:
		if point_in(objective.position, game.battle.enemy_territory_of(army)):
			any = true
			if game.state.objective_control.get(objective) != army:
				return false
	return any


## 2 or more friendly units wholly outside and wholly within 6" of friendly territory, within 3" of
## each other.
static func _form_a_wall(units: Array[BattleUnit], army: BattleArmy, game: GameController) -> bool:
	var territory := game.battle.territory_of(army)
	var grown: Array[PackedVector2Array] = []
	for polygon in territory:
		grown.append_array(Geometry2D.offset_polygon(polygon, 6.0, Geometry2D.JOIN_ROUND))
	var wall := units.filter(func(unit: BattleUnit) -> bool: return BattleGeometry.is_wholly_in(unit, grown) and not partly_in(unit, territory))
	for a: BattleUnit in wall:
		for b: BattleUnit in wall:
			if a != b and BattleGeometry.is_within(a, b, 3.0):
				return true
	return false


## More friendly units than enemy units in enemy territory, and a friendly HERO wholly in it.
static func _claim(units: Array[BattleUnit], army: BattleArmy, game: GameController) -> bool:
	var territory := game.battle.enemy_territory_of(army)
	var enemy_units := game.on_battlefield(game.battle.enemy_of(army))
	var mine := units.filter(func(unit: BattleUnit) -> bool: return partly_in(unit, territory)).size()
	var theirs := enemy_units.filter(func(unit: BattleUnit) -> bool: return partly_in(unit, territory)).size()
	var hero := units.any(func(unit: BattleUnit) -> bool: return game.stats.has_keyword(unit, "HERO") and BattleGeometry.is_wholly_in(unit, territory))
	return mine > theirs and hero


## 2 or more friendly units, not set up this turn, each near a different corner and wholly outside
## friendly territory.
static func _corners(units: Array[BattleUnit], army: BattleArmy, game: GameController) -> bool:
	var size := game.battle.battlefield_size
	var corners := [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]
	var territory := game.battle.territory_of(army)
	var taken := 0
	for corner: Vector2 in corners:
		for unit in units:
			if not game.was_set_up_this_turn(unit) and not partly_in(unit, territory) and BattleGeometry.touches_circle(unit, corner, 9.0):
				taken += 1
				break
	return taken >= 2
