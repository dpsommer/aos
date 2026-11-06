class_name SummonEffect
extends Effect
## Summons the manifestation its ability names, near the caster (Magic 7.0). Its own abilities are
## looked up like any warscroll's, and it goes when its summoner is slain (7.1).

func resolve(action: Action, game: GameController) -> DecisionRequest:
	if params.get("done", false) or action.ability().summons.is_empty():
		return null
	var unit := game.summon(action.ability().summons[0], action.army, action.user)
	if unit == null:
		return null
	return _set_up_request(unit, action, 3.0)


func answer(_action: Action, game: GameController, request: DecisionRequest, decision: Decision) -> String:
	if decision.passed:
		return "A manifestation has to be set up."
	var reason := _set_up_as_decided(game, request, decision)
	if reason.is_empty():
		_mark_done()
	return reason
