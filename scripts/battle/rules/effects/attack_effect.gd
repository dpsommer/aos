class_name AttackEffect
extends Effect
## Resolves the attacks picked at Declare (Core Rules 17.0). With [code]target_all[/code], the
## ability's targets are attacked by every eligible weapon, as 'Covering Fire' picks its own.


func resolve(action: Action, game: GameController) -> DecisionRequest:
	if action.user == null:
		return null
	var melee: bool = params.get("type", "melee") == "melee"
	if action.attack_targets.is_empty() and not action.targets.is_empty():
		for weapon in game.attacks.weapons_of(action.user, melee):
			if action.targets[0] in game.attacks.targets_for(action.user, weapon):
				action.attack_targets[weapon] = action.targets[0]
	for weapon: Weapon in action.attack_targets:
		var target: BattleUnit = action.attack_targets[weapon]
		if target.destroyed or action.user.destroyed:
			continue
		var result := game.attacks.resolve(action, action.user, weapon, target)
		game.events.publish(BattleEvent.ATTACKS_RESOLVED, {
			"unit": action.user, "target": target, "weapon": weapon, "result": result,
			"text": "%s attacks %s with %s: %d attacks, %d hits, %d wounds, %d unsaved, %d damage." % [
					action.user.name, target.name, weapon.name, result.attacks, result.hits, result.wounds, result.unsaved, result.damage],
		})
	return null
