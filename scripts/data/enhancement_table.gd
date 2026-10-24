class_name EnhancementTable
extends Resource
## A group of enhancements of one type, e.g. the "Lords of the Sky-fleets" heroic traits.

## Enhancement type, e.g. "Heroic Traits" or "Artefacts of Power".
@export var name: String
## Name of this particular table within the type, if any.
@export var group: String
@export var source: String
@export var entries: Array[Ability]
