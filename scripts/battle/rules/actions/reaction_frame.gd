class_name ReactionFrame
extends GameFrame
## Step 2 of using an ability (Core Rules 5.2): starting with the player using it, the players
## alternate using reactions until both pass in a row. A player without a reaction passes silently.

var action: Action
var _current: BattleArmy
## The player not using the ability.
var _other: BattleArmy
var _passes := 0


func _init(of: Action, enemy: BattleArmy) -> void:
	action = of
	_current = of.army
	_other = enemy


func advance(game: GameController) -> DecisionRequest:
	while _passes < 2:
		var options := game.reaction_options(action, _current)
		if not options.is_empty():
			var request := DecisionRequest.create(DecisionRequest.Kind.REACTION, _current, "React to %s?" % action.ability().name)
			request.options = options
			request.can_pass = true
			request.action = action
			return request
		_pass()
	finished = true
	return null


func answer(game: GameController, _request: DecisionRequest, decision: Decision) -> String:
	if decision.passed or decision.option == null:
		_pass()
		return ""
	var reason := game.reason_unavailable(decision.option.entry, decision.option.user)
	if not reason.is_empty():
		return reason
	_passes = 0
	_current = _other if _current == action.army else action.army
	game.push(ActionFrame.new(Action.create(decision.option, action)))
	return ""


func _pass() -> void:
	_passes += 1
	_current = _other if _current == action.army else action.army
