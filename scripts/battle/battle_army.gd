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
## The Spearhead it's made from, or null for a Forge army.
var spearhead: Spearhead
## The Spearhead regiment ability and enhancement it chose after the roll-off, or empty until it
## has (see [method choose_spearhead_options]).
var regiment_ability := ""
var enhancement := ""
## The core rules its universal deployment abilities come from, or null.
var core: CoreRules
## Names of the battle tactics cards it took, in Matched Play.
var tactics := PackedStringArray()
## The abilities of its Forge army that aren't on a warscroll: its battle traits and battle
## formation's, by where they come from. Empty for a Spearhead, whose rules are on [member spearhead].
var army_abilities: Array[Ability] = []
## The spells, prayers and summoning abilities from the lores it took.
var lore_abilities: Array[Ability] = []


## Whether it's a Spearhead that has yet to choose its regiment ability and enhancement.
func needs_spearhead_options() -> bool:
	if spearhead == null:
		return false
	return (regiment_ability.is_empty() and not spearhead.regiment_abilities.is_empty()) \
			or (enhancement.is_empty() and not spearhead.enhancements.is_empty())


## A Spearhead chooses its regiment ability called [param regiment] and its general's enhancement
## called [param enhancement_name], which fills in its deployment abilities again with them.
func choose_spearhead_options(regiment: String, enhancement_name: String) -> void:
	regiment_ability = regiment
	enhancement = enhancement_name
	if spearhead:
		DeploymentAbilities.for_spearhead_choices(self, spearhead, regiment, enhancement_name, core)


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
	army.spearhead = spearhead
	army.regiment_ability = regiment_ability
	army.enhancement = enhancement
	army.core = core
	army.tactics = tactics
	army.army_abilities = army_abilities
	army.lore_abilities = lore_abilities
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
