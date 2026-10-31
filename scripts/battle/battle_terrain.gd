class_name BattleTerrain
extends RefCounted
## A terrain feature on the battlefield: one from the battleplan, a Spearhead feature or a
## faction terrain feature. See docs/design/battle.md.

enum Kind { AREA_OR_OBSTACLE, OBSCURING, PLACE_OF_POWER, SPEARHEAD, FACTION }

## A battleplan feature's name by its type.
const NAMES := {
	"area_or_obstacle": "Area terrain or obstacle",
	"obscuring": "Obscuring terrain",
	"place_of_power": "Place of Power",
}
const KINDS := {
	"area_or_obstacle": Kind.AREA_OR_OBSTACLE,
	"obscuring": Kind.OBSCURING,
	"place_of_power": Kind.PLACE_OF_POWER,
}

var kind: Kind
## The feature's name: a Spearhead or faction terrain feature's, else the battleplan's type,
## e.g. "Obscuring terrain".
var name: String
## "small", "medium" or "large".
var size: String
## Centre in inches from the battlefield's north-west corner, once placed.
var position: Vector2
## Whether it has been placed on the battlefield.
var placed := false
## Width (x) and depth (y) in inches, before [member rotation].
var footprint: Vector2
## Clockwise rotation in radians.
var rotation: float
## A faction terrain feature's base, or null.
var base: BaseSize
## A faction terrain feature's warscroll, or null.
var warscroll: Warscroll


## A battleplan's terrain feature, placed where its map shows it.
static func from_battleplan(feature: MapFeature) -> BattleTerrain:
	var terrain := BattleTerrain.new()
	terrain.kind = KINDS.get(feature.type, Kind.AREA_OR_OBSTACLE)
	terrain.name = NAMES.get(feature.type, feature.type.capitalize())
	terrain.size = feature.size
	var width: float = MapFeature.TERRAIN_WIDTHS.get(feature.size, MapFeature.TERRAIN_WIDTHS.medium)
	terrain.footprint = Vector2(width, width)
	terrain.position = feature.position
	terrain.placed = true
	return terrain


## A Spearhead terrain feature, not yet placed.
static func from_spearhead(feature: SpearheadTerrain) -> BattleTerrain:
	var terrain := BattleTerrain.new()
	terrain.kind = Kind.SPEARHEAD
	terrain.name = feature.name
	terrain.size = feature.size
	var width: float = SpearheadTerrain.WIDTHS.get(feature.size, SpearheadTerrain.WIDTHS.large)
	terrain.footprint = Vector2(width, width)
	return terrain


## A faction terrain feature, sized from its base, not yet placed.
static func from_warscroll(of: Warscroll) -> BattleTerrain:
	var terrain := BattleTerrain.new()
	terrain.kind = Kind.FACTION
	terrain.name = of.name
	terrain.warscroll = of
	terrain.base = of.base_size if of.base_size else BaseSize.model()
	terrain.footprint = terrain.base.footprint()
	return terrain


## The radius of a circle around the feature's footprint, in inches.
func reach() -> float:
	return footprint.length() / 2


func copy() -> BattleTerrain:
	var terrain := BattleTerrain.new()
	for property in ["kind", "name", "size", "position", "placed", "footprint", "rotation", "base", "warscroll"]:
		terrain.set(property, get(property))
	return terrain
