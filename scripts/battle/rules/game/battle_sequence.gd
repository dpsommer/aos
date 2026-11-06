class_name BattleSequence
extends GameFrame
## The battle from its first round to its last (Core Rules 11.0-13.0, 33.0), at the bottom of the
## [GameController]'s stack.

enum Stage { ROUND_START, CHOOSE_FIRST, ROUND_SETUP, START_WINDOW, START_ABILITIES, TURN, TURN_END, END_ABILITIES, ROUND_END }

var _stage := Stage.ROUND_START
## Who decides who goes first, and whether they've been asked.
var _chooser: BattleArmy
## How far through the round's two turns it is.
var _turn := 0
## The phases of the current turn still to come.
var _phases: Array[AbilityTiming.Moment] = []


func advance(game: GameController) -> DecisionRequest:
	var state := game.state
	while not finished:
		match _stage:
			Stage.ROUND_START:
				if state.round_number >= game.rules.round_count():
					_end_battle(game)
					return null
				_start_round(game)
				_stage = Stage.CHOOSE_FIRST
			Stage.CHOOSE_FIRST:
				var request := DecisionRequest.create(DecisionRequest.Kind.FIRST_TURN, _chooser, "Who takes the first turn?")
				request.choices = PackedStringArray(["Go first", "Go second"])
				_stage = Stage.ROUND_SETUP
				return request
			Stage.ROUND_SETUP:
				_set_underdog(game)
				state.active = state.first_this_round
				_turn = 0
				_stage = Stage.START_WINDOW
				# A twist may have something to pick first.
				game.rules.on_round_started()
				return null
			Stage.START_WINDOW:
				_stage = Stage.START_ABILITIES
				game.push(PhaseController.new(AbilityTiming.Moment.START_OF_ROUND))
				return null
			Stage.START_ABILITIES:
				_start_turn(game)
				_stage = Stage.TURN
			Stage.TURN:
				if _phases.is_empty():
					_stage = Stage.TURN_END
					continue
				game.push(PhaseController.for_window(_phases.pop_front()))
				return null
			Stage.TURN_END:
				game.events.publish(BattleEvent.TURN_ENDED, {"army": state.active, "text": ""})
				_turn += 1
				if _turn < 2:
					_start_turn(game)
					_stage = Stage.TURN
				else:
					_stage = Stage.END_ABILITIES
					state.active = state.first_this_round
					game.push(PhaseController.new(AbilityTiming.Moment.END_OF_ROUND))
					return null
			Stage.END_ABILITIES:
				_stage = Stage.ROUND_END
			Stage.ROUND_END:
				_end_round(game)
				_stage = Stage.ROUND_START
	return null


func answer(game: GameController, request: DecisionRequest, decision: Decision) -> String:
	if request.kind != DecisionRequest.Kind.FIRST_TURN:
		return "Nothing is being asked."
	var state := game.state
	state.first_this_round = request.army if decision.choice == 0 else game.battle.enemy_of(request.army)
	game.events.publish(BattleEvent.FIRST_TURN_DECIDED, {"army": state.first_this_round, "text": "%s takes the first turn." % game.side_name(state.first_this_round)})
	return ""


func _start_round(game: GameController) -> void:
	var state := game.state
	state.round_number += 1
	state.first_last_round = state.first_this_round
	_chooser = _who_chooses(game)
	if state.round_number == 1:
		game.objectives.update()
	game.events.publish(BattleEvent.ROUND_STARTED, {"round": state.round_number, "text": "Battle round %d begins." % state.round_number})


func _end_round(game: GameController) -> void:
	var state := game.state
	game.rules.on_round_ended()
	for army in game.armies():
		state.command_points[army] = 0
	state.objectives_out_of_play.clear()
	game.events.publish(BattleEvent.ROUND_ENDED, {"round": state.round_number, "text": ""})


## Round 1: as the rules for this mode say. Later: a priority roll-off, a tie to whoever went first
## last round (12.0).
func _who_chooses(game: GameController) -> BattleArmy:
	var state := game.state
	if state.round_number == 1:
		return game.rules.first_turn_chooser()
	var armies := game.armies()
	var first := game.rng.randi_range(1, 6)
	var second := game.rng.randi_range(1, 6)
	game.events.publish(BattleEvent.ROLL_MADE, {"name": "priority", "value": first, "text": "Priority roll: %s %d, %s %d." % [game.side_name(armies[0]), first, game.side_name(armies[1]), second]})
	if first == second:
		return state.first_last_round
	return armies[0] if first > second else armies[1]


func _set_underdog(game: GameController) -> void:
	var state := game.state
	var armies := game.armies()
	var ahead := state.points_of(armies[0]) - state.points_of(armies[1])
	state.underdog = null if ahead == 0 else (armies[1] if ahead > 0 else armies[0])


func _start_turn(game: GameController) -> void:
	var state := game.state
	state.active = state.first_this_round if _turn == 0 else game.battle.enemy_of(state.first_this_round)
	state.turn_serial += 1
	state.turn_stats.clear()
	state.control_at_turn_start = state.objective_control.duplicate()
	_phases = AbilityTiming.TURN_WINDOWS.duplicate()
	game.events.publish(BattleEvent.TURN_STARTED, {"army": state.active, "round": state.round_number, "text": "%s's turn." % game.side_name(state.active)})


func _end_battle(game: GameController) -> void:
	game.rules.decide_result()
	finished = true
	var state := game.state
	var result := "The battle is a draw."
	if state.winner:
		result = "%s wins a %s victory." % [game.side_name(state.winner), "major" if state.outcome == GameState.Outcome.MAJOR_VICTORY else "minor"]
	game.events.publish(BattleEvent.BATTLE_ENDED, {"outcome": state.outcome, "winner": state.winner, "text": result})
