class_name Lore
extends Resource
## A spell, prayer or manifestation lore.

@export var name: String
## "spell", "prayer" or "manifestation".
@export var kind: String
@export var points: int
@export var entries: Array[Ability]
