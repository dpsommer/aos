extends GutTest
## Unit tests for the end-of-battle panel (scripts/ui/battle/victory_panel.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")
const UIKit := preload("res://test/support/ui_kit.gd")

var _battle: Battle
var _state: GameState


func before_each() -> void:
	Sandbox.begin()
	_battle = BattleKit.battle()
	_state = GameState.new()


func after_each() -> void:
	Sandbox.end()


func _panel() -> VictoryPanel:
	var panel := VictoryPanel.create(_state, _battle)
	add_child_autofree(panel)
	return panel


func _finish(outcome: GameState.Outcome, winner: BattleArmy) -> void:
	_state.outcome = outcome
	_state.winner = winner


func test_a_win_is_a_victory() -> void:
	_finish(GameState.Outcome.MINOR_VICTORY, _battle.player)
	assert_true(UIKit.label_texts(_panel()).has("Victory"))


func test_a_loss_is_a_defeat() -> void:
	_finish(GameState.Outcome.MINOR_VICTORY, _battle.opponent)
	assert_true(UIKit.label_texts(_panel()).has("Defeat"))


func test_no_winner_is_a_draw() -> void:
	_finish(GameState.Outcome.DRAW, null)
	assert_true(UIKit.label_texts(_panel()).has("Draw"))


func test_a_victory_and_a_defeat_are_not_the_same_text() -> void:
	_finish(GameState.Outcome.MINOR_VICTORY, _battle.player)
	var won := VictoryPanel.outcome_text(_state, _battle)
	_finish(GameState.Outcome.MINOR_VICTORY, _battle.opponent)
	assert_ne(VictoryPanel.outcome_text(_state, _battle), won)


func test_the_kind_of_result_is_said() -> void:
	var seen := {}
	for outcome: GameState.Outcome in [GameState.Outcome.MAJOR_VICTORY, GameState.Outcome.MINOR_VICTORY, GameState.Outcome.DRAW]:
		_state.outcome = outcome
		seen[VictoryPanel.kind_text(_state)] = true
	assert_eq(seen.size(), 3, "Each kind has its own words")


func test_a_major_victory_says_so() -> void:
	_finish(GameState.Outcome.MAJOR_VICTORY, _battle.player)
	assert_true(UIKit.has_label_containing(_panel(), "major"))


func test_a_minor_victory_says_so() -> void:
	_finish(GameState.Outcome.MINOR_VICTORY, _battle.player)
	assert_true(UIKit.has_label_containing(_panel(), "minor"))


func test_the_score_shows_both_sides() -> void:
	_state.victory_points[_battle.player] = 14
	_state.victory_points[_battle.opponent] = 9
	_finish(GameState.Outcome.MAJOR_VICTORY, _battle.player)
	var texts := UIKit.label_texts(_panel())
	assert_true(Array(texts).any(func(text: String) -> bool: return text.contains("14") and text.contains("9")))


func test_the_score_tells_the_player_from_the_opponent() -> void:
	_state.victory_points[_battle.player] = 14
	_state.victory_points[_battle.opponent] = 9
	_finish(GameState.Outcome.MAJOR_VICTORY, _battle.player)
	var texts := UIKit.label_texts(_panel())
	var score := ""
	for text in texts:
		if text.contains("14"):
			score = text
	assert_lt(score.find("14"), score.find("9"), "The player's score comes first")


func test_leaving_closes_the_panel() -> void:
	_finish(GameState.Outcome.DRAW, null)
	var panel := _panel()
	watch_signals(panel)
	var buttons := UIKit.buttons(panel)
	assert_eq(buttons.size(), 1)
	buttons[0].pressed.emit()
	assert_signal_emitted(panel, "closed")
