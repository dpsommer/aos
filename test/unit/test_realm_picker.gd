extends GutTest
## Unit tests for the Spearhead realm picker (scripts/ui/quick_play/realm_picker.gd).

const UIKit := preload("res://test/support/ui_kit.gd")


func after_each() -> void:
	await get_tree().process_frame


func _realm(realm_name: String, relics: Array[String] = []) -> RealmBattlefield:
	var realm := RealmBattlefield.new()
	realm.name = realm_name
	var objective := MapFeature.new()
	objective.type = "Objective of " + realm_name
	objective.position = Vector2(15, 11)
	realm.objectives.append(objective)
	var twist := TwistCard.new()
	twist.name = "Twist of " + realm_name
	twist.text = "Twist rules"
	var option := {}
	option["name"] = "Option One"
	option["text"] = "Option text"
	twist.options.append(option)
	realm.twists.append(twist)
	realm.starting_relics = PackedStringArray(relics)
	return realm


func _pack(pack_name: String, realm_names: Array[String], relics: Array[String] = []) -> SpearheadBattlepack:
	var pack := SpearheadBattlepack.new()
	pack.name = pack_name
	pack.battlefield_size = Vector2(30, 22)
	for realm_name in realm_names:
		pack.realms.append(_realm(realm_name, relics))
	for relic_name in relics:
		var relic := Ability.new()
		relic.name = relic_name
		relic.effect = "Relic effect"
		pack.relics.append(relic)
	var deployment := DeploymentMap.new()
	deployment.name = "Deployment " + pack_name
	deployment.territory_a = PackedVector2Array([Vector2(0, 0), Vector2(30, 0), Vector2(30, 11), Vector2(0, 11)])
	deployment.territory_b = PackedVector2Array([Vector2(0, 11), Vector2(30, 11), Vector2(30, 22), Vector2(0, 22)])
	pack.deployment_maps.append(deployment)
	var section := RulesSection.new()
	section.name = "Pre-battle Sequence"
	section.text = "Setup text"
	pack.battleplan_sections.append(section)
	pack.scoring = PackedStringArray(["Score a point"])
	return pack


func _packs() -> Array[SpearheadBattlepack]:
	return [_pack("Pack One", ["Alpha", "Beta"], ["Relic X"]), _pack("Pack Two", ["Gamma"])]


func _picker(chosen := "") -> RealmPicker:
	var picker := RealmPicker.new(_packs(), chosen)
	add_child_autofree(picker)
	return picker


func _maps(root: Node, detailed: bool) -> Array[Node]:
	return UIKit.find_all(root, func(n: Node) -> bool: return n is RealmMap and n.detailed == detailed)


func _has_text(root: Node, text: String) -> bool:
	return not UIKit.find_all(root, func(n: Node) -> bool: return (n is Label or n is RichTextLabel) and str(n.text).contains(text)).is_empty()


func _set_open(picker: RealmPicker, realm: String, open: bool) -> void:
	(picker.cards[realm].get_meta(&"eye") as Button).button_pressed = open


func _count(root: Node, type: Variant) -> int:
	return UIKit.find_all(root, func(n: Node) -> bool: return is_instance_of(n, type)).size()


# --- Cards ---


func test_has_a_random_card() -> void:
	assert_true(_picker().cards.has(""))


func test_has_a_card_per_side() -> void:
	var picker := _picker()
	for side in ["Alpha", "Beta", "Gamma"]:
		assert_true(picker.cards.has(side), side)


func test_has_no_other_cards() -> void:
	assert_eq(_picker().cards.size(), 4)


func test_each_pack_has_a_heading() -> void:
	var picker := _picker()
	assert_true(_has_text(picker, "PACK ONE"))
	assert_true(_has_text(picker, "PACK TWO"))


func test_side_cards_have_a_small_map() -> void:
	assert_eq(_maps(_picker(), false).size(), 3)


func test_side_cards_have_no_detailed_map() -> void:
	assert_eq(_maps(_picker(), true).size(), 0)


# --- Selection ---


func test_selected_defaults_to_random() -> void:
	assert_eq(_picker().selected, "")


func test_selected_card_is_random_when_nothing_is_chosen() -> void:
	var picker := _picker()
	assert_eq(picker.selected_card(), picker.cards[""])


func test_selected_card_is_the_chosen_sides() -> void:
	var picker := _picker("Beta")
	assert_eq(picker.selected_card(), picker.cards["Beta"])


func test_selected_card_falls_back_to_random_for_an_unknown_side() -> void:
	var picker := _picker("Nowhere")
	assert_eq(picker.selected_card(), picker.cards[""])


func test_chosen_card_looks_different_from_the_others() -> void:
	var picker := _picker("Alpha")
	assert_ne(picker.cards["Alpha"].theme_type_variation, picker.cards["Beta"].theme_type_variation)


func test_random_card_looks_picked_when_random_is_chosen() -> void:
	var picker := _picker()
	assert_ne(picker.cards[""].theme_type_variation, picker.cards["Alpha"].theme_type_variation)


# --- Picking ---


func test_pressing_a_side_emits_its_pack_and_realm() -> void:
	var picker := _picker()
	watch_signals(picker)
	picker.cards["Gamma"].pressed.emit()
	assert_signal_emitted_with_parameters(picker, "picked", ["Pack Two", "Gamma"])


func test_pressing_a_side_in_the_first_pack_emits_that_pack() -> void:
	var picker := _picker()
	watch_signals(picker)
	picker.cards["Beta"].pressed.emit()
	assert_signal_emitted_with_parameters(picker, "picked", ["Pack One", "Beta"])


func test_pressing_random_emits_empty_pack_and_realm() -> void:
	var picker := _picker("Alpha")
	watch_signals(picker)
	picker.cards[""].pressed.emit()
	assert_signal_emitted_with_parameters(picker, "picked", ["", ""])


func test_pressing_a_side_selects_it() -> void:
	var picker := _picker()
	picker.cards["Beta"].pressed.emit()
	assert_eq(picker.selected, "Beta")


func test_pressing_random_clears_the_selection() -> void:
	var picker := _picker("Beta")
	picker.cards[""].pressed.emit()
	assert_eq(picker.selected, "")


# --- battlepack_of ---


func test_battlepack_of_finds_the_pack_with_the_side() -> void:
	assert_eq(RealmPicker.battlepack_of(_packs(), "Gamma").name, "Pack Two")


func test_battlepack_of_an_unknown_side_is_null() -> void:
	assert_null(RealmPicker.battlepack_of(_packs(), "Nowhere"))


func test_battlepack_of_random_is_null() -> void:
	assert_null(RealmPicker.battlepack_of(_packs(), ""))


func test_battlepack_of_with_no_packs_is_null() -> void:
	var none: Array[SpearheadBattlepack] = []
	assert_null(RealmPicker.battlepack_of(none, "Alpha"))


# --- Eye toggle ---


func test_every_side_card_has_an_eye() -> void:
	var picker := _picker()
	for side in ["Alpha", "Beta", "Gamma"]:
		assert_true(picker.cards[side].get_meta(&"eye") is Button, side)


func test_random_card_has_no_eye() -> void:
	assert_false(_picker().cards[""].has_meta(&"eye"))


func test_eye_swaps_in_a_full_card() -> void:
	var picker := _picker()
	var brief: Control = picker.cards["Alpha"]
	_set_open(picker, "Alpha", true)
	assert_ne(picker.cards["Alpha"], brief)


func test_opening_a_card_adds_a_detailed_map() -> void:
	var picker := _picker()
	_set_open(picker, "Alpha", true)
	assert_eq(_maps(picker.cards["Alpha"], true).size(), 1)


func test_opening_a_card_adds_a_map_per_deployment() -> void:
	var picker := _picker()
	_set_open(picker, "Alpha", true)
	var maps := UIKit.find_all(picker.cards["Alpha"], func(n: Node) -> bool: return n is RealmMap and n.deployment != null)
	assert_eq(maps.size(), 1)


func test_opening_a_card_shows_its_starting_relics() -> void:
	var picker := _picker()
	_set_open(picker, "Alpha", true)
	assert_eq(_count(picker.cards["Alpha"], AbilityCard), 1)


func test_opening_a_card_without_relics_shows_none() -> void:
	var picker := _picker()
	_set_open(picker, "Gamma", true)
	assert_eq(_count(picker.cards["Gamma"], AbilityCard), 0)


func test_opening_a_card_shows_its_twists() -> void:
	var picker := _picker()
	_set_open(picker, "Alpha", true)
	assert_true(_has_text(picker.cards["Alpha"], "Twist of Alpha"))


func test_opening_a_card_shows_the_scoring() -> void:
	var picker := _picker()
	_set_open(picker, "Alpha", true)
	assert_true(_has_text(picker.cards["Alpha"], "Score a point"))


func test_opening_a_card_shows_the_setup() -> void:
	var picker := _picker()
	_set_open(picker, "Alpha", true)
	assert_true(_has_text(picker.cards["Alpha"], "Setup text"))


func test_opening_a_card_keeps_its_place_in_the_list() -> void:
	var picker := _picker()
	var index: int = picker.cards["Beta"].get_index()
	_set_open(picker, "Beta", true)
	assert_eq(picker.cards["Beta"].get_index(), index)


func test_opening_a_card_leaves_the_others_brief() -> void:
	var picker := _picker()
	_set_open(picker, "Alpha", true)
	assert_eq(_maps(picker.cards["Beta"], true).size(), 0)


func test_opening_a_card_does_not_pick_it() -> void:
	var picker := _picker()
	watch_signals(picker)
	_set_open(picker, "Alpha", true)
	assert_signal_not_emitted(picker, "picked")


func test_closing_a_card_swaps_the_brief_form_back() -> void:
	var picker := _picker()
	_set_open(picker, "Alpha", true)
	_set_open(picker, "Alpha", false)
	assert_eq(_maps(picker, true).size(), 0)


func test_open_card_can_still_be_picked() -> void:
	var picker := _picker()
	_set_open(picker, "Alpha", true)
	watch_signals(picker)
	picker.cards["Alpha"].pressed.emit()
	assert_signal_emitted_with_parameters(picker, "picked", ["Pack One", "Alpha"])
