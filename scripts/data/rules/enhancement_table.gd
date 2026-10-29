class_name EnhancementTable
extends Resource
## A group of enhancements of one type, e.g. the "Lords of the Sky-fleets" heroic traits.

## Enhancement type, e.g. "Heroic Traits" or "Artefacts of Power".
@export var name: String
## Name of this particular table within the type, if any.
@export var group: String
## Expansion the table comes from, e.g. "Scourge of Ghyran". Empty for the battletome.
@export var source: String
## Whether the table is Legends, as a table from a Scourge the battlepack doesn't use is.
@export var legends: bool
## Names of the only warscrolls that can be given these enhancements, e.g. the Skyvessels for Great
## Endrinworks. Empty when the table has no restriction of its own (Heroic Traits and Artefacts of
## Power still need a Hero).
@export var units: PackedStringArray
## How many of these enhancements an army can include, e.g. 3 First Circle Titles for the Swords of
## Chaos. Core Rules 4.1 allow 1.
@export var max := 1
@export var entries: Array[Ability]
