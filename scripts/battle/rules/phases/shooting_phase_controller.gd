class_name ShootingPhaseController
extends PhaseController
## The shooting phase: tracks who has shot, and who still can.

const SHOOT_KEYWORD := "SHOOT"


func units_that_can_shoot(game: GameController, army: BattleArmy) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for option in options_for(game, army):
		if option.user and option.entry.ability.keywords.has(SHOOT_KEYWORD) and not option.user in result:
			result.append(option.user)
	return result
