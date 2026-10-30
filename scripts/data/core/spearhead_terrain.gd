class_name SpearheadTerrain
extends Resource
## A terrain feature in a Spearhead battle, e.g. the Ruined Domicile.

## Values of [member size].
const SIZES: PackedStringArray = ["large", "small"]

@export var name: String
## "large" or "small".
@export var size: String
## Whether it's a mystical terrain feature, which the battleplan or a twist sets up rather than the
## players, e.g. the Crypt of Blood.
@export var mystical: bool
## Names of its terrain abilities, from [member SpearheadBattlepack.terrain_abilities].
@export var abilities: PackedStringArray
