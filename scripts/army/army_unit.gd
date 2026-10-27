class_name ArmyUnit
extends Resource
## One unit in an army: a warscroll plus the player's choices for it.

## Identifies the unit within its army, e.g. for the general.
@export var uid: String
@export var warscroll_id: String
## Home faction of a unit in a Regiment of Renown, or empty for the army's faction and for units the
## regiment defines itself.
@export var faction_id: String
## Player-given name, e.g. "Gilded Shields". Empty to show the warscroll name.
@export var label: String
@export var reinforced: bool
## Enhancement names by enhancement type, e.g. {"Heroic Traits": "Shock and Awe"}.
@export var enhancements: Dictionary
## Model counts by [member WeaponOption.name]. A missing option uses its maximum.
@export var weapon_options: Dictionary
