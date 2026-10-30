class_name MapFeature
extends Resource
## An objective or terrain feature on a battleplan map.

## Values of [member type] for objectives.
const OBJECTIVE_TYPES: PackedStringArray = ["Sun Seekers", "Golden Lions", "Heldenhain", "Scions of the Comet"]
## Values of [member type] for terrain features.
const TERRAIN_TYPES: PackedStringArray = ["area_or_obstacle", "obscuring", "place_of_power"]
## Values of [member size] for terrain features.
const TERRAIN_SIZES: PackedStringArray = ["small", "medium"]

## Objective type, e.g. "Sun Seekers", or terrain type: "area_or_obstacle" (the player picks
## either), "obscuring" or "place_of_power".
@export var type: String
## Terrain size, "small" or "medium". Empty for objectives.
@export var size: String
## Centre in inches from the battlefield's north-west corner.
@export var position: Vector2
## Radius in inches of a Spearhead objective that is bigger or smaller than its battlepack's
## [member SpearheadBattlepack.objective_radius]. 0 if it isn't.
@export var radius: float
## Width (x) and depth (y) in inches of a rectangular Spearhead objective, before [member rotation].
## Zero for a circular one.
@export var extent: Vector2
## Clockwise rotation in degrees of a rectangular Spearhead objective about its centre.
@export var rotation: float


## Whether this is a rectangular Spearhead objective.
func is_rectangle() -> bool:
	return extent != Vector2.ZERO


## Corners of a rectangular objective, in order, in inches from the battlefield's north-west corner.
func corners() -> PackedVector2Array:
	var result := PackedVector2Array()
	var half := extent / 2
	for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		result.append(position + corner.rotated(deg_to_rad(rotation)))
	return result
