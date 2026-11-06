class_name AbilityEntry
extends RefCounted
## One ability an army has in this battle: the rules text, what the effect data says it does, and who
## it belongs to.

var ability: Ability
## Its key in the effect data, e.g. "core:Normal Move".
var key := ""
var army: BattleArmy
## The unit whose warscroll or enhancement it's on, or null.
var owner_unit: BattleUnit
## Where it comes from, for the HUD: "Core", "Warscroll", "Battle trait".
var source := ""
## Its effect data, or empty if it's not supported yet.
var descriptor := {}
var timing: AbilityTiming
## The Spearhead battle tactic card it's the command of, or null: using it discards the card.
var card: SpearheadTacticCard


func is_supported() -> bool:
	return not descriptor.is_empty()
