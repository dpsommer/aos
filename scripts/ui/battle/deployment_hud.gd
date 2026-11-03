class_name DeploymentHud
extends Control
## The deployment phase's overlay (the design's boards 5 and 6), under the header: a banner saying
## whose turn it is, the deployment abilities on the left, the placing panel on the right
## (how to place it, single-model mode, problems, Undo and Confirm) and the tray of regiments, units and terrain to set up
## along the bottom. [DeploymentController] drives it with [method refresh] and listens to its
## signals. See docs/design/battle.md.

signal unit_picked(unit: BattleUnit)
signal regiment_picked(regiment: BattleRegiment)
signal terrain_picked(feature: BattleTerrain)
signal ability_picked(entry: DeploymentAbility)
## Single-model mode on or off.
signal single_model_toggled
signal target_toggled(unit: BattleUnit)
signal confirm_pressed
signal undo_pressed
signal cancel_pressed
## Call off 'Deploy Regiment' before any of its units is set up.
signal call_off_pressed
signal pass_pressed

const TRAY_HEIGHT := 200.0
const PLAYER_EDGE := Color("#3D74A8")
const OPPONENT_EDGE := Color("#8C2A24")

var deployment: Deployment
## The player's army.
var army: BattleArmy
var banner: PanelContainer
var banner_title: Label
var banner_text: Label
var abilities_panel: PanelContainer
var placing_panel: PanelContainer
var tray: PanelContainer
var alert: PanelContainer
var alert_label: Label
var confirm_button: Button
var undo_button: Button
## The single-model mode toggle, while a unit of several models is being placed.
var single_model_button: Button
## Buttons in the tray by the unit, regiment or terrain feature they pick.
var tray_buttons := {}
var ability_buttons: Array[Button] = []
var target_buttons: Array[Button] = []
var pass_button: Button
var _state := {}


const TILE := preload("res://scenes/ui/battle/tray_tile.tscn")
const GROUP := preload("res://scenes/ui/battle/tray_group.tscn")


static func create(of: Deployment, player_army: BattleArmy) -> DeploymentHud:
	var hud: DeploymentHud = load("res://scenes/ui/battle/deployment_hud.tscn").instantiate()
	hud.deployment = of
	hud.army = player_army
	return hud


func _init() -> void:
	theme = UITheme.get_theme()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		banner = %Banner
		banner_title = %BannerTitle
		banner_text = %BannerText
		abilities_panel = %Abilities
		placing_panel = %Placing
		tray = %Tray


## Rebuilds the overlay for the deployment's current state and [param state], what the player is
## doing: [code]mode[/code] ("", "unit", "terrain", "choose" or "army": arranging a Spearhead army
## set out on the board), [code]unit[/code],
## [code]feature[/code], [code]single[/code] (single-model mode), [code]problems[/code], [code]entry[/code],
## [code]targets[/code], [code]selected[/code] and [code]busy[/code] (the AI's turn).
func refresh(state: Dictionary) -> void:
	_state = state
	_refresh_banner()
	_refresh_abilities()
	_refresh_placing()
	_refresh_tray()


## Whether the tray is showing, so other panels can stay above it.
func is_tray_visible() -> bool:
	return tray.visible


## Shows [param problems] with the placement in the placing panel, and disables Confirm while there
## are any.
func set_problems(problems: PackedStringArray) -> void:
	_state["problems"] = problems
	if alert:
		alert.visible = not problems.is_empty()
		alert_label.text = "\n".join(problems)
	if confirm_button:
		confirm_button.disabled = not problems.is_empty()


func _is_player_turn() -> bool:
	return deployment.active == army and not _state.get("busy", false)


# Banner

func _refresh_banner() -> void:
	var edge := PLAYER_EDGE
	if deployment.is_done():
		banner_title.text = "Deployment complete"
		banner_text.text = "Both armies are deployed. Battle rounds come next."
	elif deployment.active != army:
		edge = OPPONENT_EDGE
		banner_title.text = "Opponent's deployment"
		banner_text.text = _prompt(deployment.active)
	else:
		banner_title.text = "Your deployment"
		banner_text.text = _prompt(army)
	banner.add_theme_stylebox_override("panel", _banner_box(edge))
	_centre_banner.call_deferred()


## The banner's pill, edged in [param edge]: the side whose turn it is.
func _banner_box(edge: Color) -> StyleBox:
	return UITheme.box(Color(0.09, 0.102, 0.122, 0.94), edge, 999, 10)


## What [param who] is doing now, e.g. "Set up your faction terrain".
func _prompt(who: BattleArmy) -> String:
	var yours := who == army
	match deployment.step:
		Deployment.Step.TERRAIN:
			if deployment.battle.is_spearhead():
				return "Set up your terrain features" if yours else "Setting up terrain features"
			return "Set up your faction terrain" if yours else "Setting up faction terrain"
		Deployment.Step.UNITS:
			if deployment.regiment:
				return "Deploy Regiment: %s" % deployment.regiment.name
			if yours and deployment.deploys_whole_army(army):
				return "Move your units where you want them, then confirm"
			return "Deploy a unit or a regiment" if yours else "Deploying units"
		Deployment.Step.OTHER:
			return "Use deployment abilities, or finish" if yours else "Using deployment abilities"
	return ""


## Keeps the banner centred at the top, at its new width.
func _centre_banner() -> void:
	banner.reset_size()
	banner.offset_left = -banner.size.x / 2
	banner.offset_right = banner.size.x / 2


# Side panels

## Puts [param children] in [param panel]'s content, after the [param kept] children it always has,
## e.g. a heading, and shows the panel if any were given.
func _set_content(panel: PanelContainer, children: Array, kept := 0) -> void:
	var content: VBoxContainer = panel.get_node(^"Content")
	for child in content.get_children().slice(kept):
		content.remove_child(child)
		child.queue_free()
	for child: Control in children:
		content.add_child(child)
	panel.visible = not children.is_empty()
	# Shrink to the new content, once it has its size.
	panel.offset_bottom = panel.offset_top
	panel.reset_size.call_deferred()


func _heading(text: String) -> Label:
	var label := UIBuilder.label(text.to_upper(), "MutedLabel")
	label.add_theme_font_size_override("font_size", 11)
	return label


func _refresh_abilities() -> void:
	ability_buttons.clear()
	if deployment.is_done():
		_set_content(abilities_panel, [], 1)
		return
	var rows: Array = []
	for entry in army.deployment_abilities:
		if deployment.step_of(entry) == deployment.step:
			rows.append(_ability_row(entry))
	_set_content(abilities_panel, rows, 1)


func _ability_row(entry: DeploymentAbility) -> Button:
	var reason := deployment.reason_unavailable(army, entry)
	var usable := reason.is_empty() and _is_player_turn()
	var in_use := entry.kind() == DeploymentAbility.Kind.DEPLOY_REGIMENT and deployment.regiment != null \
			and deployment.active == army
	var choosing: DeploymentAbility = _state.get("entry")
	in_use = in_use or choosing == entry
	var status := ""
	if in_use:
		status = "In use"
	elif deployment.is_used(army, entry):
		status = "Used"
	elif entry.is_once_per_battle():
		status = "Once per battle"
	var hint := "%s · %s" % [entry.source, _hint(entry)] if reason.is_empty() else reason
	var button: Button = load("res://scenes/ui/battle/deployment_ability_button.tscn").instantiate()
	button.text = "%s%s\n%s" % [entry.label(), "  ·  " + status if not status.is_empty() else "", hint]
	button.tooltip_text = entry.ability.effect
	button.accessibility_name = "%s. %s" % [entry.label(), hint]
	var acts := entry.kind() in [DeploymentAbility.Kind.RESERVE, DeploymentAbility.Kind.RECORD]
	button.disabled = not (usable and acts)
	if acts:
		button.pressed.connect(func() -> void: ability_picked.emit(entry))
	ability_buttons.append(button)
	return button


func _hint(entry: DeploymentAbility) -> String:
	match entry.kind():
		DeploymentAbility.Kind.DEPLOY_UNIT:
			if deployment.deploys_whole_army(army):
				return "your units are set out: move them, then confirm"
			return "pick a unit from the tray"
		DeploymentAbility.Kind.DEPLOY_REGIMENT:
			return "pick a regiment's name in the tray"
		DeploymentAbility.Kind.DEPLOY_TERRAIN:
			return "pick a terrain feature from the tray"
		DeploymentAbility.Kind.RESERVE:
			return "set units up %s" % entry.reserve_name()
		DeploymentAbility.Kind.RECORD:
			return "its effect isn't applied yet"
	return "not supported yet"


func _refresh_placing() -> void:
	single_model_button = null
	target_buttons.clear()
	alert = null
	confirm_button = null
	undo_button = null
	pass_button = null
	if not _is_player_turn() or deployment.is_done():
		_set_content(placing_panel, [])
		return
	var content: Array
	match _state.get("mode", ""):
		"unit":
			content = _unit_placing()
		"terrain":
			content = _terrain_placing()
		"choose":
			content = _choosing()
		"army":
			content = _army_placing()
		_:
			content = _idle()
	_set_content(placing_panel, content)
	set_problems(_state.get("problems", PackedStringArray()))


func _idle() -> Array:
	if deployment.step == Deployment.Step.OTHER:
		pass_button = UIBuilder.button("Done with abilities", pass_pressed.emit, "pass", "GoldButton")
		return [_heading("Deployment abilities"),
			UIBuilder.label("Use an ability from the list, or finish this step.", "DescriptionLabel", true),
			pass_button]
	if deployment.regiment:
		return [_heading("Deploy Regiment"), _title(deployment.regiment.name),
			UIBuilder.label("Pick its next unit.", "DescriptionLabel", true), _regiment_chips(), _call_off_button()]
	return []


func _call_off_button() -> Button:
	var button := UIBuilder.button("Call off Deploy Regiment", call_off_pressed.emit, "call_off_regiment", "GhostButton")
	button.disabled = deployment.regiment.any_deployed()
	button.tooltip_text = "Deploy this regiment's units one at a time instead."
	return button


func _title(text: String) -> Label:
	return UIBuilder.label(text, "CardTitleLabel", true)


func _chip_flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	return flow


func _regiment_chips() -> Control:
	var flow := _chip_flow()
	for unit in deployment.regiment.units:
		var chip := UIBuilder.button("%s ×%d" % [unit.name, unit.model_count()], unit_picked.emit.bind(unit), "chip_" + unit.name, "KeyButton")
		chip.toggle_mode = true
		chip.set_pressed_no_signal(_state.get("unit") == unit)
		chip.disabled = unit.deployed
		flow.add_child(chip)
	return flow


func _unit_placing() -> Array:
	var unit: BattleUnit = _state.unit
	var children: Array = [_heading("Placing"), _title(unit.name),
		UIBuilder.label("%d model%s" % [unit.model_count(), "" if unit.model_count() == 1 else "s"], "MutedLabel")]
	if deployment.regiment:
		children.append(_regiment_chips())
		if not deployment.regiment.any_deployed():
			children.append(_call_off_button())
	children.append_array(_unit_controls(unit))
	children.append(_alert())
	children.append(_buttons(_next_text()))
	return children


## How to place [param unit], and the single-model mode toggle if it has several models.
func _unit_controls(unit: BattleUnit) -> Array:
	var children: Array = []
	if unit.model_count() == 1:
		children.append(UIBuilder.label("Click to put it down. Press and drag to turn it: it faces left of the drag, so dragging left to right faces it forward. Click it to pick it up again.", "MutedLabel", true))
		return children
	children.append(UIBuilder.label("Click to put it down as it is. Press and drag to line it up: the front rank runs from where you press along the drag, as wide as you drag and coherency allows, facing left of it (left to right faces forward). Click a model to pick the unit up again.", "MutedLabel", true))
	var key := BattleHud.key_for("single_model_mode")
	var on: bool = _state.get("single", false)
	single_model_button = UIBuilder.button("%s   Single-model mode: %s" % [key, "on" if on else "off"], single_model_toggled.emit, "single_model", "KeyButton")
	single_model_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	single_model_button.toggle_mode = true
	single_model_button.set_pressed_no_signal(on)
	single_model_button.tooltip_text = "Click a model to pick up just that model, to move models one at a time."
	single_model_button.accessibility_name = "Single-model mode, %s, key %s" % ["on" if on else "off", key]
	children.append(single_model_button)
	return children


## Arranging a Spearhead army set out on the board: how to place the picked unit, every problem,
## and one Confirm for the lot.
func _army_placing() -> Array:
	var unit: BattleUnit = _state.get("unit")
	var children: Array = [_heading("Deploy your army"),
		UIBuilder.label("Your units are set out in your deployable zone. Click a unit to pick it up. Blue: it can go there.", "MutedLabel", true)]
	if unit:
		children.append(_title(unit.name))
		children.append_array(_unit_controls(unit))
	else:
		children.append(UIBuilder.label("Pick a unit on the board or in the tray to move it or line it up.", "DescriptionLabel", true))
	children.append(_alert())
	var other := deployment.battle.enemy_of(army)
	children.append(_buttons("deploy all · %s" % ("opponent next" if deployment.has_work(other) else "next step")))
	confirm_button.text = "Confirm deployment"
	undo_button.disabled = unit == null
	return children


func _terrain_placing() -> Array:
	var feature: BattleTerrain = _state.feature
	var rule := "Set it up wholly within friendly territory, more than 3\" from all objectives and other terrain features."
	if deployment.battle.is_spearhead():
		rule = "Set it up wholly within friendly territory, more than 6\" from other terrain features, more than 3\" from enemy territory and the long edges, and not on an objective."
	var children: Array = [_heading("Set up terrain" if deployment.battle.is_spearhead() else "Deploy faction terrain"), _title(feature.name),
		UIBuilder.label(rule, "DescriptionLabel", true)]
	if deployment.is_cramped(army, feature):
		var note := UIBuilder.label("There's no room left for the gap from other terrain features, so it only has to keep clear of them.", "WarningLabel", true)
		children.append(note)
	return children + [
		UIBuilder.label("Click to put it down. Press and drag to turn it: its length runs along the drag. Click it to pick it up again. Blue: it can go there.", "MutedLabel", true),
		_alert(), _buttons(_next_text())]


func _choosing() -> Array:
	var entry: DeploymentAbility = _state.entry
	var targets: Array = _state.get("targets", [])
	var selected: Array = _state.get("selected", [])
	var multi: bool = _state.get("multi", false)
	var children: Array = [_heading(entry.source), _title(entry.name())]
	if not entry.ability.declare.is_empty():
		children.append(UIBuilder.label("Declare: " + entry.ability.declare, "DescriptionLabel", true))
	children.append(UIBuilder.label("Effect: " + entry.ability.effect, "DescriptionLabel", true))
	if not targets.is_empty():
		children.append(UIBuilder.label("Pick the targets:" if multi else "Pick the target (optional):", "SectionLabel"))
		var flow := _chip_flow()
		for unit: BattleUnit in targets:
			var chip := UIBuilder.button(unit.name, target_toggled.emit.bind(unit), "target_" + unit.name, "KeyButton")
			chip.toggle_mode = true
			chip.set_pressed_no_signal(unit in selected)
			target_buttons.append(chip)
			flow.add_child(chip)
		children.append(flow)
	if entry.kind() == DeploymentAbility.Kind.RECORD:
		children.append(UIBuilder.label("Its use is recorded; its effect isn't applied yet.", "MutedLabel", true))
	children.append(_alert())
	var confirm_text := "Set up %s" % entry.reserve_name() if entry.kind() == DeploymentAbility.Kind.RESERVE else "Use"
	children.append(_buttons(confirm_text, "Cancel"))
	return children


func _alert() -> PanelContainer:
	alert = load("res://scenes/ui/battle/placement_alert.tscn").instantiate()
	alert_label = alert.get_node(^"%Text")
	return alert


func _buttons(confirm_text: String, back_text := "Undo") -> HBoxContainer:
	var row: HBoxContainer = load("res://scenes/ui/battle/placing_buttons.tscn").instantiate()
	undo_button = row.get_node(^"%Undo")
	undo_button.text = back_text
	undo_button.pressed.connect(cancel_pressed.emit if back_text == "Cancel" else undo_pressed.emit)
	undo_button.tooltip_text = "Put it back where it started (%s)" % BattleHud.key_for("undo_placement") if back_text == "Undo" else ""
	confirm_button = row.get_node(^"%Confirm")
	confirm_button.pressed.connect(confirm_pressed.emit)
	confirm_button.tooltip_text = confirm_text
	confirm_button.text = "Confirm · %s" % confirm_text if back_text == "Undo" else confirm_text
	return row


## Who goes after this placement, for Confirm's subtitle.
func _next_text() -> String:
	if deployment.regiment and deployment.regiment.units.filter(func(u: BattleUnit) -> bool: return not u.deployed).size() > 1:
		return "next unit in the regiment"
	var other := deployment.battle.enemy_of(army)
	if deployment.alternates(deployment.step) and deployment.has_work(other):
		return "opponent next"
	return "you go again"


# Tray

func _refresh_tray() -> void:
	tray_buttons.clear()
	var row: HBoxContainer = %Groups
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	var groups: Array = []
	match deployment.step:
		Deployment.Step.TERRAIN:
			if not army.terrain.is_empty():
				groups.append(_terrain_group())
		Deployment.Step.UNITS:
			for regiment in army.regiments:
				groups.append(_regiment_group(regiment))
			var loose: Array[BattleUnit] = []
			for unit in army.units:
				if unit.regiment == null:
					loose.append(unit)
			if not loose.is_empty():
				groups.append(_unit_group("Units" if deployment.battle.is_spearhead() else "Auxiliary units", loose))
	tray.visible = not groups.is_empty() and not deployment.is_done()
	for group: Control in groups:
		row.add_child(group)


## A group of [param tiles] in the tray under [param heading]: a label's text, or a [Button].
## [param highlight] edges it in the player's colour, e.g. the regiment being deployed.
func _group_panel(heading: Variant, tiles: Array, highlight := false) -> PanelContainer:
	var panel: PanelContainer = GROUP.instantiate()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.141, 0.322, 0.494, 0.18) if highlight else Color("#1A1D23"),
			PLAYER_EDGE if highlight else UITheme.BORDER, 10, 10, 2 if highlight else 1))
	if heading is Control:
		var stack: VBoxContainer = panel.get_node(^"%Stack")
		stack.add_child(heading)
		stack.move_child(heading, 0)
	else:
		var label: Label = panel.get_node(^"%Heading")
		label.text = heading
		label.visible = true
	var row: HBoxContainer = panel.get_node(^"%Tiles")
	for tile: Control in tiles:
		row.add_child(tile)
	return panel


func _regiment_group(regiment: BattleRegiment) -> PanelContainer:
	var blocker := deployment.regiment_blocker(regiment)
	var deploying := deployment.regiment == regiment
	var header := UIBuilder.button(regiment.name, regiment_picked.emit.bind(regiment), "regiment_" + regiment.name, "SubheadButton")
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.disabled = not _is_player_turn() or deployment.step != Deployment.Step.UNITS \
			or not regiment in deployment.regiments_available(army)
	if regiment.all_deployed():
		header.text = "%s · Deployed" % regiment.name
	elif deploying:
		header.text = "%s · Deploying" % regiment.name
	elif not blocker.is_empty():
		header.text = "%s · Deploy unit by unit" % regiment.name
	header.tooltip_text = blocker if not blocker.is_empty() else "Deploy Regiment: set up all of it before the opponent goes."
	header.accessibility_name = "%s. %s" % [header.text, header.tooltip_text]
	tray_buttons[regiment] = header
	var tiles: Array = []
	for unit in regiment.units:
		tiles.append(_unit_tile(unit))
	return _group_panel(header, tiles, deploying)


func _unit_group(title: String, units: Array[BattleUnit]) -> PanelContainer:
	var tiles: Array = []
	for unit in units:
		tiles.append(_unit_tile(unit))
	return _group_panel(title, tiles)


func _unit_tile(unit: BattleUnit) -> Button:
	var status := ""
	if unit.deployed:
		status = "In reserve: %s" % unit.reserve if not unit.reserve.is_empty() else "Deployed"
	var tile := _tile("%s\n×%d%s" % [unit.name, unit.model_count(), "\n" + status if not status.is_empty() else ""],
			unit_picked.emit.bind(unit), "unit_%d" % unit.get_instance_id(), 110, _state.get("unit") == unit)
	tile.disabled = not _is_player_turn() or not unit in deployment.pickable_units(army)
	tile.tooltip_text = "Deploy Unit: set %s up on its own" % unit.name if not unit.deployed else status
	if not unit.deployed and deployment.deploys_whole_army(army):
		tile.tooltip_text = "Pick %s to move it" % unit.name
	tile.accessibility_name = "%s, %d models. %s" % [unit.name, unit.model_count(), status if not status.is_empty() else "Deploy it"]
	tray_buttons[unit] = tile
	return tile


## A tray tile [param width] wide showing [param text], pressed in if it's [param picked].
func _tile(text: String, on_pressed: Callable, id: String, width: float, picked: bool) -> Button:
	var tile: Button = TILE.instantiate()
	tile.text = text
	tile.pressed.connect(on_pressed)
	tile.set_meta(&"focus_key", id)
	tile.custom_minimum_size.x = width
	tile.set_pressed_no_signal(picked)
	return tile


func _terrain_group() -> PanelContainer:
	var tiles: Array = []
	for feature in army.terrain:
		var tile := _tile("%s%s" % [feature.name, "\nSet up" if feature.placed else ""],
				terrain_picked.emit.bind(feature), "terrain_%d" % feature.get_instance_id(), 132, _state.get("feature") == feature)
		tile.disabled = not _is_player_turn() or feature.placed
		tile.accessibility_name = "%s%s" % [feature.name, ", set up" if feature.placed else ", set it up"]
		tray_buttons[feature] = tile
		tiles.append(tile)
	return _group_panel("Terrain features" if deployment.battle.is_spearhead() else "Faction terrain", tiles)
