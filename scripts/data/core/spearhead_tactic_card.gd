class_name SpearheadTacticCard
extends Resource
## A Spearhead battle tactic card. A player either completes its battle tactic at the end of their
## turn or uses its command, then discards it.

## The battle tactic's name, which is also the card's.
@export var name: String
## When the battle tactic is completed, e.g. "You complete this battle tactic if you control the
## Ignax objective at the end of your turn."
@export var condition: String
## The command the card can be used for instead. It costs no command points.
@export var command: Ability
