class_name ChargePhaseController
extends PhaseController
## The charge phase: tracks who can still charge.

const CHARGE_KEYWORD := "CHARGE"


func units_that_can_charge(game: GameController, army: BattleArmy) -> Array[BattleUnit]:
	return _users_with_keyword(game, army, CHARGE_KEYWORD)
