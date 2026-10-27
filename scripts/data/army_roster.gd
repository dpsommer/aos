class_name ArmyRoster
extends Resource
## The roster restrictions of an Army of Renown: which units its armies can include.

## Every unit in the army must match one of these entries.
@export var entries: Array[RosterEntry]
@export var regiments_of_renown := true
@export var faction_terrain := true
