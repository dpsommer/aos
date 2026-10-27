extends GutTest
## Unit tests for the builder's theme and control helpers (ui_theme.gd and ui_builder.gd).

const Kit := preload("res://test/support/army_kit.gd")
const UIKit := preload("res://test/support/ui_kit.gd")


func after_each() -> void:
	await get_tree().process_frame


func _chip(text: String, kind := "") -> PanelContainer:
	var node := UITheme.chip(text, kind)
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


func test_chip_text_contrasts_strongly_with_its_background() -> void:
	for kind: String in UITheme.CHIPS:
		var colours: Array = UITheme.CHIPS[kind]
		assert_gte(UITheme.contrast(colours[1], colours[0]), UITheme.CHIP_MIN_CONTRAST, kind)


func test_contrast_of_black_on_white_is_the_maximum() -> void:
	assert_almost_eq(UITheme.contrast(Color.BLACK, Color.WHITE), 21.0, 0.01)
	assert_almost_eq(UITheme.contrast(Color.WHITE, Color.BLACK), 21.0, 0.01)


func test_contrast_of_a_colour_with_itself_is_none() -> void:
	assert_almost_eq(UITheme.contrast(UITheme.GOLD, UITheme.GOLD), 1.0, 0.001)


func test_theme_is_created_once() -> void:
	assert_same(UITheme.get_theme(), UITheme.get_theme())


func test_box_without_a_border_has_no_border_width() -> void:
	assert_eq(UITheme.box(Color.RED, Color.TRANSPARENT).border_width_left, 0)


func test_select_calls_back_with_the_item_metadata() -> void:
	var picked := []
	var node := UIBuilder.select([["None", ""], ["Fire", "fire_id"]], "", func(value: String) -> void: picked.append(value), "k")
	autofree(node)
	node.item_selected.emit(1)
	assert_eq(picked, ["fire_id"])


func test_select_preselects_the_matching_value() -> void:
	var node := UIBuilder.select([["None", ""], ["Fire", "fire_id"]], "fire_id", func(_v: String) -> void: pass, "k")
	autofree(node)
	assert_eq(node.get_selected_metadata(), "fire_id")


func test_select_is_tagged_with_its_focus_key() -> void:
	var node := UIBuilder.select([["None", ""]], "", func(_v: String) -> void: pass, "lore:spell")
	autofree(node)
	assert_eq(node.get_meta(&"focus_key"), "lore:spell")


func test_button_without_a_key_has_no_focus_key() -> void:
	var node := UIBuilder.button("x", func() -> void: pass)
	autofree(node)
	assert_false(node.has_meta(&"focus_key"))


func test_button_with_a_key_has_a_focus_key() -> void:
	var node := UIBuilder.button("x", func() -> void: pass, "k")
	autofree(node)
	assert_eq(node.get_meta(&"focus_key"), "k")


func test_icon_button_has_its_tooltip_as_accessible_name_and_no_text() -> void:
	var node := UIBuilder.icon_button("delete", "Remove unit", func() -> void: pass, "k")
	autofree(node)
	assert_eq(node.text, "")
	assert_eq(node.tooltip_text, "Remove unit")
	assert_eq(node.accessibility_name, "Remove unit")


func test_icon_toggle_starts_in_the_given_state_without_toggling() -> void:
	var calls := []
	var node := UIBuilder.icon_toggle("crown", "Make general", true, func(_on: bool) -> void: calls.append(1), "k")
	autofree(node)
	assert_true(node.button_pressed)
	assert_true(node.toggle_mode)
	assert_eq(calls.size(), 0)


func test_portrait_uses_capital_initials() -> void:
	var node := UIBuilder.portrait("Lord Imperatant")
	autofree(node)
	assert_eq((node.get_child(0) as Label).text, "LI")


func test_portrait_ignores_lower_case_words() -> void:
	var node := UIBuilder.portrait("Knight of the Realm")
	autofree(node)
	assert_eq((node.get_child(0) as Label).text, "KR")


func test_tags_flag_legends_warscrolls() -> void:
	var scroll := Kit.warscroll("a")
	assert_eq(UIBuilder.tags(scroll).size(), 0)
	scroll.legends = true
	var tags := UIBuilder.tags(scroll)
	assert_eq(tags.size(), 1)
	for tag in tags:
		tag.free()


func test_tags_flag_scourge_warscrolls() -> void:
	var scroll := Kit.warscroll("a")
	scroll.source = "Scourge of Ghyran"
	var tags := UIBuilder.tags(scroll)
	assert_eq(tags.size(), 1)
	for tag in tags:
		tag.free()


func _scourge_text(source: String) -> String:
	var tag := UIBuilder.scourge_tag(source)
	autofree(tag)
	return (tag.get_child(0) as Label).text


func test_scourge_tag_abbreviates_scourge_of_ghyran() -> void:
	assert_eq(_scourge_text("Scourge of Ghyran"), "SOG")


func test_scourge_tag_abbreviates_scourge_of_aqshy() -> void:
	assert_eq(_scourge_text("Scourge of Aqshy"), "SOA")


func test_scourge_tag_names_the_expansion_in_its_tooltip() -> void:
	var tag := UIBuilder.scourge_tag("Scourge of Aqshy")
	autofree(tag)
	assert_eq(tag.tooltip_text, "Scourge of Aqshy")


func test_no_scourge_tag_for_other_sources() -> void:
	assert_null(UIBuilder.scourge_tag("White Dwarf"))
	assert_null(UIBuilder.scourge_tag(""))


# --- rules text ---

func test_rules_italics_slant_forwards() -> void:
	# FreeType reads the x axis's y component as a horizontal shear: positive leans the tops of
	# glyphs right. The y axis's x component tilts them the wrong way.
	var italic := UITheme.get_theme().get_font("italics_font", "RichTextLabel") as FontVariation
	assert_gt(italic.variation_transform.x.y, 0.0)
	assert_eq(italic.variation_transform.y.x, 0.0)


# --- portrait, banner, rich and small_icon ---

func test_portrait_with_a_callback_is_a_button_with_initials() -> void:
	var node := UIBuilder.portrait("Lord Imperatant", func() -> void: pass, "Show it")
	autofree(node)
	assert_true(node is Button)
	assert_eq((node as Button).text, "LI")
	assert_eq(node.theme_type_variation, "PortraitButton")
	assert_eq(node.tooltip_text, "Show it")


func test_portrait_button_calls_back_when_pressed() -> void:
	var calls := []
	var node := UIBuilder.portrait("Lord", func() -> void: calls.append(1), "x") as Button
	autofree(node)
	node.pressed.emit()
	assert_eq(calls.size(), 1)


func test_portrait_button_has_the_given_size() -> void:
	var node := UIBuilder.portrait("Lord", func() -> void: pass, "x", 64)
	autofree(node)
	assert_eq(node.custom_minimum_size, Vector2(64, 64))


func test_portrait_without_a_callback_is_not_a_button() -> void:
	var node := UIBuilder.portrait("Lord")
	autofree(node)
	assert_false(node is Button)


func _banner(open := true, count := "3", on_pressed := Callable()) -> Button:
	var node := UIBuilder.banner("Heroes", count, open, on_pressed if on_pressed.is_valid() else func() -> void: pass, "key:1")
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
	var node := UIBuilder.rich("[b]Bold[/b] text")
	autofree(node)
	assert_true(node.bbcode_enabled)
	assert_true(node.fit_content)
	assert_eq(node.get_parsed_text(), "Bold text")


func test_small_icon_is_drawn_at_the_icon_size() -> void:
	var texture := UITheme.small_icon("search")
	assert_eq(texture.get_size(), Vector2(UITheme.ICON_SIZE, UITheme.ICON_SIZE))


# --- UITheme.pill ---


func test_pill_kinds_have_different_backgrounds() -> void:
	var backgrounds := []
	for kind: String in UITheme.STATUS:
		var colour := UITheme.pill(kind).bg_color
		assert_does_not_have(backgrounds, colour, "%s looks like another kind" % kind)
		backgrounds.append(colour)


# --- UIBuilder.initials, art and breadcrumb ---


func test_initials_are_the_capitals_of_the_first_two_words() -> void:
	assert_eq(UIBuilder.initials("Stormcast Eternals"), "SE")
	assert_eq(UIBuilder.initials("Lord Exorcist Prime"), "LE")


func test_initials_split_hyphenated_names() -> void:
	assert_eq(UIBuilder.initials("Lord-Exorcist"), "LE")


func test_initials_skip_lower_case_words() -> void:
	assert_eq(UIBuilder.initials("Knights of Order"), "KO")


func test_initials_of_an_empty_title_are_empty() -> void:
	assert_eq(UIBuilder.initials(""), "")


func test_art_shows_the_text() -> void:
	var node := UIBuilder.art("AB")
	autofree(node)
	assert_has(UIKit.label_texts(node), "AB")


func test_art_lets_mouse_events_through() -> void:
	var node := UIBuilder.art("AB")
	autofree(node)
	assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_art_passes_its_size_to_the_shader_when_resized() -> void:
	var node := UIBuilder.art("AB")
	add_child_autofree(node)
	node.size = Vector2(120, 80)
	assert_eq((node.material as ShaderMaterial).get_shader_parameter("size"), Vector2(120, 80))


func test_breadcrumb_shows_every_step_in_order() -> void:
	var row := UIBuilder.breadcrumb(PackedStringArray(["One", "Two", "Three"]), 1)
	autofree(row)
	var texts := UIKit.label_texts(row)
	assert_eq(texts.size() - texts.count("›"), 3)
	assert_lt(texts.find("One"), texts.find("Two"))
	assert_lt(texts.find("Two"), texts.find("Three"))


func test_breadcrumb_marks_only_the_current_step() -> void:
	var row := UIBuilder.breadcrumb(PackedStringArray(["One", "Two", "Three"]), 1)
	autofree(row)
	var current := UIKit.labels_with_variation(row, "BreadcrumbCurrentLabel")
	assert_eq(current.size(), 1)
	assert_eq(current[0].text, "Two")


# --- OptionCard ---


func _card() -> OptionCard:
	var card := OptionCard.new()
	add_child_autofree(card)
	return card


func test_option_card_grows_to_fit_its_content() -> void:
	var card := _card()
	var short := Control.new()
	short.custom_minimum_size.y = 20
	card.add(short)
	await get_tree().process_frame
	var before := card.custom_minimum_size.y
	var tall := Control.new()
	tall.custom_minimum_size.y = 100
	card.add(tall)
	await get_tree().process_frame
	assert_gt(card.custom_minimum_size.y, before)
	assert_gte(card.custom_minimum_size.y, 120.0)


func test_option_card_honours_min_height_over_short_content() -> void:
	var card := _card()
	var content := Control.new()
	content.custom_minimum_size.y = 10
	card.add(content)
	card.min_height = 500
	assert_eq(card.custom_minimum_size.y, 500.0)


func test_option_card_content_taller_than_min_height_wins() -> void:
	var card := _card()
	card.min_height = 50
	var content := Control.new()
	content.custom_minimum_size.y = 300
	card.add(content)
	await get_tree().process_frame
	assert_gt(card.custom_minimum_size.y, 300.0)


func test_option_card_added_controls_ignore_the_mouse() -> void:
	var card := _card()
	var label := Label.new()
	card.add(label)
	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_option_card_added_controls_children_ignore_the_mouse() -> void:
	var card := _card()
	var box := VBoxContainer.new()
	var inner := Button.new()
	box.add_child(inner)
	card.add(box)
	assert_eq(inner.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_option_card_add_places_the_control_in_the_content() -> void:
	var card := _card()
	var label := Label.new()
	card.add(label)
	assert_eq(label.get_parent(), card.content)
