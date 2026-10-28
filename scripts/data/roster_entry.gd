class_name RosterEntry
extends Resource
## One line of an Army of Renown's roster options. A unit matches by [member unit] name, by being one
## of the [member one_of] names, or by having all of [member keywords] and none of [member not_keywords].

## Name of the warscroll this entry allows. Empty for an entry matching by keywords or [member one_of].
@export var unit: String
## Names of warscrolls this entry allows as alternatives ("0-1 Gaunt Summoner or Gaunt Summoner on
## Disc of Tzeentch"). [member max], [member required] and [member general] count them together.
@export var one_of: PackedStringArray
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
