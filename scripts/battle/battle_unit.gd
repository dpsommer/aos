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
## Which way the unit's models face, in radians clockwise from east.
var facing := 0.0
## The regiment the unit is in, or null for an auxiliary unit or a Spearhead's.
var regiment: BattleRegiment
## Whether it has been deployed, on the battlefield or in reserve.
var deployed := false
## The reserve it was set up in, e.g. "in the clouds", or empty if it's on the battlefield.
var reserve := ""


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


## Whether it has been set up on the battlefield (not in reserve).
func is_on_battlefield() -> bool:
	return deployed and reserve.is_empty() and not positions.is_empty()


## Whether its warscroll has [param keyword].
func has_keyword(keyword: String) -> bool:
	return warscroll != null and warscroll.has_keyword(keyword)


## A copy, not yet deployed and in no regiment ([method BattleArmy.mirror] puts it in one).
func copy() -> BattleUnit:
	var unit := BattleUnit.new()
	unit.name = name
	unit.warscroll = warscroll
	unit.bases = bases.duplicate()
	return unit
