extends GutTest
## Unit tests for the battleplan picker (scripts/ui/quick_play/battleplan_picker.gd).

const UIKit := preload("res://test/support/ui_kit.gd")


## Swapped cards are removed with queue_free, so let a frame pass for them to be freed before GUT
## counts orphans.
func after_each() -> void:
	await get_tree().process_frame


func _plan(plan_name: String, table: int, number: int) -> Battleplan:
	var plan := Battleplan.new()
	plan.name = plan_name
	plan.table = table
	plan.number = number
	plan.twist = "Twist of " + plan_name
	var objective := MapFeature.new()
	objective.position = Vector2(30, 22)
	plan.objectives.append(objective)
	return plan


func _pack() -> Battlepack:
	var pack := Battlepack.new()
	pack.battlefield_size = Vector2(60, 44)
	pack.battleplans.append(_plan("Alpha", 1, 1))
	pack.battleplans.append(_plan("Beta", 1, 2))
	pack.battleplans.append(_plan("Gamma", 2, 1))
	return pack


func _picker(chosen := "") -> BattleplanPicker:
	var picker := BattleplanPicker.new(_pack(), chosen)
	add_child_autofree(picker)
	watch_signals(picker)
	return picker


func _open_eye(picker: BattleplanPicker, plan_name: String, on := true) -> void:
	(picker.cards[plan_name].get_meta(&"eye") as Button).button_pressed = on


func _maps(node: Node, detailed: bool) -> Array[Node]:
	return UIKit.find_all(node, func(n: Node) -> bool: return n is BattleplanMap and n.detailed == detailed)


func test_has_a_card_for_random_and_each_battleplan() -> void:
	var picker := _picker()
	assert_eq(picker.cards.size(), 4)
	for key in ["", "Alpha", "Beta", "Gamma"]:
		assert_true(picker.cards.has(key), "no card for '%s'" % key)


func test_random_card_is_first() -> void:
	var picker := _picker()
	assert_eq(picker.get_child(0), picker.cards[""])


func test_pressing_a_battleplan_card_emits_its_name() -> void:
	var picker := _picker()
	picker.cards["Beta"].pressed.emit()
	assert_signal_emitted_with_parameters(picker, "picked", ["Beta"])


func test_pressing_random_emits_an_empty_name() -> void:
	var picker := _picker("Alpha")
	picker.cards[""].pressed.emit()
	assert_signal_emitted_with_parameters(picker, "picked", [""])


func test_pressing_a_card_selects_it() -> void:
	var picker := _picker()
	picker.cards["Gamma"].pressed.emit()
	assert_eq(picker.selected, "Gamma")


func test_selected_card_is_random_without_a_choice() -> void:
	var picker := _picker()
	assert_eq(picker.selected_card(), picker.cards[""])


func test_selected_card_is_the_chosen_battleplan() -> void:
	var picker := _picker("Beta")
	assert_eq(picker.selected_card(), picker.cards["Beta"])


func test_selected_card_falls_back_to_random_for_an_unknown_name() -> void:
	var picker := _picker("Nonexistent")
	assert_eq(picker.selected_card(), picker.cards[""])


func test_chosen_card_is_styled_as_picked() -> void:
	var picker := _picker("Alpha")
	assert_eq(picker.cards["Alpha"].theme_type_variation, &"PickedCardPanel")


func test_other_cards_are_not_styled_as_picked() -> void:
	var picker := _picker("Alpha")
	assert_ne(picker.cards["Beta"].theme_type_variation, &"PickedCardPanel")


func test_cards_start_with_brief_maps_only() -> void:
	var picker := _picker()
	assert_eq(_maps(picker, true).size(), 0)


func test_each_battleplan_card_has_a_brief_map() -> void:
	var picker := _picker()
	assert_eq(_maps(picker, false).size(), 3)


func test_eye_swaps_the_card_for_its_full_form() -> void:
	var picker := _picker()
	var brief: Node = picker.cards["Alpha"]
	_open_eye(picker, "Alpha")
	assert_ne(picker.cards["Alpha"], brief)


func test_full_card_shows_a_detailed_map() -> void:
	var picker := _picker()
	_open_eye(picker, "Alpha")
	assert_eq(_maps(picker.cards["Alpha"], true).size(), 1)


func test_other_cards_stay_brief_when_one_is_opened() -> void:
	var picker := _picker()
	_open_eye(picker, "Alpha")
	assert_eq(_maps(picker.cards["Beta"], true).size(), 0)


func test_swapped_card_keeps_its_place_in_the_list() -> void:
	var picker := _picker()
	var index: int = picker.cards["Beta"].get_index()
	_open_eye(picker, "Beta")
	assert_eq(picker.cards["Beta"].get_index(), index)


func test_swapping_keeps_the_number_of_cards() -> void:
	var picker := _picker()
	var count := picker.get_child_count()
	_open_eye(picker, "Beta")
	assert_eq(picker.get_child_count(), count)


func test_closing_the_eye_returns_to_the_brief_form() -> void:
	var picker := _picker()
	_open_eye(picker, "Alpha")
	_open_eye(picker, "Alpha", false)
	assert_eq(_maps(picker.cards["Alpha"], true).size(), 0)


func test_pressing_the_eye_does_not_pick_the_battleplan() -> void:
	var picker := _picker()
	_open_eye(picker, "Alpha")
	assert_signal_not_emitted(picker, "picked")


func test_full_card_shows_the_twist() -> void:
	var picker := _picker()
	_open_eye(picker, "Alpha")
	assert_true(UIKit.has_label_containing(picker.cards["Alpha"], "Twist"))


func test_describe_gives_table_and_number() -> void:
	var text := BattleplanPicker.describe(_plan("Alpha", 2, 5))
	assert_true(text.contains("2") and text.contains("5"))
