class_name SpearheadTwists
extends GameFrame
## A Spearhead twist card: asks for what it needs picked, then applies it. The Fire and Jade deck is
## written here; other decks' twists are shown to the players and not applied yet.
## See docs/technical/effect-data.md.

const SUPPORTED: PackedStringArray = ["Ring of Fire", "Let the Blood Flow", "Bloodmarked", "Reclaim Aqshy", "Reclaim Ghyran",
		"Mount the Attack", "Wreathed in Smoke", "Alarielle’s Blessing", "Take the Land", "Grasping Vines", "The Grandfather’s Blessing", "Lifespring"]

var twist: TwistCard
## What's been picked: objectives in [code]objectives[/code], units in [code]units[/code].
var picks := {"objectives": [], "units": [], "marks": {}}

## What's left to ask, each [army, kind, callback], kind being "objective", "friendly", "enemy" or an
## array of option names.
var _steps: Array = []
var _started := false


func _init(of: TwistCard) -> void:
	twist = of


static func is_supported(of: TwistCard) -> bool:
	return of != null and of.name in SUPPORTED


func advance(game: GameController) -> DecisionRequest:
	if not _started:
		_started = true
		_plan(game)
	while not _steps.is_empty():
		var step: Array = _steps[0]
		var army: BattleArmy = step[0]
		var kind: Variant = step[1]
		if kind is Array or kind is PackedStringArray:
			var names := PackedStringArray(kind)
			var choice := DecisionRequest.create(DecisionRequest.Kind.CHOICE, army, "%s: pick one." % twist.name)
			choice.choices = names
			return choice
		if kind == "objective":
			var objective := DecisionRequest.create(DecisionRequest.Kind.CHOICE, army, "%s: pick an objective." % twist.name)
			for feature: MapFeature in game.battle.objectives:
				objective.choices.append(feature.type)
			return objective
		var units := game.on_battlefield(army if kind == "friendly" else game.battle.enemy_of(army))
		if units.is_empty():
			_steps.pop_front()
			continue
		var request := DecisionRequest.create(DecisionRequest.Kind.TARGETS, army, "%s: pick a unit." % twist.name)
		request.units = units
		return request
	finished = true
	return null


func answer(game: GameController, request: DecisionRequest, decision: Decision) -> String:
	var step: Array = _steps[0]
	var callback: Callable = step[2]
	match request.kind:
		DecisionRequest.Kind.CHOICE:
			if step[1] is String and step[1] == "objective":
				callback.call(game.battle.objectives[decision.choice], game)
			else:
				callback.call(decision.choice, game)
		DecisionRequest.Kind.TARGETS:
			if decision.units.is_empty() or not decision.units[0] in request.units:
				return "Pick a unit."
			callback.call(decision.units[0], game)
	_steps.pop_front()
	return ""


func _ask(who: BattleArmy, kind: Variant, callback: Callable) -> void:
	_steps.append([who, kind, callback])


## The player who picks: the underdog, or the winner of a roll-off.
func _picker(game: GameController) -> BattleArmy:
	if game.state.underdog:
		return game.state.underdog
	return game.armies()[game.rng.randi_range(0, 1)]


func _plan(game: GameController) -> void:
	var state := game.state
	var underdog := state.underdog
	match twist.name:
		"Ring of Fire":
			_ask(_picker(game), "objective", func(objective: MapFeature, on: GameController) -> void:
				picks.objectives.append(objective)
				on.state.objectives_out_of_play[objective] = true
				on.state.objective_control.erase(objective))
		"Let the Blood Flow":
			if underdog:
				_ask(underdog, "friendly", _modify.bind({"stat": "hit", "by": 1, "weapons": "melee", "until": "round"}, underdog))
		"Bloodmarked":
			if underdog:
				_ask(underdog, "friendly", _mark.bind(game.battle.enemy_of(underdog)))
				_ask(underdog, "enemy", _mark.bind(underdog))
			else:
				for army in game.armies():
					_ask(army, "enemy", _mark.bind(army))
		"Reclaim Aqshy", "Reclaim Ghyran":
			if underdog:
				for _i in 2:
					_ask(underdog, "objective", _pick_objective)
			else:
				for army in game.armies():
					_ask(army, "objective", _pick_objective)
		"Mount the Attack":
			if underdog:
				_ask(underdog, "friendly", _modify.bind({"grant": "Charge (+1 Damage)", "weapons": "melee", "until": "round"}, underdog))
		"Wreathed in Smoke":
			_ask(_picker(game), "objective", func(objective: MapFeature, on: GameController) -> void:
				var holder: BattlefieldController = on.army_holders[on.armies()[0]]
				var modifier := Modifier.from_descriptor({"forbid": "hit_below_6", "against": true, "until": "round",
						"when": [{"target_contests": objective.type}]}, twist.name, null)
				holder.modifiers.add(modifier))
		"Alarielle’s Blessing":
			_ask(_picker(game), PackedStringArray(_option_names()), func(index: int, on: GameController) -> void:
				var chooser := _picker(on)
				if index == 0:
					_steps.append([chooser, "friendly", _shield_of_thorns.bind(chooser)])
				else:
					for _i in 3:
						_steps.append([chooser, "friendly", func(unit: BattleUnit, later: GameController) -> void:
							later.command(unit, Commands.Heal.new(DiceExpr.parse("D3").roll(later.rng)))]))
		"Take the Land":
			if underdog:
				var modifier := Modifier.from_descriptor({"stat": "wound", "by": 1, "until": "round", "aura": {"side": "friendly"},
						"when": ["target_contests_large_terrain"]}, twist.name, underdog)
				(game.army_holders[underdog] as BattlefieldController).modifiers.add(modifier)
		"Grasping Vines":
			var picker := _picker(game)
			_ask(picker, "enemy", func(unit: BattleUnit, on: GameController) -> void:
				_apply(unit, {"stat": "move", "halve": true, "until": "round"}, picker, on)
				_apply(unit, {"stat": "charge_dice", "by": -1, "until": "round"}, picker, on))
		"The Grandfather’s Blessing":
			_ask(_picker(game), PackedStringArray(_option_names()), func(index: int, on: GameController) -> void:
				var chooser := _picker(on)
				var effect: Dictionary = {"stat": "save", "by": -1, "until": "round"} if index == 0 else {"forbid": "ward_rolls", "until": "round"}
				_steps.append([chooser, "enemy", _modify.bind(effect, chooser)]))
		"Lifespring":
			_ask(_picker(game), "objective", _pick_objective)
	game.twist_picks = picks


func _option_names() -> Array:
	return twist.options.map(func(option: Dictionary) -> String: return option.name)


func _pick_objective(objective: MapFeature, _game: GameController) -> void:
	picks.objectives.append(objective)


func _mark(unit: BattleUnit, _game: GameController, scorer: BattleArmy) -> void:
	picks.marks[unit] = scorer


func _modify(unit: BattleUnit, game: GameController, descriptor: Dictionary, army: BattleArmy) -> void:
	_apply(unit, descriptor, army, game)


func _apply(unit: BattleUnit, descriptor: Dictionary, army: BattleArmy, game: GameController) -> void:
	game.command(unit, Commands.ApplyModifier.new(Modifier.from_descriptor(descriptor, twist.name, army)))


## WARD (6+), or 1 better if it has one.
func _shield_of_thorns(unit: BattleUnit, game: GameController, army: BattleArmy) -> void:
	if game.stats.value(unit, &"ward") > 0:
		_apply(unit, {"stat": "ward", "by": -1, "until": "round"}, army, game)
	else:
		_apply(unit, {"stat": "ward", "set": 6, "until": "round"}, army, game)


## What the twist scores [param army] at the end of its turn, and does after that.
static func on_scored(of: TwistCard, army: BattleArmy, game: GameController) -> void:
	if of == null:
		return
	var state := game.state
	var picked: Dictionary = game.twist_picks
	match of.name:
		"Let the Blood Flow":
			_award(game, army, state.turn_stat(army, &"enemy_destroyed"), of.name)
		"Reclaim Aqshy", "Reclaim Ghyran", "Lifespring":
			var held := 0
			for objective: MapFeature in picked.get("objectives", []):
				if state.objective_control.get(objective) == army:
					held += 1
			_award(game, army, held, of.name)
		"Mount the Attack":
			var gained := 0
			for objective: MapFeature in state.objective_control:
				if state.objective_control[objective] == army and state.control_at_turn_start.get(objective) == game.battle.enemy_of(army):
					gained += 1
			_award(game, army, gained, of.name)
		"Take the Land":
			if TacticChecks._large_terrain_models(army, game.battle.enemy_territory_of(army), game):
				_award(game, army, 1, of.name)
	# After victory points have been scored.
	match of.name:
		"Ring of Fire":
			for objective: MapFeature in picked.get("objectives", []):
				for side in game.armies():
					for unit in game.on_battlefield(side):
						if _on_objective(unit, objective, game):
							game.command(unit, Commands.DealDamage.new(DiceExpr.parse("D3").roll(game.rng)))
		"Lifespring":
			for objective: MapFeature in picked.get("objectives", []):
				for side in game.armies():
					for unit in game.on_battlefield(side):
						if game.objectives.models_contesting(unit, objective) > 0:
							game.command(unit, Commands.Heal.new(1))


## What the twist scores when its round ends.
static func on_round_ended(of: TwistCard, game: GameController) -> void:
	if of == null or of.name != "Bloodmarked":
		return
	var marks: Dictionary = game.twist_picks.get("marks", {})
	for unit: BattleUnit in marks:
		if unit.destroyed:
			_award(game, marks[unit], 1, of.name)


static func _award(game: GameController, army: BattleArmy, points: int, why: String) -> void:
	if points > 0:
		game.add_points(army, points, why)


static func _on_objective(unit: BattleUnit, objective: MapFeature, game: GameController) -> bool:
	var radius := game.battle.objective_radius(objective)
	for i in unit.positions.size():
		if BattleGeometry.model_touches_circle(unit, i, objective.position, radius):
			return true
	return false
