class_name RulesListView
extends HSplitContainer
## A list of named entries beside a detail panel showing the selected entry's rules.

var _render: Callable

@onready var list: ItemList = %List
@onready var detail: RichTextLabel = %Detail


func _ready() -> void:
	list.item_selected.connect(_show)


## Shows one list item per label. [param render] takes an item index and returns its BBCode.
func populate(labels: PackedStringArray, render: Callable) -> void:
	_render = render
	list.clear()
	for label in labels:
		list.add_item(label)
	detail.text = ""
	if not labels.is_empty():
		select(0)


func select(index: int) -> void:
	list.select(index)
	_show(index)


func _show(index: int) -> void:
	detail.text = _render.call(index)
	detail.scroll_to_line(0)
