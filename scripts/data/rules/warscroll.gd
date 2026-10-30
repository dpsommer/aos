class_name Warscroll
extends Resource
## A unit's rules: characteristics, weapons, abilities and battle profile.

@export var id: String
@export var name: String
## Expansion the warscroll comes from, e.g. "Scourge of Ghyran". Empty for the battletome.
@export var source: String
## Whether the warscroll is Legends: marked so in the data, or from a Scourge the battlepack doesn't
## use (see [member FactionLoader.scourge]).
@export var legends: bool
## The only Army of Renown that can include this unit, e.g. "The Iron March" for its Immolator
## Cogfort. Empty for a unit any army of its faction can include.
@export var army_of_renown: String
## Whether only an ability sets this unit up, such as the Auto-Endrins a Zontari Endrin Dock
## releases, so an army can't include it. [FactionLoader] sets it for a unit (not a manifestation)
## that one of its faction's abilities summons.
@export var summoned: bool

@export_group("Battle profile")
@export var points: int
@export var unit_size: int
@export var base_size: String
@export var can_reinforce: bool
@export var regiment_options: PackedStringArray
@export var notes: String

@export_group("Characteristics")
## Move in inches, or dice such as "D6+3" for units that roll their move. "0" for units that
## can't move, such as faction terrain.
@export var move: String
@export var health: int
## The x of an x+ save roll.
@export var save: int
## The x of an x+ ward roll. 0 if the unit has no ward.
@export var ward: int
@export var control: int
## Banishment value of a manifestation. 0 for other units.
@export var banishment: int

@export_group("Rules")
@export var ranged_weapons: Array[Weapon]
@export var melee_weapons: Array[Weapon]
@export var abilities: Array[Ability]
@export var keywords: PackedStringArray
## Wargear options and model breakdown.
@export var composition: String
## The wargear choices in [member composition], for the army builder. Empty if the data has none.
@export var weapon_options: Array[WeaponOption]


func has_keyword(keyword: String) -> bool:
	return keyword in keywords
