class_name BuilderUI
extends RefCounted
## Small helpers for building the army builder's controls in code.


static func label(text: String, variation := "", wrap := false) -> Label:
	var node := Label.new()
	node.text = text
	node.theme_type_variation = variation
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


## A button whose [param key] lets the builder give it focus back after redrawing.
static func button(text: String, on_pressed: Callable, key := "", variation := "", tooltip := "") -> Button:
	var node := Button.new()
	node.text = text
	node.theme_type_variation = variation
	node.tooltip_text = tooltip
	node.pressed.connect(on_pressed)
	if not key.is_empty():
		node.set_meta(&"focus_key", key)
	return node


## A button showing only [param icon_name] from assets/2d/icons. [param label] is its tooltip and
## the name screen readers announce.
static func icon_button(icon_name: String, label: String, on_pressed: Callable, key: String, variation := "IconButton") -> Button:
	var node := button("", on_pressed, key, variation, label)
	node.icon = ForgeTheme.icon(icon_name)
	node.accessibility_name = label
	node.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node


## An icon button that stays pressed while [param on] is true.
static func icon_toggle(icon_name: String, label: String, on: bool, on_toggled: Callable, key: String) -> Button:
	var node := icon_button(icon_name, label, func() -> void: pass, key)
	node.toggle_mode = true
	node.button_pressed = on
	node.toggled.connect(on_toggled)
	return node


static func toggle(text: String, on: bool, on_toggled: Callable, key: String, tooltip := "") -> Button:
	var node := button(text, func() -> void: pass, key, "IconButton", tooltip)
	node.toggle_mode = true
	node.button_pressed = on
	node.toggled.connect(on_toggled)
	return node


static func hbox(children: Array = [], separation := -1) -> HBoxContainer:
	var box := HBoxContainer.new()
	if separation >= 0:
		box.add_theme_constant_override("separation", separation)
	for child: Control in children:
		box.add_child(child)
	return box


static func vbox(children: Array = [], separation := -1) -> VBoxContainer:
	var box := VBoxContainer.new()
	if separation >= 0:
		box.add_theme_constant_override("separation", separation)
	for child: Control in children:
		box.add_child(child)
	return box


static func panel(variation: String, child: Control) -> PanelContainer:
	var node := PanelContainer.new()
	node.theme_type_variation = variation
	node.add_child(child)
	return node


static func spacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


## A square showing a unit's initials, standing in for its portrait. With [param on_pressed] it's a
## button, e.g. to show the unit in the info pane, and [param tooltip] names what it does.
static func portrait(unit_name: String, on_pressed := Callable(), tooltip := "", size := 40) -> Control:
	var initials := ""
	for word in unit_name.replace("-", " ").split(" ", false):
		if initials.length() < 2 and word[0] != word[0].to_lower():
			initials += word[0]
	if on_pressed.is_valid():
		var node := button(initials, on_pressed, "", "PortraitButton", tooltip)
		node.accessibility_name = tooltip
		node.custom_minimum_size = Vector2(size, size)
		node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return node
	var text := label(initials, "MutedLabel")
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var node := panel("", text)
	node.add_theme_stylebox_override("panel", ForgeTheme.box(Color("#252930"), Color("#343A45"), 6))
	node.custom_minimum_size = Vector2(size, size)
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return node


## A full-width button that folds a section: a chevron, [param text] and, if not empty,
## [param count] on the right.
static func banner(text: String, count: String, open: bool, on_pressed: Callable, key: String,
		variation := "BannerButton") -> Button:
	var node := button(text, on_pressed, key, variation, ("Fold " if open else "Unfold ") + text)
	node.icon = ForgeTheme.icon("chevron_down" if open else "chevron_right")
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.accessibility_name = text
	node.accessibility_description = "Expanded" if open else "Collapsed"
	if not count.is_empty():
		var tally := label(count, "MutedLabel")
		tally.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
		tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(tally)
	return node


## Rules text in BBCode, sized to fit.
static func rich(bbcode: String) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.text = bbcode
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return text


## An option list; [param items] are [text, value] pairs. Calls [param on_selected] with the value.
static func select(items: Array, selected: Variant, on_selected: Callable, key: String, tooltip := "") -> OptionButton:
	var node := OptionButton.new()
	node.tooltip_text = tooltip
	node.set_meta(&"focus_key", key)
	for i in items.size():
		node.add_item(items[i][0], i)
		node.set_item_metadata(i, items[i][1])
		if items[i][1] == selected:
			node.select(i)
	node.item_selected.connect(func(index: int) -> void: on_selected.call(node.get_item_metadata(index)))
	return node


## The warscroll's Scourge or Legends tags.
static func tags(warscroll: Warscroll) -> Array[Control]:
	var result: Array[Control] = []
	if warscroll.source.begins_with("Scourge of"):
		result.append(ForgeTheme.chip("SoA" if warscroll.source.ends_with("Aqshy") else "SoG", warscroll.source))
	if warscroll.legends:
		result.append(ForgeTheme.chip("Legends", "legends"))
	return result
