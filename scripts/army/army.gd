class_name Army
extends Resource
## An army built in the Forge: its regiments, auxiliary units and army-wide choices.
## See docs/design/forge.md.

const DEFAULT_POINTS_LIMIT := 2000

## Identifies the saved army, and names its file. Empty until it is first saved.
@export var id: String
@export var faction_id: String
@export var name: String
## Name of the Army of Renown, or empty for the faction's own rules.
@export var army_of_renown: String
## Name of the battle formation. Armies of Renown have none.
@export var formation: String
@export var points_limit := DEFAULT_POINTS_LIMIT
## Whether the Forge lists Legends warscrolls and Regiments of Renown.
@export var show_legends: bool
## Whether to skip validation and the builder's limits, e.g. for narrative play.
@export var override_constraints: bool
@export var regiments: Array[ArmyRegiment]
## Units that aren't in a regiment.
@export var auxiliary: Array[ArmyUnit]
## [member ArmyUnit.uid] of the general, or empty.
@export var general_uid: String
## Names of up to 2 battle tactics cards.
@export var tactics: PackedStringArray
@export var spell_lore: String
@export var prayer_lore: String
@export var manifestation_lore: String
## Warscroll id of the faction terrain feature, or empty.
@export var faction_terrain: String


## Every unit in the army, regiments first.
func all_units() -> Array[ArmyUnit]:
	var result: Array[ArmyUnit] = []
	for regiment in regiments:
		result.append_array(regiment.units)
	result.append_array(auxiliary)
	return result


func find_unit(uid: String) -> ArmyUnit:
	for unit in all_units():
		if unit.uid == uid:
			return unit
	return null


## The regiment holding the unit with [param uid], or null for an auxiliary or unknown unit.
func regiment_of(uid: String) -> ArmyRegiment:
	for regiment in regiments:
		for unit in regiment.units:
			if unit.uid == uid:
				return regiment
	return null


func find_regiment(regiment_id: String) -> ArmyRegiment:
	for regiment in regiments:
		if regiment.id == regiment_id:
			return regiment
	return null
