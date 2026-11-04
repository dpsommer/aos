extends GutTest
## Unit tests for UIBuilder.portrait: a unit's render when it has one, its initials when it hasn't.
## Run against the fixture models in test/fixtures/models/ and portraits in test/fixtures/portraits/.

const ModelKit := preload("res://test/support/model_kit.gd")

## Has a model and a portrait in the fixtures.
const WITH_ART := "Plain Guard"
## Has a model but no portrait.
const BAKED_NOT := "Test Shrine"
const WITHOUT_MODEL := "Lord Imperatant"


func before_each() -> void:
	UnitPortraits.use(UnitPortraits.new(ModelKit.library(), "res://test/fixtures/portraits"))


func after_each() -> void:
	UnitPortraits.end()
	await get_tree().process_frame


func _button(unit_name: String, art_name := "") -> Button:
	var node := UIBuilder.portrait(unit_name, func() -> void: pass, "Show it", 40, art_name) as Button
	autofree(node)
	return node


func _plain(unit_name: String, art_name := "") -> ArtPlaceholder:
	var node := UIBuilder.portrait(unit_name, Callable(), "", 40, art_name) as ArtPlaceholder
	autofree(node)
	return node


func _art(node: Control) -> ArtPlaceholder:
	return node.get_node(^"%Stripes") if node is Button else node


func _icon(node: Control) -> TextureRect:
	return _art(node).get_node(^"%Icon")


func _caption(node: Control) -> Label:
	return _art(node).get_node(^"%Caption")


func _colour(rect: TextureRect) -> Color:
	return rect.texture.get_image().get_pixel(0, 0)


# a button

func test_button_with_a_render_shows_it() -> void:
	var icon := _icon(_button(WITH_ART))
	assert_true(icon.visible)
	assert_eq(_colour(icon), Color.RED)


func test_button_with_a_render_has_no_initials() -> void:
	var node := _button(WITH_ART)
	assert_eq(node.text, "")
	assert_false(_caption(node).visible)


func test_button_without_a_model_shows_initials_and_no_render() -> void:
	var node := _button(WITHOUT_MODEL)
	assert_eq(node.text, "LI")
	assert_false(_icon(node).visible)
	assert_null(_icon(node).texture)


func test_button_with_an_unbaked_model_shows_initials() -> void:
	var node := _button(BAKED_NOT)
	assert_eq(node.text, "TS")
	assert_false(_icon(node).visible)


func test_button_with_a_render_keeps_its_tooltip() -> void:
	assert_eq(_button(WITH_ART).tooltip_text, "Show it")


func test_button_with_a_render_keeps_its_accessible_name() -> void:
	assert_eq(_button(WITH_ART).accessibility_name, "Show it")


func test_button_with_a_render_still_calls_back_when_pressed() -> void:
	var calls := []
	var node := UIBuilder.portrait(WITH_ART, func() -> void: calls.append(1), "x") as Button
	autofree(node)
	node.pressed.emit()
	assert_eq(calls.size(), 1)


func test_button_art_name_finds_the_render_for_a_renamed_unit() -> void:
	var icon := _icon(_button("My Favourite Boys", WITH_ART))
	assert_true(icon.visible)
	assert_eq(_colour(icon), Color.RED)


func test_button_art_name_that_has_no_art_shows_the_unit_names_initials() -> void:
	var node := _button(WITH_ART, WITHOUT_MODEL)
	assert_eq(node.text, "PG")
	assert_false(_icon(node).visible)


func test_button_looks_up_the_unit_name_when_art_name_is_empty() -> void:
	assert_true(_icon(_button(WITH_ART, "")).visible)


# not a button

func test_plain_portrait_with_a_render_shows_it() -> void:
	var icon := _icon(_plain(WITH_ART))
	assert_true(icon.visible)
	assert_eq(_colour(icon), Color.RED)


func test_plain_portrait_with_a_render_has_no_initials() -> void:
	assert_false(_caption(_plain(WITH_ART)).visible)


func test_plain_portrait_without_a_model_shows_initials_and_no_render() -> void:
	var node := _plain(WITHOUT_MODEL)
	assert_true(_caption(node).visible)
	assert_eq(_caption(node).text, "LI")
	assert_false(_icon(node).visible)


func test_plain_portrait_art_name_finds_the_render_for_a_renamed_unit() -> void:
	var icon := _icon(_plain("My Favourite Boys", WITH_ART))
	assert_true(icon.visible)
	assert_eq(_colour(icon), Color.RED)


func test_plain_portrait_art_name_that_has_no_art_shows_the_unit_names_initials() -> void:
	var node := _plain(WITH_ART, WITHOUT_MODEL)
	assert_eq(_caption(node).text, "PG")
	assert_false(_icon(node).visible)


func test_plain_portrait_has_the_given_size_with_a_render() -> void:
	assert_eq(_plain(WITH_ART).custom_minimum_size, Vector2(40, 40))
