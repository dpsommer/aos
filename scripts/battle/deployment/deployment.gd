class_name Deployment
extends RefCounted
## The deployment phase for both armies, as rules with no nodes: whose turn it is, which
## deployment abilities each side can use, and what each action does. Matched Play has three steps
## (faction terrain, units, other deployment abilities), each alternating from the attacker; a side
## with nothing left to do passes and the other keeps going. 'Deploy Regiment' keeps one side going
## until its regiment is down. In Spearhead the defender sets up its terrain, then the attacker;
## then the attacker sets up its whole army, then the defender. See docs/gameplay/deployment.md.

## Something changed: a turn, a step or an action.
signal changed
## Both armies are deployed.
signal finished

enum Step { TERRAIN, UNITS, OTHER, DONE }

## The step names for the header, in [enum Step] order.
const STEP_NAMES: PackedStringArray = ["Faction terrain", "Armies", "Abilities"]
const SPEARHEAD_STEP_NAMES: PackedStringArray = ["Terrain", "Armies", "Abilities"]

var battle: Battle
var step := Step.TERRAIN
## The side whose turn it is, or null when deployment is done.
var active: BattleArmy
## The regiment being set up with 'Deploy Regiment', or null.
var regiment: BattleRegiment
## Every action taken, in order, as dictionaries: [code]army[/code], [code]action[/code]
## ("terrain", "regiment", "unit", "reserve", "record" or "pass"), and [code]feature[/code],
## [code]unit[/code], [code]units[/code], [code]ability[/code], [code]target[/code] as the action
## has them.
var history: Array[Dictionary] = []

## Regiments some unit of which was set up by another ability than 'Deploy Regiment', by the name
## of the unit that was.
var _broken := {}
## Abilities used, by [method _used_key].
var _used := {}
## Armies that are done with the current step's optional abilities.
var _passed := {}
## Terrain features with no spot left that meets the gap from other terrain, by feature: true if
## so. Worked out when first asked, and again after any terrain is set up.
var _cramped := {}


func _init(of: Battle) -> void:
	battle = of


## Starts the first step that has something to do.
func start() -> void:
	step = Step.TERRAIN
	_enter_step()


func is_done() -> bool:
	return step == Step.DONE


func step_names() -> PackedStringArray:
	return SPEARHEAD_STEP_NAMES if battle.is_spearhead() else STEP_NAMES


## Who goes first in [param of]: in Spearhead, the defender sets up terrain first; otherwise the
## attacker.
func first_in(of: Step) -> BattleArmy:
	if battle.is_spearhead() and of == Step.TERRAIN:
		return battle.defender()
	return battle.attacker()


## Whether the sides take turns in [param of]. In Spearhead, each side sets up all its terrain and
## all its units in one go.
func alternates(of: Step) -> bool:
	return not (battle.is_spearhead() and of in [Step.TERRAIN, Step.UNITS])


## Whether [param army] still has something to do in the current step.
func has_work(army: BattleArmy) -> bool:
	match step:
		Step.TERRAIN:
			return not army.unplaced_terrain().is_empty()
		Step.UNITS:
			return not army.undeployed_units().is_empty()
		Step.OTHER:
			if _passed.has(army):
				return false
			for entry in army.deployment_abilities:
				if entry.kind() == DeploymentAbility.Kind.RECORD and reason_unavailable(army, entry).is_empty():
					return true
	return false


## What [param army] has left to deploy: units, plus terrain features in the terrain step.
func remaining(army: BattleArmy) -> int:
	return army.undeployed_units().size() + army.unplaced_terrain().size()


## Why [param army] can't use [param entry] now, or empty if it can.
func reason_unavailable(army: BattleArmy, entry: DeploymentAbility) -> String:
	if not entry in army.deployment_abilities:
		return "Not this army's ability."
	if _is_used(army, entry):
		return "Already used." if not entry.is_once_per_battle() else "Used: once per battle."
	match entry.kind():
		DeploymentAbility.Kind.UNSUPPORTED:
			return "Not supported yet."
		DeploymentAbility.Kind.DEPLOY_TERRAIN:
			if army.unplaced_terrain().is_empty():
				return "No faction terrain to set up." if army.terrain.is_empty() else "Faction terrain is set up."
		DeploymentAbility.Kind.DEPLOY_UNIT:
			if army.undeployed_units().is_empty():
				return "Every unit is deployed."
		DeploymentAbility.Kind.DEPLOY_REGIMENT:
			if regiment != null:
				return "Deploying %s." % regiment.name
			if regiments_available(army).is_empty():
				return "No regiment is still wholly undeployed."
		DeploymentAbility.Kind.RESERVE:
			if entry.regiment:
				for unit in entry.regiment.units:
					if unit.deployed:
						return "Unavailable: %s was deployed on its own." % unit.name
				if regiment != null and regiment != entry.regiment:
					return "Deploying %s." % regiment.name
			elif reserve_targets(army, entry).is_empty():
				return "No unit to set up in reserve." if entry.targets_owner() else "Every unit is deployed."
	return ""


## Whether [param army] can use [param entry] now: its turn, its step, and nothing stopping it.
func can_use(army: BattleArmy, entry: DeploymentAbility) -> bool:
	return army == active and step_of(entry) == step and reason_unavailable(army, entry).is_empty()


## The step [param entry] is used in.
func step_of(entry: DeploymentAbility) -> Step:
	match entry.step():
		DeploymentAbility.Step.TERRAIN:
			return Step.TERRAIN
		DeploymentAbility.Step.UNITS:
			return Step.UNITS
	return Step.OTHER


## [param army]'s regiments it can still set up with 'Deploy Regiment': none of their units
## deployed, and none set up by another ability.
func regiments_available(army: BattleArmy) -> Array[BattleRegiment]:
	var result: Array[BattleRegiment] = []
	if army.deployment_ability(DeploymentAbility.DEPLOY_REGIMENT, DeploymentAbility.UNIVERSAL) == null:
		return result
	for candidate in army.regiments:
		if not candidate.units.is_empty() and not candidate.any_deployed() and not _broken.has(candidate):
			result.append(candidate)
	return result


## Why [param of] can't be set up with 'Deploy Regiment', e.g. "Tyrant on Glutthorn was deployed on
## its own, so the rest of this regiment deploys unit by unit.", or empty if it can.
func regiment_blocker(of: BattleRegiment) -> String:
	if _broken.has(of):
		return "%s was deployed on its own, so the rest of this regiment deploys unit by unit." % _broken[of]
	if of.any_deployed():
		return "Some of its units are already deployed."
	return ""


## The units [param army] can pick now: undeployed, and in the regiment being deployed if there is
## one.
func pickable_units(army: BattleArmy) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in army.undeployed_units():
		if regiment == null or unit.regiment == regiment:
			result.append(unit)
	return result


## The units [param entry] can set up in reserve: its own unit, its Regiment of Renown's units, or
## any unit [param army] can pick.
func reserve_targets(army: BattleArmy, entry: DeploymentAbility) -> Array[BattleUnit]:
	var pickable := pickable_units(army)
	var result: Array[BattleUnit] = []
	if entry.regiment:
		for unit in entry.regiment.units:
			if unit in pickable:
				result.append(unit)
		return result
	if entry.targets_owner():
		if entry.owner in pickable:
			result.append(entry.owner)
		return result
	return pickable


## Sets up [param feature] of [param army] at [param at], turned by [param rotation]. Returns why
## it can't, or empty if it was set up. [param check] off skips the placement rules (for the AI
## when it can't find a valid spot).
func place_terrain(army: BattleArmy, feature: BattleTerrain, at: Vector2, rotation: float, check := true) -> String:
	if army != active or step != Step.TERRAIN:
		return "It isn't your turn to set up terrain."
	if not feature in army.terrain or feature.placed:
		return "That terrain feature can't be set up."
	if check:
		var problems := terrain_problems(army, feature, at, rotation)
		if not problems.is_empty():
			return problems[0]
	feature.position = at
	feature.rotation = rotation
	feature.placed = true
	_cramped.clear()
	var entry := army.deployment_ability(DeploymentAbility.DEPLOY_FACTION_TERRAIN)
	if entry:
		_mark_used(army, entry)
	_log({"army": army, "action": "terrain", "feature": feature})
	_advance()
	return ""


## What's wrong with setting [param feature] up at [param at], turned by [param rotation]: the
## rules ([method DeploymentRules.terrain_problems]), except that if no spot left meets the gap from
## other terrain ([method is_cramped]), it only has to keep off other terrain.
func terrain_problems(army: BattleArmy, feature: BattleTerrain, at: Vector2, rotation: float) -> PackedStringArray:
	var gap := 0.0 if is_cramped(army, feature) else -1.0
	return DeploymentRules.terrain_problems(battle, army, feature, at, rotation, gap)


## Whether no spot left for [param feature] meets the rules' gap from other terrain features, so
## it's waived: the battlefield is too cramped, e.g. a Sand and Bone Diagonal map round the Crypt
## of Blood.
func is_cramped(army: BattleArmy, feature: BattleTerrain) -> bool:
	if not _cramped.has(feature):
		_cramped[feature] = not PlaceholderDeployment.has_terrain_spot(battle, army, feature)
	return _cramped[feature]


## Starts setting up [param of] with 'Deploy Regiment': [param army] keeps going until all its
## units are deployed.
func begin_regiment(army: BattleArmy, of: BattleRegiment) -> String:
	if army != active or step != Step.UNITS:
		return "It isn't your turn to deploy units."
	if not of in regiments_available(army) or regiment != null:
		return "That regiment can't be deployed together."
	regiment = of
	_log({"army": army, "action": "regiment", "regiment": of})
	changed.emit()
	return ""


## Calls off a 'Deploy Regiment' before any of its units is set up.
func cancel_regiment(army: BattleArmy) -> String:
	if army != active or regiment == null or regiment.any_deployed():
		return "The regiment can't be called off now."
	regiment = null
	for i in range(history.size() - 1, -1, -1):
		if history[i].action == "regiment":
			history.remove_at(i)
			break
	changed.emit()
	return ""


## Sets up [param unit] of [param army] with its models at [param positions], facing
## [param facing], using 'Deploy Unit' (or 'Deploy Regiment', while one is in progress). Returns why
## it can't, or empty if it was set up. [param check] off skips the placement rules.
func place_unit(army: BattleArmy, unit: BattleUnit, positions: PackedVector2Array, facing: float, check := true) -> String:
	if army != active or step != Step.UNITS:
		return "It isn't your turn to deploy units."
	if not unit in pickable_units(army):
		return "%s can't be deployed now." % unit.name
	if positions.size() != unit.model_count():
		return "Every model needs a position."
	if check:
		var problems := DeploymentRules.unit_problems(battle, army, unit, positions, facing)
		if not problems.is_empty():
			return problems[0]
	unit.positions = positions
	unit.facing = facing
	unit.deployed = true
	unit.reserve = ""
	_break_regiment(unit)
	_log({"army": army, "action": "unit", "unit": unit})
	_advance()
	return ""


## Sets up [param units] of [param army] in reserve with [param entry]. They count as deployed.
func reserve(army: BattleArmy, entry: DeploymentAbility, units: Array[BattleUnit]) -> String:
	if not can_use(army, entry) or entry.kind() != DeploymentAbility.Kind.RESERVE:
		return "%s can't be used now." % entry.name()
	if units.is_empty():
		return "Pick at least one unit."
	var targets := reserve_targets(army, entry)
	for unit in units:
		if not unit in targets:
			return "%s can't be set up in reserve with %s." % [unit.name, entry.name()]
	var reserve_name := entry.reserve_name()
	for unit in units:
		unit.deployed = true
		unit.reserve = reserve_name
		unit.positions = PackedVector2Array()
		_break_regiment(unit)
	_mark_used(army, entry)
	_log({"army": army, "action": "reserve", "ability": entry, "units": units.duplicate()})
	_advance()
	return ""


## Records [param army] using [param entry], an ability whose effect isn't applied yet, on
## [param target] (a unit, or null).
func record(army: BattleArmy, entry: DeploymentAbility, target: BattleUnit = null) -> String:
	if not can_use(army, entry) or entry.kind() != DeploymentAbility.Kind.RECORD:
		return "%s can't be used now." % entry.name()
	_mark_used(army, entry)
	_log({"army": army, "action": "record", "ability": entry, "target": target})
	_advance()
	return ""


## [param army] is done with the abilities step.
func pass_step(army: BattleArmy) -> String:
	if army != active or step != Step.OTHER:
		return "There's nothing to pass."
	_passed[army] = true
	_log({"army": army, "action": "pass"})
	_advance()
	return ""


## Whether [param army] has used [param entry].
func is_used(army: BattleArmy, entry: DeploymentAbility) -> bool:
	return _is_used(army, entry)


## The actions [param army] has taken, in order.
func actions_of(army: BattleArmy) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in history:
		if entry.army == army:
			result.append(entry)
	return result


func _is_used(army: BattleArmy, entry: DeploymentAbility) -> bool:
	if entry.kind() in [DeploymentAbility.Kind.DEPLOY_UNIT, DeploymentAbility.Kind.DEPLOY_REGIMENT, DeploymentAbility.Kind.DEPLOY_TERRAIN]:
		return false
	return _used.has(_used_key(army, entry))


func _mark_used(army: BattleArmy, entry: DeploymentAbility) -> void:
	_used[_used_key(army, entry)] = true


## Abilities are used once in the phase each (Core Rules); once per battle (army) abilities once
## for the whole army, whichever unit has them.
func _used_key(army: BattleArmy, entry: DeploymentAbility) -> String:
	if entry.is_once_per_army():
		return "%d:%s" % [army.get_instance_id(), entry.name()]
	return "%d:%d" % [army.get_instance_id(), entry.get_instance_id()]


func _break_regiment(unit: BattleUnit) -> void:
	if unit.regiment and regiment != unit.regiment and not _broken.has(unit.regiment):
		_broken[unit.regiment] = unit.name


func _log(entry: Dictionary) -> void:
	history.append(entry)


## Hands the turn on after an action: a regiment being deployed keeps its side going; otherwise
## the other side goes if it has something left (in an alternating step), else this side keeps
## going, else the next step starts.
func _advance() -> void:
	if regiment != null:
		if not regiment.all_deployed():
			changed.emit()
			return
		regiment = null
	var other := battle.enemy_of(active)
	if alternates(step) and has_work(other):
		active = other
	elif has_work(active):
		pass
	elif has_work(other):
		active = other
	else:
		step = (step + 1) as Step
		_enter_step()
		return
	changed.emit()


func _enter_step() -> void:
	while step != Step.DONE:
		_passed.clear()
		var first := first_in(step)
		if has_work(first):
			active = first
			break
		if has_work(battle.enemy_of(first)):
			active = battle.enemy_of(first)
			break
		step = (step + 1) as Step
	if step == Step.DONE:
		active = null
		changed.emit()
		finished.emit()
		return
	changed.emit()
