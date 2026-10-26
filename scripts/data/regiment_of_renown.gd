class_name RegimentOfRenown
extends Resource
## A pre-built regiment, with abilities of its own, that armies of several factions can include.

@export var name: String
@export var source: String
@export var legends: bool
@export var points: int
@export var text: String
@export var units: Array[RegimentUnit]
@export var abilities: Array[Ability]
## Warscrolls of units the regiment defines itself, such as Gotrek Gurnisson. Other units'
## warscrolls belong to their home faction.
@export var warscrolls: Array[Warscroll]


func get_warscroll(warscroll_id: String) -> Warscroll:
	for warscroll in warscrolls:
		if warscroll.id == warscroll_id:
			return warscroll
	return null
