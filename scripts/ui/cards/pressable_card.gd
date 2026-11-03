class_name PressableCard
extends PanelContainer
## A card in a [code]CardPanel[/code] box, e.g. a battle tactics card or a lore. It has a gold outline
## while it has keyboard focus, and can be made pressable with [method make_pressable].

## Emitted when a pressable card is clicked, or Enter or Space is pressed while it has focus.
signal pressed

## Whether the card emits [signal pressed] and outlines itself while hovered.
var pressable := false
var card_name := ""
## The card's rows, from its heading and name down. Cards add their own rows after
## [method _add_title].
var content: VBoxContainer:
	get:
		return get_node(^"%Content")
## The muted heading over the card's name, or null without one.
var heading_label: Label
var _hovered := false


## Adds the card's [member content] with its first rows: [param heading] (if not empty) over
## [param title], with [param tags] after the title. [param action], e.g. an eye or a "Change"
## button, goes in the top right corner: at the end of the heading's row, so the title has the
## card's full width, or of the title's row without a heading. Cards then add their own rows to
## [member content].
func _add_title(title: String, heading := "", tags: Array[Control] = [], action: Control = null) -> void:
	card_name = title
	var title_row: HBoxContainer = %TitleRow
	title_row.visible = true
	(%Title as Label).text = title
	if not heading.is_empty():
		heading_label = %Heading
		heading_label.text = heading
		%HeadingRow.visible = true
		if action:
			%HeadingRow.add_child(action)
	for tag in tags:
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(tag)
	if action and heading.is_empty():
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(action)


## Makes the whole card a button: focusable, and emitting [signal pressed] when clicked or when
## Enter or Space is pressed. [param description] is its tooltip and accessibility description.
## Buttons on the card, e.g. an eye to show it in full, still take their own clicks.
func make_pressable(description: String) -> void:
	pressable = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = description
	accessibility_name = card_name
	accessibility_description = description
	_ignore_mouse(get_child(0))


func _ignore_mouse(node: Node) -> void:
	if node is BaseButton:
		return
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _gui_input(event: InputEvent) -> void:
	if not pressable:
		return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action_pressed("ui_accept"):
		accept_event()
		pressed.emit()


func _set_hovered(on: bool) -> void:
	_hovered = on
	queue_redraw()


## Whether the card shows its focus outline: only for keyboard focus, as buttons do.
func shows_focus() -> bool:
	return has_focus(true)


func _draw() -> void:
	if shows_focus():
		draw_style_box(get_theme_stylebox("focus", "CardPanel"), Rect2(Vector2.ZERO, size))
	elif pressable and _hovered:
		draw_style_box(get_theme_stylebox("hover", "CardPanel"), Rect2(Vector2.ZERO, size))
