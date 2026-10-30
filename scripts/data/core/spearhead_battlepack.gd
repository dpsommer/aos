class_name SpearheadBattlepack
extends Resource
## A Spearhead battlepack: a realm battlefield, its Spearhead deck and its battleplan.
##
## Map positions are in inches from the battlefield's north-west corner, x east and y south.

@export var name: String
@export var battle_rounds: int
## Battlefield size in inches: width (x) by depth (y).
@export var battlefield_size: Vector2
## Rules of the battlepack itself, e.g. "5.0 Terrain".
@export var sections: Array[RulesSection]
## Abilities every army can use, e.g. 'Call for Reinforcements'.
@export var abilities: Array[Ability]
## The battlepack's own versions of the terrain abilities its terrain features have, e.g. 'Cover'.
@export var terrain_abilities: Array[Ability]
## Terrain features each player sets up in their territory, and mystical terrain features.
@export var terrain_features: Array[SpearheadTerrain]
## Sets of terrain features the defender picks from, the attacker taking the other, each
## {"name": String, "features": PackedStringArray}. Empty if each player sets up one of each size.
@export var terrain_groups: Array[Dictionary]
## Names of the objectives printed on the realm battlefield, e.g. "Dracothion".
@export var objective_names: PackedStringArray
## Radius in inches of each objective's printed circle. A model on it is contesting it.
@export var objective_radius: float
## Each side of the realm battlefield, with its objectives and twist deck.
@export var realms: Array[RealmBattlefield]
@export var deployment_maps: Array[DeploymentMap]
@export var battleplan_name: String
## Rules of the battleplan, e.g. "Pre-battle Sequence" and "Seizing the Initiative".
@export var battleplan_sections: Array[RulesSection]
## How players score victory points at the end of each of their turns, one rule per entry.
@export var scoring: PackedStringArray
## The cards in each player's battle tactic deck. Both players' decks are the same.
@export var battle_tactic_cards: Array[SpearheadTacticCard]
## Rulings on the battlepack, each {"about": String, "question": String, "answer": String}.
@export var faqs: Array[Dictionary]


func get_realm(realm_name: String) -> RealmBattlefield:
	for realm in realms:
		if realm.name == realm_name:
			return realm
	return null


func get_deployment_map(map_name: String) -> DeploymentMap:
	for map in deployment_maps:
		if map.name == map_name:
			return map
	return null


func get_terrain_feature(feature_name: String) -> SpearheadTerrain:
	for feature in terrain_features:
		if feature.name == feature_name:
			return feature
	return null


## The radius of [param objective]'s circle in inches.
func radius_of(objective: MapFeature) -> float:
	return objective.radius if objective.radius > 0 else objective_radius


func get_terrain_ability(ability_name: String) -> Ability:
	for ability in terrain_abilities:
		if ability.name == ability_name:
			return ability
	return null
