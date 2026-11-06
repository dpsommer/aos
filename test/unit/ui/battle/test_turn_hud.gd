extends GutTest
## Unit tests for the HUD the player uses during the battle (scripts/ui/battle/turn_hud.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")
const RulesKit := preload("res://test/support/rules_kit.gd")
const Sandbox := preload("res://test/support/sandbox.gd")
const UIKit := preload("res://test/support/ui_kit.gd")

var _hud: TurnHud


func before_each() -> void:
	Sandbox.begin()
	_hud = TurnHud.create()
	add_child_autofree(_hud)


func after_each() -> void:
	Sandbox.end()


func _option(ability_name: String, user: BattleUnit = null, effect := "") -> ActionOption:
	var entry := AbilityEntry.new()
	entry.ability = BattleKit.ability(ability_name, PackedStringArray(), effect)
	return ActionOption.create(entry, user)


func _request(options: Array[ActionOption], can_pass := true) -> DecisionRequest:
	var request := DecisionRequest.create(DecisionRequest.Kind.ACTION, BattleArmy.new(), "Hero phase: use an ability or pass.")
	request.options = options
	request.can_pass = can_pass
	return request


func _options_box() -> VBoxContainer:
	return _hud.get_node(^"%Options")


func _texts() -> PackedStringArray:
	return UIKit.label_texts(_hud)


# The log

func test_a_line_is_added_to_the_log() -> void:
	_hud.add_log("The Player's turn.")
	assert_true(UIKit.has_label_containing(_hud, "The Player's turn."))


func test_log_lines_are_in_the_order_they_were_added() -> void:
	_hud.add_log("first")
	_hud.add_log("second")
	var lines := _hud.get_node(^"%Lines")
	assert_eq((lines.get_child(0) as Label).text, "first")
	assert_eq((lines.get_child(1) as Label).text, "second")


func test_the_log_keeps_only_the_latest_lines() -> void:
	for i in TurnHud.MAX_LOG_LINES + 5:
		_hud.add_log("line %d" % i)
	var lines := _hud.get_node(^"%Lines")
	assert_eq(lines.get_child_count(), TurnHud.MAX_LOG_LINES)
	assert_eq((lines.get_child(lines.get_child_count() - 1) as Label).text, "line %d" % (TurnHud.MAX_LOG_LINES + 4))
	assert_eq((lines.get_child(0) as Label).text, "line 5", "The oldest went")


# Options

func test_options_are_shown_as_buttons() -> void:
	_hud.show_options(_request([_option("Run"), _option("Rally")] as Array[ActionOption]), PackedStringArray())
	assert_true(UIKit.button_texts(_options_box()).has("Run"))
	assert_true(UIKit.button_texts(_options_box()).has("Rally"))


func test_an_option_shows_who_uses_it() -> void:
	var unit := BattleKit.unit("Brutes", 3)
	_hud.show_options(_request([_option("Run", unit)] as Array[ActionOption]), PackedStringArray())
	assert_true(UIKit.button_texts(_options_box()).has("Run (Brutes)"))


func test_the_prompt_is_shown() -> void:
	var request := _request([_option("Run")] as Array[ActionOption])
	_hud.show_options(request, PackedStringArray())
	assert_true(UIKit.has_label_containing(_hud, request.prompt))


func test_pressing_an_option_reports_it() -> void:
	var run := _option("Run")
	_hud.show_options(_request([run, _option("Rally")] as Array[ActionOption]), PackedStringArray())
	watch_signals(_hud)
	UIKit.button(_options_box(), "Run").pressed.emit()
	assert_signal_emitted_with_parameters(_hud, "option_picked", [run])


func test_the_option_pressed_is_the_one_on_the_button() -> void:
	var run := _option("Run")
	var rally := _option("Rally")
	_hud.show_options(_request([run, rally] as Array[ActionOption]), PackedStringArray())
	watch_signals(_hud)
	UIKit.button(_options_box(), "Rally").pressed.emit()
	assert_signal_emitted_with_parameters(_hud, "option_picked", [rally])


func test_an_options_rules_text_is_its_tooltip() -> void:
	_hud.show_options(_request([_option("Run", null, "It runs.")] as Array[ActionOption]), PackedStringArray())
	assert_true(UIKit.button(_options_box(), "Run").tooltip_text.contains("It runs."))


func test_pass_is_shown_only_if_the_player_can_pass() -> void:
	_hud.show_options(_request([_option("Run")] as Array[ActionOption], true), PackedStringArray())
	assert_true((_hud.get_node(^"%Pass") as Button).visible)
	_hud.show_options(_request([_option("Run")] as Array[ActionOption], false), PackedStringArray())
	assert_false((_hud.get_node(^"%Pass") as Button).visible)


func test_pressing_pass_reports_it() -> void:
	_hud.show_options(_request([] as Array[ActionOption]), PackedStringArray())
	watch_signals(_hud)
	(_hud.get_node(^"%Pass") as Button).pressed.emit()
	assert_signal_emitted(_hud, "pass_pressed")


func test_abilities_that_are_not_supported_are_listed() -> void:
	_hud.show_options(_request([] as Array[ActionOption]), PackedStringArray(["Fireball", "Roar"]))
	var label: Label = _hud.get_node(^"%NotSupported")
	assert_true(label.visible)
	assert_true(label.text.contains("Fireball"))
	assert_true(label.text.contains("Roar"))


func test_nothing_is_said_about_abilities_when_all_are_supported() -> void:
	_hud.show_options(_request([] as Array[ActionOption]), PackedStringArray())
	assert_false((_hud.get_node(^"%NotSupported") as Label).visible)


func test_the_options_can_be_narrowed_to_one_unit() -> void:
	var first := BattleKit.unit("First", 1)
	var second := BattleKit.unit("Second", 1)
	_hud.show_options(_request([_option("Run", first), _option("Run", second)] as Array[ActionOption]), PackedStringArray())
	_hud.filter_options(second)
	assert_eq(UIKit.button_texts(_options_box()), PackedStringArray(["Run (Second)"]))


func test_narrowing_again_to_no_unit_shows_them_all() -> void:
	var first := BattleKit.unit("First", 1)
	var second := BattleKit.unit("Second", 1)
	_hud.show_options(_request([_option("Run", first), _option("Run", second)] as Array[ActionOption]), PackedStringArray())
	_hud.filter_options(second)
	_hud.filter_options(null)
	assert_eq(UIKit.button_texts(_options_box()).size(), 2)


func test_narrowing_with_nothing_shown_does_nothing() -> void:
	_hud.filter_options(BattleKit.unit("First", 1))
	assert_eq(_options_box().get_child_count(), 0)


func test_showing_options_again_replaces_the_old_ones() -> void:
	_hud.show_options(_request([_option("Run")] as Array[ActionOption]), PackedStringArray())
	_hud.show_options(_request([_option("Rally")] as Array[ActionOption]), PackedStringArray())
	await get_tree().process_frame
	assert_eq(UIKit.button_texts(_options_box()), PackedStringArray(["Rally"]))


# Choices and units

func test_choices_are_shown_as_buttons_and_reported_by_index() -> void:
	_hud.show_choices("Who goes first?", PackedStringArray(["Go first", "Go second"]))
	assert_true(UIKit.has_label_containing(_hud, "Who goes first?"))
	watch_signals(_hud)
	UIKit.button(_options_box(), "Go second").pressed.emit()
	assert_signal_emitted_with_parameters(_hud, "choice_picked", [1])


func test_units_are_shown_with_their_model_count_and_reported_when_picked() -> void:
	var brutes := BattleKit.unit("Brutes", 4)
	_hud.show_units("Pick a target.", [brutes] as Array[BattleUnit])
	assert_true(UIKit.has_label_containing(_hud, "Pick a target."))
	watch_signals(_hud)
	UIKit.button(_options_box(), "Brutes (4)").pressed.emit()
	assert_signal_emitted_with_parameters(_hud, "unit_picked", [brutes])


func test_waiting_says_who_is_deciding() -> void:
	_hud.show_waiting("The opponent")
	assert_true(UIKit.has_label_containing(_hud, "The opponent is deciding"))


func test_waiting_clears_what_was_offered() -> void:
	_hud.show_options(_request([_option("Run")] as Array[ActionOption]), PackedStringArray())
	_hud.show_waiting("The opponent")
	await get_tree().process_frame
	assert_true(UIKit.buttons(_options_box()).is_empty())
	assert_false((_hud.get_node(^"%Pass") as Button).visible)


# Moving

func test_moving_shows_confirm_and_put_back_buttons() -> void:
	_hud.show_move("Move the Brutes.", true, false)
	assert_true((_hud.get_node(^"%Confirm") as Button).visible)
	assert_true((_hud.get_node(^"%Reset") as Button).visible)
	assert_true((_hud.get_node(^"%Keys") as Label).visible)


func test_moving_can_be_declined_if_the_player_can_pass() -> void:
	_hud.show_move("Move.", true, false)
	var pass_button: Button = _hud.get_node(^"%Pass")
	assert_true(pass_button.visible)
	assert_ne(pass_button.text, "Pass", "It says the models don't move")


func test_a_move_that_cannot_be_declined_has_no_pass_button() -> void:
	_hud.show_move("Move.", false, false)
	assert_false((_hud.get_node(^"%Pass") as Button).visible)


func test_the_keys_help_says_whether_a_single_model_moves() -> void:
	_hud.show_move("Move.", true, true)
	assert_true((_hud.get_node(^"%Keys") as Label).text.contains("a model"))
	_hud.show_move("Move.", true, false)
	assert_true((_hud.get_node(^"%Keys") as Label).text.contains("the unit"))


func test_confirm_can_be_disabled_until_the_move_is_legal() -> void:
	_hud.show_move("Move.", true, false)
	_hud.set_confirm_enabled(false)
	assert_true((_hud.get_node(^"%Confirm") as Button).disabled)
	_hud.set_confirm_enabled(true)
	assert_false((_hud.get_node(^"%Confirm") as Button).disabled)


func test_pressing_confirm_reports_it() -> void:
	_hud.show_move("Move.", true, false)
	watch_signals(_hud)
	(_hud.get_node(^"%Confirm") as Button).pressed.emit()
	assert_signal_emitted(_hud, "confirm_pressed")


func test_pressing_put_back_reports_it() -> void:
	_hud.show_move("Move.", true, false)
	watch_signals(_hud)
	(_hud.get_node(^"%Reset") as Button).pressed.emit()
	assert_signal_emitted(_hud, "reset_pressed")


func test_the_move_buttons_are_hidden_again_for_the_next_question() -> void:
	_hud.show_move("Move.", true, false)
	_hud.show_choices("Pick.", PackedStringArray(["A"]))
	assert_false((_hud.get_node(^"%Confirm") as Button).visible)
	assert_false((_hud.get_node(^"%Reset") as Button).visible)
	assert_false((_hud.get_node(^"%Keys") as Label).visible)
	assert_eq((_hud.get_node(^"%Pass") as Button).text, "Pass")


# Problems

func test_problems_are_listed_one_to_a_line() -> void:
	_hud.set_problems(PackedStringArray(["A model is too far.", "The unit isn't coherent."]))
	var label: Label = _hud.get_node(^"%Problems")
	assert_true(label.visible)
	assert_eq(label.text, "A model is too far.\nThe unit isn't coherent.")


func test_no_problems_hides_the_list() -> void:
	_hud.set_problems(PackedStringArray(["A model is too far."]))
	_hud.set_problems(PackedStringArray())
	assert_false((_hud.get_node(^"%Problems") as Label).visible)


func test_a_new_question_clears_the_problems() -> void:
	_hud.set_problems(PackedStringArray(["A model is too far."]))
	_hud.show_choices("Pick.", PackedStringArray(["A"]))
	assert_false((_hud.get_node(^"%Problems") as Label).visible)
