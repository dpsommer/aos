class_name OptionCard
extends Button
## A large button holding any controls, e.g. a choice of Grand Alliance or Army of Renown. It sizes
## itself to fit [member content], and in toggle mode it shows as selected while pressed.

const PADDING := 20

## Holds the card's controls. Add them with [method add].
var content: VBoxContainer:
	get:
		return get_node(^"%Content")
## The card is at least this tall, even if its content is shorter.
var min_height := 0:
	set(value):
		min_height = value
		_fit_content()


static func create() -> OptionCard:
	return load("res://scenes/ui/common/option_card.tscn").instantiate()


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
