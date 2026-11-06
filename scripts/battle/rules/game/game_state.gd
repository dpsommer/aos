class_name GameState
extends RefCounted
## Where the battle is, and each side's score: what the [GameController] and its phases change, and
## what the HUD and the AI read.

## How a battle ended.
enum Outcome { UNDECIDED, MAJOR_VICTORY, MINOR_VICTORY, DRAW }

## The battle round, from 1; 0 before the first.
var round_number := 0
## The army whose turn it is, or null between turns.
var active: BattleArmy
## Who took the first turn this round, and last round.
var first_this_round: BattleArmy
var first_last_round: BattleArmy
## The current round's underdog, or null.
var underdog: BattleArmy
## The window being played, a value of [enum AbilityTiming.Moment], or -1.
var window := -1
## Counts windows, turns and rounds, so a limit can tell whether it's still the same one.
var window_serial := 0
var turn_serial := 0

var victory_points := {}
var command_points := {}
var tactics_completed := {}
## Who controls each objective, by [MapFeature]: a [BattleArmy], absent if nobody does.
var objective_control := {}
## Who controlled each objective when the turn started.
var control_at_turn_start := {}
## Each objective that's out of play this round, as a [MapFeature] key.
var objectives_out_of_play := {}
## Who controls each terrain feature right now, by [BattleTerrain]. Terrain control doesn't last.
var terrain_control := {}
## What happened this turn, by army: [code]destroyed[/code] (enemy units it destroyed), and so on.
var turn_stats := {}
## Armies whose general has been slain.
var generals_slain := {}
## The battle's result: the winner, or null for a draw or while it goes on.
var outcome := Outcome.UNDECIDED
var winner: BattleArmy


func points_of(army: BattleArmy) -> int:
	return victory_points.get(army, 0)


func commands_of(army: BattleArmy) -> int:
	return command_points.get(army, 0)


func tactics_of(army: BattleArmy) -> int:
	return tactics_completed.get(army, 0)


func is_over() -> bool:
	return outcome != Outcome.UNDECIDED


## How many objectives [param army] controls.
func objectives_held(army: BattleArmy) -> int:
	var total := 0
	for held: BattleArmy in objective_control.values():
		if held == army:
			total += 1
	return total


## The objectives [param army] controls that [param from] controlled when the turn started.
func objectives_gained(army: BattleArmy, from: BattleArmy) -> Array[MapFeature]:
	var result: Array[MapFeature] = []
	for objective: MapFeature in objective_control:
		if objective_control[objective] == army and control_at_turn_start.get(objective) == from:
			result.append(objective)
	return result


## Whether [param army] controls an objective of type [param objective_type].
func controls_objective_of_type(army: BattleArmy, objective_type: String) -> bool:
	for objective: MapFeature in objective_control:
		if objective_control[objective] == army and objective.type == objective_type:
			return true
	return false


## Adds [param by] to [param stat] of [param army]'s turn so far.
func count_turn(army: BattleArmy, stat: StringName, by := 1) -> void:
	if not turn_stats.has(army):
		turn_stats[army] = {}
	turn_stats[army][stat] = turn_stats[army].get(stat, 0) + by


func turn_stat(army: BattleArmy, stat: StringName) -> int:
	return turn_stats.get(army, {}).get(stat, 0)
