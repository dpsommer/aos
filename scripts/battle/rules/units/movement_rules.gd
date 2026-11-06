class_name MovementRules
extends RefCounted
## Whether a move is allowed (Core Rules 15.0-15.4), and planning one towards a point. Both the player
## and the AI use these. Each model moves in a straight line: without paths around things, a model
## that's blocked has to take a different line.

## Slack on a model's maximum distance, so a drag exactly to the limit counts.
const EPSILON := 0.01
## How many steps back from the farthest move [method plan_towards] tries.
const PLAN_STEPS := 8
const PLAN_ANGLES: Array[float] = [0.0, 0.35, -0.35, 0.8, -0.8, 1.3, -1.3]
## How far apart [method spot_beside] looks.
const SPOT_ANGLES := 16


## What's wrong with moving under [param spec] to [param positions], as sentences. Empty if allowed.
static func problems(game: GameController, spec: MoveSpec, positions: PackedVector2Array) -> PackedStringArray:
	var result := PackedStringArray()
	var bad := invalid_models(game, spec, positions)
	if not bad.too_far.is_empty():
		result.append("%s too far: each can move up to %s\"." % [_models(bad.too_far.size()), _inches(spec.max_distance)])
	if not bad.off_board.is_empty():
		result.append("%s off the battlefield." % _models(bad.off_board.size()))
	if not bad.blocked.is_empty():
		result.append("%s moving through or onto another model." % _models(bad.blocked.size()))
	if not bad.into_combat.is_empty():
		result.append("%s in an enemy's combat range." % _models(bad.into_combat.size()))
	if not bad.incoherent.is_empty():
		result.append("%s out of coherency." % _models(bad.incoherent.size()))
	result.append_array(_unit_problems(game, spec, positions))
	return result


static func _models(count: int) -> String:
	return "1 model is" if count == 1 else "%d models are" % count


static func _inches(distance: float) -> String:
	return ("%.1f" % distance).trim_suffix(".0")


## Which models break which rule, each a [PackedInt32Array] of indices: [code]too_far[/code],
## [code]off_board[/code], [code]blocked[/code], [code]into_combat[/code], [code]incoherent[/code].
static func invalid_models(game: GameController, spec: MoveSpec, positions: PackedVector2Array) -> Dictionary:
	var unit := spec.unit
	var bad := {"too_far": PackedInt32Array(), "off_board": PackedInt32Array(), "blocked": PackedInt32Array(),
			"into_combat": PackedInt32Array(), "incoherent": Coherency.failing(positions, unit.bases, unit.facing)}
	var flies := game.stats.has_keyword(unit, "FLY")
	var others := _other_units(game, unit)
	var enemies := game.enemies_on_battlefield(game.army_of(unit))
	var solid := _impassable_terrain(game)
	for i in positions.size():
		var from := unit.positions[i]
		var to := positions[i]
		var base := unit.bases[i]
		if from.distance_to(to) > spec.max_distance + EPSILON:
			bad.too_far.append(i)
		if not BattleGeometry.is_on_battlefield(base, to, unit.facing, game.battle.battlefield_size):
			bad.off_board.append(i)
		if _ends_on_other(base, to, unit.facing, others, solid) or (not flies and from != to and _path_blocked(base, from, to, others)):
			bad.blocked.append(i)
		if _breaks_combat_rule(spec, base, from, to, enemies, flies):
			bad.into_combat.append(i)
	return bad


## Whether it could finish a move here: nothing else breaks [method problems].
static func is_legal(game: GameController, spec: MoveSpec, positions: PackedVector2Array) -> bool:
	return problems(game, spec, positions).is_empty()


static func _other_units(game: GameController, unit: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for army in game.armies():
		for other in game.on_battlefield(army):
			if other != unit:
				result.append(other)
	return result


## Faction terrain is a model on its own base: nothing can stand on it (Terrain 1.5).
static func _impassable_terrain(game: GameController) -> Array[BattleTerrain]:
	var result: Array[BattleTerrain] = []
	for feature in game.battle.all_terrain():
		if feature.placed and DeploymentRules.is_impassable(feature):
			result.append(feature)
	return result


static func _ends_on_other(base: BaseSize, at: Vector2, facing: float, others: Array[BattleUnit], solid: Array[BattleTerrain]) -> bool:
	for other in others:
		for j in other.positions.size():
			if DeploymentRules.bases_overlap(base, at, facing, other.bases[j], other.positions[j], other.facing):
				return true
	var outline := DeploymentRules.base_outline(base, at, facing)
	for feature in solid:
		var shape := DeploymentRules.terrain_outline(feature, feature.position, feature.rotation)
		if not Geometry2D.intersect_polygons(outline, shape).is_empty():
			return true
	return false


## Whether the straight line from [param from] to [param to] runs through another unit's model.
static func _path_blocked(base: BaseSize, from: Vector2, to: Vector2, others: Array[BattleUnit]) -> bool:
	var radius := minf(base.footprint().x, base.footprint().y) / 2
	for other in others:
		for j in other.positions.size():
			var other_size := other.bases[j].footprint()
			if BattleGeometry.distance_to_path(other.positions[j], from, to) < radius + minf(other_size.x, other_size.y) / 2 - BattleGeometry.EPSILON:
				return true
	return false


static func _breaks_combat_rule(spec: MoveSpec, base: BaseSize, from: Vector2, to: Vector2,
		enemies: Array[BattleUnit], flies: bool) -> bool:
	var facing := spec.unit.facing
	match spec.kind:
		MoveSpec.Kind.NORMAL, MoveSpec.Kind.RUN:
			if flies:
				for enemy in enemies:
					if BattleGeometry.model_gap_at(base, to, facing, enemy) <= BattleGeometry.COMBAT_RANGE:
						return true
				return false
			for enemy in enemies:
				if _path_gap(base, from, to, enemy) <= BattleGeometry.COMBAT_RANGE:
					return true
		MoveSpec.Kind.RETREAT:
			for enemy in enemies:
				if BattleGeometry.model_gap_at(base, to, facing, enemy) <= BattleGeometry.COMBAT_RANGE:
					return true
		MoveSpec.Kind.FREE:
			if spec.avoid_new_combat:
				for enemy in enemies:
					if not enemy in spec.ignores_combat_of and BattleGeometry.model_gap_at(base, to, facing, enemy) <= BattleGeometry.COMBAT_RANGE:
						return true
	return false


## The nearest a model comes to [param enemy] along its path.
static func _path_gap(base: BaseSize, from: Vector2, to: Vector2, enemy: BattleUnit) -> float:
	var radius := DeploymentRules.reach_of(base)
	var best := INF
	for j in enemy.positions.size():
		var gap := BattleGeometry.distance_to_path(enemy.positions[j], from, to) - radius - DeploymentRules.reach_of(enemy.bases[j])
		best = minf(best, gap)
	return maxf(best, 0.0)


## Rules about where the whole unit ends up.
static func _unit_problems(game: GameController, spec: MoveSpec, positions: PackedVector2Array) -> PackedStringArray:
	var result := PackedStringArray()
	var unit := spec.unit
	var moved := _at(unit, positions)
	var enemies := game.enemies_on_battlefield(game.army_of(unit))
	match spec.kind:
		MoveSpec.Kind.CHARGE:
			var reached := false
			for enemy in enemies:
				if BattleGeometry.unit_gap(moved, enemy) <= BattleGeometry.CHARGE_REACH + BattleGeometry.EPSILON:
					reached = true
					break
			if not reached:
				result.append("A charge has to end within ½\" of an enemy unit.")
		MoveSpec.Kind.PILE_IN:
			result.append_array(_pile_in_problems(unit, moved, spec, enemies))
	if spec.must_end_in_combat:
		var in_combat := false
		for enemy in enemies:
			if BattleGeometry.in_combat_with(moved, enemy):
				in_combat = true
				break
		if not in_combat:
			result.append("This move has to end in combat.")
	return result


static func _pile_in_problems(unit: BattleUnit, moved: BattleUnit, spec: MoveSpec, enemies: Array[BattleUnit]) -> PackedStringArray:
	var result := PackedStringArray()
	var target := spec.pile_in_target
	if target == null:
		return result
	for i in unit.positions.size():
		if BattleGeometry.model_gap(moved, i, target) > BattleGeometry.model_gap(unit, i, target) + BattleGeometry.EPSILON:
			result.append("Each model has to end no further from %s." % target.name)
			break
	for enemy in enemies:
		if BattleGeometry.in_combat_with(unit, enemy) and not BattleGeometry.in_combat_with(moved, enemy):
			result.append("It has to stay in combat with %s." % enemy.name)
	return result


## A copy of [param unit] standing at [param positions], for asking about where it would end up.
static func _at(unit: BattleUnit, positions: PackedVector2Array) -> BattleUnit:
	var moved := BattleUnit.new()
	moved.bases = unit.bases
	moved.facing = unit.facing
	moved.positions = positions
	moved.deployed = true
	return moved


## The furthest allowed move of the whole unit towards [param goal] under [param spec], the models
## keeping their places, trying angles either side if the straight line is blocked. Empty if none.
## A move that has to reach something uses [param stop_short]: it stops that far from [param goal].
static func plan_towards(game: GameController, spec: MoveSpec, goal: Vector2, stop_short := 0.0) -> PackedVector2Array:
	var unit := spec.unit
	var centre := BattleGeometry.middle(unit)
	var distance := maxf(centre.distance_to(goal) - stop_short, 0.0)
	var furthest := minf(distance, spec.max_distance)
	if furthest <= 0.0:
		return PackedVector2Array()
	var direction := centre.direction_to(goal)
	for step in PLAN_STEPS:
		var length := furthest * (1.0 - float(step) / PLAN_STEPS)
		for angle in PLAN_ANGLES:
			var moved := shifted(unit, direction.rotated(angle) * length)
			if is_legal(game, spec, moved):
				return moved
	return PackedVector2Array()


## [param unit]'s positions moved by [param by].
static func shifted(unit: BattleUnit, by: Vector2) -> PackedVector2Array:
	var result := unit.positions.duplicate()
	for i in result.size():
		result[i] += by
	return result


## A charge for [param spec]: the whole unit moved in a line to within reach of [param enemy], the
## model nearest the enemy leading. Empty if it can't get there.
static func plan_charge(game: GameController, spec: MoveSpec, enemy: BattleUnit) -> PackedVector2Array:
	var unit := spec.unit
	var lead := 0
	var lead_gap := INF
	for i in unit.positions.size():
		var gap := BattleGeometry.model_gap(unit, i, enemy)
		if gap < lead_gap:
			lead = i
			lead_gap = gap
	var nearest := enemy.positions[0]
	for at in enemy.positions:
		if unit.positions[lead].distance_to(at) < unit.positions[lead].distance_to(nearest):
			nearest = at
	var line := unit.positions[lead].direction_to(nearest)
	# Aim to end just inside ½", so a little slack in the angle still reaches.
	var needed := lead_gap - BattleGeometry.CHARGE_REACH * 0.6
	if needed > spec.max_distance:
		return PackedVector2Array()
	for angle in PLAN_ANGLES:
		var moved := shifted(unit, line.rotated(angle * 0.3) * maxf(needed, 0.0))
		if is_legal(game, spec, moved):
			return moved
	return PackedVector2Array()


## A pile-in for [param spec]: each model moved straight at the target as far as it's allowed.
## Empty if the unit is best left where it is.
static func plan_pile_in(game: GameController, spec: MoveSpec) -> PackedVector2Array:
	var unit := spec.unit
	var target := spec.pile_in_target
	if target == null:
		return PackedVector2Array()
	var moved := unit.positions.duplicate()
	for i in moved.size():
		var gap := BattleGeometry.model_gap(unit, i, target)
		var nearest := target.positions[0]
		for at in target.positions:
			if unit.positions[i].distance_to(at) < unit.positions[i].distance_to(nearest):
				nearest = at
		moved[i] += unit.positions[i].direction_to(nearest) * clampf(gap - 0.1, 0.0, spec.max_distance)
	if is_legal(game, spec, moved):
		return moved
	# Crowding at the front: move the whole unit together instead.
	var by := BattleGeometry.unit_gap(unit, target) - 0.1
	if by > 0.0:
		var together := shifted(unit, BattleGeometry.middle(unit).direction_to(BattleGeometry.middle(target)) * minf(by, spec.max_distance))
		if is_legal(game, spec, together):
			return together
	return PackedVector2Array()


## A free spot for a model on [param base] within coherency of [param unit], or null.
static func spot_beside(game: GameController, unit: BattleUnit, base: BaseSize) -> Variant:
	var others := _other_units(game, unit)
	var solid := _impassable_terrain(game)
	for i in unit.positions.size():
		var distance := DeploymentRules.reach_of(unit.bases[i]) + DeploymentRules.reach_of(base) + 0.1
		for step in SPOT_ANGLES:
			var spot := unit.positions[i] + Vector2.from_angle(TAU * step / SPOT_ANGLES) * distance
			if _spot_free(game, unit, base, spot, others, solid):
				return spot
	return null


static func _spot_free(game: GameController, unit: BattleUnit, base: BaseSize, spot: Vector2,
		others: Array[BattleUnit], solid: Array[BattleTerrain]) -> bool:
	if not BattleGeometry.is_on_battlefield(base, spot, unit.facing, game.battle.battlefield_size):
		return false
	if _ends_on_other(base, spot, unit.facing, others, solid):
		return false
	for j in unit.positions.size():
		if DeploymentRules.bases_overlap(base, spot, unit.facing, unit.bases[j], unit.positions[j], unit.facing):
			return false
	# A returned model can only be set up in combat with a unit it's already in combat with (22.0).
	for enemy in game.enemies_on_battlefield(game.army_of(unit)):
		if BattleGeometry.model_gap_at(base, spot, unit.facing, enemy) <= BattleGeometry.COMBAT_RANGE and not BattleGeometry.in_combat_with(unit, enemy):
			return false
	var positions := unit.positions.duplicate()
	var bases := unit.bases.duplicate()
	positions.append(spot)
	bases.append(base)
	return Coherency.is_coherent(positions, bases, unit.facing)
