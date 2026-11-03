class_name InlineLine
extends Container
## A label with controls right after its text, such as a unit's name and its rename button, or
## its details and their tags. The label is cut short with an ellipsis when there isn't room for
## all of them.

## The gap between the label and the controls after it, and between those controls.
@export var separation := 4


func _init(gap := 4) -> void:
	separation = gap


func _get_minimum_size() -> Vector2:
	var result := Vector2.ZERO
	for child: Control in get_children():
		result.y = maxf(result.y, child.get_combined_minimum_size().y)
	for child in _trailing():
		result.x += child.get_combined_minimum_size().x + separation
	return result


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var heading := get_child(0) as Label
	var room := size.x
	for child in _trailing():
		room -= child.get_combined_minimum_size().x + separation
	var text_width := heading.get_theme_font("font").get_string_size(heading.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			heading.get_theme_font_size("font_size")).x + 1
	var x := clampf(text_width, 0, maxf(room, 0))
	fit_child_in_rect(heading, Rect2(0, 0, x, size.y))
	for child in _trailing():
		var child_size := child.get_combined_minimum_size()
		x += separation
		fit_child_in_rect(child, Rect2(x, (size.y - child_size.y) / 2, child_size.x, child_size.y))
		x += child_size.x


func _trailing() -> Array[Control]:
	var result: Array[Control] = []
	for child in get_children().slice(1):
		result.append(child as Control)
	return result
