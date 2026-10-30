class_name RulesListView
extends HSplitContainer
## A list of named entries beside a scrolling detail panel showing the selected entry's rules.

var _render: Callable

@onready var list: ItemList = %List
@onready var scroll: ScrollContainer = %Scroll
## Holds the selected entry's rules.
@onready var detail: VBoxContainer = %Detail


func _ready() -> void:
	list.item_selected.connect(_show)


## Shows one list item per label. [param render] takes an item index and returns its rules as a
## [Control], e.g. from [RulesView].
func populate(labels: PackedStringArray, render: Callable) -> void:
	_render = render
	list.clear()
	for label in labels:
		list.add_item(label)
	_clear()
	if not labels.is_empty():
		select(0)


func select(index: int) -> void:
	list.select(index)
	list.ensure_current_is_visible()
	_show(index)


func _show(index: int) -> void:
	_clear()
	detail.add_child(_render.call(index))
	scroll.scroll_vertical = 0


func _clear() -> void:
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
