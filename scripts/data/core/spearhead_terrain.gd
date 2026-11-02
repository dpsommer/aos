class_name SpearheadTerrain
extends Resource
## A terrain feature in a Spearhead battle, e.g. the Ruined Domicile.

## Values of [member size].
const SIZES: PackedStringArray = ["large", "small"]
## Each size of feature's footprint in inches, length by width, when the data gives none: a
## rectangle about the size of the Spearhead terrain kits.
const FOOTPRINTS := {"large": Vector2(6.0, 3.0), "small": Vector2(3.0, 2.0)}

@export var name: String
## "large" or "small".
@export var size: String
## Whether it's a mystical terrain feature, which the battleplan or a twist sets up rather than the
## players, e.g. the Crypt of Blood.
@export var mystical: bool
## Names of its terrain abilities, from [member SpearheadBattlepack.terrain_abilities].
@export var abilities: PackedStringArray
## Its footprint in inches, its long side then its short side, or zero for its size's
## ([constant FOOTPRINTS]).
@export var length: float
@export var width: float


## Its footprint in inches: x along its long side, y across it.
func footprint() -> Vector2:
	if length > 0.0 and width > 0.0:
		return Vector2(length, width)
	return FOOTPRINTS.get(size, FOOTPRINTS.large)
