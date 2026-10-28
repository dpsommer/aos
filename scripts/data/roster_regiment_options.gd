class_name RosterRegimentOptions
extends Resource
## Regiment options an Army of Renown gives some of its leaders as well as their own, such as
## Gorechosen Champions' "Any Bloodbound Warmongers can be added to a regiment led by a GORECHOSEN
## CHAMPIONS unit".

## Unit names or keywords of the leaders that gain the options, matched like
## [member RosterEntry.per]. Empty for every leader, as when the text names the keyword all of the
## army's units gain.
@export var leaders: PackedStringArray
## Regiment options as written on warscrolls, e.g. "Any Bloodbound Warmonger".
@export var options: PackedStringArray
## Whether Heroes with the options' keywords can join as well, rather than only those the options
## name or whose role they name, as The Magnate's Crew Ironclad's "Any MAGNATE’S CREW units" lets an
## Endrinmaster with Dirigible Suit join.
@export var heroes: bool
