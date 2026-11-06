class_name Effect
extends RefCounted
## One thing an ability does, from one entry in its effect data's [code]do[/code] or
## [code]declare[/code]. It acts on its targets by sending commands to their controllers.

## The descriptor it was built from.
var params := {}


## The effects for [param descriptors]. One it doesn't know is an error, and does nothing.
static func build_all(descriptors: Array) -> Array[Effect]:
	var result: Array[Effect] = []
	for descriptor: Dictionary in descriptors:
		var effect := _build(descriptor.get("op", ""))
		if effect:
			effect.params = descriptor
			result.append(effect)
		else:
			push_error("Unknown effect op '%s'" % descriptor.get("op", ""))
	return result


static func _build(op: String) -> Effect:
	match op:
		"modify", "grant":
			return ModifyEffect.new()
		"mortal":
			return MortalEffect.new()
		"heal":
			return HealEffect.new()
		"move":
			return MoveEffect.new()
		"pick_attacks":
			return PickAttacksEffect.new()
		"attack":
			return AttackEffect.new()
		"setup":
			return SetUpEffect.new()
		"counter":
			return CounterEffect.new()
		"return_models":
			return ReturnModelsEffect.new()
		"summon":
			return SummonEffect.new()
		"hook":
			return HookEffect.new()
	return null


## Whether a roll lets it happen: [code]if_roll[/code] or [code]unless_roll[/code], each
## {"name": the roll's name, "at_least": what it has to reach}, e.g. "if the chanting roll was 8+".
func roll_allows(action: Action) -> bool:
	if params.has("if_roll") and action.rolls.get(params.if_roll.name, 0) < int(params.if_roll.at_least):
		return false
	if params.has("unless_roll") and action.rolls.get(params.unless_roll.name, 0) >= int(params.unless_roll.at_least):
		return false
	return true


## Moves the effect on. Returns a question if it needs one answered, or null once it's done.
func resolve(_action: Action, _game: GameController) -> DecisionRequest:
	return null


## Takes the answer to [param request], which it asked. Returns why it can't, or empty. It's then
## resolved again.
func answer(_action: Action, _game: GameController, _request: DecisionRequest, _decision: Decision) -> String:
	return ""


## The units it acts on: [code]to[/code] is "target" (the default, or the user if there are no
## targets), "user", "parent_user", "parent_targets", or "friendly" for all friendly units,
## narrowed by [code]within[/code] and [code]wholly[/code] of the user.
func subjects(action: Action, game: GameController) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	match params.get("to", "target"):
		"user":
			if action.user:
				result.append(action.user)
		"parent_user":
			if action.parent and action.parent.user:
				result.append(action.parent.user)
		"parent_targets":
			if action.parent:
				result.append_array(action.parent.targets)
		"friendly":
			for unit in game.on_battlefield(action.army):
				if _in_reach(unit, action):
					result.append(unit)
		_:
			result = action.targets.duplicate()
			if result.is_empty() and action.user:
				result.append(action.user)
	return result.filter(func(unit: BattleUnit) -> bool: return not unit.destroyed)


func _in_reach(unit: BattleUnit, action: Action) -> bool:
	if not params.has("within") or action.user == null:
		return true
	var reach := float(params.within)
	return BattleGeometry.is_wholly_within(unit, action.user, reach) if params.get("wholly", false) \
			else BattleGeometry.is_within(unit, action.user, reach)
