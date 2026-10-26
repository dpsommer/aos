class_name BattleTactic
extends Resource
## One battle tactic on a battle tactics card.

## Values of [member kind], in the order a card's battle tactics must be completed.
const KINDS: PackedStringArray = ["affray", "strike", "domination"]

@export var name: String
## "affray", "strike" or "domination".
@export var kind: String
## When the battle tactic is completed, e.g. "You complete this battle tactic at the end of your
## turn if you control the enemy hideout."
@export var condition: String
@export var victory_points: int
