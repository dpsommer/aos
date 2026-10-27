class_name ArmyRegiment
extends Resource
## A regiment: a Hero leader followed by the units accompanying them, or a Regiment of Renown.

@export var id: String
@export var name: String
## The leader first, unless the regiment is empty or a Regiment of Renown.
@export var units: Array[ArmyUnit]
## Name of the Regiment of Renown this regiment is, or empty for a regiment the player built.
@export var regiment_of_renown: String


func is_regiment_of_renown() -> bool:
	return not regiment_of_renown.is_empty()


func leader() -> ArmyUnit:
	return null if units.is_empty() or is_regiment_of_renown() else units[0]
