class_name UIBuilder
extends RefCounted
## Small helpers for building the game's controls in code.


static func label(text: String, variation := "", wrap := false) -> Label:
	var node := Label.new()
	node.text = text
	node.theme_type_variation = variation
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


## The first node under [param node], depth first, for which [param matches] returns true, or null.
static func find_descendant(node: Node, matches: Callable) -> Node:
	for child in node.get_children():
		if matches.call(child):
			return child
		var found := find_descendant(child, matches)
		if found:
			return found
	return null


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
	node.icon = UITheme.icon(icon_name)
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
	if on_pressed.is_valid():
		var node := button(initials(unit_name), on_pressed, "", "PortraitButton", tooltip)
		node.accessibility_name = tooltip
		node.custom_minimum_size = Vector2(size, size)
		node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var stripes := ArtPlaceholder.new(6)
		stripes.show_behind_parent = true
		stripes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		node.add_child(stripes)
		return node
	var node := art(initials(unit_name), 6, 12)
	node.custom_minimum_size = Vector2(size, size)
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return node


## Up to two capital initials of [param title], e.g. "LE" for "Lord-Exorcist".
static func initials(title: String) -> String:
	var result := ""
	for word in title.replace("-", " ").split(" ", false):
		if result.length() < 2 and word[0] != word[0].to_lower():
			result += word[0]
	return result


## Striped placeholder art with [param text] in the middle, e.g. an army's initials.
static func art(text: String, corner_radius := 8, font_size := 14) -> ArtPlaceholder:
	var node := ArtPlaceholder.new(corner_radius)
	var caption := label(text, "ArtLabel")
	caption.add_theme_font_size_override("font_size", font_size)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.add_child(caption)
	return node


## Striped placeholder art with [param texture] in the middle at [param icon_size] pixels, e.g. a
## faction's icon.
static func icon_art(texture: Texture2D, icon_size: int, corner_radius := 8) -> ArtPlaceholder:
	var node := ArtPlaceholder.new(corner_radius)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.modulate = UITheme.TEXT
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	icon.grow_vertical = Control.GROW_DIRECTION_BOTH
	node.add_child(icon)
	return node


## The steps of a flow, e.g. "Order › Stormcast Eternals › Army of Renown", with the step at
## [param current] in bold.
static func breadcrumb(steps: PackedStringArray, current: int) -> HBoxContainer:
	var row := hbox([], 10)
	row.accessibility_name = "Forge steps"
	for i in steps.size():
		if i > 0:
			row.add_child(label("›", "BreadcrumbLabel"))
		row.add_child(label(steps[i], "BreadcrumbCurrentLabel" if i == current else "BreadcrumbLabel"))
	return row


## A full-width button that folds a section: a chevron, [param text] and, if not empty,
## [param count] on the right.
static func banner(text: String, count: String, open: bool, on_pressed: Callable, key: String,
		variation := "BannerButton") -> Button:
	var node := button(text, on_pressed, key, variation, ("Fold " if open else "Unfold ") + text)
	node.icon = UITheme.icon("chevron_down" if open else "chevron_right")
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


## The gold check a selected card shows in its corner.
static func check_badge() -> PanelContainer:
	var check := TextureRect.new()
	check.texture = UITheme.icon("check")
	check.modulate = Color("#17140C")
	check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check.custom_minimum_size = Vector2(14, 14)
	var badge := panel("", check)
	badge.add_theme_stylebox_override("panel", UITheme.box(UITheme.GOLD, Color.TRANSPARENT, 12, 5))
	return badge


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


## A setting that's on or off: [param title] and [param description] beside a switch, which calls
## [param on_toggled] with whether it's on.
static func switch_row(title: String, description: String, on: bool, on_toggled: Callable, key: String) -> PanelContainer:
	var check := CheckButton.new()
	check.button_pressed = on
	check.accessibility_name = title
	check.set_meta(&"focus_key", key)
	check.toggled.connect(on_toggled)
	var text := vbox([label(title, "CardTitleLabel"), label(description, "MutedLabel", true)], 4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel("RowPanel", hbox([text, check], 16))


## A setting: [param title] above [param control], with [param note] below if it isn't empty.
static func setting_row(title: String, control: Control, note := "") -> PanelContainer:
	var box := vbox([label(title, "CardTitleLabel"), control], 8)
	if not note.is_empty():
		box.add_child(label(note, "MutedLabel", true))
	return panel("RowPanel", box)


## The warscroll's Scourge or Legends tags.
static func tags(warscroll: Warscroll) -> Array[Control]:
	var result: Array[Control] = []
	var scourge := scourge_tag(warscroll.source)
	if scourge:
		result.append(scourge)
	if warscroll.legends:
		result.append(UITheme.chip("Legends", "legends"))
	return result


## A "SoA" or "SoG" tag for rules from Scourge of Aqshy or Scourge of Ghyran, with the full name as
## its tooltip, or null for any other [param source].
static func scourge_tag(source: String) -> Control:
	if not source.begins_with("Scourge of"):
		return null
	var tag := UITheme.chip("SoA" if source.ends_with("Aqshy") else "SoG", source)
	tag.tooltip_text = source
	return tag
