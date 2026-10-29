extends GutTest
## Unit tests for the setting rows in scripts/ui/common/ui_builder.gd (switch_row and setting_row).

const UIKit := preload("res://test/support/ui_kit.gd")


func _switch(on := false, on_toggled := func(_on: bool) -> void: pass) -> PanelContainer:
	var row := UIBuilder.switch_row("Title text", "Description text", on, on_toggled, "settings:thing")
	add_child_autofree(row)
	return row


func test_switch_row_shows_title_and_description() -> void:
	var row := _switch()
	assert_true(UIKit.has_label_containing(row, "Title text"))
	assert_true(UIKit.has_label_containing(row, "Description text"))


func test_switch_row_starts_in_the_given_state() -> void:
	assert_true((UIKit.keyed(_switch(true), "settings:thing") as CheckButton).button_pressed)
	assert_false((UIKit.keyed(_switch(false), "settings:thing") as CheckButton).button_pressed)


func test_switch_row_does_not_call_back_when_built() -> void:
	var calls := []
	_switch(true, func(on: bool) -> void: calls.append(on))
	assert_eq(calls.size(), 0)


func test_switch_row_calls_back_with_the_new_state() -> void:
	var calls := []
	var row := _switch(false, func(on: bool) -> void: calls.append(on))
	(UIKit.keyed(row, "settings:thing") as CheckButton).button_pressed = true
	assert_eq(calls, [true])


func test_switch_row_switch_is_named_for_screen_readers() -> void:
	var check := UIKit.keyed(_switch(), "settings:thing") as CheckButton
	assert_eq(check.accessibility_name, "Title text")


func test_setting_row_contains_the_control() -> void:
	var control := Button.new()
	var row := UIBuilder.setting_row("Title text", control)
	add_child_autofree(row)
	assert_true(row.is_ancestor_of(control))


func test_setting_row_shows_the_title() -> void:
	var row := UIBuilder.setting_row("Title text", Control.new())
	add_child_autofree(row)
	assert_true(UIKit.has_label_containing(row, "Title text"))


func test_setting_row_shows_the_note_when_given() -> void:
	var row := UIBuilder.setting_row("Title text", Control.new(), "Note text")
	add_child_autofree(row)
	assert_true(UIKit.has_label_containing(row, "Note text"))


func test_setting_row_without_a_note_has_only_the_title_label() -> void:
	var row := UIBuilder.setting_row("Title text", Control.new())
	add_child_autofree(row)
	assert_eq(UIKit.label_texts(row), PackedStringArray(["Title text"]))
