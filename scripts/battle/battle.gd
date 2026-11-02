class_name Battle
extends RefCounted
## A battle ready to be fought: the battlefield, its objectives and terrain, and both armies, with
## Quick Play's random choices made. [BattleBuilder] makes it from a [BattleSetup]. Who is the
## attacker is decided by the roll-off ([method assign_roles]), and in Spearhead the defender then
## picks the deployment map ([method choose_deployment]). Positions are in inches from the
## battlefield's north-west corner, x east and y south. See docs/design/battle.md.

const MATCHED_PLAY_BATTLEFIELD := Vector2(60, 44)
const SPEARHEAD_BATTLEFIELD := Vector2(30, 22)
## Units within this many inches of a Matched Play objective contest it.
const CONTROL_RANGE := 3.0
## A Matched Play objective marker's diameter: 40mm.
const OBJECTIVE_MARKER := 40.0 / BaseSize.MM_PER_INCH

var mode: BattleSetup.Mode
var battlefield_size: Vector2
## The battleplan's name, or the realm battlefield side's, e.g. "Aqshy".
var title: String
## The battleplan's twist, in Matched Play.
var twist: String
## The battleplan's table, in Matched Play, or 0.
var table: int
## Whether the battleplan or realm battlefield was picked at random.
var was_random: bool

## Matched Play's battleplan, or null.
var battleplan: Battleplan
## Spearhead's battlepack, realm battlefield side and deployment map, or null.
var battlepack: SpearheadBattlepack
var realm: RealmBattlefield
var deployment: DeploymentMap

var objectives: Array[MapFeature] = []
## Roads printed on a realm battlefield.
var roads: Array[PackedVector2Array] = []
## The battlefield's terrain features, the armies' own (see [member BattleArmy.terrain]) not
## included.
var terrain: Array[BattleTerrain] = []

var player: BattleArmy
var opponent: BattleArmy
var player_is_attacker: bool
## Whether the roll-off has decided who is the attacker.
var roles_assigned := false
## The roll-off, once rolled.
var roll_off: RollOff
## Each side's territory as polygons, once known: after the roll-off in Matched Play, after the
## defender picks the deployment map in Spearhead.
var player_territory: Array[PackedVector2Array] = []
var opponent_territory: Array[PackedVector2Array] = []


func is_spearhead() -> bool:
	return mode == BattleSetup.Mode.SPEARHEAD


## Makes the player the attacker if [param player_attacks], else the defender. In Matched Play
## that gives each side its territory. In Spearhead each side takes its terrain features: the
## defender the first terrain group (or every feature), the attacker the second.
func assign_roles(player_attacks: bool) -> void:
	player_is_attacker = player_attacks
	roles_assigned = true
	if battleplan:
		var attacker_territory := BattleBuilder.merge_rects(battleplan.attacker_territory)
		var defender_territory := BattleBuilder.merge_rects(battleplan.defender_territory)
		player_territory = attacker_territory if player_attacks else defender_territory
		opponent_territory = defender_territory if player_attacks else attacker_territory
		face_armies()
	if battlepack:
		player.terrain = BattleBuilder.spearhead_terrain(battlepack, 1 if player_attacks else 0)
		opponent.terrain = BattleBuilder.spearhead_terrain(battlepack, 0 if player_attacks else 1)


## Spearhead: the defender fights on [param map], the player taking territory A if
## [param player_has_a], else B.
func choose_deployment(map: DeploymentMap, player_has_a: bool) -> void:
	deployment = map
	player_territory = [map.territory_a if player_has_a else map.territory_b] as Array[PackedVector2Array]
	opponent_territory = [map.territory_b if player_has_a else map.territory_a] as Array[PackedVector2Array]
	face_armies()


## Whether each side has its territory.
func has_territories() -> bool:
	return not player_territory.is_empty() and not opponent_territory.is_empty()


## Turns each army, and its units, towards the enemy territory.
func face_armies() -> void:
	for army in [player, opponent]:
		if army == null:
			continue
		var away := PlaceholderDeployment.centroid(enemy_territory_of(army)) - PlaceholderDeployment.centroid(territory_of(army))
		army.facing = away.angle() if away.length() > 0.001 else Vector2.UP.angle()
		for unit: BattleUnit in army.units:
			if not unit.deployed:
				unit.facing = army.facing


func attacker() -> BattleArmy:
	return player if player_is_attacker else opponent


func defender() -> BattleArmy:
	return opponent if player_is_attacker else player


## The other side's army.
func enemy_of(army: BattleArmy) -> BattleArmy:
	return opponent if army == player else player


func territory_of(army: BattleArmy) -> Array[PackedVector2Array]:
	return player_territory if army == player else opponent_territory


func enemy_territory_of(army: BattleArmy) -> Array[PackedVector2Array]:
	return opponent_territory if army == player else player_territory


## The radius in inches of [param objective]'s control zone (Matched Play) or of the objective
## itself (Spearhead).
func objective_radius(objective: MapFeature) -> float:
	return battlepack.radius_of(objective) if battlepack else CONTROL_RANGE


## Every terrain feature: the battlefield's, then the player's, then the opponent's.
func all_terrain() -> Array[BattleTerrain]:
	var result: Array[BattleTerrain] = terrain.duplicate()
	if player:
		result.append_array(player.terrain)
	if opponent:
		result.append_array(opponent.terrain)
	return result


## "60" × 44"".
func battlefield_text() -> String:
	return "%d\" × %d\"" % [int(battlefield_size.x), int(battlefield_size.y)]
