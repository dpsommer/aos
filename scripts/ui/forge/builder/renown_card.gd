class_name RenownCard
extends PanelContainer
## A Regiment of Renown in full: its units, each with its warscroll on demand, its rules and a
## button to add it. Shown in the info pane's Regiments of Renown tab and in the picker.

var builder: ArmyBuilder
var regiment: RegimentOfRenown


## [param context] ("tab" or "pick") keeps each place's open warscrolls apart. [param on_added]
## runs after the regiment is added. [param flash] highlights the card after a link to it.
static func create(army_builder: ArmyBuilder, renown: RegimentOfRenown, context: String, on_added := Callable(),
		flash := false) -> RenownCard:
	var card: RenownCard = load("res://scenes/ui/forge/builder/renown_card.tscn").instantiate()
	card._fill(army_builder, renown, context, on_added, flash)
	return card


func _fill(army_builder: ArmyBuilder, renown: RegimentOfRenown, context: String, on_added: Callable, flash: bool) -> void:
	builder = army_builder
	regiment = renown
	if flash:
		theme_type_variation = "FlashCardPanel"
	set_meta(&"info_key", "ror:" + regiment.name)
	var army := builder.editor.army
	var count := 0
	for unit in regiment.units:
		count += unit.count
	(%Title as Label).text = regiment.name
	(%Subtitle as Label).text = "%d unit%s · fixed regiment" % [count, "" if count == 1 else "s"]
	%TitleRow.add_child(UITheme.chip("%d pts" % regiment.points, "gold"))
	var allowed := regiment in builder.catalog.regiments_of_renown(army)
	var chips: HFlowContainer = %Chips
	if not allowed:
		chips.add_child(UITheme.chip("Not normally available", "legends"))
	if regiment.legends:
		chips.add_child(UITheme.chip("Legends", "legends"))
	chips.visible = chips.get_child_count() > 0

	# The units' warscroll toggles, then the regiment's rules, go before its text.
	var content: VBoxContainer = %Content
	var rules: Array[Control] = []
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
		rules.append(toggle)
		if open and warscroll:
			rules.append(WarscrollCard.create(warscroll, builder.catalog.summoned))
	var text_label: Label = %Text
	for control in rules:
		content.add_child(control)
		content.move_child(control, text_label.get_index())
	if not regiment.text.is_empty():
		text_label.text = regiment.text
		text_label.visible = true
	var status: Label = %Status
	for ability in regiment.abilities:
		for control: Control in [AbilityCard.create(ability) as Control] + _summoned(ability):
			content.add_child(control)
			content.move_child(control, status.get_index())

	var in_army := army.regiments.any(func(r: ArmyRegiment) -> bool: return r.regiment_of_renown == regiment.name)
	var has_one := army.regiments.any(func(r: ArmyRegiment) -> bool: return r.is_regiment_of_renown())
	if has_one and not army.override_constraints:
		status.text = "In your army" if in_army else "Your army already has a Regiment of Renown"
		status.visible = true
	else:
		var add: Button = %Add
		add.tooltip_text = "Add %s to the army" % regiment.name
		add.set_meta(&"focus_key", "%s:add:%s" % [context, regiment.name])
		add.pressed.connect(func() -> void:
			if builder.editor.add_regiment_of_renown(regiment.name) and on_added.is_valid():
				on_added.call())
		%AddRow.visible = true
		if context == "tab":
			builder.drag.source(self, {"kind": "ror", "name": regiment.name}, regiment.name)
			mouse_default_cursor_shape = Control.CURSOR_MOVE
	if context == "tab":
		# Drags from the card's text start a drag of the card.
		BuilderDragDrop.pass_mouse(self)


func _summoned(ability: Ability) -> Array[Control]:
	var result: Array[Control] = []
	for summoned_unit: Warscroll in builder.catalog.summoned(ability):
		result.append(WarscrollCard.summoned_card(summoned_unit))
	return result


func _warscroll(unit: RegimentUnit) -> Warscroll:
	var army_unit := ArmyUnit.new()
	army_unit.warscroll_id = unit.warscroll_id
	army_unit.faction_id = unit.faction_id
	var as_regiment := ArmyRegiment.new()
	as_regiment.regiment_of_renown = regiment.name
	return builder.catalog.warscroll(army_unit, as_regiment)
