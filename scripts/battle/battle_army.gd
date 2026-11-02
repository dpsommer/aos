class_name BattleArmy
extends RefCounted
## One side's army on the battlefield: its units and regiments, the terrain features it brings and
## the abilities it can use in the deployment phase. See docs/design/battle.md.

var name: String
var faction_name: String
## The army's points, or -1 for a Spearhead, which has none.
var points := -1
var units: Array[BattleUnit] = []
## Its regiments, each holding some of [member units]. Auxiliary and Spearhead units are in none.
var regiments: Array[BattleRegiment] = []
## Terrain features the army sets up: its faction terrain, or a Spearhead's terrain features.
var terrain: Array[BattleTerrain] = []
## The abilities it can use in the deployment phase, universal ones first.
var deployment_abilities: Array[DeploymentAbility] = []
## Which way the army's models face by default, in radians clockwise from east: towards the enemy.
var facing: float


func model_count() -> int:
	var count := 0
	for unit in units:
		count += unit.model_count()
	return count


## "Kharadron Overlords · 1940 pts", or "Kharadron Overlords · Spearhead".
func details() -> String:
	return "%s · %s" % [faction_name, "Spearhead" if points < 0 else "%d pts" % points]


## Units not yet deployed.
func undeployed_units() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in units:
		if not unit.deployed:
			result.append(unit)
	return result


## Terrain features not yet set up.
func unplaced_terrain() -> Array[BattleTerrain]:
	var result: Array[BattleTerrain] = []
	for feature in terrain:
		if not feature.placed:
			result.append(feature)
	return result


## The deployment ability called [param ability_name] from [param from] (any source if empty), or
## null.
func deployment_ability(ability_name: String, from := "") -> DeploymentAbility:
	for entry in deployment_abilities:
		if entry.name() == ability_name and (from.is_empty() or entry.source == from):
			return entry
	return null


## A copy, not yet deployed: the AI's army, until it can choose its own. Its units, regiments,
## terrain and deployment abilities are in the same order as this army's.
func mirror() -> BattleArmy:
	var army := BattleArmy.new()
	army.name = name
	army.faction_name = faction_name
	army.points = points
	var unit_copies := {}
	for unit in units:
		var copy := unit.copy()
		unit_copies[unit] = copy
		army.units.append(copy)
	var regiment_copies := {}
	for regiment in regiments:
		var copy := BattleRegiment.new()
		copy.name = regiment.name
		copy.is_renown = regiment.is_renown
		for unit in regiment.units:
			var unit_copy: BattleUnit = unit_copies[unit]
			unit_copy.regiment = copy
			copy.units.append(unit_copy)
		regiment_copies[regiment] = copy
		army.regiments.append(copy)
	for feature in terrain:
		var copy := feature.copy()
		copy.placed = false
		army.terrain.append(copy)
	for entry in deployment_abilities:
		army.deployment_abilities.append(entry.mirrored(unit_copies, regiment_copies))
	return army
