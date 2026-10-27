class_name ArmyBuilder
extends Control
## The army builder: the army list on the right, and an info pane on the left that a picker takes
## over to add units, battle tactics cards and Regiments of Renown. See docs/design/forge.md.

signal back_pressed

const LORE_HELP := {
	"spell": "Your army must contain one or more Wizards to cast the spells in your spell lore.",
	"prayer": "Your army must contain one or more Priests to chant the prayers in your prayer lore.",
	"manifestation": "Your army must contain at least one Wizard or Priest in order to summon manifestations.",
}

var editor: ArmyEditor
var catalog: ArmyCatalog
var picker: Picker
var info_pane: InfoPane
## Unit uids with their options open, and other expanded panels' keys.
var expanded := {}
## Ids of collapsed regiments.
var collapsed := {}
## Id of the regiment being renamed, or empty.
var renaming := ""
var _drawing := false
var _redraw_again := false

@onready var back_button: Button = %BackButton
@onready var faction_label: Label = %FactionLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var points_label: Label = %PointsLabel
@onready var points_bar: ProgressBar = %PointsBar
@onready var status_panel: PanelContainer = %StatusPanel
@onready var status_label: Label = %StatusLabel
@onready var save_button: Button = %SaveButton
@onready var left_pane: PanelContainer = %LeftPane
@onready var builder_list: VBoxContainer = %BuilderList


func _ready() -> void:
	theme = ForgeTheme.get_theme()
	back_button.icon = ForgeTheme.icon("back")
	back_button.pressed.connect(back_pressed.emit)
	info_pane = InfoPane.new(self)
	left_pane.add_child(info_pane)
	picker = Picker.new(self)
	picker.hide()
	picker.closed.connect(_on_picker_closed)
	left_pane.add_child(picker)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if picker.is_open():
			picker.close()
		elif not renaming.is_empty():
			renaming = ""
			redraw()
		else:
			back_pressed.emit()


## Starts editing [param army] with its faction's data, or [param army_catalog] if given.
func open(army: Army, army_catalog: ArmyCatalog = null) -> void:
	if army_catalog == null:
		var faction := FactionCatalog.load_faction(FactionCatalog.name_for_id(army.faction_id))
		army_catalog = ArmyCatalog.new(faction, CoreRulesCatalog.get_rules())
	catalog = army_catalog
	editor = ArmyEditor.new(army, catalog)
	editor.changed.connect(redraw)
	info_pane.open()
	redraw()
	back_button.grab_focus()


func toggle_expanded(key: String) -> void:
	if not expanded.erase(key):
		expanded[key] = true
	redraw()


func toggle_collapsed(regiment_id: String) -> void:
	if not collapsed.erase(regiment_id):
		collapsed[regiment_id] = true
	redraw()


func start_renaming(regiment_id: String) -> void:
	renaming = regiment_id
	redraw()


func finish_renaming(regiment_id: String, regiment_name: String) -> void:
	if renaming != regiment_id:
		return
	renaming = ""
	var regiment := editor.army.find_regiment(regiment_id)
	if regiment and regiment.name != regiment_name.strip_edges() and not regiment_name.strip_edges().is_empty():
		editor.rename_regiment(regiment_id, regiment_name)
	else:
		redraw()


## Redraws the header, the army list and any open picker from the army, keeping keyboard focus on
## the same control.
func redraw() -> void:
	if _drawing:
		_redraw_again = true
		return
	_drawing = true
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var key: String = focused.get_meta(&"focus_key", "") if focused else ""
	_draw_header()
	for child in builder_list.get_children():
		builder_list.remove_child(child)
		child.queue_free()
	for section in [_name_section(), _validation_section(), _tactics_section(), _army_list_section(),
			_auxiliary_section(), _terrain_section(), _lores_section()]:
		if section:
			builder_list.add_child(section)
	if info_pane.visible:
		info_pane.refresh()
	picker.refresh()
	_drawing = false
	if _redraw_again:
		_redraw_again = false
		redraw()
	elif not key.is_empty():
		var target := find_focus_key(self, key)
		if target:
			target.grab_focus()


## The control under [param node] tagged with [param key] for focus, or null.
static func find_focus_key(node: Node, key: String) -> Control:
	for child in node.get_children():
		if child.get_meta(&"focus_key", "") == key and child is Control and child.is_visible_in_tree():
			return child
		var found := find_focus_key(child, key)
		if found:
			return found
	return null


func _draw_header() -> void:
	var army := editor.army
	faction_label.text = catalog.faction.name + (" (Legends)" if catalog.faction.legends else "")
	var rules := "Army of Renown: " + army.army_of_renown if not army.army_of_renown.is_empty() else army.formation
	var alliance := GrandAlliance.display_name(catalog.faction.grand_alliance)
	subtitle_label.text = alliance if rules.is_empty() else "%s · %s" % [alliance, rules]
	var total := ArmyPoints.total(army, catalog)
	var over := total > army.points_limit
	points_label.text = "%d / %d pts" % [total, army.points_limit]
	points_label.add_theme_color_override("font_color", ForgeTheme.DANGER if over else ForgeTheme.TEXT)
	points_bar.max_value = maxi(army.points_limit, 1)
	points_bar.value = mini(total, army.points_limit)
	points_bar.add_theme_stylebox_override("fill", ForgeTheme.box(ForgeTheme.DANGER if over else ForgeTheme.GOOD, Color.TRANSPARENT, 3))
	var validation := ArmyValidator.validate(army, catalog)
	var colors: Array
	if validation.overridden:
		status_label.text = "Constraints overridden"
		colors = [Color("#2A2F38"), Color("#C9CCD3")]
	elif validation.is_valid():
		status_label.text = "Army valid"
		colors = [ForgeTheme.GOOD_BG, ForgeTheme.GOOD]
	else:
		var count := validation.problems.size()
		status_label.text = "%d problem%s" % [count, "" if count == 1 else "s"]
		colors = [ForgeTheme.DANGER_BG, ForgeTheme.DANGER]
	var pill := ForgeTheme.box(colors[0], Color.TRANSPARENT, 16, 0)
	pill.content_margin_left = 12
	pill.content_margin_right = 12
	pill.content_margin_top = 6
	pill.content_margin_bottom = 6
	status_panel.add_theme_stylebox_override("panel", pill)
	status_label.add_theme_color_override("font_color", colors[1])


func _section(title: String, children: Array) -> VBoxContainer:
	var box := BuilderUI.vbox([BuilderUI.label(title, "SectionLabel")], 10)
	for child: Control in children:
		box.add_child(child)
	return box


func _name_section() -> Control:
	var edit := LineEdit.new()
	edit.text = editor.army.name
	edit.tooltip_text = "Army name"
	edit.add_theme_font_size_override("font_size", 20)
	edit.set_meta(&"focus_key", "army:name")
	var commit := func(_text := "") -> void:
		if edit.text.strip_edges() != editor.army.name:
			editor.set_army_name(edit.text)
	edit.text_submitted.connect(commit)
	edit.focus_exited.connect(commit)
	return edit


func _validation_section() -> Control:
	var validation := ArmyValidator.validate(editor.army, catalog)
	if validation.overridden:
		return BuilderUI.label("Army constraints are overridden, so the army isn't checked.", "MutedLabel", true)
	if validation.problems.is_empty() and validation.warnings.is_empty():
		return null
	var box := BuilderUI.vbox([], 8)
	for list: Array in [[validation.problems, "ProblemsPanel", "ProblemLabel"], [validation.warnings, "WarningsPanel", "WarningLabel"]]:
		var messages: PackedStringArray = list[0]
		if messages.is_empty():
			continue
		var lines := BuilderUI.vbox([], 4)
		for message in messages:
			lines.add_child(BuilderUI.label("• " + message, list[2], true))
		box.add_child(BuilderUI.panel(list[1], lines))
	return box


func _tactics_section() -> Control:
	var army := editor.army
	var row := BuilderUI.hbox([], 12)
	for slot in ArmyValidator.MAX_TACTICS:
		var card_name := army.tactics[slot] if slot < army.tactics.size() else ""
		var card := catalog.battle_tactic_card(card_name)
		var heading := "Battle tactics card %d" % (slot + 1)
		var slot_control: Control
		if card:
			var change := BuilderUI.button("Change", pick_tactic.bind(slot), "tactic:%d" % slot, "", "Change %s" % heading.to_lower())
			slot_control = TacticCard.new(card, false, heading, change)
			_link(slot_control, info_pane.show_tactic.bind(card.name), "Show %s in the Rules tab" % card.name, "tactic_card:%d" % slot)
		else:
			slot_control = BuilderUI.button("Choose " + heading.to_lower(), pick_tactic.bind(slot), "tactic:%d" % slot, "GhostButton")
			slot_control.custom_minimum_size.y = 92
		slot_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slot_control)
	return _section("Battle Tactics", [row])


func _army_list_section() -> Control:
	var children: Array = []
	for regiment in editor.army.regiments:
		children.append(RegimentPanel.new(self, regiment))
	children.append(BuilderUI.hbox([
		BuilderUI.button("Add regiment", pick_leader.bind(""), "army:add_regiment", "GhostButton"),
		BuilderUI.button("Add Regiment of Renown", pick_regiment_of_renown, "army:add_ror", "GhostButton"),
	], 12))
	return _section("Army List", children)


func _auxiliary_section() -> Control:
	var children: Array = []
	for unit in editor.army.auxiliary:
		children.append(UnitRow.new(self, unit, null))
	children.append(BuilderUI.button("Add auxiliary unit", pick_auxiliary, "army:add_aux", "GhostButton"))
	return _section("Auxiliary Units", children)


func _terrain_section() -> Control:
	var terrain := catalog.terrain_warscrolls()
	var army_roster := catalog.roster(editor.army)
	if terrain.is_empty() or (army_roster and not army_roster.faction_terrain):
		return null
	var items := [["None", ""]]
	for warscroll in terrain:
		items.append(["%s · %d pts" % [warscroll.name, warscroll.points] if warscroll.points else warscroll.name, warscroll.id])
	return _section("Faction Terrain", [BuilderUI.select(items, editor.army.faction_terrain, editor.set_faction_terrain,
			"army:terrain", "Faction terrain")])


func _lores_section() -> Control:
	var army := editor.army
	var wizard := false
	var priest := false
	for unit in army.all_units():
		var regiment := army.regiment_of(unit.uid)
		var warscroll := catalog.warscroll(unit, regiment)
		if warscroll and not (regiment and regiment.is_regiment_of_renown()):
			for keyword in warscroll.keywords:
				wizard = wizard or keyword.begins_with("WIZARD")
				priest = priest or keyword.begins_with("PRIEST")
	var rows: Array = []
	for pick: Array in [["spell", "Spell Lore", army.spell_lore, wizard], ["prayer", "Prayer Lore", army.prayer_lore, priest],
			["manifestation", "Manifestation Lore", army.manifestation_lore, wizard or priest]]:
		var lores := catalog.lores(army, pick[0])
		if lores.is_empty():
			continue
		var items := [["None", ""]]
		for lore in lores:
			items.append(["%s · %d pts" % [lore.name, lore.points] if lore.points else lore.name, lore.name])
		var help := BuilderUI.label("?", "MutedLabel")
		help.tooltip_text = LORE_HELP[pick[0]]
		help.mouse_filter = Control.MOUSE_FILTER_STOP
		if pick[3] and pick[2].is_empty():
			help.add_theme_color_override("font_color", ForgeTheme.WARNING)
		var title := BuilderUI.label(pick[1])
		title.custom_minimum_size.x = 160
		var kind: String = pick[0]
		var choose := func(value: String) -> void:
			editor.set_lore(kind, value)
			if not value.is_empty():
				info_pane.show_lore(value)
		var select := BuilderUI.select(items, pick[2], choose, "lore:" + kind, pick[1])
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.append(BuilderUI.hbox([title, help, select]))
	return _section("Lores", rows) if not rows.is_empty() else null


## Makes [param control] call [param on_pressed] when clicked, or on Enter or Space with keyboard focus.
func _link(control: Control, on_pressed: Callable, tooltip: String, key: String) -> void:
	control.focus_mode = Control.FOCUS_ALL
	control.tooltip_text = tooltip
	control.accessibility_name = tooltip
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.set_meta(&"focus_key", key)
	var on_input := func(event: InputEvent) -> void:
		var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		if click or event.is_action_pressed("ui_accept"):
			control.accept_event()
			on_pressed.call()
	control.gui_input.connect(on_input)


## Units the player can add: no Legends units unless shown, and no second copy of a Unique unit
## unless constraints are overridden. [param allow] filters further.
func available_units(allow: Callable) -> Array[Warscroll]:
	var army := editor.army
	var taken := {}
	for unit in army.all_units():
		var warscroll := catalog.warscroll(unit, army.regiment_of(unit.uid))
		if warscroll and warscroll.has_keyword("UNIQUE"):
			taken[warscroll.name] = true
	var result: Array[Warscroll] = []
	for warscroll in catalog.unit_warscrolls():
		if warscroll.legends and not army.show_legends:
			continue
		if taken.has(warscroll.name) and not army.override_constraints:
			continue
		if allow.call(warscroll):
			result.append(warscroll)
	result.sort_custom(func(a: Warscroll, b: Warscroll) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	return result


func _show_picker() -> void:
	info_pane.hide()
	picker.show()


func _on_picker_closed() -> void:
	picker.hide()
	info_pane.show()
	info_pane.refresh()


## Picks a Hero to lead [param regiment_id], or a new regiment when empty.
func pick_leader(regiment_id: String) -> void:
	_show_picker()
	var heroes := available_units.bind(func(w: Warscroll) -> bool: return w.has_keyword("HERO"))
	var pick := func(warscroll_id: String) -> void:
		picker.close()
		if regiment_id.is_empty():
			editor.add_regiment(warscroll_id)
		else:
			editor.add_unit(regiment_id, warscroll_id)
	picker.open_units("Choose a leader", heroes, pick)


## Picks a unit for [param regiment_id] from its leader's regiment options, or from every unit when
## constraints are overridden.
func pick_unit(regiment_id: String) -> void:
	var regiment := editor.army.find_regiment(regiment_id)
	var leader := catalog.warscroll(regiment.leader(), regiment) if regiment and regiment.leader() else null
	var options := RegimentOption.parse_all(leader.regiment_options) if leader else [] as Array[RegimentOption]
	var allowed := func(w: Warscroll) -> bool:
		return editor.army.override_constraints or options.any(func(o: RegimentOption) -> bool: return o.matches(w))
	_show_picker()
	var pick := func(warscroll_id: String) -> void:
		editor.add_unit(regiment_id, warscroll_id)
		if not editor.has_room(regiment):
			picker.close()
	picker.open_units("Add to %s" % regiment.name, available_units.bind(allowed), pick)


func pick_auxiliary() -> void:
	_show_picker()
	var pick := func(warscroll_id: String) -> void:
		editor.add_auxiliary(warscroll_id)
		picker.close()
	picker.open_units("Add an auxiliary unit", available_units.bind(func(_w: Warscroll) -> bool: return true), pick)


func pick_tactic(slot: int) -> void:
	_show_picker()
	picker.open_tactics(slot)


func pick_regiment_of_renown() -> void:
	_show_picker()
	picker.open_regiments_of_renown()
