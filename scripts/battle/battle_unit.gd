class_name BattleUnit
extends RefCounted
## A unit on the battlefield: its warscroll and one base per model. See docs/design/battle.md.

## Base used for a warscroll with no base size in the data.
const FALLBACK_BASE_MM := 32.0

var name: String
## The warscroll's rules, or null if the data has none.
var warscroll: Warscroll
## One base per model.
var bases: Array[BaseSize] = []
## Each model's centre, in inches from the battlefield's north-west corner, once deployed.
var positions := PackedVector2Array()


## A unit of [param model_count] models of [param of], whose bases come from [param base_source]
## (defaults to [param of]): a Spearhead unit's own warscroll has no battle profile.
static func create(unit_name: String, of: Warscroll, model_count: int, base_source: Warscroll = null) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.name = unit_name
	unit.warscroll = of
	var source := base_source if base_source else of
	var base := source.base_size if source and source.base_size else BaseSize.round_base(FALLBACK_BASE_MM)
	unit.bases = base.bases_for(maxi(model_count, 1))
	return unit


func model_count() -> int:
	return bases.size()


## A copy, not yet deployed.
func copy() -> BattleUnit:
	var unit := BattleUnit.new()
	unit.name = name
	unit.warscroll = warscroll
	unit.bases = bases.duplicate()
	return unit
