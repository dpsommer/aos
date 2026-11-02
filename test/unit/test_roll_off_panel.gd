extends GutTest
## Unit tests for the roll-off screen (scripts/ui/battle/roll_off_panel.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")
const UIKit := preload("res://test/support/ui_kit.gd")


func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	Sandbox.end()


func _roll_off(rolls: Array[Vector2i]) -> RollOff:
	var result := RollOff.new()
	result.rolls = rolls
	return result


func _won() -> RollOff:
	return _roll_off([Vector2i(5, 2)] as Array[Vector2i])


func _lost() -> RollOff:
	return _roll_off([Vector2i(2, 5)] as Array[Vector2i])


func _panel(rolled: RollOff, ai_attacks := true, battle: Battle = null) -> RollOffPanel:
	var panel := RollOffPanel.new(battle if battle else BattleKit.battle(), rolled, ai_attacks)
	add_child_autofree(panel)
	return panel


func _matched_battle() -> Battle:
	var battle := BattleKit.battle()
	battle.mode = BattleSetup.Mode.MATCHED_PLAY
	battle.battleplan = BattleKit.battleplan("Plan")
	return battle


# before the result

func test_the_result_is_hidden_until_the_dice_land() -> void:
	assert_false(_panel(_won()).result_card.visible)


func test_finish_shows_the_result() -> void:
	var panel := _panel(_won())
	panel.finish()
	assert_true(panel.result_card.visible)


func test_finish_shows_the_final_dice() -> void:
	var panel := _panel(_roll_off([Vector2i(3, 3), Vector2i(2, 6)] as Array[Vector2i]))
	panel.finish()
	assert_eq(panel.player_value.text, "2")
	assert_eq(panel.opponent_value.text, "6")
	assert_eq(panel.player_die.value, 2)
	assert_eq(panel.opponent_die.value, 6)


func test_finish_stops_the_dice_tumbling() -> void:
	var panel := _panel(_won())
	panel.finish()
	assert_false(panel.player_die.tumbling)
	assert_false(panel.opponent_die.tumbling)


func test_finish_clears_the_tie_message() -> void:
	var panel := _panel(_roll_off([Vector2i(3, 3), Vector2i(2, 6)] as Array[Vector2i]))
	panel.finish()
	assert_eq(panel.status_label.text, "")


func test_finishing_twice_is_harmless() -> void:
	var panel := _panel(_won())
	panel.finish()
	panel.finish()
	assert_true(panel.result_card.visible)


# the player won

func test_a_win_offers_attacker_and_defender() -> void:
	var panel := _panel(_won())
	panel.finish()
	assert_not_null(panel.attacker_button)
	assert_not_null(panel.defender_button)
	assert_null(panel.continue_button)


func test_choosing_attacker_emits_true() -> void:
	var panel := _panel(_won())
	panel.finish()
	watch_signals(panel)
	panel.attacker_button.pressed.emit()
	assert_signal_emitted_with_parameters(panel, "role_chosen", [true])


func test_choosing_defender_emits_false() -> void:
	var panel := _panel(_won())
	panel.finish()
	watch_signals(panel)
	panel.defender_button.pressed.emit()
	assert_signal_emitted_with_parameters(panel, "role_chosen", [false])


func test_a_win_says_so() -> void:
	var panel := _panel(_won())
	panel.finish()
	assert_true(UIKit.has_label_containing(panel.result_card, "You won"))


func test_the_role_buttons_describe_their_roles_for_screen_readers() -> void:
	var panel := _panel(_won())
	assert_string_contains(panel.attacker_button.accessibility_name, "Attacker")
	assert_string_contains(panel.defender_button.accessibility_name, "Defender")


func test_a_matched_play_win_previews_the_battleplan() -> void:
	var panel := _panel(_won(), true, _matched_battle())
	var maps := UIKit.find_all(panel.attacker_button, func(n: Node) -> bool: return n is BattleplanMap)
	assert_eq(maps.size(), 1)


func test_a_spearhead_win_describes_spearheads_roles() -> void:
	var panel := _panel(_won())
	assert_string_contains(panel.defender_button.accessibility_name, "deployment map")


# the AI won

func test_a_loss_offers_only_continue() -> void:
	var panel := _panel(_lost())
	panel.finish()
	assert_not_null(panel.continue_button)
	assert_null(panel.attacker_button)
	assert_null(panel.defender_button)


func test_continue_makes_the_player_the_defender_when_the_ai_attacks() -> void:
	var panel := _panel(_lost(), true)
	panel.finish()
	watch_signals(panel)
	panel.continue_button.pressed.emit()
	assert_signal_emitted_with_parameters(panel, "role_chosen", [false])


func test_continue_makes_the_player_the_attacker_when_the_ai_defends() -> void:
	var panel := _panel(_lost(), false)
	panel.finish()
	watch_signals(panel)
	panel.continue_button.pressed.emit()
	assert_signal_emitted_with_parameters(panel, "role_chosen", [true])


func test_a_loss_says_which_role_the_ai_chose() -> void:
	var attacking := _panel(_lost(), true)
	var defending := _panel(_lost(), false)
	assert_true(UIKit.has_label_containing(attacking.result_card, "chose to be the attacker"))
	assert_true(UIKit.has_label_containing(defending.result_card, "chose to be the defender"))


func test_a_loss_tells_the_player_their_role() -> void:
	var panel := _panel(_lost(), true)
	assert_true(UIKit.has_label_containing(panel.result_card, "You are the defender"))
