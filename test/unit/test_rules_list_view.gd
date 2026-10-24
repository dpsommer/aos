extends GutTest
## Unit tests for the list-and-detail rules panel (scripts/ui/forge/rules_list_view.gd).

const RulesListViewScene := preload("res://scenes/ui/forge/rules_list_view.tscn")


func _make_view() -> RulesListView:
	var view: RulesListView = RulesListViewScene.instantiate()
	add_child_autofree(view)
	return view


func _labels() -> PackedStringArray:
	return PackedStringArray(["First entry", "Second entry", "Third entry"])


## Renders an entry as text that identifies its index.
func _render(index: int) -> String:
	return "Detail for entry %d" % index


func test_populate_adds_one_item_per_label() -> void:
	var view := _make_view()
	view.populate(_labels(), _render)
	assert_eq(view.list.item_count, _labels().size())


func test_populate_uses_labels_as_item_text() -> void:
	var view := _make_view()
	var labels := _labels()
	view.populate(labels, _render)
	for i in labels.size():
		assert_eq(view.list.get_item_text(i), labels[i])


func test_populate_selects_first_item() -> void:
	var view := _make_view()
	view.populate(_labels(), _render)
	assert_eq(view.list.get_selected_items(), PackedInt32Array([0]))


func test_populate_renders_first_item() -> void:
	var view := _make_view()
	view.populate(_labels(), _render)
	assert_eq(view.detail.text, _render(0))


func test_populate_twice_replaces_items() -> void:
	var view := _make_view()
	view.populate(_labels(), _render)
	var fewer := PackedStringArray(["Only entry"])
	view.populate(fewer, _render)
	assert_eq(view.list.item_count, fewer.size())


func test_populate_with_no_labels_clears_detail() -> void:
	var view := _make_view()
	view.populate(_labels(), _render)
	view.populate(PackedStringArray(), _render)
	assert_eq(view.detail.text, "")


func test_populate_with_no_labels_does_not_render() -> void:
	var view := _make_view()
	var calls := []
	view.populate(PackedStringArray(), func(i: int) -> String:
		calls.append(i)
		return "")
	assert_eq(calls.size(), 0)


func test_select_renders_that_entry() -> void:
	var view := _make_view()
	view.populate(_labels(), _render)
	var last := _labels().size() - 1
	view.select(last)
	assert_eq(view.detail.text, _render(last))


func test_select_highlights_that_item() -> void:
	var view := _make_view()
	view.populate(_labels(), _render)
	var last := _labels().size() - 1
	view.select(last)
	assert_eq(view.list.get_selected_items(), PackedInt32Array([last]))


func test_clicking_list_item_renders_that_entry() -> void:
	var view := _make_view()
	view.populate(_labels(), _render)
	view.list.item_selected.emit(1)
	assert_eq(view.detail.text, _render(1))
