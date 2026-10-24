class_name Weapon
extends Resource
## A ranged or melee weapon profile on a warscroll.

@export var name: String
## Range in inches. 0 for melee weapons.
@export var range: int
## Attacks and Damage can be dice expressions such as "2D6" or "D3+1".
@export var attacks: String
@export var hit: int
@export var wound: int
@export var rend: int
@export var damage: String
## Weapon abilities such as "Shoot in Combat" or "Crit (Mortal)".
@export var abilities: PackedStringArray


func is_melee() -> bool:
	return range == 0
