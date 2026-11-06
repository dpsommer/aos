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
	var request := DecisionRequest.create(DecisionRequest.Kind.SET_UP, action.army, "Set up %s." % units[0].name)
	request.unit = units[0]
	request.min_enemy_gap = float(params.get("min_enemy_gap", 9))
	request.action = action
	if params.has("near_user"):
		request.near_unit = action.user
		request.near_reach = float(params.near_user)
	request.can_pass = true
	return request


func answer(_action: Action, game: GameController, request: DecisionRequest, decision: Decision) -> String:
	if not decision.passed:
		var problems := game.set_up_problems(request.unit, decision.positions, request.min_enemy_gap, request.near_unit, request.near_reach)
		if not problems.is_empty():
			return " ".join(problems)
		game.command(request.unit, Commands.SetUp.new(decision.positions))
	params = params.duplicate()
	params["done"] = true
	return ""
