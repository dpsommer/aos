class_name TacticCard
extends PanelContainer
## A battle tactics card: in full, with each battle tactic's condition and victory points, or as a
## short summary of its battle tactics' names for the army list. It has a gold outline while it has
## keyboard focus, and can be made pressable with [method make_pressable].

## Emitted when a pressable card is clicked, or Enter or Space is pressed while it has focus.
signal pressed

const KIND_NAMES := {"affray": "Affray", "strike": "Strike", "domination": "Domination"}

## Whether the card emits [signal pressed] and outlines itself while hovered.
var pressable := false
var card_name := ""
var _hovered := false


## [param action] is shown beside the card's name, e.g. a "Change" button or a chip, or null for
## none.
func _init(card: BattleTacticCard, full: bool, heading := "", action: Control = null) -> void:
	theme_type_variation = "CardPanel"
	card_name = card.name
	var content := UIBuilder.vbox([], 8)
	if not heading.is_empty():
		content.add_child(UIBuilder.label(heading, "MutedLabel"))
	var title := UIBuilder.label(card.name, "TitleLabel", true)
	content.add_child(UIBuilder.hbox([title, action] if action else [title]))
	if full:
		if not card.text.is_empty():
			content.add_child(UIBuilder.label(card.text, "MutedLabel", true))
		for tactic in card.tactics:
			var name_row := UIBuilder.hbox([UITheme.chip(KIND_NAMES.get(tactic.kind, tactic.kind), tactic.kind),
					UIBuilder.label(tactic.name), UIBuilder.spacer(), UIBuilder.label("%d VP" % tactic.victory_points, "MutedLabel")])
			content.add_child(UIBuilder.vbox([name_row, UIBuilder.label(tactic.condition, "MutedLabel", true)], 4))
		for faq in card.faqs:
			content.add_child(UIBuilder.rich("[b]FAQ:[/b] %s\n[b]Answer:[/b] %s" % [
					str(faq.get("question", "")).replace("[", "[lb]"), str(faq.get("answer", "")).replace("[", "[lb]")]))
	else:
		var chips := HFlowContainer.new()
		for tactic in card.tactics:
			chips.add_child(UITheme.chip(tactic.name, tactic.kind))
		content.add_child(chips)
	add_child(content)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Makes the whole card a button: focusable, and emitting [signal pressed] when clicked or when
## Enter or Space is pressed. [param description] is its tooltip and accessibility description.
func make_pressable(description: String) -> void:
	pressable = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = description
	accessibility_name = card_name
	accessibility_description = description
	_ignore_mouse(get_child(0))


func _ignore_mouse(node: Node) -> void:
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
