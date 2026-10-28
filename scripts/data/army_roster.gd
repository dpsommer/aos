class_name ArmyRoster
extends Resource
## The roster restrictions of an Army of Renown: which units its armies can include.

## Every unit in the army must match one of these entries.
@export var entries: Array[RosterEntry]
## Other factions' units the army can draw from as well as its own.
@export var included_units: Array[RosterInclusion]
@export var regiments_of_renown := true
@export var faction_terrain := true
## Whether the army can pick a manifestation lore.
@export var manifestations := true
## Names of warscrolls the army can't include even if an entry matches them ("You cannot include
## Morathi-Khaine or the Shadow Queen").
@export var excluded_units: PackedStringArray
