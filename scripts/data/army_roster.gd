class_name ArmyRoster
extends Resource
## The roster restrictions of an Army of Renown: which units its armies can include.

## Every unit in the army must match one of these entries.
@export var entries: Array[RosterEntry]
## Other factions' units the army can draw from as well as its own.
@export var included_units: Array[RosterInclusion]
## Regiment options the army's leaders gain as well as their own.
@export var regiment_options: Array[RosterRegimentOptions]
@export var regiments_of_renown := true
@export var faction_terrain := true
## Whether the army can pick a manifestation lore.
@export var manifestations := true
## Names of warscrolls the army can't include even if an entry matches them ("You cannot include
## Morathi-Khaine or the Shadow Queen").
@export var excluded_units: PackedStringArray
## Two keywords, e.g. ["IRONJAWZ", "KRULEBOYZ"] for Big Waaagh!: for each regiment led by a Hero
## with one, the army must include a regiment led by a Hero with the other. A Hero with both
## (Kragnos) leads for one of them, using that faction's version of its warscroll, and can't include
## units of both in its regiment.
@export var paired_leaders: PackedStringArray
## A unit that isn't a Hero but can be the general instead of one, gaining the HERO keyword, e.g.
## The Magnate's Crew's Arkanaut Ironclad. Empty for none.
@export var non_hero_general: String
## Units whose inclusion stops [member non_hero_general] being the general, e.g. Brokk Grungsson.
@export var non_hero_general_unless: PackedStringArray
