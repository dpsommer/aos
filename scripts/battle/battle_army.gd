class_name BattleArmy
extends RefCounted
## One side's army on the battlefield: its units and the terrain features it brings. See
## docs/design/battle.md.

var name: String
var faction_name: String
## The army's points, or -1 for a Spearhead, which has none.
var points := -1
var units: Array[BattleUnit] = []
## Terrain features the army sets up: its faction terrain, or a Spearhead's terrain features.
var terrain: Array[BattleTerrain] = []
## Which way the army's models face, in radians clockwise from east: towards the enemy.
var facing: float


func model_count() -> int:
	var count := 0
	for unit in units:
		count += unit.model_count()
	return count


## "Kharadron Overlords · 1940 pts", or "Kharadron Overlords · Spearhead".
func details() -> String:
	return "%s · %s" % [faction_name, "Spearhead" if points < 0 else "%d pts" % points]


## A copy, not yet deployed: the AI's army, until it can choose its own.
func mirror() -> BattleArmy:
	var army := BattleArmy.new()
	army.name = name
	army.faction_name = faction_name
	army.points = points
	for unit in units:
		army.units.append(unit.copy())
	for feature in terrain:
		var copy := feature.copy()
		copy.placed = false
		army.terrain.append(copy)
	return army
