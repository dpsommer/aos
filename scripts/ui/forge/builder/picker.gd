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
	_title = UIBuilder.label("", "TitleLabel", true)
	add_child(UIBuilder.hbox([_title, UIBuilder.icon_button("close", "Close without picking", close, "picker:close")]))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = UIBuilder.vbox([], 8)
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
	focus_first()


## Focuses the list's first enabled button or pressable card, or the close button when there is
## none.
func focus_first() -> void:
	var first := _first_button(_list)
	(first if first else get_child(0).get_child(1) as Control).grab_focus()


func _first_button(node: Node) -> Control:
	for child in node.get_children():
		if (child is Button and not child.disabled) or (child is TacticCard and child.pressable):
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
			_list.add_child(UIBuilder.label("No units can be added here.", "MutedLabel", true))
		for warscroll in shown:
			_list.add_child(_unit_item(warscroll, on_pick))
	_open(title, render)


func _unit_item(warscroll: Warscroll, on_pick: Callable) -> PanelContainer:
	var names := UIBuilder.vbox([UIBuilder.label(warscroll.name, "", true)], 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var details := UIBuilder.hbox([UIBuilder.label("%d pts" % warscroll.points, "MutedLabel")], 6)
	for tag in UIBuilder.tags(warscroll):
		details.add_child(tag)
	names.add_child(details)
	var add := UIBuilder.button("Add", func() -> void: on_pick.call(warscroll.id), "pick:" + warscroll.id, "", "Add %s" % warscroll.name)
	return UIBuilder.panel("RowPanel", UIBuilder.hbox([UIBuilder.portrait(warscroll.name), names, add], 10))


## Lists the battlepack's battle tactics cards in full to fill tactics card [param slot]. Pressing a
## card chooses it. The other slot's card isn't listed, and the slot's current card can't be pressed.
func open_tactics(slot: int) -> void:
	var render := func() -> void:
		var core := builder.catalog.core
		var cards: Array[BattleTacticCard] = core.battlepack.battle_tactic_cards if core and core.battlepack else []
		var tactics := builder.editor.army.tactics
		var current := tactics[slot] if slot < tactics.size() else ""
		for card in cards:
			# The other slot's card can't be chosen twice.
			if card.name in tactics and card.name != current:
				continue
			if card.name == current:
				_list.add_child(TacticCard.new(card, true, "", UITheme.chip("Chosen", "gold")))
				continue
			var item := TacticCard.new(card, true)
			item.make_pressable("Choose %s for battle tactics card %d" % [card.name, slot + 1])
			item.set_meta(&"focus_key", "pick:" + card.name)
			item.pressed.connect(func() -> void:
				builder.editor.set_tactic(slot, card.name)
				close())
			_list.add_child(item)
	_open("Battle tactics card %d" % (slot + 1), render)


## Lists the Regiments of Renown the army can include, with their rules and warscrolls.
func open_regiments_of_renown() -> void:
	var render := func() -> void:
		var army := builder.editor.army
		var available := builder.catalog.regiments_of_renown(army) if not army.override_constraints \
				else builder.catalog.faction.regiments_of_renown
		var shown := available.filter(func(r: RegimentOfRenown) -> bool: return army.show_legends or not r.legends)
		if shown.is_empty():
			_list.add_child(UIBuilder.label("This army can't include any Regiments of Renown.", "MutedLabel", true))
		for regiment: RegimentOfRenown in shown:
			_list.add_child(RenownCard.new(builder, regiment, "pick", close))
	_open("Add a Regiment of Renown", render)
