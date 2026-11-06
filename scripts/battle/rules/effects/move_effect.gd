class_name MoveEffect
extends Effect
## Lets its subjects move, asking whoever commands them where to. [code]kind[/code] is normal, run,
## retreat, charge, pile_in or free. [code]distance[/code] is dice, or "move" for the Move
## characteristic; "run" adds a run roll; "roll" is the action's named [code]roll[/code].

const KINDS := {"normal": MoveSpec.Kind.NORMAL, "run": MoveSpec.Kind.RUN, "retreat": MoveSpec.Kind.RETREAT,
		"charge": MoveSpec.Kind.CHARGE, "pile_in": MoveSpec.Kind.PILE_IN, "free": MoveSpec.Kind.FREE}

var _queue: Array[BattleUnit] = []
var _started := false
var _spec: MoveSpec


func resolve(action: Action, game: GameController) -> DecisionRequest:
	if not _started:
		_started = true
		_queue = subjects(action, game)
	while not _queue.is_empty():
		var unit: BattleUnit = _queue[0]
		if unit.destroyed or unit.positions.is_empty():
			_queue.pop_front()
			continue
		_spec = _spec_for(unit, action, game)
		if _spec.max_distance <= 0.0:
			_queue.pop_front()
			continue
		var request := DecisionRequest.create(DecisionRequest.Kind.MOVE, game.army_of(unit), "Move %s up to %s\"." % [unit.name, ("%.1f" % _spec.max_distance).trim_suffix(".0")])
		request.move = _spec
		request.unit = unit
		request.action = action
		request.can_pass = true
		return request
	return null


func answer(_action: Action, game: GameController, _request: DecisionRequest, decision: Decision) -> String:
	if decision.passed:
		_queue.pop_front()
		return ""
	var problems := MovementRules.problems(game, _spec, decision.positions)
	if not problems.is_empty():
		return " ".join(problems)
	var reason := game.command(_spec.unit, Commands.MoveModels.new(decision.positions, _spec))
	if reason.is_empty():
		_queue.pop_front()
	return reason


func _spec_for(unit: BattleUnit, action: Action, game: GameController) -> MoveSpec:
	var kind: MoveSpec.Kind = KINDS.get(params.get("kind", "free"), MoveSpec.Kind.FREE)
	var spec := MoveSpec.create(unit, kind, _distance_for(unit, action, game))
	if kind == MoveSpec.Kind.PILE_IN:
		spec.max_distance = MoveSpec.PILE_IN_DISTANCE
		spec.pile_in_target = game.nearest_in_combat(unit)
	if params.get("end_in_combat_if_was", false) and game.in_combat(unit):
		spec.must_end_in_combat = true
	spec.avoid_new_combat = params.get("avoid_new_combat", false)
	if spec.avoid_new_combat:
		spec.ignores_combat_of = game.enemies_in_combat_with(unit)
	return spec


func _distance_for(unit: BattleUnit, action: Action, game: GameController) -> float:
	var distance: Variant = params.get("distance", "move")
	var context := RuleContext.of_unit(game, unit)
	match distance:
		"move":
			return game.stats.value(unit, &"move", context)
		"run":
			var move := game.stats.value(unit, &"move", context)
			if action.flags.has("added_move"):
				return move + int(action.flags.added_move)
			return move + game.stats.modified(game.make_roll(action, "run", DiceExpr.parse("D6")), &"run", context)
		"roll":
			return float(game.stats.modified(action.rolls.get(params.get("roll", "roll"), 0), StringName(params.get("roll", "roll")), context))
	return float(DiceExpr.parse(str(distance)).roll(game.rng))
