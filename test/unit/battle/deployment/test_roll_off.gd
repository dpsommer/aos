extends GutTest
## Unit tests for the roll-off (scripts/battle/deployment/roll_off.gd).


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _off(rolls: Array[Vector2i]) -> RollOff:
	var result := RollOff.new()
	result.rolls = rolls
	return result


# roll

func test_roll_ends_on_a_roll_that_is_not_a_tie() -> void:
	for seed_value in 20:
		var result := RollOff.roll(_rng(seed_value))
		assert_ne(result.final().x, result.final().y, "seed %d" % seed_value)


func test_roll_only_ties_before_the_last_roll() -> void:
	for seed_value in 20:
		var result := RollOff.roll(_rng(seed_value))
		for i in result.rolls.size() - 1:
			assert_eq(result.rolls[i].x, result.rolls[i].y, "seed %d roll %d" % [seed_value, i])


func test_roll_dice_are_between_one_and_six() -> void:
	var result := RollOff.roll(_rng(3))
	for dice in result.rolls:
		assert_between(dice.x, 1, 6)
		assert_between(dice.y, 1, 6)


func test_roll_is_repeatable_with_the_same_seed() -> void:
	assert_eq(RollOff.roll(_rng(7)).rolls, RollOff.roll(_rng(7)).rolls)


# final, player_won, ties

func test_final_is_the_last_roll() -> void:
	assert_eq(_off([Vector2i(3, 3), Vector2i(2, 5)]).final(), Vector2i(2, 5))


func test_final_is_zero_without_rolls() -> void:
	assert_eq(RollOff.new().final(), Vector2i.ZERO)


func test_player_won_when_the_player_rolls_higher() -> void:
	assert_true(_off([Vector2i(5, 2)]).player_won())


func test_player_lost_when_the_opponent_rolls_higher() -> void:
	assert_false(_off([Vector2i(2, 5)]).player_won())


func test_player_won_judges_only_the_last_roll() -> void:
	assert_false(_off([Vector2i(4, 4), Vector2i(1, 6)]).player_won())


func test_ties_counts_the_rolls_before_the_last() -> void:
	assert_eq(_off([Vector2i(3, 3), Vector2i(4, 4), Vector2i(1, 2)]).ties(), 2)


func test_ties_is_zero_for_a_single_roll() -> void:
	assert_eq(_off([Vector2i(1, 2)]).ties(), 0)


func test_ties_is_zero_without_rolls() -> void:
	assert_eq(RollOff.new().ties(), 0)


# ai_picks_attacker

func test_ai_picks_both_roles_over_many_rolls() -> void:
	var rng := _rng(1)
	var picks := {}
	for i in 50:
		picks[RollOff.ai_picks_attacker(rng)] = true
	assert_eq(picks.size(), 2)
