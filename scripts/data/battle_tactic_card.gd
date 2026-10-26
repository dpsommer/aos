class_name BattleTacticCard
extends Resource
## A battle tactics card: an Affray, a Strike and a Domination battle tactic, completed in order.

@export var number: int
@export var name: String
## Rules that apply to the whole card, e.g. picking the enemy hideout. Empty if none.
@export var text: String
## The card's battle tactics in the order they must be completed.
@export var tactics: Array[BattleTactic]
## Rulings on the card, each {"about": String, "question": String, "answer": String}.
@export var faqs: Array[Dictionary]
