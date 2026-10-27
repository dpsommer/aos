extends GutTest
## Unit tests for the builder's theme and control helpers (forge_theme.gd and ui.gd).

const Kit := preload("res://test/support/army_kit.gd")


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
