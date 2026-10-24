class_name Ability
extends Resource
## A rule with a timing and effect: battle traits, enhancements, warscroll abilities, prayers.

## Icon category, e.g. "offensive", "movement", "special".
@export var category: String
@export var name: String
## When the ability is used, e.g. "Passive" or "Your Hero Phase".
@export var timing: String
## Usage limit, e.g. "Once Per Battle". Empty if unlimited.
@export var frequency: String
@export var declare: String
@export var effect: String
## Free text that isn't part of Declare or Effect.
@export var text: String
@export var keywords: PackedStringArray
## Named sub-effects the player picks from, each {"name": String, "text": String}.
@export var options: Array[Dictionary]
## Points cost when the ability is an enhancement.
@export var points: int
## Expansion the ability comes from, e.g. "Scourge of Aqshy". Empty for the battletome.
@export var source: String
