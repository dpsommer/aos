extends GutTest
## Unit tests for Quick Play's game mode step (scripts/ui/quick_play/game_mode_screen.gd).

const GameModeScene := preload("res://scenes/ui/quick_play/game_mode_screen.tscn")
const Sandbox := preload("res://test/support/sandbox.gd")


func before_each() -> void:
	Sandbox.begin()


func after_each() -> void:
	Sandbox.end()


func _make_screen() -> GameModeScreen:
	var screen: GameModeScreen = GameModeScene.instantiate()
	add_child_autofree(screen)
	watch_signals(screen)
	return screen


func _escape_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func _legends_spearheads() -> Array:
	return FactionCatalog.spearheads().filter(func(entry: Dictionary) -> bool: return FactionCatalog.is_legends(entry.faction))


func test_has_a_card_for_each_mode() -> void:
	var screen := _make_screen()
	for mode: BattleSetup.Mode in BattleSetup.Mode.values():
		assert_true(screen.mode_cards.has(mode), "no card for mode %d" % mode)


func test_pressing_spearhead_card_emits_that_mode() -> void:
	var screen := _make_screen()
	screen.mode_cards[BattleSetup.Mode.SPEARHEAD].pressed.emit()
	assert_signal_emitted_with_parameters(screen, "mode_chosen", [BattleSetup.Mode.SPEARHEAD])


func test_pressing_matched_play_card_emits_that_mode() -> void:
	var screen := _make_screen()
	screen.mode_cards[BattleSetup.Mode.MATCHED_PLAY].pressed.emit()
	assert_signal_emitted_with_parameters(screen, "mode_chosen", [BattleSetup.Mode.MATCHED_PLAY])


func test_pressing_a_card_does_not_go_back() -> void:
	var screen := _make_screen()
	screen.mode_cards[BattleSetup.Mode.SPEARHEAD].pressed.emit()
	assert_signal_not_emitted(screen, "back_pressed")


func test_back_button_emits_back_pressed() -> void:
	var screen := _make_screen()
	screen.back_button.pressed.emit()
	assert_signal_emitted(screen, "back_pressed")


func test_escape_emits_back_pressed() -> void:
	var screen := _make_screen()
	screen._unhandled_input(_escape_event())
	assert_signal_emitted(screen, "back_pressed")


func test_back_button_does_not_choose_a_mode() -> void:
	var screen := _make_screen()
	screen.back_button.pressed.emit()
	assert_signal_not_emitted(screen, "mode_chosen")


func test_focus_mode_card_focuses_that_card() -> void:
	var screen := _make_screen()
	screen.focus_mode_card(BattleSetup.Mode.MATCHED_PLAY)
	assert_true(screen.mode_cards[BattleSetup.Mode.MATCHED_PLAY].has_focus())


func test_spearhead_card_has_focus_on_ready() -> void:
	var screen := _make_screen()
	assert_true(screen.mode_cards[BattleSetup.Mode.SPEARHEAD].has_focus())


func test_spearhead_chip_counts_the_shown_spearheads() -> void:
	var count := GameModeScreen.shown_spearheads().size()
	var first_chip: String = GameModeScreen.mode_chips(BattleSetup.Mode.SPEARHEAD)[0][0]
	assert_true(first_chip.begins_with(str(count)))


func test_spearhead_chip_follows_the_legends_setting() -> void:
	if _legends_spearheads().is_empty():
		pending("no Legends faction has a Spearhead")
		return
	GameSettings.current().show_legends = true
	var shown: String = GameModeScreen.mode_chips(BattleSetup.Mode.SPEARHEAD)[0][0]
	GameSettings.current().show_legends = false
	var hidden: String = GameModeScreen.mode_chips(BattleSetup.Mode.SPEARHEAD)[0][0]
	assert_ne(shown, hidden)


func test_every_mode_has_chips() -> void:
	for mode: BattleSetup.Mode in BattleSetup.Mode.values():
		assert_gt(GameModeScreen.mode_chips(mode).size(), 0, "mode %d has no chips" % mode)


func test_shown_spearheads_include_legends_factions_when_setting_is_on() -> void:
	if _legends_spearheads().is_empty():
		pending("no Legends faction has a Spearhead")
		return
	GameSettings.current().show_legends = true
	assert_eq(GameModeScreen.shown_spearheads().size(), FactionCatalog.spearheads().size())


func test_shown_spearheads_hide_legends_factions_when_setting_is_off() -> void:
	GameSettings.current().show_legends = false
	for entry in GameModeScreen.shown_spearheads():
		assert_false(FactionCatalog.is_legends(entry.faction), "%s is Legends" % entry.faction)


func test_shown_spearheads_keep_other_factions_when_legends_are_hidden() -> void:
	GameSettings.current().show_legends = false
	var expected := FactionCatalog.spearheads().size() - _legends_spearheads().size()
	assert_eq(GameModeScreen.shown_spearheads().size(), expected)
