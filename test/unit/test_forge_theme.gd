extends GutTest
## Unit tests for the builder's theme and control helpers (forge_theme.gd and ui.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")


func after_each() -> void:
	await get_tree().process_frame


func _chip(text: String, kind := "") -> PanelContainer:
	var node := ForgeTheme.chip(text, kind)
	autofree(node)
	return node


func _chip_text_colour(chip: PanelContainer) -> Color:
	return (chip.get_child(0) as Label).get_theme_color("font_color")


func _chip_background(chip: PanelContainer) -> Color:
	return (chip.get_theme_stylebox("panel") as StyleBoxFlat).bg_color


func test_chip_text_is_upper_case() -> void:
	assert_eq(((_chip("Legends")).get_child(0) as Label).text, "LEGENDS")


func test_chip_kinds_have_different_colours() -> void:
	assert_ne(_chip_text_colour(_chip("x", "affray")), _chip_text_colour(_chip("x", "strike")))
	assert_ne(_chip_background(_chip("x", "legends")), _chip_background(_chip("x")))


func test_chip_with_an_unknown_kind_looks_like_the_default() -> void:
	assert_eq(_chip_text_colour(_chip("x", "no such kind")), _chip_text_colour(_chip("x")))
	assert_eq(_chip_background(_chip("x", "no such kind")), _chip_background(_chip("x")))


func test_every_battle_tactic_kind_has_its_own_chip_colour() -> void:
	for kind in BattleTactic.KINDS:
		assert_ne(_chip_background(_chip("x", kind)), _chip_background(_chip("x")), kind)


func test_theme_is_created_once() -> void:
	assert_same(ForgeTheme.get_theme(), ForgeTheme.get_theme())


func test_box_without_a_border_has_no_border_width() -> void:
	assert_eq(ForgeTheme.box(Color.RED, Color.TRANSPARENT).border_width_left, 0)


func test_select_calls_back_with_the_item_metadata() -> void:
	var picked := []
	var node := BuilderUI.select([["None", ""], ["Fire", "fire_id"]], "", func(value: String) -> void: picked.append(value), "k")
	autofree(node)
	node.item_selected.emit(1)
	assert_eq(picked, ["fire_id"])


func test_select_preselects_the_matching_value() -> void:
	var node := BuilderUI.select([["None", ""], ["Fire", "fire_id"]], "fire_id", func(_v: String) -> void: pass, "k")
	autofree(node)
	assert_eq(node.get_selected_metadata(), "fire_id")


func test_select_is_tagged_with_its_focus_key() -> void:
	var node := BuilderUI.select([["None", ""]], "", func(_v: String) -> void: pass, "lore:spell")
	autofree(node)
	assert_eq(node.get_meta(&"focus_key"), "lore:spell")


func test_button_without_a_key_has_no_focus_key() -> void:
	var node := BuilderUI.button("x", func() -> void: pass)
	autofree(node)
	assert_false(node.has_meta(&"focus_key"))


func test_button_with_a_key_has_a_focus_key() -> void:
	var node := BuilderUI.button("x", func() -> void: pass, "k")
	autofree(node)
	assert_eq(node.get_meta(&"focus_key"), "k")


func test_icon_button_has_its_tooltip_as_accessible_name_and_no_text() -> void:
	var node := BuilderUI.icon_button("delete", "Remove unit", func() -> void: pass, "k")
	autofree(node)
	assert_eq(node.text, "")
	assert_eq(node.tooltip_text, "Remove unit")
	assert_eq(node.accessibility_name, "Remove unit")


func test_icon_toggle_starts_in_the_given_state_without_toggling() -> void:
	var calls := []
	var node := BuilderUI.icon_toggle("crown", "Make general", true, func(_on: bool) -> void: calls.append(1), "k")
	autofree(node)
	assert_true(node.button_pressed)
	assert_true(node.toggle_mode)
	assert_eq(calls.size(), 0)


func test_portrait_uses_capital_initials() -> void:
	var node := BuilderUI.portrait("Lord Imperatant")
	autofree(node)
	assert_eq((node.get_child(0) as Label).text, "LI")


func test_portrait_ignores_lower_case_words() -> void:
	var node := BuilderUI.portrait("Knight of the Realm")
	autofree(node)
	assert_eq((node.get_child(0) as Label).text, "KR")


func test_tags_flag_legends_warscrolls() -> void:
	var scroll := Kit.warscroll("a")
	assert_eq(BuilderUI.tags(scroll).size(), 0)
	scroll.legends = true
	var tags := BuilderUI.tags(scroll)
	assert_eq(tags.size(), 1)
	for tag in tags:
		tag.free()


func test_tags_flag_scourge_warscrolls() -> void:
	var scroll := Kit.warscroll("a")
	scroll.source = "Scourge of Ghyran"
	var tags := BuilderUI.tags(scroll)
	assert_eq(tags.size(), 1)
	for tag in tags:
		tag.free()


# --- portrait, banner, rich and small_icon ---

func test_portrait_with_a_callback_is_a_button_with_initials() -> void:
	var node := BuilderUI.portrait("Lord Imperatant", func() -> void: pass, "Show it")
	autofree(node)
	assert_true(node is Button)
	assert_eq((node as Button).text, "LI")
	assert_eq(node.theme_type_variation, "PortraitButton")
	assert_eq(node.tooltip_text, "Show it")


func test_portrait_button_calls_back_when_pressed() -> void:
	var calls := []
	var node := BuilderUI.portrait("Lord", func() -> void: calls.append(1), "x") as Button
	autofree(node)
	node.pressed.emit()
	assert_eq(calls.size(), 1)


func test_portrait_button_has_the_given_size() -> void:
	var node := BuilderUI.portrait("Lord", func() -> void: pass, "x", 64)
	autofree(node)
	assert_eq(node.custom_minimum_size, Vector2(64, 64))


func test_portrait_without_a_callback_is_not_a_button() -> void:
	var node := BuilderUI.portrait("Lord")
	autofree(node)
	assert_false(node is Button)


func _banner(open := true, count := "3", on_pressed := Callable()) -> Button:
	var node := BuilderUI.banner("Heroes", count, open, on_pressed if on_pressed.is_valid() else func() -> void: pass, "key:1")
	autofree(node)
	return node


func test_banner_shows_its_text_and_key() -> void:
	var node := _banner()
	assert_eq(node.text, "Heroes")
	assert_eq(node.get_meta(&"focus_key"), "key:1")


func test_banner_shows_the_count() -> void:
	assert_true(UIKit.has_label_containing(_banner(true, "3"), "3"))


func test_banner_without_a_count_has_no_tally() -> void:
	assert_eq(_banner(true, "").get_child_count(), 0)


func test_banner_icon_differs_when_open_and_closed() -> void:
	assert_ne(_banner(true).icon, _banner(false).icon)


func test_banner_describes_its_state_for_screen_readers() -> void:
	assert_ne(_banner(true).accessibility_description, _banner(false).accessibility_description)


func test_banner_tooltip_says_what_pressing_does() -> void:
	assert_string_starts_with(_banner(true).tooltip_text, "Fold")
	assert_string_starts_with(_banner(false).tooltip_text, "Unfold")


func test_banner_calls_back_when_pressed() -> void:
	var calls := []
	var node := _banner(true, "", func() -> void: calls.append(1))
	node.pressed.emit()
	assert_eq(calls.size(), 1)


func test_rich_shows_bbcode_and_fits_its_content() -> void:
	var node := BuilderUI.rich("[b]Bold[/b] text")
	autofree(node)
	assert_true(node.bbcode_enabled)
	assert_true(node.fit_content)
	assert_eq(node.get_parsed_text(), "Bold text")


func test_small_icon_is_drawn_at_the_icon_size() -> void:
	var texture := ForgeTheme.small_icon("search")
	assert_eq(texture.get_size(), Vector2(ForgeTheme.ICON_SIZE, ForgeTheme.ICON_SIZE))
