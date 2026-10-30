class_name RenownCard
extends PanelContainer
## A Regiment of Renown in full: its units, each with its warscroll on demand, its rules and a
## button to add it. Shown in the info pane's Regiments of Renown tab and in the picker.

var builder: ArmyBuilder
var regiment: RegimentOfRenown


## [param context] ("tab" or "pick") keeps each place's open warscrolls apart. [param on_added]
## runs after the regiment is added. [param flash] highlights the card after a link to it.
func _init(army_builder: ArmyBuilder, renown: RegimentOfRenown, context: String, on_added := Callable(), flash := false) -> void:
	builder = army_builder
	regiment = renown
	theme_type_variation = "FlashCardPanel" if flash else "CardPanel"
	set_meta(&"info_key", "ror:" + regiment.name)
	var army := builder.editor.army
	var count := 0
	for unit in regiment.units:
		count += unit.count
	var title := UIBuilder.label(regiment.name, "CardTitleLabel", true)
	var names := UIBuilder.vbox([title, UIBuilder.label("%d unit%s · fixed regiment" % [count, "" if count == 1 else "s"],
			"MutedLabel")], 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := UIBuilder.vbox([UIBuilder.hbox([names, UITheme.chip("%d pts" % regiment.points, "gold")])], 8)
	var allowed := regiment in builder.catalog.regiments_of_renown(army)
	if not allowed or regiment.legends:
		var chips := HFlowContainer.new()
		if not allowed:
			chips.add_child(UITheme.chip("Not normally available", "legends"))
		if regiment.legends:
			chips.add_child(UITheme.chip("Legends", "legends"))
		content.add_child(chips)

	for i in regiment.units.size():
		var unit := regiment.units[i]
		var key := "%s:%s:%d" % [context, regiment.name, i]
		var open := builder.expanded.has(key)
		var text := ("%d × " % unit.count if unit.count > 1 else "") + unit.name
		if not unit.notes.is_empty():
			text += " (%s)" % unit.notes
		var warscroll := _warscroll(unit)
		var toggle := UIBuilder.banner(text, "", open, builder.toggle_expanded.bind(key), key, "SubheadButton")
		toggle.tooltip_text = ("Hide " if open else "Show ") + unit.name + "'s warscroll"
		toggle.disabled = warscroll == null
		content.add_child(toggle)
		if open and warscroll:
			content.add_child(WarscrollCard.new(warscroll, builder.catalog.summoned))

	if not regiment.text.is_empty():
		content.add_child(UIBuilder.label(regiment.text, "MutedLabel", true))
	if not regiment.abilities.is_empty():
		for ability in regiment.abilities:
			content.add_child(AbilityCard.new(ability))
			for summoned_unit: Warscroll in builder.catalog.summoned(ability):
				content.add_child(WarscrollCard.summoned_card(summoned_unit))

	var in_army := army.regiments.any(func(r: ArmyRegiment) -> bool: return r.regiment_of_renown == regiment.name)
	var has_one := army.regiments.any(func(r: ArmyRegiment) -> bool: return r.is_regiment_of_renown())
	if has_one and not army.override_constraints:
		content.add_child(UIBuilder.label("In your army" if in_army else "Your army already has a Regiment of Renown",
				"MutedLabel", true))
	else:
		var add := func() -> void:
			if builder.editor.add_regiment_of_renown(regiment.name) and on_added.is_valid():
				on_added.call()
		content.add_child(UIBuilder.hbox([UIBuilder.button("Add to army", add, "%s:add:%s" % [context, regiment.name],
				"GoldButton", "Add %s to the army" % regiment.name)]))
		if context == "tab":
			builder.drag.source(self, {"kind": "ror", "name": regiment.name}, regiment.name)
			mouse_default_cursor_shape = Control.CURSOR_MOVE
	add_child(content)
	if context == "tab":
		# Drags from the card's text start a drag of the card.
		BuilderDragDrop.pass_mouse(self)


func _warscroll(unit: RegimentUnit) -> Warscroll:
	var army_unit := ArmyUnit.new()
	army_unit.warscroll_id = unit.warscroll_id
	army_unit.faction_id = unit.faction_id
	var as_regiment := ArmyRegiment.new()
	as_regiment.regiment_of_renown = regiment.name
	return builder.catalog.warscroll(army_unit, as_regiment)
