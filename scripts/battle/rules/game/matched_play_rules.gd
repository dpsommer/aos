class_name MatchedPlayRules
extends BattleRules
## Matched Play: the General's Handbook battlepack and the Commands rules.

## Command points each player gets at the start of a round, and the underdog's extra (Commands 1.1).
const COMMAND_POINTS := 4
const UNDERDOG_EXTRA := 1
## How many points ahead makes a major victory (Glorious Victory).
const MAJOR_MARGIN := 5
## Effect data's namespace for the battlepack's battle tactics.
const PACK_SPACE := "General's Handbook"
## A player this far behind going first isn't seizing the initiative (Battle Tactics 2.0).
const SEIZE_LIMIT := 11

## How far through each battle tactics card each army is, by [army, card name].
var _cards_done := {}


func round_count() -> int:
	var pack := game.core.battlepack if game.core else null
	return pack.battle_rounds if pack and pack.battle_rounds > 0 else 5


func uses_commands() -> bool:
	return true


func uses_magic() -> bool:
	return true


## The player who finished setting up their army first (Core Rules 12.0).
func first_turn_chooser() -> BattleArmy:
	if game.deployment:
		var finished_at := {}
		for i in game.deployment.history.size():
			var entry: Dictionary = game.deployment.history[i]
			if entry.get("action") in ["unit", "regiment", "reserve"]:
				finished_at[entry.army] = i
		var armies := game.armies()
		if finished_at.has(armies[0]) and finished_at.has(armies[1]):
			return armies[0] if finished_at[armies[0]] < finished_at[armies[1]] else armies[1]
	return game.battle.attacker()


func on_round_started() -> void:
	for army in game.armies():
		game.state.command_points[army] = COMMAND_POINTS + (UNDERDOG_EXTRA if army == game.state.underdog else 0)


func scoring() -> PackedStringArray:
	return game.battle.battleplan.scoring if game.battle.battleplan else PackedStringArray()


## The battleplan's scoring, then battle tactics (Battle Tactics 1.0-3.0): one per card each turn, in
## card order, none for a player who seized the initiative this turn.
func score_turn(army: BattleArmy) -> void:
	super(army)
	var state := game.state
	var seized := state.round_number > 1 and army == state.first_this_round and army != state.first_last_round \
			and state.points_of(game.battle.enemy_of(army)) < state.points_of(army) + SEIZE_LIMIT
	if seized:
		return
	for card_name in army.tactics:
		_score_card(army, card_name)


func _tactic_card(card_name: String) -> BattleTacticCard:
	if game.core and game.core.battlepack:
		for card in game.core.battlepack.battle_tactic_cards:
			if card.name == card_name:
				return card
	return null


func _score_card(army: BattleArmy, card_name: String) -> void:
	var card := _tactic_card(card_name)
	if card == null:
		return
	var done: int = _cards_done.get([army, card_name], 0)
	if done >= card.tactics.size():
		return
	var tactic: BattleTactic = card.tactics[done]
	if TacticChecks.is_complete(PACK_SPACE, tactic.name, army, game):
		_cards_done[[army, card_name]] = done + 1
		game.complete_tactic(army, tactic.name)
		game.add_points(army, tactic.victory_points, tactic.name)


## A margin of 5 is a major victory, less a minor one; a tie goes to the most battle tactics (Glorious
## Victory).
func decide_result() -> void:
	var state := game.state
	var armies := game.armies()
	var ahead := state.points_of(armies[0]) - state.points_of(armies[1])
	if ahead != 0:
		state.winner = armies[0] if ahead > 0 else armies[1]
		state.outcome = GameState.Outcome.MAJOR_VICTORY if absi(ahead) >= MAJOR_MARGIN else GameState.Outcome.MINOR_VICTORY
		return
	var tactics := state.tactics_of(armies[0]) - state.tactics_of(armies[1])
	if tactics == 0:
		state.outcome = GameState.Outcome.DRAW
	else:
		state.winner = armies[0] if tactics > 0 else armies[1]
		state.outcome = GameState.Outcome.MINOR_VICTORY
