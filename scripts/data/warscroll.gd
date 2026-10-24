class_name Warscroll
extends Resource
## A unit's rules: characteristics, weapons, abilities and battle profile.

@export var id: String
@export var name: String
## Expansion the warscroll comes from, e.g. "Scourge of Ghyran". Empty for the battletome.
@export var source: String
@export var legends: bool

@export_group("Battle profile")
@export var points: int
@export var unit_size: int
@export var base_size: String
@export var can_reinforce: bool
@export var regiment_options: PackedStringArray
@export var notes: String

@export_group("Characteristics")
## Move in inches. 0 for units that can't move, such as faction terrain.
@export var move: int
@export var health: int
## The x of an x+ save roll.
@export var save: int
## The x of an x+ ward roll. 0 if the unit has no ward.
@export var ward: int
@export var control: int

@export_group("Rules")
@export var ranged_weapons: Array[Weapon]
@export var melee_weapons: Array[Weapon]
@export var abilities: Array[Ability]
@export var keywords: PackedStringArray
## Wargear options and model breakdown.
@export var composition: String


func has_keyword(keyword: String) -> bool:
	return keyword in keywords
