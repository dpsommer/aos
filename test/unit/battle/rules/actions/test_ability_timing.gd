extends GutTest
## Reading an ability's timing text.

const M := AbilityTiming.Moment
const W := AbilityTiming.Whose


func test_windows_and_whose_turn() -> void:
	# [text, window, whose, first round only]
	var cases := [
		["Your Hero Phase", M.HERO, W.YOURS, false],
		["Any Hero Phase", M.HERO, W.ANY, false],
		["Enemy Hero Phase", M.HERO, W.ENEMYS, false],
		["Your Movement Phase", M.MOVEMENT, W.YOURS, false],
		["Enemy Movement Phase", M.MOVEMENT, W.ENEMYS, false],
		["Any Shooting Phase", M.SHOOTING, W.ANY, false],
		["Your Charge Phase", M.CHARGE, W.YOURS, false],
		["Enemy Combat Phase", M.COMBAT, W.ENEMYS, false],
		["Any Combat Phase", M.COMBAT, W.ANY, false],
		["Deployment Phase", M.DEPLOYMENT, W.ANY, false],
		["Start of Battle", M.START_OF_BATTLE, W.ANY, false],
		["Start of Your Turn", M.START_OF_TURN, W.YOURS, false],
		["Start of Enemy Turn", M.START_OF_TURN, W.ENEMYS, false],
		["Start of Any Turn", M.START_OF_TURN, W.ANY, false],
		["End of Your Turn", M.END_OF_TURN, W.YOURS, false],
		["End of Enemy Turn", M.END_OF_TURN, W.ENEMYS, false],
		["End of Any Turn", M.END_OF_TURN, W.ANY, false],
		["Start of Battle Round", M.START_OF_ROUND, W.ANY, false],
		["Start of First Battle Round", M.START_OF_ROUND, W.ANY, true],
		["Start of the First Battle Round", M.START_OF_ROUND, W.ANY, true],
		["End of the First Battle Round", M.END_OF_ROUND, W.ANY, true],
		["Passive", M.PASSIVE, W.ANY, false],
	]
	for entry: Array in cases:
		var timing := AbilityTiming.parse(entry[0])
		assert_eq(timing.window, entry[1], "%s: window" % entry[0])
		assert_eq(timing.whose, entry[2], "%s: whose turn" % entry[0])
		assert_eq(timing.first_round_only, entry[3], "%s: first round" % entry[0])


func test_a_trailing_full_stop_is_ignored() -> void:
	assert_eq(AbilityTiming.parse("Any Hero Phase.").window, M.HERO)


func test_a_usage_limit_after_the_window_is_ignored() -> void:
	var timing := AbilityTiming.parse("Any Combat Phase, Once Per Battle")
	assert_eq(timing.window, M.COMBAT)
	assert_eq(timing.whose, W.ANY)


func test_text_that_is_not_a_timing_is_unknown() -> void:
	assert_false(AbilityTiming.parse("").is_known())
	assert_false(AbilityTiming.parse("Whenever you like").is_known())


func test_a_window_is_known() -> void:
	assert_true(AbilityTiming.parse("Your Hero Phase").is_known())


func test_a_bracketed_note_before_the_window_is_ignored() -> void:
	# "(Army,) Your Shooting Phase" is in the data: a comma inside the brackets.
	var timing := AbilityTiming.parse("(Army,) Your Shooting Phase")
	assert_eq(timing.window, AbilityTiming.Moment.SHOOTING)
	assert_eq(timing.whose, AbilityTiming.Whose.YOURS)


# Which windows an ability fits

func test_fits_needs_the_same_window() -> void:
	var timing := AbilityTiming.parse("Your Hero Phase")
	assert_true(timing.fits(M.HERO, true))
	assert_false(timing.fits(M.MOVEMENT, true))


func test_fits_whose_turn() -> void:
	# [text, fits in your turn, fits in the enemy's]
	var cases := [["Your Hero Phase", true, false], ["Enemy Hero Phase", false, true], ["Any Hero Phase", true, true]]
	for entry: Array in cases:
		var timing := AbilityTiming.parse(entry[0])
		assert_eq(timing.fits(M.HERO, true), entry[1], "%s, your turn" % entry[0])
		assert_eq(timing.fits(M.HERO, false), entry[2], "%s, enemy's turn" % entry[0])


func test_turn_windows_fit_whose_turn() -> void:
	assert_true(AbilityTiming.parse("Start of Your Turn").fits(M.START_OF_TURN, true))
	assert_false(AbilityTiming.parse("Start of Your Turn").fits(M.START_OF_TURN, false))
	assert_true(AbilityTiming.parse("End of Enemy Turn").fits(M.END_OF_TURN, false))
	assert_false(AbilityTiming.parse("End of Enemy Turn").fits(M.END_OF_TURN, true))


func test_a_passive_fits_only_the_passive_window() -> void:
	var timing := AbilityTiming.parse("Passive")
	assert_true(timing.fits(M.PASSIVE, true))
	assert_false(timing.fits(M.HERO, true))


# Reactions

func test_a_reaction_is_a_reaction_window() -> void:
	assert_eq(AbilityTiming.parse("Reaction: Opponent declared a SPELL ability").window, M.REACTION)


func test_a_reaction_to_the_opponent_or_to_you() -> void:
	assert_true(AbilityTiming.parse("Reaction: Opponent declared a SPELL ability").to_opponent)
	assert_false(AbilityTiming.parse("Reaction: You declared a SPELL ability").to_opponent)


func test_reaction_trigger_keywords() -> void:
	var timing := AbilityTiming.parse("Reaction: You declared a SPELL or PRAYER ability for a unit")
	assert_eq(timing.trigger_keywords, PackedStringArray(["SPELL", "PRAYER"]))
	assert_true(timing.trigger_excludes.is_empty())


func test_a_non_keyword_is_excluded_not_required() -> void:
	var timing := AbilityTiming.parse("Reaction: You declared a non-CHARGE MOVE ability for an Arkanaut Frigate")
	assert_eq(timing.trigger_keywords, PackedStringArray(["MOVE"]))
	assert_eq(timing.trigger_excludes, PackedStringArray(["CHARGE"]))


func test_trigger_keywords_are_upper_case_whatever_the_text() -> void:
	var timing := AbilityTiming.parse("Reaction: Opponent declared an Attack ability that targeted this unit")
	assert_eq(timing.trigger_keywords, PackedStringArray(["ATTACK"]))


func test_a_named_ability_in_single_quotes() -> void:
	var timing := AbilityTiming.parse("Reaction: You declared the 'Counter-charge' command for this unit")
	assert_eq(timing.trigger_ability, "Counter-charge")
	assert_true(timing.trigger_keywords.is_empty())


func test_a_named_ability_in_curly_quotes() -> void:
	var timing := AbilityTiming.parse("Reaction: You declared the ‘Call for Reinforcements’ ability")
	assert_eq(timing.trigger_ability, "Call for Reinforcements")


func test_an_apostrophe_in_the_name_does_not_close_it() -> void:
	var timing := AbilityTiming.parse("Reaction: You declared the 'Sorcerer's Bane' ability for this unit")
	assert_eq(timing.trigger_ability, "Sorcerer's Bane")


func test_a_command_trigger() -> void:
	var timing := AbilityTiming.parse("Reaction: Opponent declared a command for a unit within 12\" of this unit")
	assert_true(timing.trigger_command)
	assert_true(timing.to_opponent)


func test_this_unit_only() -> void:
	assert_true(AbilityTiming.parse("Reaction: You declared a CHARGE ability for this unit").this_unit_only)
	assert_false(AbilityTiming.parse("Reaction: You declared a CHARGE ability for a friendly unit").this_unit_only)


func test_this_unit_targeted() -> void:
	assert_true(AbilityTiming.parse("Reaction: Opponent declared an Attack ability that targeted this unit").this_unit_targeted)
	assert_false(AbilityTiming.parse("Reaction: Opponent declared an ATTACK ability").this_unit_targeted)


func test_a_reaction_limited_to_a_window() -> void:
	var timing := AbilityTiming.parse("Your Shooting Phase, Reaction: You declared a SHOOT ability for this unit")
	assert_eq(timing.window, M.REACTION)
	assert_eq(timing.within_window, M.SHOOTING)
	assert_eq(timing.whose, W.YOURS)
	assert_eq(timing.trigger_keywords, PackedStringArray(["SHOOT"]))


func test_a_reaction_without_a_window_is_not_limited() -> void:
	assert_eq(AbilityTiming.parse("Reaction: You declared a RUN ability").within_window, M.UNKNOWN)


func test_a_declaration_without_the_reaction_label_is_a_reaction() -> void:
	var timing := AbilityTiming.parse("You declared a FIGHT ability for this unit")
	assert_eq(timing.window, M.REACTION)
	assert_eq(timing.trigger_keywords, PackedStringArray(["FIGHT"]))
	assert_true(timing.this_unit_only)


func test_the_text_after_the_trigger_is_kept() -> void:
	var timing := AbilityTiming.parse("Reaction: You declared a CHARGE ability for a unit wholly within 12\" of your general")
	assert_true(timing.trigger_rest.contains("12\""))


func test_your_opponent_is_the_opponent() -> void:
	assert_true(AbilityTiming.parse("Reaction: Your opponent declared a FIGHT ability").to_opponent)


func test_being_picked_as_a_target_reacts_to_any_other_ability() -> void:
	var timing := AbilityTiming.parse("Reaction: This unit was picked as the target of a non-CORE ability")
	assert_true(timing.to_opponent and timing.reacts_to_any and timing.this_unit_targeted)
	assert_has(timing.trigger_excludes, "CORE")
