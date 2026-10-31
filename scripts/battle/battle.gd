class_name Battle
extends RefCounted
## A battle ready to be fought: the battlefield, its objectives and terrain, and both armies, with
## Quick Play's random choices made. [BattleBuilder] makes it from a [BattleSetup]. Positions are
## in inches from the battlefield's north-west corner, x east and y south. See
## docs/design/battle.md.

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
## Each side's territory as polygons.
var player_territory: Array[PackedVector2Array] = []
var opponent_territory: Array[PackedVector2Array] = []


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
