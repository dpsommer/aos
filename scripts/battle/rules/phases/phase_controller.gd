class_name PhaseController
extends GameFrame
## One window of the battle in which abilities can be used, usually a phase of a turn: the active
## player uses abilities in the order they choose, then their opponent (Core Rules 13.0). It tracks
## what units have done in it. The player and AI act through the same requests.

enum Stage { OPENING, ACTIVE, OPPONENT, EXTRA, CLOSING }

var window: AbilityTiming.Moment
var _stage := Stage.OPENING
## What each unit has used here, in order: a [BattleUnit] to an array of ability names.
var _used := {}


func _init(of: AbilityTiming.Moment) -> void:
	window = of


## The controller for a phase of the turn.
static func for_window(of: AbilityTiming.Moment) -> PhaseController:
	match of:
		AbilityTiming.Moment.HERO:
			return HeroPhaseController.new(of)
		AbilityTiming.Moment.MOVEMENT:
			return MovementPhaseController.new(of)
		AbilityTiming.Moment.SHOOTING:
			return ShootingPhaseController.new(of)
		AbilityTiming.Moment.CHARGE:
			return ChargePhaseController.new(of)
		AbilityTiming.Moment.COMBAT:
			return CombatPhaseController.new(of)
		AbilityTiming.Moment.END_OF_TURN:
			return EndOfTurnController.new(of)
	return PhaseController.new(of)


func advance(game: GameController) -> DecisionRequest:
	var state := game.state
	while not finished:
		match _stage:
			Stage.OPENING:
				state.window = window
				state.window_serial += 1
				game.phase = self
				game.events.publish(BattleEvent.PHASE_STARTED, {"window": window, "army": state.active, "text": ""})
				_on_opened(game)
				_stage = Stage.ACTIVE
			Stage.ACTIVE, Stage.OPPONENT:
				var army: BattleArmy = state.active if _stage == Stage.ACTIVE else game.battle.enemy_of(state.active)
				var request := _request_for(game, army)
				if request:
					return request
				_next_stage()
			Stage.EXTRA:
				var request := _advance_extra(game)
				if request or game.phase != self or _stage != Stage.EXTRA:
					return request
			Stage.CLOSING:
				_on_closing(game)
				game.events.publish(BattleEvent.PHASE_ENDED, {"window": window, "text": ""})
				game.phase = null
				finished = true
	return null


func _next_stage() -> void:
	_stage = Stage.OPPONENT if _stage == Stage.ACTIVE else _after_opponent()


## What comes after both players have had their go.
func _after_opponent() -> Stage:
	return Stage.CLOSING


## A phase's own stage after the players' abilities. Sets the stage to go on from it.
func _advance_extra(_game: GameController) -> DecisionRequest:
	_stage = Stage.CLOSING
	return null


func _request_for(game: GameController, army: BattleArmy) -> DecisionRequest:
	var options := options_for(game, army)
	if options.is_empty():
		return null
	var request := DecisionRequest.create(DecisionRequest.Kind.ACTION, army, "%s phase: use an ability or pass." % AbilityTiming.WINDOW_NAMES.get(window, ""))
	request.options = options
	request.can_pass = true
	return request


## What [param army] can use in this phase, right now.
func options_for(game: GameController, army: BattleArmy) -> Array[ActionOption]:
	return game.options_in(window, army)


func answer(game: GameController, request: DecisionRequest, decision: Decision) -> String:
	if decision.passed or decision.option == null:
		_next_stage()
		return ""
	if not decision.option in request.options:
		return "That can't be used now."
	var reason := game.reason_unavailable(decision.option.entry, decision.option.user)
	if not reason.is_empty():
		return reason
	game.push(ActionFrame.new(Action.create(decision.option)))
	return ""


## [param army]'s units that can still use an ability with [param keyword] in this phase.
func _users_with_keyword(game: GameController, army: BattleArmy, keyword: String) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for option in options_for(game, army):
		if option.user and option.entry.ability.keywords.has(keyword) and not option.user in result:
			result.append(option.user)
	return result


## Notes what's been used here. The [GameController] calls this when an ability has resolved.
func record_use(action: Action) -> void:
	if action.user:
		if not _used.has(action.user):
			_used[action.user] = []
		_used[action.user].append(action.ability().name)


## Whether [param unit] has used an ability called [param ability_name] here, or any if empty.
func has_used(unit: BattleUnit, ability_name := "") -> bool:
	if not _used.has(unit):
		return false
	return ability_name.is_empty() or ability_name in _used[unit]


func _on_opened(_game: GameController) -> void:
	pass


func _on_closing(_game: GameController) -> void:
	pass
