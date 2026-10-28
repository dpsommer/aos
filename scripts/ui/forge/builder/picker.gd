class_name Picker
extends VBoxContainer
## Takes over the info pane to pick a unit, battle tactics card, lore or Regiment of Renown to add.

## Emitted when the player closes the picker without picking, or after a pick.
signal closed

var builder: ArmyBuilder
var _title: Label
var _list: VBoxContainer
## Unit types folded in the unit list, e.g. "Hero".
var folded := {}
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
	folded.clear()
	_render = render
	refresh()
	focus_first()


## Focuses the list's first enabled button (not a section's banner) or pressable card, or the
## close button when there is none.
func focus_first() -> void:
	var first := _first_button(_list)
	(first if first else get_child(0).get_child(1) as Control).grab_focus()


func _first_button(node: Node) -> Control:
	for child in node.get_children():
		if (child is Button and not child.disabled and child.theme_type_variation != &"BannerButton") \
				or (child is PressableCard and child.pressable):
			return child
		var found := _first_button(child)
		if found:
			return found
	return null


## Lists [param warscrolls] (or, as a Callable returning them, a list that updates as the army
## changes) in foldable sections by unit type, as the Roster does, and calls [param on_pick] with
## the chosen warscroll's id.
func open_units(title: String, warscrolls: Callable, on_pick: Callable) -> void:
	var render := func() -> void:
		var shown: Array[Warscroll] = warscrolls.call()
		if shown.is_empty():
			_list.add_child(UIBuilder.label("No units can be added here.", "MutedLabel", true))
		var by_type := {}
		for warscroll in shown:
			var type := InfoPane.unit_type(warscroll)
			if not by_type.has(type):
				by_type[type] = []
			by_type[type].append(warscroll)
		for type: Array in InfoPane.UNIT_TYPES:
			var units: Array = by_type.get(type[0], [])
			if units.is_empty():
				continue
			var open := not folded.has(type[0])
			var section := UIBuilder.vbox([UIBuilder.banner(type[0].to_upper(), str(units.size()), open,
					_toggle_fold.bind(type[0]), "picker:type:" + type[0])], 6)
			if open:
				for warscroll: Warscroll in units:
					section.add_child(_unit_item(warscroll, on_pick))
			_list.add_child(section)
	_open(title, render)


func _toggle_fold(type: String) -> void:
	if not folded.erase(type):
		folded[type] = true
	refresh()
	var banner := ArmyBuilder.find_focus_key(_list, "picker:type:" + type) if is_inside_tree() else null
	if banner:
		banner.grab_focus()


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
## card chooses it. Cards already chosen for either slot aren't listed.
func open_tactics(slot: int) -> void:
	var render := func() -> void:
		var core := builder.catalog.core
		var cards: Array[BattleTacticCard] = core.battlepack.battle_tactic_cards if core and core.battlepack else []
		var tactics := builder.editor.army.tactics
		for card in cards:
			if card.name in tactics:
				continue
			var item := TacticCard.new(card, true)
			item.make_pressable("Choose %s for battle tactics card %d" % [card.name, slot + 1])
			item.set_meta(&"focus_key", "pick:" + card.name)
			item.pressed.connect(func() -> void:
				builder.editor.set_tactic(slot, card.name)
				close())
			_list.add_child(item)
	_open("Battle tactics card %d" % (slot + 1), render)


## Lists the lores of [param kind] ("spell", "prayer" or "manifestation") the army can take, in
## full, under [param title], e.g. "Spell Lore". Pressing a lore picks it. The army's current lore
## isn't listed.
func open_lores(kind: String, title: String) -> void:
	var render := func() -> void:
		var army := builder.editor.army
		var picked: String = army.get("%s_lore" % kind)
		var core := builder.catalog.core
		for lore in builder.catalog.lore_choices(army, kind):
			if lore.name == picked:
				continue
			var universal := core != null and lore in core.manifestation_lores
			var item := LoreCard.new(lore, true, "Universal Manifestation Lore" if universal else "", null,
					builder.catalog.summoned)
			item.make_pressable("Choose %s as the army's %s" % [lore.name, title.to_lower()])
			item.set_meta(&"focus_key", "pick:lore:" + lore.name)
			item.pressed.connect(func() -> void:
				builder.editor.set_lore(kind, lore.name)
				close())
			_list.add_child(item)
		if _list.get_child_count() == 0:
			_list.add_child(UIBuilder.label("There are no other lores to choose.", "MutedLabel", true))
	_open(title, render)


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
