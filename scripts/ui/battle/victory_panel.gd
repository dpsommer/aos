class_name VictoryPanel
extends Control
## The end of the battle over the dimmed battlefield: who won, how, and the score. See
## docs/design/battle.md.

## The player is done with it.
signal closed


static func create(state: GameState, battle: Battle) -> VictoryPanel:
	var panel: VictoryPanel = load("res://scenes/ui/battle/victory_panel.tscn").instantiate()
	(panel.get_node(^"%Outcome") as Label).text = outcome_text(state, battle)
	(panel.get_node(^"%Kind") as Label).text = kind_text(state)
	(panel.get_node(^"%Score") as Label).text = "You %d · Opponent %d" % [state.points_of(battle.player), state.points_of(battle.opponent)]
	return panel


func _init() -> void:
	theme = UITheme.get_theme()


func _on_leave_pressed() -> void:
	closed.emit()


static func outcome_text(state: GameState, battle: Battle) -> String:
	if state.winner == null:
		return "Draw"
	return "Victory" if state.winner == battle.player else "Defeat"


static func kind_text(state: GameState) -> String:
	match state.outcome:
		GameState.Outcome.MAJOR_VICTORY:
			return "A major victory"
		GameState.Outcome.MINOR_VICTORY:
			return "A minor victory"
	return "Neither side prevailed"
