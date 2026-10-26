class_name Battleplan
extends Resource
## A battleplan: its twist, scoring and map.
##
## Map positions are in inches from the battlefield's north-west corner, x east and y south.

@export var number: int
## Battleplan table (1 or 2) the battleplan is rolled on.
@export var table: int
@export var name: String
## Set-up rules, e.g. where terrain must be placed. Empty if none.
@export var text: String
## Rules text introducing the twist and saying who can use its abilities.
@export var twist: String
@export var abilities: Array[Ability]
## How players score victory points at the end of each of their turns, one rule per entry.
@export var scoring: PackedStringArray
@export var objectives: Array[MapFeature]
@export var terrain: Array[MapFeature]
## Areas of the attacker's and defender's territories. The rest of the battlefield is neutral.
@export var attacker_territory: Array[Rect2]
@export var defender_territory: Array[Rect2]
## Rulings on the battleplan, each {"about": String, "question": String, "answer": String}.
@export var faqs: Array[Dictionary]
