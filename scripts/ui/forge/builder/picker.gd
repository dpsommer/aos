class_name Picker
extends VBoxContainer
## Takes over the info pane to pick a unit, battle tactics card or Regiment of Renown to add.

## Emitted when the player closes the picker without picking, or after a pick.
signal closed

var builder: ArmyBuilder
var _title: Label
var _list: VBoxContainer
## Redraws the current list, e.g. after the army changes which units are still available.
var _render := Callable()


func _init(army_builder: ArmyBuilder) -> void:
	builder = army_builder
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_title = BuilderUI.label("", "TitleLabel", true)
	add_child(BuilderUI.hbox([_title, BuilderUI.icon_button("close", "Close without picking", close, "picker:close")]))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = BuilderUI.vbox([], 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	add_child(scroll)


func close() -> void:
	_render = Callable()
	closed.emit()


func is_open() -> bool:
	return _render.is_valid()


## Redraws the open list.
func refresh() -> void:
	if not is_open():
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_render.call()


func _open(title: String, render: Callable) -> void:
	_title.text = title
	_render = render
	refresh()
	var first := _first_button(_list)
	(first if first else get_child(0).get_child(1) as Control).grab_focus()


func _first_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button and not child.disabled:
			return child
		var found := _first_button(child)
		if found:
			return found
	return null


## Lists [param warscrolls] (or, as a Callable returning them, a list that updates as the army
## changes) and calls [param on_pick] with the chosen warscroll's id.
func open_units(title: String, warscrolls: Callable, on_pick: Callable) -> void:
	var render := func() -> void:
		var shown: Array[Warscroll] = warscrolls.call()
		if shown.is_empty():
			_list.add_child(BuilderUI.label("No units can be added here.", "MutedLabel", true))
		for warscroll in shown:
			_list.add_child(_unit_item(warscroll, on_pick))
	_open(title, render)


func _unit_item(warscroll: Warscroll, on_pick: Callable) -> PanelContainer:
	var names := BuilderUI.vbox([BuilderUI.label(warscroll.name, "", true)], 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var details := BuilderUI.hbox([BuilderUI.label("%d pts" % warscroll.points, "MutedLabel")], 6)
	for tag in BuilderUI.tags(warscroll):
		details.add_child(tag)
	names.add_child(details)
	var add := BuilderUI.button("Add", func() -> void: on_pick.call(warscroll.id), "pick:" + warscroll.id, "", "Add %s" % warscroll.name)
	return BuilderUI.panel("RowPanel", BuilderUI.hbox([BuilderUI.portrait(warscroll.name), names, add], 10))


## Lists the battlepack's battle tactics cards in full to fill tactics card [param slot].
func open_tactics(slot: int) -> void:
	var render := func() -> void:
		var core := builder.catalog.core
		var cards: Array[BattleTacticCard] = core.battlepack.battle_tactic_cards if core and core.battlepack else []
		for card in cards:
			var pick := func() -> void:
				builder.editor.set_tactic(slot, card.name)
				close()
			var current := builder.editor.army.tactics[slot] == card.name
			var choose := BuilderUI.button("Chosen" if current else "Choose", pick, "pick:" + card.name, "GoldButton")
			choose.disabled = current
			_list.add_child(TacticCard.new(card, true, "", choose))
	_open("Battle tactics card %d" % (slot + 1), render)


## Lists the Regiments of Renown the army can include, with their rules and warscrolls.
func open_regiments_of_renown() -> void:
	var render := func() -> void:
		var army := builder.editor.army
		var available := builder.catalog.regiments_of_renown(army) if not army.override_constraints \
				else builder.catalog.faction.regiments_of_renown
		var shown := available.filter(func(r: RegimentOfRenown) -> bool: return army.show_legends or not r.legends)
		if shown.is_empty():
			_list.add_child(BuilderUI.label("This army can't include any Regiments of Renown.", "MutedLabel", true))
		for regiment: RegimentOfRenown in shown:
			_list.add_child(_regiment_card(regiment))
	_open("Add a Regiment of Renown", render)


func _regiment_card(regiment: RegimentOfRenown) -> PanelContainer:
	var pick := func() -> void:
		if builder.editor.add_regiment_of_renown(regiment.name):
			close()
	var add := BuilderUI.button("Add", pick, "pick:" + regiment.name, "GoldButton", "Add %s" % regiment.name)
	var title := BuilderUI.label(regiment.name + (" (Legends)" if regiment.legends else ""), "TitleLabel", true)
	var content := BuilderUI.vbox([BuilderUI.hbox([title, BuilderUI.label("%d pts" % regiment.points, "MutedLabel"), add])], 8)
	content.add_child(_rich(RulesFormatter.regiment_of_renown(regiment)))
	var key := "scrolls:" + regiment.name
	var showing := builder.expanded.has(key)
	var show_scrolls := func(_on: bool) -> void:
		builder.toggle_expanded(key)
		refresh()
	content.add_child(BuilderUI.toggle("Hide warscrolls" if showing else "Show warscrolls", showing, show_scrolls, key))
	if showing:
		var seen := {}
		for unit in regiment.units:
			if seen.has(unit.warscroll_id):
				continue
			seen[unit.warscroll_id] = true
			var army_unit := ArmyUnit.new()
			army_unit.warscroll_id = unit.warscroll_id
			army_unit.faction_id = unit.faction_id
			var as_regiment := ArmyRegiment.new()
			as_regiment.regiment_of_renown = regiment.name
			var warscroll := builder.catalog.warscroll(army_unit, as_regiment)
			if warscroll:
				content.add_child(_rich(RulesFormatter.warscroll(warscroll)))
	return BuilderUI.panel("CardPanel", content)


func _rich(bbcode: String) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.text = bbcode
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return text
