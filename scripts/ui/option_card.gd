class_name OptionCard
extends Button
## A large button holding any controls, e.g. a choice of Grand Alliance or Army of Renown. It sizes
## itself to fit [member content], and in toggle mode it shows as selected while pressed.

const PADDING := 20

## Holds the card's controls. Add them with [method add].
var content := VBoxContainer.new()
## The card is at least this tall, even if its content is shorter.
var min_height := 0:
	set(value):
		min_height = value
		_fit_content()


func _init() -> void:
	theme_type_variation = "OptionCard"
	content.add_theme_constant_override("separation", 12)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, PADDING)
	content.minimum_size_changed.connect(_fit_content)
	add_child(content)


## Adds [param control] to the card. Mouse events on it go to the card.
func add(control: Control) -> Control:
	_ignore_mouse(control)
	content.add_child(control)
	return control


func _fit_content() -> void:
	custom_minimum_size.y = maxf(min_height, content.get_combined_minimum_size().y + PADDING * 2)


static func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_ignore_mouse(child)
