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
