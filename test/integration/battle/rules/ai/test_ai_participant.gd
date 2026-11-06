extends GutTest
## The AI plays whole battles by answering the same requests the player does, and the engine accepts
## every answer.

const BattleSim := preload("res://test/support/battle_sim.gd")


func _play(game: GameController) -> String:
	var reason := BattleSim.play_out(game, AiParticipant.new())
	game.dispose()
	return reason


func test_every_answer_in_spearhead_battles_is_accepted() -> void:
	for seed_value in [11, 12]:
		var game := GameController.new(BattleSim.spearhead_battle(seed_value), BattleSim.seeded(seed_value))
		assert_eq(_play(game), "", "Seed %d" % seed_value)


func test_every_answer_in_matched_play_battles_is_accepted() -> void:
	for seed_value in [5, 6]:
		var game := GameController.new(BattleSim.matched_battle(seed_value), BattleSim.seeded(seed_value))
		assert_eq(_play(game), "", "Seed %d" % seed_value)


func test_the_same_answers_are_given_to_the_same_requests() -> void:
	var first := GameController.new(BattleSim.spearhead_battle(3), BattleSim.seeded(3))
	var second := GameController.new(BattleSim.spearhead_battle(3), BattleSim.seeded(3))
	BattleSim.play_out(first, AiParticipant.new())
	BattleSim.play_out(second, AiParticipant.new())
	assert_eq(first.answers.size(), second.answers.size())
	assert_eq(first.events.log_text(), second.events.log_text())
	first.dispose()
	second.dispose()
