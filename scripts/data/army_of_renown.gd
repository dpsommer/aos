class_name ArmyOfRenown
extends Resource
## An alternative set of faction rules with a restricted roster.

@export var name: String
@export var source: String
## Description and roster restrictions.
@export var text: String
@export var battle_traits: Array[Ability]
@export var enhancement_tables: Array[EnhancementTable]
@export var lores: Array[Lore]
