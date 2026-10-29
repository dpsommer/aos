class_name Spearhead
extends Resource
## A fixed Spearhead army with its own rules and warscrolls.

@export var name: String
@export var text: String
## Name of the general's warscroll.
@export var general: String
@export var units: Array[SpearheadUnit]
@export var battle_traits: Array[Ability]
@export var regiment_abilities: Array[Ability]
@export var enhancements: Array[Ability]
## Spearhead versions of warscrolls. These differ from the matched play warscrolls.
@export var warscrolls: Array[Warscroll]


func get_warscroll(warscroll_name: String) -> Warscroll:
	for warscroll in warscrolls:
		if warscroll.name == warscroll_name:
			return warscroll
	return null
