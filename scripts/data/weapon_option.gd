class_name WeaponOption
extends Resource
## A wargear choice on a warscroll, e.g. "1/5 models can replace their Warhammer with a Grandhammer".

## The weapon models can take.
@export var name: String
## The weapon it replaces.
@export var replaces: String
## How many models can take it for every [member per] models. Unused if [member choice] is set.
@export var max: int
@export var per: int
## Whether every model can take it, e.g. an either/or weapon choice.
@export var choice: bool
## Further restrictions, e.g. "The champion cannot replace their weapon".
@export var note: String
