class_name BattleFormation
extends Resource
## An army-wide option that grants one or more abilities.

@export var name: String
## Expansion the formation comes from, e.g. "Scourge of Ghyran". Empty for the battletome.
@export var source: String
## Whether the formation is Legends, as a formation from a Scourge the battlepack doesn't use is.
## Armies can only pick one when they override their constraints.
@export var legends: bool
@export var points: int
@export var abilities: Array[Ability]
