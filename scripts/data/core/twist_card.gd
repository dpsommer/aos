class_name TwistCard
extends Resource
## A Spearhead twist card: a rule that applies to the battle round in which it is drawn.

@export var name: String
## The twist's rules, followed when the card is drawn.
@export var text: String
## Named effects the underdog picks from, each {"name": String, "text": String}. Empty if none.
@export var options: Array[Dictionary]
