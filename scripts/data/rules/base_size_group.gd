class_name BaseSizeGroup
extends Resource
## One group of models in a unit with mixed bases, e.g. "2 × Gryph-hounds: 40mm". See [BaseSize].

## Who the group is, e.g. "Gryph-hounds". Empty for a share of the unit, e.g. "9/10 28.5mm".
@export var name: String
## How many models the group has in a unit of the warscroll's unit size.
@export var count := 1
## A note on the group, e.g. "Champion".
@export var note: String
## The base each of its models has: round, oval or model, never mixed.
@export var base: BaseSize
