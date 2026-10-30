class_name RealmBattlefield
extends Resource
## One side of a Spearhead realm battlefield, e.g. Aqshy: its printed objectives and its twist deck.

@export var name: String
## Objectives printed on this side, each a [MapFeature] whose type is the objective's name.
@export var objectives: Array[MapFeature]
## Terrain features set up on this side before the players set up theirs, each a [MapFeature]
## whose type names one of the battlepack's terrain features, e.g. Ossia's Crypt of Blood.
@export var terrain: Array[MapFeature]
## Areas printed on this side that rules refer to as roads, as polygons. Empty if none.
@export var roads: Array[PackedVector2Array]
## Relics the players set up in their territories before the battle, the defender first. Empty
## if the battlepack has no relics.
@export var starting_relics: PackedStringArray
## The twist deck used when the battle is fought on this side.
@export var twists: Array[TwistCard]


func get_objective(objective_name: String) -> MapFeature:
	for objective in objectives:
		if objective.type == objective_name:
			return objective
	return null
