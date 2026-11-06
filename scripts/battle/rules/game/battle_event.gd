class_name BattleEvent
extends RefCounted
## Something that happened in the battle. The event log is what the map animates and the HUD shows,
## and two battles from the same seed and answers have the same log.

const ROUND_STARTED := &"round_started"
const ROUND_ENDED := &"round_ended"
const FIRST_TURN_DECIDED := &"first_turn_decided"
const TURN_STARTED := &"turn_started"
const TURN_ENDED := &"turn_ended"
const PHASE_STARTED := &"phase_started"
const PHASE_ENDED := &"phase_ended"
const ABILITY_DECLARED := &"ability_declared"
const ABILITY_RESOLVED := &"ability_resolved"
const ROLL_MADE := &"roll_made"
const ATTACKS_RESOLVED := &"attacks_resolved"
const UNIT_DAMAGED := &"unit_damaged"
const UNIT_HEALED := &"unit_healed"
const MODEL_SLAIN := &"model_slain"
const MODEL_RETURNED := &"model_returned"
const UNIT_DESTROYED := &"unit_destroyed"
const UNIT_MOVED := &"unit_moved"
const UNIT_SET_UP := &"unit_set_up"
const MODIFIER_APPLIED := &"modifier_applied"
const OBJECTIVE_CHANGED := &"objective_changed"
const POINTS_SCORED := &"points_scored"
const TACTIC_COMPLETED := &"tactic_completed"
const TWIST_DRAWN := &"twist_drawn"
const BATTLE_ENDED := &"battle_ended"

var kind: StringName
## What it's about: a line for the HUD in [code]text[/code], and references for whoever listens.
var data: Dictionary


func _init(of: StringName, with: Dictionary) -> void:
	kind = of
	data = with


## A line for the battle log.
func text() -> String:
	return data.get("text", "")
