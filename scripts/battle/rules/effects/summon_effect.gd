class_name SummonEffect
extends Effect
## Summons the manifestation its ability names, near the caster (Magic 7.0). Its own abilities are
## looked up like any warscroll's, and it goes when its summoner is slain (7.1).

var _unit: BattleUnit


func resolve(action: Action, game: GameController) -> DecisionRequest:
	if params.get("done", false) or action.ability().summons.is_empty():
		return null
	_unit = game.summon(action.ability().summons[0], action.army, action.user)
	if _unit == null:
		return null
	var request := DecisionRequest.create(DecisionRequest.Kind.SET_UP, action.army, "Set up %s." % _unit.name)
	request.unit = _unit
	request.min_enemy_gap = float(params.get("min_enemy_gap", 3))
	request.action = action
	if params.has("near_user"):
		request.near_unit = action.user
		request.near_reach = float(params.near_user)
	return request


func answer(_action: Action, game: GameController, request: DecisionRequest, decision: Decision) -> String:
	if decision.passed:
		return "A manifestation has to be set up."
	var problems := game.set_up_problems(request.unit, decision.positions, request.min_enemy_gap, request.near_unit, request.near_reach)
	if not problems.is_empty():
		return " ".join(problems)
	game.command(request.unit, Commands.SetUp.new(decision.positions))
	params = params.duplicate()
	params["done"] = true
	return ""
