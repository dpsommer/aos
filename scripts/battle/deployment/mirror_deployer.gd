class_name MirrorDeployer
extends RefCounted
## The AI's deployment until it has one of its own: it copies what the player did, reflected
## through the middle of the battlefield. Its army is a mirror of the player's
## ([method BattleArmy.mirror]), so each unit, regiment, terrain feature and deployment ability has
## a counterpart at the same index. Whatever it can't mirror (nothing to copy yet, or the reflected
## spot isn't allowed) it sets up automatically ([PlaceholderDeployment]). See
## docs/gameplay/deployment.md.

var deployment: Deployment
## The AI's army.
var army: BattleArmy
## The army it mirrors.
var model: BattleArmy


func _init(of: Deployment, ai: BattleArmy, player: BattleArmy) -> void:
	deployment = of
	army = ai
	model = player


## The point opposite [param point] through the middle of the battlefield.
func reflect(point: Vector2) -> Vector2:
	return deployment.battle.battlefield_size - point


## Takes one action on the AI's turn. Returns false if it isn't the AI's turn or it couldn't act.
func take_turn() -> bool:
	if deployment.active != army or deployment.is_done():
		return false
	match deployment.step:
		Deployment.Step.TERRAIN:
			return _terrain_turn()
		Deployment.Step.UNITS:
			return _units_turn()
		Deployment.Step.OTHER:
			return _other_turn()
	return false


## Takes turns until it's no longer the AI's turn.
func play() -> void:
	var guard := 1000
	while deployment.active == army and not deployment.is_done() and guard > 0:
		guard -= 1
		if not take_turn():
			break


func _terrain_turn() -> bool:
	var feature: BattleTerrain = null
	var at := Vector2.ZERO
	var rotation := 0.0
	# The first terrain feature the player has set up that the AI hasn't.
	for entry in deployment.actions_of(model):
		if entry.action != "terrain":
			continue
		var index := model.terrain.find(entry.feature)
		if index >= 0 and index < army.terrain.size() and not army.terrain[index].placed:
			feature = army.terrain[index]
			at = reflect(entry.feature.position)
			rotation = entry.feature.rotation + PI
			break
	if feature and deployment.place_terrain(army, feature, at, rotation).is_empty():
		return true
	if feature == null:
		feature = army.unplaced_terrain()[0]
	var spot := PlaceholderDeployment.spot_for_terrain(deployment.battle, army, feature, deployment.is_cramped(army, feature))
	if not spot.is_empty() and deployment.place_terrain(army, feature, spot.at, spot.rotation).is_empty():
		return true
	# Nowhere is allowed: set it up as near the rules as it can rather than stall.
	spot = PlaceholderDeployment.spot_for_terrain(deployment.battle, army, feature, true)
	if spot.is_empty():
		spot = {"at": PlaceholderDeployment.centroid(deployment.battle.territory_of(army)), "rotation": army.facing + PI / 2}
	return deployment.place_terrain(army, feature, spot.at, spot.rotation, false).is_empty()


func _units_turn() -> bool:
	if deployment.regiment != null:
		return _next_in_regiment()
	for entry in deployment.actions_of(model):
		match entry.action:
			"regiment":
				var regiment := _counterpart_regiment(entry.regiment)
				if regiment and regiment in deployment.regiments_available(army):
					deployment.begin_regiment(army, regiment)
					return _next_in_regiment()
			"unit":
				var unit := _counterpart_unit(entry.unit)
				if unit and unit in deployment.pickable_units(army):
					return _mirror_unit(entry.unit, unit)
			"reserve":
				var ability := _counterpart_ability(entry.ability)
				var units: Array[BattleUnit] = []
				for unit: BattleUnit in entry.units:
					var counterpart := _counterpart_unit(unit)
					if counterpart and not counterpart.deployed:
						units.append(counterpart)
				if ability and not units.is_empty() and deployment.can_use(army, ability) \
						and deployment.reserve(army, ability, units).is_empty():
					return true
	var pickable := deployment.pickable_units(army)
	return _auto_unit(pickable[0]) if not pickable.is_empty() else false


## Sets up the next unit of the regiment being deployed: mirrored if the player has set its
## counterpart up, else automatically.
func _next_in_regiment() -> bool:
	var pickable := deployment.pickable_units(army)
	if pickable.is_empty():
		return false
	var unit := pickable[0]
	var counterpart := _model_unit(unit)
	if counterpart and counterpart.deployed and not counterpart.reserve.is_empty():
		var ability := _reserve_ability_for(counterpart)
		if ability and deployment.can_use(army, ability):
			var units: Array[BattleUnit] = [unit]
			if deployment.reserve(army, ability, units).is_empty():
				return true
	if counterpart and counterpart.is_on_battlefield():
		return _mirror_unit(counterpart, unit)
	return _auto_unit(unit)


## Sets [param unit] up where [param original] stands, reflected; automatically if that isn't
## allowed.
func _mirror_unit(original: BattleUnit, unit: BattleUnit) -> bool:
	if original.is_on_battlefield():
		var positions := PackedVector2Array()
		for position in original.positions:
			positions.append(reflect(position))
		if deployment.place_unit(army, unit, positions, original.facing + PI).is_empty():
			return true
	return _auto_unit(unit)


func _auto_unit(unit: BattleUnit) -> bool:
	var positions := PlaceholderDeployment.spot_for_unit(deployment.battle, army, unit)
	if not positions.is_empty() and deployment.place_unit(army, unit, positions, army.facing).is_empty():
		return true
	# No room anywhere: set it up regardless rather than stall the phase.
	if positions.is_empty():
		var middle := PlaceholderDeployment.centroid(deployment.battle.territory_of(army))
		positions = Formations.arrange(Formations.Kind.WIDE_BLOCK, unit.bases, middle, army.facing)
	return deployment.place_unit(army, unit, positions, army.facing, false).is_empty()


func _other_turn() -> bool:
	for entry in deployment.actions_of(model):
		if entry.action != "record":
			continue
		var ability := _counterpart_ability(entry.ability)
		if ability and deployment.can_use(army, ability):
			var target: BattleUnit = _counterpart_unit(entry.target) if entry.target else null
			if deployment.record(army, ability, target).is_empty():
				return true
	return deployment.pass_step(army).is_empty()


## The reserve ability the player used on [param unit], as the AI's own.
func _reserve_ability_for(unit: BattleUnit) -> DeploymentAbility:
	for entry in deployment.actions_of(model):
		if entry.action == "reserve" and unit in entry.units:
			return _counterpart_ability(entry.ability)
	return null


func _counterpart_unit(unit: BattleUnit) -> BattleUnit:
	return _at_same_index(unit, model.units, army.units)


## The player's unit that [param unit] mirrors.
func _model_unit(unit: BattleUnit) -> BattleUnit:
	return _at_same_index(unit, army.units, model.units)


func _counterpart_regiment(regiment: BattleRegiment) -> BattleRegiment:
	return _at_same_index(regiment, model.regiments, army.regiments)


func _counterpart_ability(entry: DeploymentAbility) -> DeploymentAbility:
	return _at_same_index(entry, model.deployment_abilities, army.deployment_abilities)


## The item of [param to] at [param item]'s index in [param from], or null.
static func _at_same_index(item: Variant, from: Array, to: Array) -> Variant:
	var index := from.find(item)
	return to[index] if index >= 0 and index < to.size() else null
