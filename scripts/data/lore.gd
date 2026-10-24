class_name Lore
extends Resource
## A spell, prayer or manifestation lore.

@export var name: String
## "spell", "prayer" or "manifestation".
@export var kind: String
@export var points: int
## Expansion the lore comes from, e.g. "Scourge of Ghyran". Empty for the battletome.
@export var source: String
@export var entries: Array[Ability]
