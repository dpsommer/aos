class_name CoreRules
extends Resource
## Rules every army uses: the core rules' abilities, the universal manifestation lores and the
## General's Handbook battlepack.

## Deployment, core, command, magic and passive abilities, such as 'Normal Move' and 'Rally'.
@export var abilities: Array[Ability]
## Universal weapon abilities, such as 'Crit (Mortal)'.
@export var weapon_abilities: Array[Ability]
## Universal terrain abilities, such as 'Cover'.
@export var terrain_abilities: Array[Ability]
## Manifestation lores any army can take, such as 'Forbidden Power'.
@export var manifestation_lores: Array[Lore]
## The manifestations those lores summon.
@export var manifestations: Array[Warscroll]
## The current General's Handbook battlepack: season rules, battle tactics and battleplans.
@export var battlepack: Battlepack


func get_ability(ability_name: String) -> Ability:
	for ability in abilities:
		if ability.name == ability_name:
			return ability
	return null


func get_manifestation(warscroll_id: String) -> Warscroll:
	for warscroll in manifestations:
		if warscroll.id == warscroll_id:
			return warscroll
	return null
