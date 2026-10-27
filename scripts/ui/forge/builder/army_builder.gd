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
var drag: BuilderDragDrop
## Covers the info pane while a unit is dragged, to remove it from the army when dropped there.
var remove_overlay: PanelContainer
## Holds the auxiliary units, as a drop target.
var auxiliary_box: PanelContainer
## Unit uids with their options open, and other expanded panels' keys.
var expanded := {}
## Whether the army has changed since it was opened or last saved.
var dirty := false
## Asks whether to discard unsaved changes when leaving.
var discard_dialog: ConfirmationDialog
## Ids of collapsed regiments.
var collapsed := {}
## Id of the regiment being renamed, or empty.
var renaming := ""
## Focus key of the control that opened the picker, which gets focus back when it closes.
var _picker_opener := ""
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
@onready var builder_scroll: ScrollContainer = %BuilderScroll


func _ready() -> void:
	theme = UITheme.get_theme()
	back_button.icon = UITheme.icon("back")
	back_button.pressed.connect(request_back)
	save_button.pressed.connect(save)
	var shortcut := InputEventKey.new()
	shortcut.keycode = KEY_S
	shortcut.command_or_control_autoremap = true
	save_button.shortcut = Shortcut.new()
	save_button.shortcut.events = [shortcut]
	# Named once, for this platform: Command+S on macOS, else Ctrl+S.
	save_button.shortcut_in_tooltip = false
	save_button.tooltip_text = "Save army (%s)" % save_button.shortcut.get_as_text()
	discard_dialog = ConfirmationDialog.new()
	discard_dialog.title = "Unsaved changes"
	discard_dialog.dialog_text = "This army has unsaved changes."
	discard_dialog.ok_button_text = "Discard changes"
	discard_dialog.cancel_button_text = "Keep editing"
	discard_dialog.add_button("Save and go back", true, "save")
	discard_dialog.confirmed.connect(back_pressed.emit)
	discard_dialog.custom_action.connect(_on_discard_dialog_action)
	add_child(discard_dialog)
	info_pane = InfoPane.new(self)
	left_pane.add_child(info_pane)
	picker = Picker.new(self)
	picker.hide()
	picker.closed.connect(_on_picker_closed)
	left_pane.add_child(picker)
	drag = BuilderDragDrop.new(self)
	_add_remove_overlay()
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN and drag:
		drag.begin(get_viewport().gui_get_drag_data())
	elif what == NOTIFICATION_DRAG_END and drag:
		drag.end()


func _process(delta: float) -> void:
	drag.process(delta)


func _add_remove_overlay() -> void:
	var bin := TextureRect.new()
	bin.texture = UITheme.icon("delete")
	bin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bin.custom_minimum_size = Vector2(28, 28)
	bin.modulate = UITheme.DANGER
	var text := UIBuilder.label("Drop to remove from army", "CardTitleLabel")
	text.add_theme_color_override("font_color", UITheme.DANGER)
	var center := CenterContainer.new()
	center.add_child(UIBuilder.vbox([bin, text], 10))
	remove_overlay = UIBuilder.panel("RemoveDropPanel", center)
	remove_overlay.hide()
	drag.target(remove_overlay, _can_drop_remove, _drop_remove)
	left_pane.add_child(remove_overlay)


func _can_drop_remove(_at: Vector2, data: Dictionary) -> bool:
	if data.get("kind") != "unit" or editor.army.find_unit(data.get("uid", "")) == null:
		return false
	drag.highlight(remove_overlay, "RemoveDropOnPanel")
	return true


func _drop_remove(_at: Vector2, data: Dictionary) -> void:
	editor.remove_unit(data.uid)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if picker.is_open():
			picker.close()
		elif not renaming.is_empty():
			renaming = ""
			redraw()
		else:
			request_back()


## Starts editing [param army] with its faction's data, or [param army_catalog] if given.
func open(army: Army, army_catalog: ArmyCatalog = null) -> void:
	if army_catalog == null:
		var faction := FactionCatalog.load_faction(FactionCatalog.name_for_id(army.faction_id))
		army_catalog = ArmyCatalog.new(faction, CoreRulesCatalog.get_rules())
	catalog = army_catalog
	editor = ArmyEditor.new(army, catalog)
	editor.changed.connect(_on_army_changed)
	dirty = false
	info_pane.open()
	redraw()
	back_button.grab_focus()


func _on_army_changed() -> void:
	dirty = true
	redraw()


## Saves the army with [ArmyStore]. Returns whether it saved.
func save() -> bool:
	# Commit a name or count still being typed, e.g. when saving with Ctrl+S.
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit and is_ancestor_of(focused):
		focused.text_submitted.emit(focused.text)
	var error := ArmyStore.save(editor.army)
	if error != OK:
		push_error("Couldn't save the army: %s" % error_string(error))
		var failed := AcceptDialog.new()
		failed.title = "Couldn't save"
		failed.dialog_text = "The army couldn't be saved (%s)." % error_string(error)
		failed.confirmed.connect(failed.queue_free)
		failed.canceled.connect(failed.queue_free)
		add_child(failed)
		failed.popup_centered()
		return false
	dirty = false
	_draw_header()
	return true


## Leaves the builder, first asking whether to discard unsaved changes.
func request_back() -> void:
	if dirty:
		discard_dialog.popup_centered()
		discard_dialog.get_cancel_button().grab_focus()
	else:
		back_pressed.emit()


func _on_discard_dialog_action(action: StringName) -> void:
	if action == &"save":
		discard_dialog.hide()
		if save():
			back_pressed.emit()


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
	elif focused:
		var target := find_focus_key(self, key) if not key.is_empty() else null
		if target:
			target.grab_focus()
		elif not focused.is_visible_in_tree():
			_focus_fallback()


## Focuses something sensible after the focused control is gone, so the keyboard isn't stranded:
## the picker's first button while it's open, else the back button.
func _focus_fallback() -> void:
	if picker.is_open():
		picker.focus_first()
	else:
		back_button.grab_focus()


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
	points_label.add_theme_color_override("font_color", UITheme.DANGER if over else UITheme.TEXT)
	points_bar.max_value = maxi(army.points_limit, 1)
	points_bar.value = mini(total, army.points_limit)
	points_bar.add_theme_stylebox_override("fill", UITheme.box(UITheme.DANGER if over else UITheme.GOOD, Color.TRANSPARENT, 3))
	var saved := not dirty and not army.id.is_empty()
	save_button.text = "Saved" if saved else "Save army"
	save_button.disabled = saved
	var validation := ArmyValidator.validate(army, catalog)
	var kind: String
	if validation.overridden:
		status_label.text = "Constraints overridden"
		kind = "overridden"
	elif validation.is_valid():
		status_label.text = "Army valid"
		kind = "valid"
	else:
		var count := validation.problems.size()
		status_label.text = "%d problem%s" % [count, "" if count == 1 else "s"]
		kind = "problems"
	status_panel.add_theme_stylebox_override("panel", UITheme.pill(kind))
	status_label.add_theme_color_override("font_color", UITheme.STATUS[kind][1])


func _section(title: String, children: Array) -> VBoxContainer:
	var box := UIBuilder.vbox([UIBuilder.label(title, "SectionLabel")], 10)
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
		return UIBuilder.label("Army constraints are overridden, so the army isn't checked.", "MutedLabel", true)
	if validation.problems.is_empty() and validation.warnings.is_empty():
		return null
	var box := UIBuilder.vbox([], 8)
	for list: Array in [[validation.problems, "ProblemsPanel", "ProblemLabel"], [validation.warnings, "WarningsPanel", "WarningLabel"]]:
		var messages: PackedStringArray = list[0]
		if messages.is_empty():
			continue
		var lines := UIBuilder.vbox([], 4)
		for message in messages:
			lines.add_child(UIBuilder.label("• " + message, list[2], true))
		box.add_child(UIBuilder.panel(list[1], lines))
	return box


func _tactics_section() -> Control:
	var army := editor.army
	var row := UIBuilder.hbox([], 12)
	for slot in ArmyValidator.MAX_TACTICS:
		var card_name := army.tactics[slot] if slot < army.tactics.size() else ""
		var card := catalog.battle_tactic_card(card_name)
		var heading := "Battle tactics card %d" % (slot + 1)
		var slot_control: Control
		if card:
			var change := UIBuilder.button("Change", pick_tactic.bind(slot), "tactic:%d" % slot, "", "Change %s" % heading.to_lower())
			slot_control = TacticCard.new(card, false, heading, change)
			_link(slot_control, info_pane.show_tactic.bind(card.name), "Show %s in the Rules tab" % card.name, "tactic_card:%d" % slot)
		else:
			slot_control = UIBuilder.button("Choose " + heading.to_lower(), pick_tactic.bind(slot), "tactic:%d" % slot, "GhostButton")
			slot_control.custom_minimum_size.y = 92
		slot_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slot_control)
	return _section("Battle Tactics", [row])


func _army_list_section() -> Control:
	var children: Array = []
	for regiment in editor.army.regiments:
		children.append(RegimentPanel.new(self, regiment))
	var add_buttons := UIBuilder.hbox([
		UIBuilder.button("Add regiment", pick_leader.bind(""), "army:add_regiment", "GhostButton"),
		UIBuilder.button("Add Regiment of Renown", pick_regiment_of_renown, "army:add_ror", "GhostButton"),
	], 12)
	children.append(add_buttons)
	var section := _section("Army List", children)
	# A Regiment of Renown card from the info pane is dropped on the army list.
	var can_drop := func(at: Vector2, data: Dictionary) -> bool: return _can_drop_regiment_of_renown(at, data, section, add_buttons)
	drag.target(section, can_drop, _drop_regiment_of_renown)
	return section


func _can_drop_regiment_of_renown(_at: Vector2, data: Dictionary, section: Control, add_buttons: Control) -> bool:
	if data.get("kind") != "ror" or not editor.can_add_regiment_of_renown(data.get("name", "")):
		return false
	drag.show_line(section, add_buttons.get_global_rect(), false, 6)
	return true


func _drop_regiment_of_renown(_at: Vector2, data: Dictionary) -> void:
	editor.add_regiment_of_renown(data.name)


func _auxiliary_section() -> Control:
	var box := UIBuilder.vbox([], 10)
	for unit in editor.army.auxiliary:
		box.add_child(UnitRow.new(self, unit, null))
	var add := UIBuilder.button("Add auxiliary unit", pick_auxiliary, "army:add_aux", "GhostButton")
	box.add_child(add)
	auxiliary_box = UIBuilder.panel("DropBoxPanel", box)
	var can_drop := func(at: Vector2, data: Dictionary) -> bool: return _can_drop_auxiliary(at, data, box, add)
	drag.target(auxiliary_box, can_drop, _drop_auxiliary)
	return _section("Auxiliary Units", [auxiliary_box])


func _can_drop_auxiliary(_at: Vector2, data: Dictionary, box: Control, add: Control) -> bool:
	if not drag.accepts_unit(data, null):
		return false
	var rows := box.get_children().filter(func(n: Node) -> bool: return n is UnitRow)
	if rows.is_empty():
		drag.show_line(auxiliary_box, add.get_global_rect(), false)
	else:
		drag.show_line_in(auxiliary_box, rows, rows.size(), add)
	return true


func _drop_auxiliary(_at: Vector2, data: Dictionary) -> void:
	drag.place_unit(data, null, editor.army.auxiliary.size())


func _terrain_section() -> Control:
	var terrain := catalog.terrain_warscrolls()
	var army_roster := catalog.roster(editor.army)
	if terrain.is_empty() or (army_roster and not army_roster.faction_terrain):
		return null
	var items := [["None", ""]]
	for warscroll in terrain:
		items.append(["%s · %d pts" % [warscroll.name, warscroll.points] if warscroll.points else warscroll.name, warscroll.id])
	return _section("Faction Terrain", [UIBuilder.select(items, editor.army.faction_terrain, editor.set_faction_terrain,
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
		var lores := catalog.lore_choices(army, pick[0], pick[2])
		if lores.is_empty():
			continue
		var items := [["None", ""]]
		for lore in lores:
			var label := "%s · %d pts" % [lore.name, lore.points] if lore.points else lore.name
			items.append([label + (" (Legends)" if lore.legends else ""), lore.name])
		var help := UIBuilder.label("?", "MutedLabel")
		help.tooltip_text = LORE_HELP[pick[0]]
		help.mouse_filter = Control.MOUSE_FILTER_STOP
		if pick[3] and pick[2].is_empty():
			help.add_theme_color_override("font_color", UITheme.WARNING)
		var title := UIBuilder.label(pick[1])
		title.custom_minimum_size.x = 160
		var kind: String = pick[0]
		var choose := func(value: String) -> void:
			editor.set_lore(kind, value)
			if not value.is_empty():
				info_pane.show_lore(value)
		var select := UIBuilder.select(items, pick[2], choose, "lore:" + kind, pick[1])
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.append(UIBuilder.hbox([title, help, select]))
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
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused and not picker.is_ancestor_of(focused):
		_picker_opener = focused.get_meta(&"focus_key", "")
	info_pane.hide()
	picker.show()


## Hides the picker and returns focus to the control that opened it, as hiding the picker drops
## focus from its buttons.
func _on_picker_closed() -> void:
	picker.hide()
	info_pane.show()
	info_pane.refresh()
	if not is_inside_tree():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused and focused.is_visible_in_tree():
		return
	var opener := find_focus_key(builder_list, _picker_opener) if not _picker_opener.is_empty() else null
	if opener:
		opener.grab_focus()
	else:
		_focus_fallback()


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
