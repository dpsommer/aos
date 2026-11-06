class_name EndOfTurnController
extends PhaseController
## The end of a turn (Core Rules 31.0): End of Turn abilities, then objective control, then the
## active player scores.


func _on_closing(game: GameController) -> void:
	game.objectives.update()
	game.rules.score_turn(game.state.active)
