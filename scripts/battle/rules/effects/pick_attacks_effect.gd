class_name PickAttacksEffect
extends Effect
## An ATTACK ability's Declare: picks each weapon's target (Core Rules 16.0). [code]type[/code] is
## "melee" or "shooting". Sets the action's targets, for reactions like 'All-out Defence'.


func resolve(action: Action, game: GameController) -> DecisionRequest:
	if params.get("done", false):
		return null
	var melee: bool = params.get("type", "melee") == "melee"
	var unit := action.user
	var weapons: Array[Weapon] = []
	var eligible := {}
	for weapon in game.attacks.weapons_of(unit, melee):
		var targets := game.attacks.targets_for(unit, weapon)
		if not targets.is_empty():
			weapons.append(weapon)
			eligible[weapon] = targets
	if weapons.is_empty():
		return null
	var request := DecisionRequest.create(DecisionRequest.Kind.ATTACK_TARGETS, action.army, "Pick %s's targets." % unit.name)
	request.attacker = unit
	request.weapons = weapons
	request.weapon_targets = eligible
	request.action = action
	return request


func answer(action: Action, _game: GameController, request: DecisionRequest, decision: Decision) -> String:
	if decision.attack_targets.is_empty():
		return "Pick a target."
	for weapon: Weapon in request.weapons:
		if not decision.attack_targets.has(weapon):
			return "Pick a target for %s." % weapon.name
		if not decision.attack_targets[weapon] in request.weapon_targets[weapon]:
			return "%s can't target that." % weapon.name
	action.attack_targets = decision.attack_targets
	for target: BattleUnit in decision.attack_targets.values():
		if not target in action.targets:
			action.targets.append(target)
	_mark_done()
	return ""
