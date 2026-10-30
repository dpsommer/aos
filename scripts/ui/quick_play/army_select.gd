class_name ArmySelect
extends Control
## Quick Play's army step, for either game mode. The left pane lists the player's Forge armies
## (Matched Play) or every Spearhead, and the right shows the chosen army's rules and units. The
## left pane gives way to a unit's warscroll, a Regiment of Renown or the battleplans, each with
## Back to the list. Play is enabled once the army can play. See docs/design/quick-play.md.

signal back_pressed
## The player pressed Play with [param setup].
signal play_requested(setup: BattleSetup)
## The player asked to edit [param army] in the Forge's army builder.
signal edit_requested(army: Army)
## The player has no saved armies and asked to build one.
signal forge_requested

enum Pane { LIST, WARSCROLL, REGIMENT, PLANS }

## Lore kinds, in the order the Lores section shows them.
const LORE_KINDS: PackedStringArray = ["spell", "prayer", "manifestation"]
const SPEARHEAD_GROUPS := [
	["regiment", "Regiment Abilities", "Your army can use the one you choose."],
	["enhancement", "Enhancements", "Your general takes the one you choose."],
]

var mode := BattleSetup.Mode.MATCHED_PLAY
var pane := Pane.LIST
## The chosen battleplan's name, or empty for Random.
var battleplan := ""
## Matched Play: the saved armies, most recently saved first, and the chosen one's id.
var entries: Array[ArmyStore.Entry] = []
var army_id := ""
## Spearhead: the Spearheads shown ([method GameModeScreen.shown_spearheads]) and the chosen one.
var spearheads: Array[Dictionary] = []
var spearhead: Spearhead
var spearhead_faction: Faction
## The Spearhead's regiment ability and enhancement the player chose, or empty.
var regiment_ability := ""
var enhancement := ""
## The Spearhead list's search query.
var query := ""

## The chosen army's [method army_info], in Matched Play.
var _info := {}
## Keys of the cards shown in full, and of battle traits unfolded.
var _open := {}
## The control that opened the current pane, which gets focus back with the list.
var _opener: Control
var _plan_card: OptionCard
var _list_box: VBoxContainer
var _search: LineEdit
## The Spearhead choice cards by group key ("regiment" or "enhancement").
var _choice_cards := {}
## Holds each Spearhead group's "Choose 1" or "Chosen" chip, by group key.
var _choice_chips := {}
var _setup_pill: Control

@onready var back_button: Button = %BackButton
@onready var breadcrumb: HBoxContainer = %Breadcrumb
@onready var limit_label: Label = %LimitLabel
@onready var rules_label: Label = %RulesLabel
@onready var play_button: Button = %PlayButton
@onready var pane_box: VBoxContainer = %Pane
@onready var detail: ScrollContainer = %Detail
@onready var detail_column: VBoxContainer = %DetailColumn


func _ready() -> void:
	theme = UITheme.get_theme()
	back_button.icon = UITheme.icon("back")
	back_button.pressed.connect(back_pressed.emit)
	play_button.icon = UITheme.icon("play")
	play_button.pressed.connect(func() -> void: play_requested.emit(setup()))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _search and _search.has_focus() and not _search.text.is_empty():
		_search.clear()
		_on_search_changed("")
	else:
		go_back()


## Shows [param of]'s armies, choosing the army with id [param focus] (Matched Play) or the
## Spearhead named [param focus], else the first one.
func open(of: BattleSetup.Mode, focus := "") -> void:
	mode = of
	_clear(breadcrumb)
	breadcrumb.add_child(UIBuilder.breadcrumb(["Quick Play", BattleSetup.display_name(mode), "Army"], 2, "Quick Play steps"))
	if mode == BattleSetup.Mode.MATCHED_PLAY:
		entries = ArmyStore.list()
		var first := ""
		for entry in entries:
			if entry.id == focus or (first.is_empty() and _can_choose(entry)):
				first = entry.id
		_choose_army(first)
	else:
		spearheads = GameModeScreen.shown_spearheads()
		var chosen: Dictionary = spearheads[0] if not spearheads.is_empty() else {}
		for entry in spearheads:
			if entry.name == focus:
				chosen = entry
		_choose_spearhead(chosen)
	show_list()
	_focus_chosen()


## Goes back, as Escape does: from another pane to the list, else to the game mode.
func go_back() -> void:
	if pane != Pane.LIST:
		show_list()
	else:
		back_pressed.emit()


## Why the army can't play yet, which Play's tooltip shows, or empty if it can.
func play_blocker() -> String:
	if mode == BattleSetup.Mode.MATCHED_PLAY:
		if army_id.is_empty():
			return "Choose an army to play"
		if not _info.problems.is_empty() and not _info.overridden:
			return "Fix this army's problems to play"
		return ""
	if spearhead == null:
		return "Choose a Spearhead to play"
	var missing := PackedStringArray()
	if regiment_ability.is_empty():
		missing.append("a regiment ability")
	if enhancement.is_empty():
		missing.append("an enhancement")
	return "" if missing.is_empty() else "Choose %s to play" % " and ".join(missing)


## What the player has chosen, as Play hands it on.
func setup() -> BattleSetup:
	var result := BattleSetup.new()
	result.mode = mode
	result.battleplan = battleplan
	if mode == BattleSetup.Mode.MATCHED_PLAY:
		var entry := _entry(army_id)
		result.army = entry.army if entry else null
	elif spearhead:
		result.faction = spearhead_faction.name
		result.spearhead = spearhead.name
		result.regiment_ability = regiment_ability
		result.enhancement = enhancement
	return result


# --- Left pane ---


## Shows the list of armies or Spearheads, giving focus back to whatever opened the last pane.
func show_list() -> void:
	_set_pane(Pane.LIST)
	if mode == BattleSetup.Mode.MATCHED_PLAY:
		var count := entries.size()
		pane_box.add_child(_list_heading("Your armies", "%d arm%s · last saved first" % [count, "y" if count == 1 else "ies"]))
	else:
		pane_box.add_child(_list_heading("Spearheads", "%d armies" % spearheads.size()))
		_search = LineEdit.new()
		_search.placeholder_text = "Search Spearheads or factions"
		_search.accessibility_name = "Search Spearheads"
		_search.clear_button_enabled = true
		_search.right_icon = UITheme.small_icon("search")
		_search.text = query
		_search.text_changed.connect(_on_search_changed)
		pane_box.add_child(_search)
	_list_box = UIBuilder.vbox([], 8)
	pane_box.add_child(_scroll(_list_box))
	_fill_list()
	if is_instance_valid(_opener) and _opener.is_inside_tree():
		_opener.grab_focus()
	_opener = null


## Shows [param unit]'s warscroll in the left pane.
func show_warscroll(unit: Warscroll) -> void:
	_open_pane(Pane.WARSCROLL, "Warscroll")
	var catalog: ArmyCatalog = _info.get("catalog") if mode == BattleSetup.Mode.MATCHED_PLAY else null
	var card := WarscrollCard.new(unit, catalog.summoned if catalog else Callable(), show_warscroll)
	pane_box.add_child(_scroll(card))


## Shows [param regiment]'s units and rules in the left pane.
func show_regiment(regiment: RegimentOfRenown) -> void:
	_open_pane(Pane.REGIMENT, "Regiment of Renown")
	var catalog: ArmyCatalog = _info.get("catalog")
	pane_box.add_child(_scroll(RulesView.regiment_of_renown(regiment, catalog.summoned if catalog else Callable())))


## Shows the battlepack's battleplans to choose from in the left pane.
func show_plans() -> void:
	var core := CoreRulesCatalog.get_rules()
	if core == null or core.battlepack == null or _plan_card == null:
		return
	_open_pane(Pane.PLANS, "Choose battle plan", BattleplanPicker.legend())
	var picker := BattleplanPicker.new(core.battlepack, battleplan)
	picker.picked.connect(_on_plan_picked)
	pane_box.add_child(_scroll(picker))
	_plan_card.set_pressed_no_signal(true)
	_focus_later(picker.selected_card())


func _on_plan_picked(plan: String) -> void:
	battleplan = plan
	_opener = _plan_card
	_refresh_plan_card()
	show_list()


func _set_pane(shown: Pane) -> void:
	pane = shown
	_search = null
	_list_box = null
	_clear(pane_box)
	if _plan_card:
		_plan_card.set_pressed_no_signal(shown == Pane.PLANS)


## Opens a pane with Back to the list, [param title] and [param extra] (if not null) in its header.
func _open_pane(shown: Pane, title: String, extra: Control = null) -> void:
	if pane == Pane.LIST:
		_opener = get_viewport().gui_get_focus_owner()
	_set_pane(shown)
	var back := UIBuilder.button("Spearheads" if mode == BattleSetup.Mode.SPEARHEAD else "Armies", show_list, "", "",
			"Back to the list")
	back.icon = UITheme.icon("back")
	var heading := UIBuilder.label(title, "TitleLabel")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIBuilder.hbox([back, heading], 10)
	if extra:
		extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(extra)
	pane_box.add_child(row)
	_focus_later(back)


func _list_heading(title: String, count: String) -> HBoxContainer:
	var heading := UIBuilder.label(title, "CardHeadingLabel")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return UIBuilder.hbox([heading, UIBuilder.label(count, "MutedLabel")], 8)


func _fill_list() -> void:
	_clear(_list_box)
	if mode == BattleSetup.Mode.MATCHED_PLAY:
		var group := ButtonGroup.new()
		for entry in entries:
			_list_box.add_child(_army_entry(entry, group))
		if entries.is_empty():
			var forge := UIBuilder.button("Open the Forge", forge_requested.emit, "", "GoldButton")
			forge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_list_box.add_child(UIBuilder.panel("EmptyPanel", UIBuilder.vbox([
					UIBuilder.label("No saved armies yet", "CardHeadingLabel"),
					UIBuilder.label("Build an army in the Forge to bring it to Matched Play.", "DescriptionLabel", true),
					forge], 12)))
		return
	var words := RulesSearch.words(query)
	var group := ButtonGroup.new()
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var shown := spearheads.filter(func(entry: Dictionary) -> bool:
			return entry.alliance == alliance and RulesSearch.matches("%s %s" % [entry.name, entry.faction], words))
		if shown.is_empty():
			continue
		_list_box.add_child(UIBuilder.label(GrandAlliance.display_name(alliance).to_upper(), "StatNameLabel"))
		for entry: Dictionary in shown:
			_list_box.add_child(_spearhead_entry(entry, group))
	if _list_box.get_child_count() == 0:
		_list_box.add_child(UIBuilder.label("No Spearheads match \"%s\"." % query, "MutedLabel", true))


func _on_search_changed(text: String) -> void:
	query = text
	_fill_list()


## A saved army's entry: its faction's icon, name, faction and points, a "!" naming its problems,
## and Edit. Pressing it chooses the army.
func _army_entry(entry: ArmyStore.Entry, group: ButtonGroup) -> OptionCard:
	var info := army_info(entry)
	var card := _entry_card(group, entry.id == army_id, info.name)
	card.set_meta(&"army_id", entry.id)
	var lines: Array = [info.faction if not info.faction.is_empty() else info.note]
	if not info.rules.is_empty():
		lines[0] += " · " + info.rules
	if not info.points.is_empty():
		lines.append(" · ".join(Array([info.points, saved_when(entry.saved_at)]).filter(func(part: String) -> bool:
				return not part.is_empty())))
	var row := _entry_row(info.faction, info.name, lines)
	card.add(row)
	card.disabled = not _can_choose(entry)
	card.pressed.connect(_choose_army.bind(entry.id))
	var problems: PackedStringArray = info.problems
	if not problems.is_empty() and not info.overridden:
		var tip := "%d problem%s:\n• %s" % [problems.size(), "" if problems.size() == 1 else "s", "\n• ".join(problems)]
		var badge := UIBuilder.button("!", func() -> void: pass, "", "ProblemButton", tip)
		badge.accessibility_name = tip
		badge.focus_mode = Control.FOCUS_NONE
		badge.custom_minimum_size = Vector2(36, 36)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge)
	if entry.army and not info.faction.is_empty():
		var edit := UIBuilder.icon_button("rename", "Edit %s in the Forge" % info.name, edit_requested.emit.bind(entry.army), "")
		edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(edit)
	return card


func _spearhead_entry(entry: Dictionary, group: ButtonGroup) -> OptionCard:
	var chosen: bool = spearhead != null and spearhead.name == entry.name and spearhead_faction.name == entry.faction
	var card := _entry_card(group, chosen, entry.name)
	card.set_meta(&"spearhead", entry.name)
	card.add(_entry_row(entry.faction, entry.name, ["%s · %d units" % [entry.faction, entry.units]]))
	card.pressed.connect(_choose_spearhead.bind(entry))
	return card


func _entry_card(group: ButtonGroup, chosen: bool, title: String) -> OptionCard:
	var card := OptionCard.new()
	card.toggle_mode = true
	card.button_group = group
	card.button_pressed = chosen
	card.accessibility_name = title
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


## An entry's faction icon (or its initials), [param title] and [param lines] under it.
static func _entry_row(faction: String, title: String, lines: Array) -> HBoxContainer:
	var icon := UITheme.faction_icon(faction)
	var art := UIBuilder.icon_art(icon, 28) if icon else UIBuilder.art(UIBuilder.initials(faction if not faction.is_empty() else title))
	art.custom_minimum_size = Vector2(48, 48)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var text := UIBuilder.vbox([UIBuilder.label(title, "TitleLabel", true)], 3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for line: String in lines:
		text.add_child(UIBuilder.label(line, "MutedLabel", true))
	return UIBuilder.hbox([art, text], 14)


func _focus_chosen() -> void:
	if _list_box == null:
		return
	for card in _list_box.get_children():
		if card is OptionCard and card.button_pressed:
			card.grab_focus()
			return
	if not entries.is_empty() or not spearheads.is_empty():
		for card in _list_box.get_children():
			if card is OptionCard and not card.disabled:
				card.grab_focus()
				return
	back_button.grab_focus()


# --- Choosing ---


func _can_choose(entry: ArmyStore.Entry) -> bool:
	return entry.army != null and not FactionCatalog.name_for_id(entry.army.faction_id).is_empty()


func _entry(id: String) -> ArmyStore.Entry:
	for entry in entries:
		if entry.id == id:
			return entry
	return null


func _choose_army(id: String) -> void:
	var entry := _entry(id)
	army_id = id if entry and _can_choose(entry) else ""
	_info = army_info(entry) if not army_id.is_empty() else {}
	_open = {"trait:0": true}
	limit_label.text = "%d pts" % entry.army.points_limit if not army_id.is_empty() else "—"
	var core := CoreRulesCatalog.get_rules()
	rules_label.text = core.battlepack.name if core and core.battlepack else "Matched Play"
	_show_detail()


func _choose_spearhead(entry: Dictionary) -> void:
	spearhead = null
	spearhead_faction = FactionCatalog.load_faction(entry.faction) if not entry.is_empty() else null
	if spearhead_faction:
		for army in spearhead_faction.spearheads:
			if army.name == entry.name:
				spearhead = army
	regiment_ability = ""
	enhancement = ""
	_open = {"trait:0": true}
	limit_label.text = "Fixed roster"
	rules_label.text = "Spearhead"
	_show_detail()


func _choose(group: String, ability_name: String) -> void:
	var current: String = regiment_ability if group == "regiment" else enhancement
	var chosen := "" if current == ability_name else ability_name
	if group == "regiment":
		regiment_ability = chosen
	else:
		enhancement = chosen
	_update_choices()


# --- Detail ---


func _show_detail() -> void:
	_clear(detail_column)
	_choice_cards.clear()
	_choice_chips.clear()
	_plan_card = null
	_setup_pill = null
	if mode == BattleSetup.Mode.MATCHED_PLAY:
		if army_id.is_empty():
			detail_column.add_child(_empty("No army chosen", "Choose one of your armies on the left."))
		else:
			_matched_detail(_entry(army_id).army)
	elif spearhead == null:
		detail_column.add_child(_empty("No Spearhead chosen", "Choose a Spearhead on the left."))
	else:
		_spearhead_detail()
	detail.scroll_vertical = 0
	_update_play()


func _matched_detail(army: Army) -> void:
	var catalog: ArmyCatalog = _info.catalog
	# The pill follows the name, so the name doesn't stretch.
	var title := UIBuilder.label(_info.name, "PageTitleLabel")
	var title_row := UIBuilder.hbox([title, _status_pill()], 12)
	var subtitle: String = _info.faction + (" · " + _info.rules if not _info.rules.is_empty() else "")
	var heading := UIBuilder.vbox([title_row, UIBuilder.label(subtitle, "DescriptionLabel", true),
			UIBuilder.label(_info.points, "MutedLabel")], 8)
	detail_column.add_child(_top_row(heading))
	if not _info.problems.is_empty() and not _info.overridden:
		var lines := UIBuilder.vbox([], 4)
		for problem: String in _info.problems:
			lines.add_child(UIBuilder.label("• " + problem, "ProblemLabel", true))
		detail_column.add_child(UIBuilder.panel("ProblemsPanel", lines))

	var renown := catalog.army_of_renown(army.army_of_renown) if not army.army_of_renown.is_empty() else null
	var traits: Array[Ability] = renown.battle_traits if renown else catalog.faction.battle_traits
	if not traits.is_empty():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		for i in traits.size():
			grid.add_child(_trait_card(traits[i], i))
		detail_column.add_child(_section("Battle Traits", grid))

	var formation := catalog.battle_formation(army, army.formation) if not army.formation.is_empty() else null
	if formation:
		detail_column.add_child(_section("Battle Formation", _toggle_card("formation", formation.name,
				func(full: bool, eye: Control) -> Control: return FormationCard.new(formation, full, eye))))

	var tactics := UIBuilder.vbox([], 10)
	for slot in ArmyValidator.MAX_TACTICS:
		var card := catalog.battle_tactic_card(army.tactics[slot]) if slot < army.tactics.size() else null
		if card:
			var heading_text := "Slot %d" % (slot + 1)
			tactics.add_child(_toggle_card("tactic:%d" % slot, card.name, func(full: bool, eye: Control) -> Control:
				return TacticCard.new(card, TacticCard.Form.FULL if full else TacticCard.Form.SUMMARY, heading_text, eye)))
		else:
			tactics.add_child(_placeholder("No battle tactics card in slot %d" % (slot + 1)))
	var lores := UIBuilder.vbox([], 10)
	var missing := UIBuilder.hbox([], 10)
	for kind in LORE_KINDS:
		var lore_name := army.lore_name(kind)
		var lore := catalog.lore(army, kind, lore_name) if not lore_name.is_empty() else null
		if lore:
			lores.add_child(_toggle_card("lore:" + kind, lore.name, func(full: bool, eye: Control) -> Control:
				return LoreCard.new(lore, full, "%s Lore" % kind.capitalize(), eye, catalog.summoned)))
		else:
			var empty := _placeholder("No %s lore" % kind)
			empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			missing.add_child(empty)
	if missing.get_child_count() > 0:
		lores.add_child(missing)
	var columns := UIBuilder.hbox([_section("Battle Tactics", tactics), _section("Lores", lores)], 24)
	for column: Control in columns.get_children():
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_column.add_child(columns)

	var regiments := UIBuilder.vbox([], 12)
	for regiment in army.regiments:
		var meta := "%d unit%s · %d pts" % [regiment.units.size(), "" if regiment.units.size() == 1 else "s",
				ArmyPoints.regiment_points(regiment, army, catalog)]
		regiments.add_child(_regiment_panel(regiment.name, regiment.is_regiment_of_renown(), meta,
				regiment.units.map(func(unit: ArmyUnit) -> Control: return _army_portrait(army, unit, regiment))))
	if not army.auxiliary.is_empty():
		var points := 0
		for unit in army.auxiliary:
			points += ArmyPoints.unit_points(unit, null, army, catalog)
		regiments.add_child(_regiment_panel("Auxiliary Units", false, "%d units · %d pts" % [army.auxiliary.size(), points],
				army.auxiliary.map(func(unit: ArmyUnit) -> Control: return _army_portrait(army, unit, null))))
	if regiments.get_child_count() == 0:
		regiments.add_child(_placeholder("This army has no units yet"))
	detail_column.add_child(_section("Army", regiments, "Click a portrait to see its warscroll"))

	var terrain := catalog.faction.get_warscroll(army.faction_terrain) if not army.faction_terrain.is_empty() else null
	if terrain:
		var portrait := _portrait(terrain.name, "%d pts" % terrain.points, "", false, show_warscroll.bind(terrain),
				"%s warscroll" % terrain.name)
		detail_column.add_child(_section("Faction Terrain", _regiment_panel("", false, "", [portrait])))


func _spearhead_detail() -> void:
	var title := UIBuilder.label(spearhead.name, "PageTitleLabel", true)
	var subtitle := "%s · %s · General: %s" % [spearhead_faction.name, GrandAlliance.display_name(spearhead_faction.grand_alliance),
			spearhead.general]
	_setup_pill = UIBuilder.hbox()
	detail_column.add_child(_top_row(UIBuilder.vbox([title, UIBuilder.label(subtitle, "DescriptionLabel", true), _setup_pill], 8)))
	var columns := UIBuilder.hbox([], 24)
	var traits := UIBuilder.vbox([], 10)
	for i in spearhead.battle_traits.size():
		traits.add_child(_trait_card(spearhead.battle_traits[i], i))
	columns.add_child(_section("Battle Traits", traits))
	for group: Array in SPEARHEAD_GROUPS:
		var key: String = group[0]
		var abilities: Array[Ability] = spearhead.regiment_abilities if key == "regiment" else spearhead.enhancements
		var cards := UIBuilder.vbox([], 10)
		cards.accessibility_name = group[1]
		_choice_cards[key] = []
		for ability in abilities:
			var card := _choice_card(key, ability)
			_choice_cards[key].append(card)
			cards.add_child(card)
		cards.add_child(UIBuilder.label(group[2], "MutedLabel", true))
		_choice_chips[key] = UIBuilder.hbox()
		columns.add_child(_section(group[1], cards, "", _choice_chips[key]))
	for column: Control in columns.get_children():
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_column.add_child(columns)
	var portraits: Array = []
	var general := spearhead.get_warscroll(spearhead.general)
	portraits.append(_spearhead_portrait(spearhead.general, 1, general, true))
	for unit in spearhead.units:
		portraits.append(_spearhead_portrait(unit.name, unit.count, spearhead.get_warscroll(unit.name), false, unit.notes))
	detail_column.add_child(_section("Army", _regiment_panel("", false, "", portraits), "Click a portrait to see its warscroll"))
	_update_choices()


## The army's name and details, with the battleplan card on the right.
func _top_row(heading: Control) -> HBoxContainer:
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plan_card = OptionCard.new()
	_plan_card.toggle_mode = true
	_plan_card.custom_minimum_size.x = 360
	_plan_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_refresh_plan_card()
	_plan_card.pressed.connect(show_plans)
	return UIBuilder.hbox([heading, _plan_card], 24)


## Fills the battleplan card: Random or the chosen battleplan. Spearhead has no battleplans of its
## own in the game data yet, so its card is disabled.
func _refresh_plan_card() -> void:
	for child in _plan_card.content.get_children():
		_plan_card.content.remove_child(child)
		child.queue_free()
	var name_text := "Random"
	var sub := "Picked when the battle starts"
	var core := CoreRulesCatalog.get_rules()
	var plan := core.battlepack.get_battleplan(battleplan) if core and core.battlepack and not battleplan.is_empty() else null
	if plan:
		name_text = plan.name
		sub = BattleplanPicker.describe(plan)
	if mode == BattleSetup.Mode.SPEARHEAD:
		sub = "Spearhead battleplans aren't in the game yet"
	_plan_card.disabled = mode == BattleSetup.Mode.SPEARHEAD or core == null or core.battlepack == null
	_plan_card.accessibility_name = "Battle plan: %s" % name_text
	_plan_card.accessibility_description = sub
	_plan_card.tooltip_text = sub if _plan_card.disabled else "Choose the battle plan"
	var art := UIBuilder.icon_art(UITheme.icon("aos/white/misc/circle"), 28, 6)
	art.get_child(0).modulate = UITheme.GOLD
	art.custom_minimum_size = Vector2(64, 48)
	var text := UIBuilder.vbox([UIBuilder.label("BATTLE PLAN", "StatNameLabel"), UIBuilder.label(name_text, "TitleLabel", true),
			UIBuilder.label(sub, "MutedLabel", true)], 3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chevron := TextureRect.new()
	chevron.texture = UITheme.icon("chevron_right")
	chevron.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	chevron.modulate = UITheme.MUTED
	_plan_card.add(UIBuilder.hbox([art, text, chevron], 14))


func _status_pill() -> Control:
	var kind := "overridden" if _info.overridden else "valid" if _info.problems.is_empty() else "problems"
	var count: int = _info.problems.size()
	var text: String = {"overridden": "Constraints overridden", "valid": "Army valid",
			"problems": "%d problem%s" % [count, "" if count == 1 else "s"]}[kind]
	return _pill(text, kind)


static func _pill(text: String, kind: String) -> Control:
	var label := UIBuilder.label(text)
	label.add_theme_color_override("font_color", UITheme.STATUS[kind][1])
	var pill := UIBuilder.panel("", label)
	pill.add_theme_stylebox_override("panel", UITheme.pill(kind))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return pill


## A battle trait's card, folded unless it's open: the first starts open.
func _trait_card(rule: Ability, index: int) -> AbilityCard:
	var key := "trait:%d" % index
	var card := AbilityCard.new(rule)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.make_foldable(_open.has(key))
	card.fold_button.pressed.connect(func() -> void:
		if card.folded:
			_open.erase(key)
		else:
			_open[key] = true)
	return card


## A card built by [param make], given whether to show it in full and an eye toggle to put on it.
## Toggling the eye swaps the card for the other form in place, keeping focus on the eye.
func _toggle_card(key: String, card_name: String, make: Callable) -> Control:
	var full := _open.has(key)
	var eye := UIBuilder.icon_toggle("eye", ("Hide " if full else "Show ") + card_name + " rules", full,
			func(_on: bool) -> void: pass, key)
	var card: Control = make.call(full, eye)
	eye.toggled.connect(func(on: bool) -> void:
		if on:
			_open[key] = true
		else:
			_open.erase(key)
		var parent := card.get_parent()
		var index := card.get_index()
		var swapped := _toggle_card(key, card_name, make)
		parent.remove_child(card)
		card.queue_free()
		parent.add_child(swapped)
		parent.move_child(swapped, index)
		(swapped.get_meta(&"eye") as Button).grab_focus())
	card.set_meta(&"eye", eye)
	return card


## A Spearhead regiment ability or enhancement to choose: its ability card, folded until its eye
## shows it, with a check while it's chosen. Pressing it chooses it, or unchooses it if chosen.
func _choice_card(group: String, ability: Ability) -> PressableCard:
	var key := group + ":" + ability.name
	var card := PressableCard.new()
	card.card_name = ability.name
	var rules := AbilityCard.new(ability)
	rules.set_folded(not _open.has(key))
	var check := UIBuilder.check_badge()
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var eye := UIBuilder.icon_toggle("eye", "Show %s rules" % ability.name, not rules.folded, func(_on: bool) -> void: pass, key)
	eye.toggled.connect(func(on: bool) -> void:
		rules.set_folded(not on)
		eye.tooltip_text = ("Hide %s rules" if on else "Show %s rules") % ability.name
		eye.accessibility_name = eye.tooltip_text
		if on:
			_open[key] = true
		else:
			_open.erase(key))
	card.add_child(UIBuilder.vbox([UIBuilder.hbox([check, UIBuilder.spacer(), eye], 8), rules], 8))
	card.make_pressable("Choose " + ability.name)
	card.set_meta(&"ability", ability.name)
	card.set_meta(&"check", check)
	card.pressed.connect(_choose.bind(group, ability.name))
	return card


## Shows which Spearhead regiment ability and enhancement are chosen, and whether it can play.
func _update_choices() -> void:
	for group: String in _choice_cards:
		var chosen: String = regiment_ability if group == "regiment" else enhancement
		for card: PressableCard in _choice_cards[group]:
			var picked: bool = card.get_meta(&"ability") == chosen
			card.theme_type_variation = "PickedCardPanel" if picked else "CardPanel"
			(card.get_meta(&"check") as Control).modulate.a = 1.0 if picked else 0.0
			card.accessibility_description = ("Chosen. Press to unchoose " if picked else "Choose ") + card.card_name
		_clear(_choice_chips[group])
		_choice_chips[group].add_child(UITheme.chip("Chosen" if not chosen.is_empty() else "Choose 1",
				"" if not chosen.is_empty() else "gold"))
	if _setup_pill:
		_clear(_setup_pill)
		var blocker := play_blocker()
		_setup_pill.add_child(_pill("Ready to play" if blocker.is_empty() else blocker, "valid" if blocker.is_empty() else "overridden"))
	_update_play()


func _update_play() -> void:
	var blocker := play_blocker()
	play_button.disabled = not blocker.is_empty()
	play_button.tooltip_text = "Start the battle" if blocker.is_empty() else blocker


## A regiment's box: its name, a Regiment of Renown chip, [param meta], then [param portraits].
func _regiment_panel(title: String, renown: bool, meta: String, portraits: Array) -> PanelContainer:
	var box := UIBuilder.vbox([], 12)
	if not title.is_empty():
		var row := UIBuilder.hbox([UIBuilder.label(title, "TitleLabel")], 10)
		if renown:
			var chip := UITheme.chip("Regiment of Renown", "gold")
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(chip)
		var meta_label := UIBuilder.label(meta, "MutedLabel")
		meta_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(meta_label)
		box.add_child(row)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 14)
	for portrait: Control in portraits:
		flow.add_child(portrait)
	box.add_child(flow)
	return UIBuilder.panel("RenownRegimentPanel" if renown else "RegimentPanel", box)


func _army_portrait(army: Army, unit: ArmyUnit, regiment: ArmyRegiment) -> Control:
	var catalog: ArmyCatalog = _info.catalog
	var unit_scroll := catalog.warscroll(unit, regiment)
	var title := unit.label if not unit.label.is_empty() else unit_scroll.name if unit_scroll else unit.warscroll_id
	var general := unit.uid == army.general_uid
	var parts := PackedStringArray(["General"] if general else [])
	for type: String in unit.enhancements:
		if not unit.enhancements[type].is_empty():
			parts.append(unit.enhancements[type])
	parts.append("%d pts" % ArmyPoints.unit_points(unit, regiment, army, catalog))
	var count := "×%d" % WeaponOptions.models(unit_scroll, unit.reinforced) if unit_scroll else ""
	var open := Callable()
	var tooltip := ""
	if regiment and regiment.is_regiment_of_renown():
		var renown := catalog.regiment_of_renown(regiment.regiment_of_renown)
		if renown:
			open = show_regiment.bind(renown)
			tooltip = "%s: show the Regiment of Renown" % regiment.name
	elif unit_scroll:
		open = show_warscroll.bind(unit_scroll)
		tooltip = "%s%s: show its warscroll" % [title, ", General" if general else ""]
	return _portrait(title, " · ".join(parts), count, general, open, tooltip)


func _spearhead_portrait(unit_name: String, count: int, unit: Warscroll, general: bool, notes := "") -> Control:
	var open := show_warscroll.bind(unit) if unit else Callable()
	var sub := "General" if general else notes
	return _portrait(unit_name, sub, "×%d" % count, general, open, "%s%s: show its warscroll" % [unit_name, ", General" if general else ""])


## A unit's 112 px portrait, with the General's crown and its model count on it, and its name and
## [param sub] under it. With [param on_pressed], the portrait is a button that shows its rules.
static func _portrait(title: String, sub: String, count: String, general: bool, on_pressed: Callable, tooltip: String) -> VBoxContainer:
	var art := UIBuilder.portrait(title, on_pressed, tooltip, 112)
	art.add_theme_font_size_override("font_size", 22)
	if general:
		var crown := TextureRect.new()
		crown.texture = UITheme.icon("crown")
		crown.modulate = UITheme.GOLD
		crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crown.custom_minimum_size = Vector2(14, 14)
		var badge := UIBuilder.panel("", crown)
		badge.add_theme_stylebox_override("panel", UITheme.box(UITheme.WARNING_BG, UITheme.GOLD, 12, 4))
		badge.tooltip_text = "General"
		_pin(art, badge, Control.PRESET_TOP_LEFT)
	if not count.is_empty():
		var tally := UIBuilder.panel("", UIBuilder.label(count, "BodyLabel"))
		tally.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.BACKGROUND, 0.85), Color.TRANSPARENT, 4, 2))
		_pin(art, tally, Control.PRESET_BOTTOM_RIGHT)
	var name_label := UIBuilder.label(title, "CardTitleLabel", true)
	name_label.add_theme_font_size_override("font_size", 13)
	var box := UIBuilder.vbox([art, name_label], 6)
	if not sub.is_empty():
		box.add_child(UIBuilder.label(sub, "MutedLabel", true))
	box.custom_minimum_size.x = 112
	return box


static func _pin(art: Control, badge: Control, corner: Control.LayoutPreset) -> void:
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(badge)
	badge.set_anchors_and_offsets_preset(corner, Control.PRESET_MODE_MINSIZE, 6)


## [param title] in gold over [param content], with [param note] beside the title if given, and
## [param extra] at the end of its row if not null.
static func _section(title: String, content: Control, note := "", extra: Control = null) -> VBoxContainer:
	var heading := UIBuilder.hbox([UIBuilder.label(title, "GoldTitleLabel")], 12)
	if not note.is_empty():
		var note_label := UIBuilder.label(note, "MutedLabel")
		note_label.size_flags_vertical = Control.SIZE_SHRINK_END
		heading.add_child(note_label)
	if extra:
		extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		heading.add_child(UIBuilder.spacer())
		heading.add_child(extra)
	var section := UIBuilder.vbox([heading, content], 12)
	section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return section


## A dashed box saying a slot is empty, e.g. "No spell lore".
static func _placeholder(text: String) -> PanelContainer:
	var panel := UIBuilder.panel("", UIBuilder.label(text, "MutedLabel", true))
	panel.add_theme_stylebox_override("panel", DashedStyleBox.new(UITheme.CONTROL_BORDER, 8, 12))
	return panel


static func _empty(title: String, text: String) -> PanelContainer:
	return UIBuilder.panel("EmptyPanel", UIBuilder.vbox([UIBuilder.label(title, "CardHeadingLabel"),
			UIBuilder.label(text, "DescriptionLabel", true)], 8))


static func _scroll(content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll


## Gives [param control] focus once it's laid out, unless it has gone by then.
static func _focus_later(control: Control) -> void:
	(func() -> void:
		if is_instance_valid(control) and control.is_inside_tree():
			control.grab_focus()).call_deferred()


static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# --- Summaries ---


## A saved army's details, for its entry and the detail pane:
## [br]- [code]name[/code]: its name;
## [br]- [code]faction[/code]: its faction's name, or empty without data;
## [br]- [code]rules[/code]: its Army of Renown or battle formation, or empty;
## [br]- [code]points[/code]: its points against its limit, e.g. "1940 / 2000 pts", or empty;
## [br]- [code]problems[/code]: what [ArmyValidator] reports, and [code]overridden[/code], whether
## it overrides its constraints;
## [br]- [code]catalog[/code]: an [ArmyCatalog] for it, or null without faction data;
## [br]- [code]note[/code]: why it can't be chosen, or empty.
static func army_info(entry: ArmyStore.Entry) -> Dictionary:
	var info := {"name": "", "faction": "", "rules": "", "points": "", "problems": PackedStringArray(), "overridden": false,
			"catalog": null, "note": ""}
	var army := entry.army
	if army == null:
		info.name = "Unreadable army (%s)" % entry.id
		info.note = " ".join(entry.errors)
		return info
	info.name = army.name if not army.name.is_empty() else "Unnamed army"
	info.rules = army.army_of_renown if not army.army_of_renown.is_empty() else army.formation
	var faction_name := FactionCatalog.name_for_id(army.faction_id)
	var faction := FactionCatalog.load_faction(faction_name) if not faction_name.is_empty() else null
	if faction == null:
		info.note = "No data for the faction '%s'" % army.faction_id
		return info
	var catalog := ArmyCatalog.new(faction, CoreRulesCatalog.get_rules())
	info.faction = faction.name
	info.catalog = catalog
	info.points = "%d / %d pts" % [ArmyPoints.total(army, catalog), army.points_limit]
	var validation := ArmyValidator.validate(army, catalog)
	info.problems = validation.problems
	info.overridden = validation.overridden
	return info


## When an army was saved, from [param saved_at] (seconds since the Unix epoch) to [param now],
## in local days: "saved today", "saved yesterday", "saved 3 days ago", "saved last week",
## "saved 3 weeks ago" or "saved on 2 Mar 2026". Empty if it isn't known.
static func saved_when(saved_at: float, now: float = Time.get_unix_time_from_system()) -> String:
	if saved_at <= 0:
		return ""
	var offset: int = Time.get_time_zone_from_system().bias * 60
	var days := floori((now + offset) / 86400.0) - floori((saved_at + offset) / 86400.0)
	if days <= 0:
		return "saved today"
	if days == 1:
		return "saved yesterday"
	if days < 7:
		return "saved %d days ago" % days
	if days < 14:
		return "saved last week"
	if days < 60:
		return "saved %d weeks ago" % (days / 7)
	var date := Time.get_date_dict_from_unix_time(int(saved_at + offset))
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "saved on %d %s %d" % [date.day, MONTHS[date.month - 1], date.year]
