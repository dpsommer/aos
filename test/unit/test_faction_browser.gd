extends GutTest
## Unit tests for the faction rules browser (scripts/ui/forge/faction_browser.gd).
##
## Uses the fixture faction in test/fixtures/factions/valid rather than real faction data.

const FactionBrowserScene := preload("res://scenes/ui/forge/faction_browser.tscn")
const FIXTURE := "res://test/fixtures/factions/valid"


func _make_browser() -> FactionBrowser:
	var browser: FactionBrowser = FactionBrowserScene.instantiate()
	add_child_autofree(browser)
	watch_signals(browser)
	return browser


func _fixture() -> Faction:
	var loader := FactionLoader.new()
	var faction := loader.load_faction(FIXTURE)
	assert_eq(loader.errors.size(), 0, "fixture failed to load: %s" % str(loader.errors))
	return faction


func _press_cancel(browser: FactionBrowser, pressed := true) -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = pressed
	browser._unhandled_input(event)


func test_title_shows_faction_name() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	browser.show_faction(faction)
	assert_eq(browser.title.text, faction.name)


func test_title_is_faction_name_when_not_legends() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	faction.legends = false
	browser.show_faction(faction)
	assert_eq(browser.title.text, faction.name)


func test_legends_faction_title_marks_legends() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	faction.legends = true
	browser.show_faction(faction)
	assert_string_contains(browser.title.text, "Legends")


func test_legends_faction_title_starts_with_faction_name() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	faction.legends = true
	browser.show_faction(faction)
	assert_true(browser.title.text.begins_with(faction.name), browser.title.text)


func test_legends_faction_rules_tab_shows_faction_rules() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	faction.legends = true
	browser.show_faction(faction)
	assert_eq(browser.rules.text, RulesFormatter.faction_rules(faction))


func test_keeps_shown_faction() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	browser.show_faction(faction)
	assert_same(browser.faction, faction)


func test_rules_tab_shows_faction_rules() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	browser.show_faction(faction)
	assert_eq(browser.rules.text, RulesFormatter.faction_rules(faction))


func test_warscrolls_list_has_item_per_warscroll() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	browser.show_faction(faction)
	assert_eq(browser.warscrolls.list.item_count, faction.warscrolls.size())


func test_warscroll_label_includes_name_and_points() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	browser.show_faction(faction)
	var label := browser.warscrolls.list.get_item_text(0)
	assert_string_contains(label, faction.warscrolls[0].name)
	assert_string_contains(label, str(faction.warscrolls[0].points))


func test_warscroll_label_includes_source() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	var index := -1
	for i in faction.warscrolls.size():
		if not faction.warscrolls[i].source.is_empty():
			index = i
	assert_gt(index, -1, "fixture needs a warscroll with a source")
	browser.show_faction(faction)
	assert_string_contains(browser.warscrolls.list.get_item_text(index), faction.warscrolls[index].source)


func test_first_warscroll_is_rendered() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	browser.show_faction(faction)
	assert_eq(browser.warscrolls.detail.text, RulesFormatter.warscroll(faction.warscrolls[0]))


func test_selecting_warscroll_renders_it() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	browser.show_faction(faction)
	var last := faction.warscrolls.size() - 1
	browser.warscrolls.select(last)
	assert_eq(browser.warscrolls.detail.text, RulesFormatter.warscroll(faction.warscrolls[last]))


func test_armies_of_renown_list_has_item_per_army() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	browser.show_faction(faction)
	assert_eq(browser.armies_of_renown.list.item_count, faction.armies_of_renown.size())


## Index of the first army in [param faction] whose legends flag is [param legends].
func _army_index(faction: Faction, legends: bool) -> int:
	for i in faction.armies_of_renown.size():
		if faction.armies_of_renown[i].legends == legends:
			return i
	return -1


func test_legends_army_of_renown_label_marks_legends() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	var index := _army_index(faction, true)
	assert_gt(index, -1, "fixture needs a legends army of renown")
	browser.show_faction(faction)
	var label := browser.armies_of_renown.list.get_item_text(index)
	assert_string_contains(label, faction.armies_of_renown[index].name)
	assert_string_contains(label, "Legends")


func test_army_of_renown_label_is_name_when_not_legends() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	var index := _army_index(faction, false)
	assert_gt(index, -1, "fixture needs an army of renown that isn't legends")
	browser.show_faction(faction)
	assert_eq(browser.armies_of_renown.list.get_item_text(index), faction.armies_of_renown[index].name)


func test_selecting_legends_army_of_renown_renders_it() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	var index := _army_index(faction, true)
	assert_gt(index, -1, "fixture needs a legends army of renown")
	browser.show_faction(faction)
	browser.armies_of_renown.select(index)
	assert_eq(browser.armies_of_renown.detail.text, RulesFormatter.army_of_renown(faction.armies_of_renown[index]))


func test_first_army_of_renown_is_rendered() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	browser.show_faction(faction)
	assert_eq(browser.armies_of_renown.detail.text, RulesFormatter.army_of_renown(faction.armies_of_renown[0]))


func test_regiments_of_renown_list_has_item_per_regiment() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	browser.show_faction(faction)
	assert_gt(faction.regiments_of_renown.size(), 0, "fixture needs regiments of renown")
	assert_eq(browser.regiments_of_renown.list.item_count, faction.regiments_of_renown.size())


## Index of the first regiment in [param faction] whose legends flag is [param legends].
func _regiment_index(faction: Faction, legends: bool) -> int:
	for i in faction.regiments_of_renown.size():
		if faction.regiments_of_renown[i].legends == legends:
			return i
	return -1


func test_regiment_of_renown_label_has_name_and_points() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	var index := _regiment_index(faction, false)
	assert_gt(index, -1, "fixture needs a regiment of renown that isn't legends")
	browser.show_faction(faction)
	var regiment := faction.regiments_of_renown[index]
	assert_eq(browser.regiments_of_renown.list.get_item_text(index), "%s - %d pts" % [regiment.name, regiment.points])


func test_legends_regiment_of_renown_label_marks_legends() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	var index := _regiment_index(faction, true)
	assert_gt(index, -1, "fixture needs a legends regiment of renown")
	browser.show_faction(faction)
	var regiment := faction.regiments_of_renown[index]
	var label := browser.regiments_of_renown.list.get_item_text(index)
	assert_string_contains(label, regiment.name)
	assert_string_contains(label, "Legends")
	assert_string_contains(label, str(regiment.points))


func test_selecting_regiment_of_renown_renders_it() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	var last := faction.regiments_of_renown.size() - 1
	assert_gt(last, 0, "fixture needs several regiments of renown")
	browser.show_faction(faction)
	browser.regiments_of_renown.select(last)
	assert_eq(browser.regiments_of_renown.detail.text, RulesFormatter.regiment_of_renown(faction.regiments_of_renown[last]))


func test_first_regiment_of_renown_is_rendered() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	browser.show_faction(faction)
	assert_eq(browser.regiments_of_renown.detail.text, RulesFormatter.regiment_of_renown(faction.regiments_of_renown[0]))


func test_regiments_of_renown_tab_is_titled() -> void:
	var browser := _make_browser()
	var index := browser.tabs.get_tab_idx_from_control(browser.regiments_of_renown)
	assert_eq(browser.tabs.get_tab_title(index), "Regiments of Renown")


func test_spearheads_list_has_item_per_spearhead() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	browser.show_faction(faction)
	assert_eq(browser.spearheads.list.item_count, faction.spearheads.size())


func test_first_spearhead_is_rendered() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	browser.show_faction(faction)
	assert_eq(browser.spearheads.detail.text, RulesFormatter.spearhead(faction.spearheads[0]))


func test_path_to_glory_list_has_item_per_section() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	browser.show_faction(faction)
	assert_eq(browser.path_to_glory.list.item_count, faction.path_to_glory.size())


func test_selecting_path_to_glory_section_renders_it() -> void:
	var browser := _make_browser()
	var faction := _fixture()
	browser.show_faction(faction)
	var last := faction.path_to_glory.size() - 1
	browser.path_to_glory.select(last)
	assert_eq(browser.path_to_glory.detail.text, RulesFormatter.rules_section(faction.path_to_glory[last]))


func test_empty_faction_leaves_lists_empty() -> void:
	var browser := _make_browser()
	var faction := Faction.new()
	faction.name = "Empty"
	browser.show_faction(faction)
	assert_eq([browser.warscrolls.list.item_count, browser.armies_of_renown.list.item_count,
			browser.regiments_of_renown.list.item_count, browser.spearheads.list.item_count,
			browser.path_to_glory.list.item_count], [0, 0, 0, 0, 0])


func test_every_tab_has_a_title() -> void:
	var browser := _make_browser()
	for i in browser.tabs.get_tab_count():
		assert_ne(browser.tabs.get_tab_title(i), "", "tab %d has no title" % i)


func test_tab_titles_are_unique() -> void:
	var browser := _make_browser()
	var seen := {}
	for i in browser.tabs.get_tab_count():
		var tab_title := browser.tabs.get_tab_title(i)
		assert_false(seen.has(tab_title), "%s is used by two tabs" % tab_title)
		seen[tab_title] = true


func test_back_button_has_focus_on_ready() -> void:
	var browser := _make_browser()
	assert_true(browser.back_button.has_focus())


func test_back_button_emits_back_pressed() -> void:
	var browser := _make_browser()
	browser.back_button.pressed.emit()
	assert_signal_emitted(browser, "back_pressed")


func test_cancel_emits_back_pressed() -> void:
	var browser := _make_browser()
	_press_cancel(browser)
	assert_signal_emitted(browser, "back_pressed")


func test_released_cancel_does_nothing() -> void:
	var browser := _make_browser()
	_press_cancel(browser, false)
	assert_signal_not_emitted(browser, "back_pressed")
