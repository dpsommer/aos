class_name RosterEntry
extends Resource
## One line of an Army of Renown's roster options. A unit matches by [member unit] name, or by having
## all of [member keywords] and none of [member not_keywords].

## Name of the warscroll this entry allows. Empty for an entry matching by keywords.
@export var unit: String
@export var keywords: PackedStringArray
@export var not_keywords: PackedStringArray
## If set, the army can include one unit matching this entry for each unit matching any of these
## unit names or keywords ("HERO MONSTER" needs both). Otherwise any number, up to [member max].
@export var per: PackedStringArray
## The most units matching this entry the army can include ("0-1"). 0 for no limit.
@export var max: int
## Whether the army must include this unit.
@export var required: bool
## Whether this unit must be the army's general.
@export var general: bool
## Keywords the unit gains, e.g. WARMASTER.
@export var gains_keywords: PackedStringArray
