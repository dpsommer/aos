class_name SetUpEffect
extends Effect
## Takes its subject off the battlefield and sets it up again anywhere more than
## [code]min_enemy_gap[/code] inches from all enemies, as a reserve or redeployment ability does. A
## unit in reserve is laid out ready to be placed.


func resolve(action: Action, game: GameController) -> DecisionRequest:
	var units := subjects(action, game)
	if units.is_empty() or params.get("done", false):
		return null
	if units[0].positions.is_empty():
		game.lay_out(units[0], game.battle.battlefield_size / 2)
	var request := _set_up_request(units[0], action, 9.0)
	request.can_pass = true
	return request


func answer(_action: Action, game: GameController, request: DecisionRequest, decision: Decision) -> String:
	if not decision.passed:
		var reason := _set_up_as_decided(game, request, decision)
		if not reason.is_empty():
			return reason
	_mark_done()
	return ""
