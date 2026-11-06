class_name ActionFrame
extends GameFrame
## Uses an ability, one step at a time (Core Rules 5.2): declare it (targets, Declare instructions
## and rolls), reactions, resolve the effect, then the damage sequence (18.0). Asks whoever has to
## choose along the way, and pushes a [ReactionFrame] for the reactions.

enum Stage { BEGIN, PICK_TARGETS, DECLARE, ROLL, REACT, GATE, RESOLVE, DAMAGE, FINISH }

var action: Action
var _stage := Stage.BEGIN
var _effects: Array[Effect] = []
## Asking for this effect's answer.
var _asking: Effect
var _targets_picked := false
## Whether the gate roll failed, so the effect doesn't happen.
var _gate_failed := false


func _init(of: Action) -> void:
	action = of


func advance(game: GameController) -> DecisionRequest:
	while not finished:
		match _stage:
			Stage.BEGIN:
				_begin(game)
				_stage = Stage.PICK_TARGETS
			Stage.PICK_TARGETS:
				var request := _pick_targets(game)
				if request:
					return request
				_effects = Effect.build_all(action.entry.descriptor.get("declare", []))
				_stage = Stage.DECLARE
			Stage.DECLARE:
				var request := _run_effects(game)
				if request:
					return request
				_stage = Stage.ROLL
			Stage.ROLL:
				_make_declared_roll(game)
				_stage = Stage.REACT
				if game.rules.uses_magic() and not _power_roll(game):
					_stage = Stage.DAMAGE
			Stage.REACT:
				_stage = Stage.GATE
				game.push(ReactionFrame.new(action, game.battle.enemy_of(action.army)))
				return null
			Stage.GATE:
				_roll_gate(game)
				if action.flags.has("unbound"):
					_gate_failed = true
				_effects.clear()
				if not _gate_failed:
					_effects = Effect.build_all(action.entry.descriptor.get("do", []))
				_stage = Stage.RESOLVE
			Stage.RESOLVE:
				var request := _run_effects(game)
				if request:
					return request
				_stage = Stage.DAMAGE
			Stage.DAMAGE:
				_damage_sequence(game)
				_stage = Stage.FINISH
			Stage.FINISH:
				finished = true
				game.finish_action(action)
	return null


func answer(game: GameController, request: DecisionRequest, decision: Decision) -> String:
	if request.kind == DecisionRequest.Kind.TARGETS and _asking == null:
		return _answer_targets(game, request, decision)
	if _asking:
		var reason := _asking.answer(action, game, request, decision)
		if reason.is_empty():
			_asking = null
		return reason
	return "Nothing is being asked."


func _begin(game: GameController) -> void:
	game.declare_action(action)


func _pick_targets(game: GameController) -> DecisionRequest:
	var spec: Dictionary = action.entry.descriptor.get("target", {})
	if spec.is_empty() or _targets_picked:
		return null
	_targets_picked = true
	var eligible := game.eligible_targets(action, spec)
	if spec.get("count", 1) is String and spec.count == "all":
		action.targets = eligible
		return null
	var count := int(spec.get("count", 1))
	if eligible.size() <= count:
		action.targets = eligible
		return null
	var request := DecisionRequest.create(DecisionRequest.Kind.TARGETS, action.army, "Pick a target for %s." % action.ability().name)
	request.units = eligible
	request.count = count
	request.action = action
	return request


func _answer_targets(_game: GameController, request: DecisionRequest, decision: Decision) -> String:
	if decision.units.size() != request.count:
		return "Pick %d." % request.count
	for unit in decision.units:
		if not unit in request.units:
			return "%s can't be picked." % unit.name
	action.targets = decision.units
	return ""


func _make_declared_roll(game: GameController) -> void:
	var roll: Dictionary = action.entry.descriptor.get("roll", {})
	if not roll.is_empty():
		game.make_roll(action, roll.get("name", "roll"), DiceExpr.parse(roll.get("dice", "D6")))


## The casting or chanting roll of a spell or prayer (Magic 2.0 and 3.0). False if it fails, in
## which case no reactions are used and the effect doesn't resolve.
func _power_roll(game: GameController) -> bool:
	var ability := action.ability()
	if action.user == null:
		return true
	var context := RuleContext.of_unit(game, action.user)
	if ability.type == "spell" and ability.casting_value > 0:
		return _cast(game, context)
	if ability.type == "prayer" and ability.chanting_value > 0:
		return _chant(game, context)
	return true


func _cast(game: GameController, context: RuleContext) -> bool:
	var first := game.rng.randi_range(1, 6)
	var second := game.rng.randi_range(1, 6)
	var total := first + second + game.stats.roll_modifier(&"casting", context)
	action.rolls["casting"] = total
	game.events.publish(BattleEvent.ROLL_MADE, {"action": action, "name": "casting", "value": total, "unit": action.user,
			"text": "%s rolls %d to cast %s." % [action.user.name, total, action.ability().name]})
	if first == 1 and second == 1:
		# A miscast: D3 mortal damage, and no more spells this phase.
		action.add_damage(action.user, DiceExpr.parse("D3").roll(game.rng))
		game.usage.mark_cast(action.user, game.power_level(action.user))
		return false
	return total >= action.ability().casting_value


func _chant(game: GameController, context: RuleContext) -> bool:
	var raw := game.rng.randi_range(1, 6)
	var unit := game.controller_of(action.user)
	action.rolls["chanting"] = raw
	game.events.publish(BattleEvent.ROLL_MADE, {"action": action, "name": "chanting", "value": raw, "unit": action.user,
			"text": "%s rolls %d to chant %s." % [action.user.name, raw, action.ability().name]})
	if raw == 1:
		var lost := mini(DiceExpr.parse("D3").roll(game.rng), unit.counter(EffectHooks.RITUAL_POINTS))
		game.command(action.user, Commands.ChangeCounter.new(EffectHooks.RITUAL_POINTS, -lost))
		return false
	# Answer the prayer if the ritual points get it there, else bank the roll for later (3.0).
	var total := raw + unit.counter(EffectHooks.RITUAL_POINTS) + game.stats.roll_modifier(&"chanting", context)
	if total >= action.ability().chanting_value:
		action.rolls["chanting"] = total
		game.command(action.user, Commands.ChangeCounter.new(EffectHooks.RITUAL_POINTS, -unit.counter(EffectHooks.RITUAL_POINTS)))
		return true
	game.command(action.user, Commands.ChangeCounter.new(EffectHooks.RITUAL_POINTS, raw))
	return false


func _roll_gate(game: GameController) -> void:
	var gate: Dictionary = action.entry.descriptor.get("gate", {})
	if gate.is_empty():
		return
	var result := game.make_roll(action, gate.get("name", "gate"), DiceExpr.parse(gate.get("dice", "D6")))
	_gate_failed = result < int(gate.get("at_least", 0))


## Runs [member _effects] in order until one has a question.
func _run_effects(game: GameController) -> DecisionRequest:
	while not _effects.is_empty():
		var effect: Effect = _effects[0]
		if not effect.roll_allows(action):
			_effects.pop_front()
			continue
		var request := effect.resolve(action, game)
		if request:
			_asking = effect
			return request
		_effects.pop_front()
	return null


## Each damaged unit's pool, the active player's first (18.0).
func _damage_sequence(game: GameController) -> void:
	var units: Array = action.damage_pool.keys()
	units.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return game.army_of(a) == game.state.active and game.army_of(b) != game.state.active)
	for unit: BattleUnit in units:
		game.command(unit, Commands.DealDamage.new(action.damage_pool[unit], action.army))
	action.damage_pool.clear()
