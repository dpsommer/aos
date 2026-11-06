class_name BattleRules
extends RefCounted
## What differs between ways of playing: how long the battle lasts, how it's scored and won, who
## goes first in the first round, and what happens at the start of a round. [MatchedPlayRules] and
## [SpearheadRules] fill it in.

var game: GameController


func _init(on: GameController) -> void:
	game = on


func round_count() -> int:
	return 5


## Whether the Magic rules are used: casting rolls, chanting rolls and unbinding.
func uses_magic() -> bool:
	return false


## Whether the Commands rules are used: command points and the commands they pay for.
func uses_commands() -> bool:
	return false


## Who decides who takes the first turn of the first round.
func first_turn_chooser() -> BattleArmy:
	return game.battle.attacker()


## What's done after the underdog is known, before Start of Battle Round abilities.
func on_round_started() -> void:
	pass


## What's done as the round ends.
func on_round_ended() -> void:
	pass


## The sentences scored at the end of a turn.
func scoring() -> PackedStringArray:
	return PackedStringArray()


## Scores what's due at the end of [param army]'s turn.
func score_turn(army: BattleArmy) -> void:
	for sentence in scoring():
		var points := ScoringRules.points_for(sentence, army, game)
		if points > 0:
			game.add_points(army, points, sentence)


## What the end of a battle comes to: sets [member GameState.outcome] and [member GameState.winner].
func decide_result() -> void:
	var state := game.state
	var armies := game.armies()
	var ahead := state.points_of(armies[0]) - state.points_of(armies[1])
	if ahead == 0:
		state.outcome = GameState.Outcome.DRAW
	else:
		state.winner = armies[0] if ahead > 0 else armies[1]
		state.outcome = GameState.Outcome.MINOR_VICTORY
