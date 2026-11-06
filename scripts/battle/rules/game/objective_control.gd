class_name ObjectiveControl
extends RefCounted
## Contesting and controlling objectives and terrain (Core Rules 32.0-32.3). A model contests a
## Matched Play objective within its control zone, or a Spearhead objective when its base is on it:
## both are a circle of the battle's objective radius.

var game: GameController


func _init(on: GameController) -> void:
	game = on


## Whether any model of [param unit] is contesting any objective.
func contests_any(unit: BattleUnit) -> bool:
	for objective in game.battle.objectives:
		if models_contesting(unit, objective) > 0:
			return true
	return false


## Whether [param unit] contests the objective of type [param objective_type].
func contests_named(unit: BattleUnit, objective_type: String) -> bool:
	for objective in game.battle.objectives:
		if objective.type == objective_type and models_contesting(unit, objective) > 0:
			return true
	return false


## Whether [param unit] contests a large terrain feature.
func contests_large_terrain(unit: BattleUnit) -> bool:
	for feature in game.battle.all_terrain():
		if feature.placed and feature.size == "large" and _terrain_score(unit, feature) > 0:
			return true
	return false


## How many of [param unit]'s models contest [param objective]. None if something stops them.
func models_contesting(unit: BattleUnit, objective: MapFeature) -> int:
	if game.state.objectives_out_of_play.has(objective):
		return 0
	var radius := game.battle.objective_radius(objective)
	var total := 0
	for i in unit.positions.size():
		if BattleGeometry.model_touches_circle(unit, i, objective.position, radius):
			total += 1
	if total > 0 and game.stats.is_forbidden(unit, &"contest"):
		return 0
	return total


## The objective [param unit] counts as contesting for control: each unit contests one (32.1), the
## nearest it reaches. Null if none.
func contested_by(unit: BattleUnit) -> MapFeature:
	var best: MapFeature = null
	var best_distance := INF
	var centre := BattleGeometry.middle(unit)
	for objective in game.battle.objectives:
		if models_contesting(unit, objective) == 0:
			continue
		var distance := centre.distance_to(objective.position)
		if distance < best_distance:
			best = objective
			best_distance = distance
	return best


## A unit's control score on [param objective] (32.2): its contesting models' Control, at least 1.
func control_score(unit: BattleUnit, objective: MapFeature) -> int:
	var models := models_contesting(unit, objective)
	if models == 0:
		return 0
	var per_model := game.stats.value(unit, &"control")
	return maxi(game.stats.modified(per_model * models, &"control_score", RuleContext.of_unit(game, unit)), 1)


## Works out who controls each objective now (32.2), keeping who already has it on a tie.
func update() -> void:
	var state := game.state
	var scores := {}
	for army in game.armies():
		for unit in game.on_battlefield(army):
			var objective := contested_by(unit)
			if objective:
				if not scores.has(objective):
					scores[objective] = {}
				scores[objective][army] = scores[objective].get(army, 0) + control_score(unit, objective)
	for objective: MapFeature in game.battle.objectives:
		if state.objectives_out_of_play.has(objective):
			state.objective_control.erase(objective)
			continue
		var score: Dictionary = scores.get(objective, {})
		var armies := game.armies()
		var first: int = score.get(armies[0], 0)
		var second: int = score.get(armies[1], 0)
		if first != second:
			_set_control(objective, armies[0] if first > second else armies[1])
	_update_terrain()


func _set_control(objective: MapFeature, army: BattleArmy) -> void:
	if game.state.objective_control.get(objective) == army:
		return
	game.state.objective_control[objective] = army
	game.events.publish(BattleEvent.OBJECTIVE_CHANGED, {"objective": objective, "army": army,
			"text": "%s takes the %s objective." % [game.side_name(army), objective.type]})


## Terrain control doesn't last: whoever has more Control within 3" of it now (32.3).
func _update_terrain() -> void:
	game.state.terrain_control.clear()
	var armies := game.armies()
	for feature in game.battle.all_terrain():
		if not feature.placed:
			continue
		var scores := {armies[0]: 0, armies[1]: 0}
		for army in armies:
			for unit in game.on_battlefield(army):
				scores[army] += _terrain_score(unit, feature)
		if scores[armies[0]] != scores[armies[1]]:
			game.state.terrain_control[feature] = armies[0] if scores[armies[0]] > scores[armies[1]] else armies[1]


func _terrain_score(unit: BattleUnit, feature: BattleTerrain) -> int:
	var outline := DeploymentRules.terrain_outline(feature, feature.position, feature.rotation)
	var total := 0
	for i in unit.positions.size():
		var base_outline := DeploymentRules.base_outline(unit.bases[i], unit.positions[i], unit.facing)
		if DeploymentRules.gap_between(base_outline, outline) <= BattleGeometry.COMBAT_RANGE:
			total += 1
	return game.stats.value(unit, &"control") * total if total > 0 else 0
