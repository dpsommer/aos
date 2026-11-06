class_name ShootingPhaseController
extends PhaseController
## The shooting phase: tracks who has shot, and who still can.

const SHOOT_KEYWORD := "SHOOT"


func units_that_can_shoot(game: GameController, army: BattleArmy) -> Array[BattleUnit]:
	return _users_with_keyword(game, army, SHOOT_KEYWORD)
