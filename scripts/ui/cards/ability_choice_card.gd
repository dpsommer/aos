class_name AbilityChoiceCard
extends AbilityCard
## An ability to choose, e.g. a Forge enhancement or a Spearhead regiment ability. It shows only its
## header and name until the eye at the right of its header shows it in full. The whole card is a
## button: pressing it emits [signal pressed]. While [member selected] it has a gold outline, as
## when it has keyboard focus, and a check left of the eye.

## Emitted when the card is clicked, or Enter or Space is pressed while it has focus.
signal pressed
## Emitted when the eye shows the card in full ([param open]) or folds it again.
signal eye_toggled(open: bool)

const OUTLINE_WIDTH := 3
## The outline while hovered, light enough to show on any ability colour.
const HOVER_COLOUR := Color(1, 1, 1, 0.35)

## Whether the card is chosen: it shows the check and the gold outline.
var selected := false:
	set(value):
		selected = value
		_check.modulate.a = 1.0 if value else 0.0
		tooltip_text = ("Unchoose %s" if value else "Choose %s") % ability.name
		accessibility_description = ("Chosen. " if value else "") + AbilityCard.header(ability)
		queue_redraw()
## The eye that shows the card in full or folds it.
var eye: Button
var _check: Control
var _hovered := false


## [param open] shows the card in full. [param key] is the eye's focus key.
func _init(rule: Ability, open := false, key := "") -> void:
	super(rule)
	set_folded(not open)
	var check := UIBuilder.check_badge()
	add_header_control(check)
	eye = UIBuilder.icon_button("eye", "", func() -> void: pass, key, "SmallIconButton")
	eye.toggle_mode = true
	eye.button_pressed = open
	_label_eye()
	eye.toggled.connect(func(on: bool) -> void:
		set_folded(not on)
		_label_eye()
		eye_toggled.emit(on))
	add_header_control(eye)
	_check = check
	selected = false
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_ignore_mouse(get_child(0))
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Adds [param control] to the header, before the check and the eye, e.g. a chip.
func add_header_control(control: Control) -> void:
	super(control)
	if _check:
		_header.move_child(control, _check.get_index())


func _label_eye() -> void:
	eye.tooltip_text = ("Hide %s rules" if eye.button_pressed else "Show %s rules") % ability.name
	eye.accessibility_name = eye.tooltip_text


## Lets clicks through to the card, except on buttons such as the eye.
static func _ignore_mouse(node: Node) -> void:
	if node is BaseButton:
		return
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _gui_input(event: InputEvent) -> void:
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
	var colour := Color.TRANSPARENT
	if selected or shows_focus():
		colour = UITheme.GOLD
	elif _hovered:
		colour = HOVER_COLOUR
	if colour.a > 0:
		draw_style_box(UITheme.box(Color.TRANSPARENT, colour, 8, 0, OUTLINE_WIDTH), Rect2(Vector2.ZERO, size))
