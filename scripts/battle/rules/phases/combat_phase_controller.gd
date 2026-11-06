class_name CombatPhaseController
extends PhaseController
## The combat phase (Core Rules 13.1): the players use their other combat abilities, then alternate
## picking a unit to fight, the active player first, each unit having to fight if it can.
## STRIKE-FIRST units go before others and STRIKE-LAST after them (19.0).

const FIGHT_KEYWORD := "FIGHT"

var _picker: BattleArmy
## Units in combat when the phase started: STRIKE-FIRST only works for them (19.0).
var _in_combat_at_start := {}


func _on_opened(game: GameController) -> void:
	_picker = game.state.active
	for army in game.armies():
		for unit in game.on_battlefield(army):
			if game.in_combat(unit):
				_in_combat_at_start[unit] = true


func options_for(game: GameController, army: BattleArmy) -> Array[ActionOption]:
	return game.options_in(window, army).filter(func(option: ActionOption) -> bool:
		return not FIGHT_KEYWORD in option.entry.ability.keywords)


func _after_opponent() -> Stage:
	return Stage.EXTRA


func _advance_extra(game: GameController) -> DecisionRequest:
	var mine := fight_options(game, _picker)
	if mine.is_empty():
		var other := game.battle.enemy_of(_picker)
		var theirs := fight_options(game, other)
		if theirs.is_empty():
			_stage = Stage.CLOSING
			return null
		_picker = other
		mine = theirs
	var request := DecisionRequest.create(DecisionRequest.Kind.ACTION, _picker, "Pick a unit to fight.")
	request.options = mine
	return request


func answer(game: GameController, request: DecisionRequest, decision: Decision) -> String:
	if _stage != Stage.EXTRA:
		return super(game, request, decision)
	if decision.option == null:
		return "A unit has to fight if it can."
	if not decision.option in request.options:
		return "It can't fight yet."
	_picker = game.battle.enemy_of(_picker)
	game.push(ActionFrame.new(Action.create(decision.option)))
	return ""


## The FIGHT abilities [param army] can use now, going by strike order: while any STRIKE-FIRST unit
## hasn't fought, only those can; STRIKE-LAST units wait for everyone else.
func fight_options(game: GameController, army: BattleArmy) -> Array[ActionOption]:
	var options: Array[ActionOption] = game.options_in(window, army).filter(func(option: ActionOption) -> bool:
		return FIGHT_KEYWORD in option.entry.ability.keywords)
	var first_waiting := _waiting_strike_first(game)
	var others_waiting := _waiting_others(game)
	return options.filter(func(option: ActionOption) -> bool:
		var user := option.user
		if first_waiting:
			return strikes_first(game, user)
		if strikes_last(game, user):
			return not others_waiting
		return true)


func _waiting_strike_first(game: GameController) -> bool:
	return _any_can_fight(game, func(unit: BattleUnit) -> bool: return strikes_first(game, unit))


func _waiting_others(game: GameController) -> bool:
	return _any_can_fight(game, func(unit: BattleUnit) -> bool: return not strikes_last(game, unit))


## Whether either army has a FIGHT ability it can use now whose user passes [param test].
func _any_can_fight(game: GameController, test: Callable) -> bool:
	for army in game.armies():
		for option in game.options_in(window, army):
			if FIGHT_KEYWORD in option.entry.ability.keywords and test.call(option.user):
				return true
	return false


## Whether [param unit] has STRIKE-FIRST: both STRIKE-FIRST and STRIKE-LAST cancel out, and it does
## nothing for a unit not in combat at the start of the phase (19.0).
func strikes_first(game: GameController, unit: BattleUnit) -> bool:
	if unit == null or not _in_combat_at_start.has(unit):
		return false
	return game.stats.has_keyword(unit, "STRIKE-FIRST") and not game.stats.has_keyword(unit, "STRIKE-LAST")


func strikes_last(game: GameController, unit: BattleUnit) -> bool:
	return unit != null and game.stats.has_keyword(unit, "STRIKE-LAST") and not game.stats.has_keyword(unit, "STRIKE-FIRST")
