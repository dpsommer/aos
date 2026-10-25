class_name Faction
extends Resource
## All rules and warscrolls for one faction.

@export var id: String
@export var name: String
@export var grand_alliance: GrandAlliance.Type
@export var legends: bool
@export var battle_traits: Array[Ability]
@export var battle_formations: Array[BattleFormation]
@export var enhancement_tables: Array[EnhancementTable]
@export var lores: Array[Lore]
@export var warscrolls: Array[Warscroll]
@export var armies_of_renown: Array[ArmyOfRenown]
@export var spearheads: Array[Spearhead]
@export var path_to_glory: Array[RulesSection]


func get_warscroll(warscroll_id: String) -> Warscroll:
	for warscroll in warscrolls:
		if warscroll.id == warscroll_id:
			return warscroll
	return null
