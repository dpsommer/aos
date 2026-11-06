class_name TerrainController
extends BattlefieldController
## One terrain feature's rules: its universal terrain abilities (Terrain 1.2), held as the same
## modifiers units have. Cover is an aura that takes 1 off hit rolls against a unit behind or on it.
## A faction terrain feature also fights and takes damage as a unit: see [member proxy].

## Which abilities each kind of terrain has (Terrain 1.4, Spearhead 5.0). Unstable and Impassable
## are movement rules; without terrain height, only faction terrain blocks models.
const HAS_OBSCURING: Array[BattleTerrain.Kind] = [BattleTerrain.Kind.OBSCURING]

var feature: BattleTerrain
## The unit standing in for a faction terrain feature (Terrain 1.5), or null.
var proxy: UnitController


func _init(on: GameController, of: BattleTerrain) -> void:
	super(on)
	feature = of
	var cover := Modifier.new()
	cover.source_name = "Cover"
	cover.stat = &"hit"
	cover.value = -1
	cover.against = true
	cover.passive = true
	cover.conditions = ["covered_by_holder"]
	modifiers.add(cover)


## Whether this feature gives [param target] Cover from [param attacker]: it's behind or wholly on
## it, unless it charged this turn or has FLY.
func covers(attacker: BattleUnit, target: BattleUnit) -> bool:
	if attacker == null or target == null or not _is_placed():
		return false
	if game.stats.has_keyword(target, "FLY") or game.controller_of(target).charged:
		return false
	return BattleGeometry.is_wholly_on(target, feature) or BattleGeometry.is_behind(attacker, target, feature)


## Whether this feature is Obscuring, and so stops [param attacker] shooting at [param target]: the
## target is behind or wholly on it, has no FLY and the attacker isn't within its combat range.
func blocks_shooting(attacker: BattleUnit, target: BattleUnit) -> bool:
	if not is_obscuring() or not _is_placed() or game.stats.has_keyword(target, "FLY"):
		return false
	if BattleGeometry.in_combat_with(attacker, target):
		return false
	return BattleGeometry.is_wholly_on(target, feature) or BattleGeometry.is_behind(attacker, target, feature)


func is_obscuring() -> bool:
	if feature.kind in HAS_OBSCURING:
		return true
	return feature.kind == BattleTerrain.Kind.SPEARHEAD and feature.size == "large"


func _is_placed() -> bool:
	return feature.placed and (proxy == null or not proxy.unit.destroyed)
