class_name RollOff
extends RefCounted
## The pre-battle roll-off: each player rolls a dice, rolling again on a tie, and the winner picks
## who is the attacker. See docs/gameplay/deployment.md.

## Every roll, (player, opponent), the last one the one that counts.
var rolls: Array[Vector2i] = []


## Rolls until someone wins. [param rng] makes it repeatable.
static func roll(rng: RandomNumberGenerator) -> RollOff:
	var result := RollOff.new()
	while true:
		var dice := Vector2i(rng.randi_range(1, 6), rng.randi_range(1, 6))
		result.rolls.append(dice)
		if dice.x != dice.y:
			break
	return result


## The roll that decided it.
func final() -> Vector2i:
	return rolls[-1] if not rolls.is_empty() else Vector2i.ZERO


func player_won() -> bool:
	return final().x > final().y


## How many ties were rolled again.
func ties() -> int:
	return maxi(rolls.size() - 1, 0)


## Whether the AI, having won, picks attacker. It picks at random for now.
static func ai_picks_attacker(rng: RandomNumberGenerator) -> bool:
	return rng.randi_range(0, 1) == 0
