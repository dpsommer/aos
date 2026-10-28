class_name ArmyOfRenown
extends Resource
## An alternative set of faction rules with a restricted roster.

@export var name: String
@export var source: String
@export var legends: bool
## The keyword every unit in the army that its roster allows gains, e.g. "MAGNATE’S CREW". Empty
## if the data doesn't give one.
@export var keyword: String
## Description and roster restrictions.
@export var text: String
## The roster options in [member text], for the army builder. Null if the data has none.
@export var roster: ArmyRoster
@export var battle_traits: Array[Ability]
@export var enhancement_tables: Array[EnhancementTable]
@export var lores: Array[Lore]
