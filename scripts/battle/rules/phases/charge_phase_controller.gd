class_name ChargePhaseController
extends PhaseController
## The charge phase: tracks who can still charge.

const CHARGE_KEYWORD := "CHARGE"


func units_that_can_charge(game: GameController, army: BattleArmy) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for option in options_for(game, army):
		if option.user and option.entry.ability.keywords.has(CHARGE_KEYWORD) and not option.user in result:
			result.append(option.user)
	return result
