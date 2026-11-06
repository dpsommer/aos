class_name AiParticipant
extends Participant
## A simple opponent: it weighs up what it can do by rules of thumb. Anything it can't judge it leaves
## alone. Being a [Participant], it only ever sees what the player would.

## How far a charge can usually get. Rolling above this is a gamble it'll still take if it's close.
const LIKELY_CHARGE := 7.0
const MAX_CHARGE := 12.0
## The enemy within this of a melee unit is worth going for rather than an objective.
const MELEE_INTEREST := 14.0


func decide(request: DecisionRequest, game: GameController) -> Decision:
	match request.kind:
		DecisionRequest.Kind.FIRST_TURN:
			return Decision.choose(0)
		DecisionRequest.Kind.ACTION:
			return _pick_action(request, game)
		DecisionRequest.Kind.REACTION:
			return _pick_reaction(request, game)
		DecisionRequest.Kind.TARGETS:
			return _pick_targets(request)
		DecisionRequest.Kind.ATTACK_TARGETS:
			return _pick_attacks(request)
		DecisionRequest.Kind.MOVE:
			return _pick_move(request, game)
		DecisionRequest.Kind.SET_UP:
			return _pick_set_up(request, game)
		DecisionRequest.Kind.CHOICE:
			return Decision.choose(0)
	return Decision.pass_it()


func _pick_action(request: DecisionRequest, game: GameController) -> Decision:
	var best: ActionOption = null
	var best_score := 0.0
	for option in request.options:
		var score := _score_action(option, game)
		if score > best_score:
			best = option
			best_score = score
	if best == null:
		if request.can_pass:
			return Decision.pass_it()
		return Decision.use(request.options[0])
	return Decision.use(best)


func _score_action(option: ActionOption, game: GameController) -> float:
	var ability := option.entry.ability
	var unit := option.user
	if "FIGHT" in ability.keywords:
		return 20.0 + (unit.model_count() if unit else 0)
	if "SHOOT" in ability.keywords:
		return 15.0
	if "CHARGE" in ability.keywords:
		var gap := _nearest_enemy_gap(unit, game)
		return 12.0 if gap <= LIKELY_CHARGE else (6.0 if gap <= MAX_CHARGE - 1.0 else 0.0)
	if "RETREAT" in ability.keywords:
		return 0.0
	if "RUN" in ability.keywords and "CORE" in ability.keywords:
		return 8.0 if _wants_to_run(unit, game) else 0.0
	if ability.name == "Normal Move":
		return 7.0
	if ability.name == "Rally":
		return 5.0 if unit and (not unit.slain_bases.is_empty() or game.controller_of(unit).damage_points > 0) else 0.0
	if option.entry.card:
		# A card's command costs its battle tactic: only worth it when time is running out.
		return 2.0 if game.state.round_number == game.rules.round_count() else 0.0
	if ability.type == "command":
		return 0.0
	return 4.0


## Run if nothing is near enough to charge after a normal move: running stops it charging.
func _wants_to_run(unit: BattleUnit, game: GameController) -> bool:
	var move := game.stats.value(unit, &"move")
	var goal := _movement_goal(unit, game)
	if BattleGeometry.middle(unit).distance_to(goal) <= move:
		return false
	return _nearest_enemy_gap(unit, game) > move + MAX_CHARGE


func _nearest_enemy_gap(unit: BattleUnit, game: GameController) -> float:
	var best := INF
	for enemy in game.enemies_on_battlefield(game.army_of(unit)):
		best = minf(best, BattleGeometry.unit_gap(unit, enemy))
	return best


func _nearest_enemy(unit: BattleUnit, game: GameController) -> BattleUnit:
	var found: BattleUnit = null
	var best := INF
	for enemy in game.enemies_on_battlefield(game.army_of(unit)):
		var gap := BattleGeometry.unit_gap(unit, enemy)
		if gap < best:
			best = gap
			found = enemy
	return found


## Where a unit wants to go: at a nearby enemy if it fights in melee, else the nearest objective it
## doesn't hold, else the nearest enemy.
func _movement_goal(unit: BattleUnit, game: GameController) -> Vector2:
	var army := game.army_of(unit)
	var centre := BattleGeometry.middle(unit)
	var enemy := _nearest_enemy(unit, game)
	if enemy and BattleGeometry.unit_gap(unit, enemy) <= MELEE_INTEREST and not game.attacks.weapons_of(unit, true).is_empty():
		return BattleGeometry.middle(enemy)
	var best := INF
	var goal := BattleGeometry.middle(enemy) if enemy else centre
	for objective in game.battle.objectives:
		if game.state.objective_control.get(objective) == army:
			continue
		var distance := centre.distance_to(objective.position)
		if distance < best:
			best = distance
			goal = objective.position
	return goal


func _pick_reaction(request: DecisionRequest, game: GameController) -> Decision:
	for option in request.options:
		match option.entry.ability.name:
			"All-out Attack", "All-out Defence":
				# Worth a command point for anything but a small unit.
				if option.user and (option.user.model_count() >= 3 or option.user.is_general) and game.state.commands_of(request.army) >= 2:
					return Decision.use(option)
			"Forward to Victory":
				if _charge_fell_short(request.action, game):
					return Decision.use(option)
			"Unbind":
				return Decision.use(option)
			_:
				if option.entry.ability.type != "command" and option.entry.card == null:
					return Decision.use(option)
	return Decision.pass_it()


func _charge_fell_short(action: Action, game: GameController) -> bool:
	if action == null or action.user == null:
		return false
	return action.rolls.get("charge", 12) < _nearest_enemy_gap(action.user, game)


func _pick_targets(request: DecisionRequest) -> Decision:
	var ranked := request.units.duplicate()
	var user := request.action.user if request.action else null
	if user:
		ranked.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return BattleGeometry.unit_gap(user, a) < BattleGeometry.unit_gap(user, b))
	var picks: Array[BattleUnit] = []
	for i in mini(request.count, ranked.size()):
		picks.append(ranked[i])
	return Decision.pick(picks)


## Each weapon goes for the target with the fewest models left, to finish things off.
func _pick_attacks(request: DecisionRequest) -> Decision:
	var targets := {}
	for weapon in request.weapons:
		var best: BattleUnit = null
		for target: BattleUnit in request.weapon_targets[weapon]:
			if best == null or target.model_count() < best.model_count():
				best = target
		targets[weapon] = best
	return Decision.attack(targets)


func _pick_move(request: DecisionRequest, game: GameController) -> Decision:
	var spec := request.move
	var unit := spec.unit
	var positions := PackedVector2Array()
	match spec.kind:
		MoveSpec.Kind.CHARGE:
			positions = _plan_charge(spec, game)
		MoveSpec.Kind.PILE_IN:
			positions = _plan_pile_in(spec, game)
		MoveSpec.Kind.RETREAT:
			var enemy := _nearest_enemy(unit, game)
			if enemy:
				var away := BattleGeometry.middle(unit) + BattleGeometry.middle(enemy).direction_to(BattleGeometry.middle(unit)) * spec.max_distance
				positions = MovementRules.plan_towards(game, spec, away)
		_:
			positions = MovementRules.plan_towards(game, spec, _movement_goal(unit, game))
	return Decision.move_to(positions) if not positions.is_empty() else Decision.pass_it()


func _plan_charge(spec: MoveSpec, game: GameController) -> PackedVector2Array:
	var enemies := game.enemies_on_battlefield(game.army_of(spec.unit))
	enemies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return BattleGeometry.unit_gap(spec.unit, a) < BattleGeometry.unit_gap(spec.unit, b))
	for enemy in enemies:
		var positions := MovementRules.plan_charge(game, spec, enemy)
		if not positions.is_empty():
			return positions
	return PackedVector2Array()


func _plan_pile_in(spec: MoveSpec, game: GameController) -> PackedVector2Array:
	if spec.pile_in_target:
		return MovementRules.plan_pile_in(game, spec)
	var enemy := _nearest_enemy(spec.unit, game)
	if enemy == null:
		return PackedVector2Array()
	return MovementRules.plan_towards(game, spec, BattleGeometry.middle(enemy), 0.1)


## Sets the unit up where it can, as near the enemy as the rules allow, trying spots on a grid.
func _pick_set_up(request: DecisionRequest, game: GameController) -> Decision:
	var unit := request.unit
	var centre := BattleGeometry.middle(unit)
	var size := game.battle.battlefield_size
	var enemy := _nearest_enemy(unit, game)
	var best := PackedVector2Array()
	var best_distance := INF
	var goal := BattleGeometry.middle(enemy) if enemy else centre
	for x in range(2, int(size.x) - 1, 2):
		for y in range(2, int(size.y) - 1, 2):
			var by := Vector2(x, y) - centre
			var positions := MovementRules.shifted(unit, by)
			if not game.set_up_problems(unit, positions, request.min_enemy_gap, request.near_unit, request.near_reach).is_empty():
				continue
			var distance := Vector2(x, y).distance_to(goal)
			if distance < best_distance:
				best_distance = distance
				best = positions
	return Decision.move_to(best) if not best.is_empty() else Decision.pass_it()
