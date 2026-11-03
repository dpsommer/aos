class_name ArmyHeading
extends VBoxContainer
## The army select detail pane's heading: the army's or Spearhead's name, with anything added to its
## title row (e.g. a status pill) just after it, then a subtitle and the points. The name keeps its
## own width so what follows it stays beside it, and wraps only when the row is too narrow for it,
## e.g. a long name with the UI scaled up ([constant GameSettings.MIN_UI_SIZE]).

var _title: Label
var _title_row: HBoxContainer


## A heading for [param title], [param subtitle] and, if not empty, [param points].
static func create(title: String, subtitle: String, points := "") -> ArmyHeading:
	var heading: ArmyHeading = load("res://scenes/ui/quick_play/army_heading.tscn").instantiate()
	heading._title.text = title
	(heading.get_node(^"%Subtitle") as Label).text = subtitle
	if not points.is_empty():
		var label: Label = heading.get_node(^"%Points")
		label.text = points
		label.visible = true
	return heading


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_title = get_node(^"%Title")
		_title_row = get_node(^"%TitleRow")
	elif what == NOTIFICATION_RESIZED:
		_fit_title()


## The width the title takes unwrapped.
func title_width() -> float:
	var font := _title.get_theme_font(&"font")
	var font_size := _title.get_theme_font_size(&"font_size")
	return font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Gives the title its unwrapped width, or as much of the row as the rest of it leaves.
func _fit_title() -> void:
	var others := 0.0
	var shown := 0
	for child: Control in _title_row.get_children():
		if child.visible:
			shown += 1
			if child != _title:
				others += child.get_combined_minimum_size().x
	others += _title_row.get_theme_constant(&"separation") * maxi(shown - 1, 0)
	_title.custom_minimum_size.x = ceilf(minf(title_width(), maxf(size.x - others, 0.0)))
