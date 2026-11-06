extends GutTest
## Whole battles, played by the AI on both sides through the same requests the player answers.

const BattleSim := preload("res://test/support/battle_sim.gd")


func _play(seed_value: int) -> GameController:
	var game := GameController.new(BattleSim.spearhead_battle(seed_value), BattleSim.seeded(seed_value))
	var invariants := func() -> void:
		for army in game.armies():
			for unit in army.units:
				if unit.is_on_battlefield():
					assert_eq(unit.positions.size(), unit.bases.size(), "Bases and positions stay in step: %s" % unit.name)
	assert_eq(BattleSim.play_out(game, AiParticipant.new(), invariants), "")
	return game


func test_a_spearhead_battle_plays_to_a_result() -> void:
	var game := _play(1)
	assert_true(game.is_over())
	assert_eq(game.state.round_number, game.rules.round_count())
	game.dispose()


func test_the_same_seed_plays_the_same_battle() -> void:
	var first := _play(7)
	var second := _play(7)
	assert_eq(first.events.log_text(), second.events.log_text())
	first.dispose()
	second.dispose()


func test_different_seeds_play_different_battles() -> void:
	var first := _play(1)
	var second := _play(2)
	assert_ne(first.events.log_text(), second.events.log_text())
	first.dispose()
	second.dispose()


func test_a_matched_play_battle_plays_to_a_result() -> void:
	var game := GameController.new(BattleSim.matched_battle(3), BattleSim.seeded(3))
	assert_eq(BattleSim.play_out(game, AiParticipant.new()), "")
	assert_true(game.is_over())
	assert_eq(game.state.round_number, game.rules.round_count())
	game.dispose()
