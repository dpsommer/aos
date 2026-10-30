class_name InfoPane
extends VBoxContainer
## The army builder's left pane: a search box and tabs for the faction's roster, the army's rules,
## Regiments of Renown and the army's settings. See docs/design/forge.md.

const TABS := {"roster": "Roster", "rules": "Rules", "renown": "Regiments of Renown", "settings": "Army settings"}
const PLACEHOLDERS := {"roster": "Search units", "rules": "Search rules", "renown": "Search Regiments of Renown",
		"settings": "Search settings"}
## Roster sections and the keyword that puts a unit in each. A unit goes in the first that matches,
## or in "Other".
const UNIT_TYPES := [["Hero", "HERO"], ["Infantry", "INFANTRY"], ["Cavalry", "CAVALRY"], ["Monster", "MONSTER"],
		["War Machine", "WAR MACHINE"], ["Other", ""]]
## How long a card stays highlighted after a link to it.
const FLASH_SECONDS := 1.6
const POINTS_STEP := 250

## Where favourite units are kept, by faction id.
static var favourites_path := "user://forge.cfg"

var builder: ArmyBuilder
var tab := "roster"
var query := ""
## Keys of folded roster types ("type:") and rules sections ("sec:") and groups ("grp:").
var folded := {}
## Names of unfolded lores; lores start folded.
var open_lores := {}
## Key of the roster card showing its warscroll: a warscroll id, with "fav:" in front for a
## favourite. Empty for none.
var selected := ""
## Warscroll ids of the faction's favourite units, newest first.
var favourites := PackedStringArray()
## Info key of the card highlighted after a link to it, or empty.
var flash_key := ""
var search: LineEdit
## Tab buttons by tab.
var tab_buttons := {}
var _scroll: ScrollContainer
var _content: VBoxContainer
var _flash_timer: Timer
## Info key of the node to scroll to after the next refresh.
var _scroll_to := ""
## Frames to wait for the new content's layout before scrolling to [member _scroll_to].
var _scroll_wait := 0
## What the current content was drawn from, to skip redrawing when the army changes in ways it
## doesn't show.
var _drawn_from := ""


func _init(army_builder: ArmyBuilder) -> void:
	builder = army_builder
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)
	search = LineEdit.new()
	search.clear_button_enabled = true
	search.right_icon = UITheme.small_icon("search")
	search.set_meta(&"focus_key", "info:search")
	search.text_changed.connect(_on_search_changed)
	search.gui_input.connect(_on_search_input)
	add_child(search)

	var bar := UIBuilder.hbox([], 0)
	var group := ButtonGroup.new()
	for key: String in TABS:
		var button := UIBuilder.button(TABS[key], set_tab.bind(key), "info:tab:" + key, "TabButton")
		button.toggle_mode = true
		button.button_group = group
		if key == "settings":
			button.text = ""
			button.icon = UITheme.icon("settings")
			button.tooltip_text = TABS[key]
			button.accessibility_name = TABS[key]
			bar.add_child(UIBuilder.spacer())
		tab_buttons[key] = button
		bar.add_child(button)
	add_child(UIBuilder.panel("TabBarPanel", bar))

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 4)
	_content = UIBuilder.vbox([], 12)
	margin.add_child(_content)
	_scroll.add_child(margin)
	add_child(_scroll)

	_flash_timer = Timer.new()
	_flash_timer.one_shot = true
	_flash_timer.wait_time = FLASH_SECONDS
	_flash_timer.timeout.connect(_end_flash)
	add_child(_flash_timer)
	set_process(false)


## Loads the faction's favourites and shows the current tab.
func open() -> void:
	var config := ConfigFile.new()
	config.load(favourites_path)
	favourites = config.get_value("favourites", builder.catalog.faction.id, PackedStringArray())
	refresh()


func set_tab(key: String) -> void:
	tab = key
	refresh()


## Redraws the current tab from the army, keeping keyboard focus on the same control. Does nothing
## if nothing the tab shows has changed.
func refresh() -> void:
	if builder.editor == null:
		return
	var state := var_to_str(_state())
	if state == _drawn_from and _scroll_wait == 0:
		return
	_drawn_from = state
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var key: String = focused.get_meta(&"focus_key", "") if focused and is_ancestor_of(focused) else ""
	for key_name: String in tab_buttons:
		tab_buttons[key_name].set_pressed_no_signal(key_name == tab)
	search.placeholder_text = PLACEHOLDERS.get(tab, "Search")
	search.accessibility_name = search.placeholder_text
	if search.text != query:
		search.text = query
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	match tab:
		"roster":
			_roster()
		"rules":
			_rules()
		"renown":
			_renown()
		"settings":
			_settings()
	if not _scroll_to.is_empty():
		# Rules text sizes itself over the next frames.
		_scroll_wait = 2
		set_process(true)
	elif not key.is_empty() and (focused == null or not is_instance_valid(focused) or not focused.is_inside_tree()):
		var target := ArmyBuilder.find_focus_key(self, key)
		if target:
			target.grab_focus()


## Everything the current tab is drawn from.
func _state() -> Array:
	var army := builder.editor.army
	var state: Array = [tab, query, folded, flash_key, army.show_legends, army.override_constraints, army.army_of_renown]
	match tab:
		"roster":
			# Unique units in the army can't be added again.
			state.append_array([selected, favourites, builder.catalog.unique_unit_names(army)])
		"rules":
			state.append_array([open_lores, army.formation, army.tactics, army.spell_lore, army.prayer_lore,
					army.manifestation_lore])
		"renown":
			var regiments := PackedStringArray()
			for regiment in army.regiments:
				if regiment.is_regiment_of_renown():
					regiments.append(regiment.regiment_of_renown)
			var open := builder.expanded.keys().filter(func(key: String) -> bool: return key.begins_with("tab:"))
			state.append_array([regiments, open])
		"settings":
			state.append_array([army.points_limit, army.formation])
	return state


func _on_search_changed(text: String) -> void:
	query = text
	refresh()


func _on_search_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not query.is_empty():
		search.accept_event()
		clear_search()


func clear_search() -> void:
	query = ""
	search.text = ""
	refresh()


## The roster type a warscroll is listed under.
static func unit_type(warscroll: Warscroll) -> String:
	for type: Array in UNIT_TYPES:
		if type[1].is_empty() or warscroll.has_keyword(type[1]):
			return type[0]
	return "Other"


func _empty(text: String) -> void:
	var label := UIBuilder.label(text, "MutedLabel", true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(label)


func _roster() -> void:
	var army := builder.editor.army
	var query_words := RulesSearch.words(query)
	var hidden := 0
	var by_type := {}
	var by_id := {}
	for warscroll in builder.catalog.unit_warscrolls(army):
		if warscroll.legends and not army.show_legends:
			hidden += 1
			continue
		var type := unit_type(warscroll)
		if not RulesSearch.matches(RulesSearch.warscroll_text(warscroll) + " " + type, query_words):
			continue
		by_id[warscroll.id] = warscroll
		if not by_type.has(type):
			by_type[type] = []
		by_type[type].append(warscroll)
	var note := "Drag a unit into a regiment, or click it to see its warscroll."
	if hidden > 0:
		note += " %d Legends unit%s hidden." % [hidden, "" if hidden == 1 else "s"]
	_content.add_child(UIBuilder.label(note, "MutedLabel", true))

	var pinned: Array[Warscroll] = []
	for id in favourites:
		if by_id.has(id):
			pinned.append(by_id[id])
	if not pinned.is_empty():
		var title := UIBuilder.label("FAVOURITES", "FavouritesLabel")
		var heading := UIBuilder.hbox([TextureRect.new(), title], 8)
		var star: TextureRect = heading.get_child(0)
		star.texture = UITheme.icon("star_filled")
		star.modulate = UITheme.WARNING
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.custom_minimum_size = Vector2(16, 16)
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var section := UIBuilder.vbox([UIBuilder.panel("FavouritesPanel", heading)], 6)
		for warscroll in pinned:
			section.add_child(_unit_card(warscroll, true))
		_content.add_child(section)

	if by_id.is_empty() and not query_words.is_empty():
		_empty("Nothing matches “%s”." % query.strip_edges())
	for type: Array in UNIT_TYPES:
		var units: Array = by_type.get(type[0], [])
		if units.is_empty():
			continue
		var key: String = "type:" + type[0]
		var open := not query_words.is_empty() or not folded.has(key)
		var section := UIBuilder.vbox([UIBuilder.banner(type[0].to_upper(), str(units.size()), open, _toggle_fold.bind(key),
				"info:" + key)], 6)
		if open:
			for warscroll: Warscroll in units:
				section.add_child(_unit_card(warscroll, false))
		_content.add_child(section)


func _unit_card(warscroll: Warscroll, pinned: bool) -> PanelContainer:
	var key := ("fav:" if pinned else "") + warscroll.id
	var open := selected == key
	var flash := not pinned and flash_key == "unit:" + warscroll.id
	var card := PanelContainer.new()
	card.theme_type_variation = "FlashRowPanel" if flash else "PickedRowPanel" if open else "RowPanel"
	if not pinned:
		card.set_meta(&"info_key", "unit:" + warscroll.id)

	var title := UIBuilder.label(warscroll.name, "CardTitleLabel")
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var details := UIBuilder.hbox([UIBuilder.label("%d pts" % warscroll.points, "MutedLabel")], 6)
	for tag in UIBuilder.tags(warscroll):
		details.add_child(tag)
	var names := UIBuilder.vbox([title, details], 3)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	var face := UIBuilder.hbox([UIBuilder.portrait(warscroll.name, Callable(), "", 48), names], 12)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var toggle_card := func() -> void:
		selected = "" if selected == key else key
		refresh()
	var button := UIBuilder.button("", toggle_card, "info:card:" + key, "CardButton", ("Hide " if open else "Show ") + "warscroll")
	button.accessibility_name = warscroll.name
	button.custom_minimum_size.y = 52
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_child(face)
	_ignore_mouse(face)
	# The focus outline goes around the whole card, star included, not just the button.
	var unfocused := card.theme_type_variation
	button.focus_entered.connect(func() -> void:
		card.theme_type_variation = "FocusPickedRowPanel" if open else "FocusRowPanel")
	button.focus_exited.connect(func() -> void: card.theme_type_variation = unfocused)
	builder.drag.source(button, {"kind": "roster", "warscroll_id": warscroll.id}, warscroll.name, card)

	var favourite := warscroll.id in favourites
	var star := UIBuilder.icon_toggle("star_filled" if favourite else "star",
			"Remove from favourites" if favourite else "Add to favourites", favourite,
			func(_on: bool) -> void: toggle_favourite(warscroll.id), "info:star:" + key)
	var content := UIBuilder.vbox([UIBuilder.hbox([button, star], 4)], 10)
	if open:
		content.add_child(WarscrollCard.new(warscroll, builder.catalog.summoned))
		var add := UIBuilder.button("Add as auxiliary unit", func() -> void: builder.editor.add_auxiliary(warscroll.id),
				"info:aux:" + key, "", "Add %s to the army as an auxiliary unit" % warscroll.name)
		add.disabled = builder.available_units(func(w: Warscroll) -> bool: return w == warscroll).is_empty()
		content.add_child(UIBuilder.hbox([add]))
	card.add_child(content)
	return card


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func toggle_favourite(warscroll_id: String) -> void:
	var index := favourites.find(warscroll_id)
	if index >= 0:
		favourites.remove_at(index)
	else:
		favourites.insert(0, warscroll_id)
	var config := ConfigFile.new()
	config.load(favourites_path)
	config.set_value("favourites", builder.catalog.faction.id, favourites)
	config.save(favourites_path)
	refresh()


func _toggle_fold(key: String) -> void:
	if not folded.erase(key):
		folded[key] = true
	refresh()


## Folds or unfolds the lore with group key [param lore_key].
func _toggle_lore(lore_key: String) -> void:
	if not open_lores.erase(lore_key):
		open_lores[lore_key] = true
	refresh()


func _rules() -> void:
	var army := builder.editor.army
	var searching := not RulesSearch.words(query).is_empty()
	var sections := RulesSections.filter(RulesSections.build(army, builder.catalog), query)
	if sections.is_empty() and searching:
		_empty("Nothing matches “%s”." % query.strip_edges())
	for section in sections:
		var key := "sec:" + section.title
		var open := searching or not folded.has(key)
		var box := UIBuilder.vbox([UIBuilder.banner(section.title.to_upper(), str(section.count()), open,
				_toggle_fold.bind(key), "info:" + key)], 10)
		box.set_meta(&"info_key", key)
		_content.add_child(box)
		if not open:
			continue
		for group in section.groups:
			box.add_child(_rules_group(section, group, searching))


func _rules_group(section: RulesSections.Section, group: RulesSections.Group, searching: bool) -> Control:
	var army := builder.editor.army
	var box := UIBuilder.vbox([], 8)
	var open := true
	if not group.title.is_empty():
		var key := "grp:%s:%s" % [section.title, group.key]
		open = searching or (open_lores.has(group.key) if group.lore else not folded.has(key))
		var toggle := _toggle_lore.bind(group.key) if group.lore else _toggle_fold.bind(key)
		var subhead := UIBuilder.banner(group.title, "", open, toggle, "info:" + key, "SubheadButton")
		box.add_child(subhead)
		var chips := UIBuilder.hbox([], 6)
		if not group.note.is_empty():
			chips.add_child(UIBuilder.label(group.note, "MutedLabel"))
		var scourge := UIBuilder.scourge_tag(group.source)
		if scourge:
			chips.add_child(scourge)
		if group.legends:
			chips.add_child(UITheme.chip("Legends", "legends"))
		chips.add_child(UIBuilder.spacer())
		if group.selected:
			chips.add_child(UITheme.chip("Selected", "affray"))
		if group.points >= 0 and (group.lore or group.points > 0):
			chips.add_child(UITheme.chip("%d pts" % group.points, "gold" if group.points > 0 else ""))
		if chips.get_child_count() > 1:
			box.add_child(chips)
		else:
			chips.free()
	if open:
		for ability in group.abilities:
			box.add_child(AbilityCard.new(ability))
			# A summoning spell or prayer carries the warscrolls of the manifestations it summons.
			for summoned: Warscroll in group.summons.get(ability, []):
				box.add_child(WarscrollCard.new(summoned))
		for warscroll in group.warscrolls:
			var warscroll_card := WarscrollCard.new(warscroll)
			warscroll_card.set_meta(&"info_key", "terrain:" + warscroll.id)
			warscroll_card.focus_mode = Control.FOCUS_ALL
			if flash_key == "terrain:" + warscroll.id:
				warscroll_card.theme_type_variation = "FlashWarscrollPanel"
			box.add_child(warscroll_card)
		for card in group.cards:
			var slot := army.tactics.find(card.name)
			var chip := UITheme.chip("Battle tactic %d" % (slot + 1), "affray") if slot >= 0 else null
			var tactic := TacticCard.new(card, TacticCard.Form.FULL, "", chip)
			tactic.set_meta(&"info_key", "tactic:" + card.name)
			tactic.focus_mode = Control.FOCUS_ALL
			if flash_key == "tactic:" + card.name:
				tactic.theme_type_variation = "FlashCardPanel"
			box.add_child(tactic)
	if group.lore:
		var panel := UIBuilder.panel("FlashGroupPanel" if flash_key == "lore:" + group.title else "", box)
		panel.set_meta(&"info_key", "lore:" + group.title)
		return panel
	return box


func _renown() -> void:
	var army := builder.editor.army
	var query_words := RulesSearch.words(query)
	var available := builder.catalog.faction.regiments_of_renown if army.override_constraints \
			else builder.catalog.regiments_of_renown(army)
	var shown := available.filter(func(r: RegimentOfRenown) -> bool: return army.show_legends or not r.legends)
	_content.add_child(UIBuilder.label("Showing every Regiment of Renown: army constraints are overridden."
			if army.override_constraints else "Regiments of Renown available to this army. An army can include 1.",
			"MutedLabel", true))
	var found_by_query := func(r: RegimentOfRenown) -> bool:
		return RulesSearch.matches(RulesSearch.regiment_text(r), query_words)
	var found := shown.filter(found_by_query)
	if found.is_empty():
		var army_roster := builder.catalog.roster(army)
		if not query_words.is_empty() and not shown.is_empty():
			_empty("No Regiments of Renown match “%s”." % query.strip_edges())
		elif army_roster and not army_roster.regiments_of_renown and not army.override_constraints:
			_empty("%s armies can't include Regiments of Renown." % army.army_of_renown)
		else:
			_empty("No Regiments of Renown are available to this army.")
	for regiment: RegimentOfRenown in found:
		_content.add_child(RenownCard.new(builder, regiment, "tab", Callable(), flash_key == "ror:" + regiment.name))


func _settings() -> void:
	var editor := builder.editor
	var army := editor.army
	_content.add_child(UIBuilder.label("Army Settings", "SectionLabel"))
	# Each setting is shown when every word of the search is in its title or note.
	var query_words := RulesSearch.words(query)
	var shown := [0]
	var add := func(control: Control, text: String) -> void:
		if RulesSearch.matches(text, query_words):
			_content.add_child(control)
			shown[0] += 1
		else:
			control.free()
	var legends_note := "Legends warscrolls aren't used in matched play."
	add.call(UIBuilder.switch_row("Show Legends units", legends_note, army.show_legends, editor.set_show_legends, "info:legends"),
			"Show Legends units " + legends_note)
	var override_note := "Turns off validation. Any unit can join any regiment."
	add.call(UIBuilder.switch_row("Override army constraints", override_note, army.override_constraints,
			editor.set_override_constraints, "info:override"), "Override army constraints " + override_note)

	var spin := SpinBox.new()
	spin.max_value = 100000
	spin.step = 50
	spin.value = army.points_limit
	spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
	spin.custom_minimum_size.x = 120
	spin.accessibility_name = "Points limit"
	spin.set_meta(&"focus_key", "info:points")
	spin.value_changed.connect(func(value: float) -> void: editor.set_points_limit(int(value)))
	var down := UIBuilder.button("−", func() -> void: editor.set_points_limit(army.points_limit - POINTS_STEP),
			"info:points_down", "", "Decrease points limit by %d" % POINTS_STEP)
	var up := UIBuilder.button("+", func() -> void: editor.set_points_limit(army.points_limit + POINTS_STEP),
			"info:points_up", "", "Increase points limit by %d" % POINTS_STEP)
	for button: Button in [down, up]:
		button.accessibility_name = button.tooltip_text
		button.custom_minimum_size.x = 40
	add.call(UIBuilder.setting_row("Points limit", UIBuilder.hbox([down, spin, up])), "Points limit")

	var faction := builder.catalog.faction
	if not faction.armies_of_renown.is_empty():
		var renown := builder.catalog.army_of_renown(army.army_of_renown) if not army.army_of_renown.is_empty() else null
		var slot := _choice_slot(renown, "Army of Renown", "info:aor", builder.pick_army_of_renown,
				"Use the %s rules" % faction.name, builder.remove_army_of_renown)
		var note := "Uses the Army of Renown's battle traits, enhancements and lores instead of the faction's." \
				if renown else "Choose an Army of Renown to replace the faction rules."
		add.call(UIBuilder.setting_row("Army of Renown", slot, note), "Army of Renown " + note)
	if not builder.catalog.battle_formations(army).is_empty():
		var slot := _choice_slot(builder.catalog.battle_formation(army, army.formation), "Battle Formation", "info:formation", builder.pick_formation,
				"Remove the battle formation", builder.remove_formation)
		add.call(UIBuilder.setting_row("Battle Formation", slot), "Battle Formation")
	if shown[0] == 0:
		_empty("No settings match “%s”." % query.strip_edges())


## The army's choice of [param title] ("Army of Renown" or "Battle Formation"): a dashed box that
## calls [param pick] while [param choice] is null, else its short card with Change, which also
## calls [param pick], and a red bin icon button labelled [param remove_label] that calls
## [param remove].
func _choice_slot(choice: Resource, title: String, key: String, pick: Callable, remove_label: String,
		remove: Callable) -> Control:
	if choice == null:
		var slot := UIBuilder.button("Choose " + title, pick, key, "DashedButton")
		slot.custom_minimum_size.y = ArmyBuilder.SLOT_HEIGHT
		return slot
	var change := UIBuilder.button("Change", pick, key, "", "Change %s" % title)
	var bin := UIBuilder.icon_button("delete", remove_label, remove, key + "_remove", "DangerIconButton")
	var actions := UIBuilder.hbox([change, bin], 4)
	if choice is ArmyOfRenown:
		return RenownArmyCard.new(choice, false, actions)
	return FormationCard.new(choice, false, actions)


## Shows the unit's card in the Roster with its warscroll open, highlighted and focused.
func show_unit(warscroll: Warscroll) -> void:
	if warscroll.legends and not builder.editor.army.show_legends:
		builder.editor.set_show_legends(true)
	folded.erase("type:" + unit_type(warscroll))
	selected = warscroll.id
	_go("roster", "unit:" + warscroll.id)


func show_regiment_of_renown(regiment_name: String) -> void:
	_go("renown", "ror:" + regiment_name)


## Shows the faction terrain feature's warscroll in the Rules tab's Faction Terrain section.
func show_terrain(warscroll_id: String) -> void:
	folded.erase("sec:Faction Terrain")
	_go("rules", "terrain:" + warscroll_id)


## Shows the battle tactics card in the Rules tab's Battle Tactics section.
func show_tactic(card_name: String) -> void:
	folded.erase("sec:Battle Tactics")
	_go("rules", "tactic:" + card_name)


## Shows the lore, unfolded, in the Rules tab's Lores section. Every lore of that name unfolds, as
## an army picks its lores by name.
func show_lore(lore_name: String) -> void:
	folded.erase("sec:Lores")
	open_lores[lore_name] = true
	for section in RulesSections.build(builder.editor.army, builder.catalog):
		if section.title == "Lores":
			for group in section.groups:
				if group.title == lore_name:
					open_lores[group.key] = true
	_go("rules", "lore:" + lore_name)


## Shows the Rules tab's Lores section, unfolded, and focuses its banner.
func show_lores() -> void:
	folded.erase("sec:Lores")
	_go("rules", "sec:Lores")


## Clears the search and switches to [param to_tab], then scrolls to and highlights [param key].
func _go(to_tab: String, key: String) -> void:
	if builder.picker.is_open():
		builder.picker.close()
	tab = to_tab
	query = ""
	flash_key = key
	_scroll_to = key
	_scroll_wait = 1
	_flash_timer.start()
	refresh()


func _end_flash() -> void:
	flash_key = ""
	if visible:
		refresh()


func _process(_delta: float) -> void:
	_scroll_wait -= 1
	if _scroll_wait > 0:
		return
	set_process(false)
	var target := _find_info_key(_content, _scroll_to)
	_scroll_to = ""
	if target == null:
		return
	_scroll.scroll_vertical = int(target.global_position.y - _content.global_position.y)
	var focus := target if target.focus_mode == Control.FOCUS_ALL else _first_button(target)
	if focus:
		focus.grab_focus()


static func _find_info_key(node: Node, key: String) -> Control:
	return UIBuilder.find_descendant(node, func(child: Node) -> bool: return child.get_meta(&"info_key", "") == key) as Control


static func _first_button(node: Node) -> Button:
	return UIBuilder.find_descendant(node, func(child: Node) -> bool: return child is Button and not child.disabled) as Button
