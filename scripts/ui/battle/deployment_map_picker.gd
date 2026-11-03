class_name DeploymentMapPicker
extends Control
## Spearhead: the defender picks the side of the realm battlefield (Pre-battle Sequence, step 3),
## then the deployment map and which territory is theirs (step 4), over the dimmed battlefield.
## Each map is shown on the chosen side with territory A lighter than B. See docs/design/battle.md.

## The player picked [param side] of the realm battlefield and [param map], taking territory A if
## [param player_has_a].
signal chosen(side: RealmBattlefield, map: DeploymentMap, player_has_a: bool)

const DIM := Color(0.047, 0.051, 0.063, 0.72)

var battle: Battle
var realm_buttons: Array[Button] = []
var map_buttons: Array[Button] = []
var territory_a_button: Button
var territory_b_button: Button
var confirm_button: Button
var preview_holder: Control
var _realm: RealmBattlefield
var _map: DeploymentMap
var _has_a := true


func _init(of: Battle) -> void:
	battle = of
	name = "DeploymentMapPicker"
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var pack := battle.battlepack
	_realm = battle.realm if battle.realm else (pack.realms[0] if not pack.realms.is_empty() else null)
	_map = pack.deployment_maps[0] if not pack.deployment_maps.is_empty() else null
	var title := UIBuilder.label("Pick the battlefield", "DisplayTitleLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := UIBuilder.label("You're the defender: pick the side of the %s realm battlefield, the deployment map and which territory is yours. Territory A is the lighter one." % pack.name, "DescriptionLabel")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var realms := UIBuilder.hbox([], 8)
	for realm in pack.realms:
		var button := UIBuilder.button(realm.name, _pick_realm.bind(realm), "realm_" + realm.name, "TabButton")
		button.toggle_mode = true
		button.accessibility_name = "Side: %s" % realm.name
		realm_buttons.append(button)
		realms.add_child(button)
	realms.alignment = BoxContainer.ALIGNMENT_CENTER
	var maps := UIBuilder.hbox([], 8)
	for map in battle.battlepack.deployment_maps:
		var button := UIBuilder.button(map.name, _pick_map.bind(map), "map_" + map.name, "TabButton")
		button.toggle_mode = true
		button.accessibility_name = "Deployment map: %s" % map.name
		map_buttons.append(button)
		maps.add_child(button)
	maps.alignment = BoxContainer.ALIGNMENT_CENTER
	territory_a_button = UIBuilder.button("Territory A", _pick_territory.bind(true), "territory_a", "TabButton")
	territory_b_button = UIBuilder.button("Territory B", _pick_territory.bind(false), "territory_b", "TabButton")
	for button in [territory_a_button, territory_b_button]:
		button.toggle_mode = true
	var territories := UIBuilder.hbox([territory_a_button, territory_b_button], 8)
	territories.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_holder = CenterContainer.new()
	preview_holder.custom_minimum_size = Vector2(480, 352)
	confirm_button = UIBuilder.button("Confirm", _confirm, "confirm", "GoldButton")
	confirm_button.custom_minimum_size = Vector2(220, 44)
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var card := UIBuilder.panel("CardPanel", UIBuilder.vbox([_row("Side", realms), _row("Deployment map", maps), preview_holder,
			_row("Your territory", territories), confirm_button], 16))
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var column := UIBuilder.vbox([title, subtitle, card], 20)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(column)
	add_child(center)
	_refresh()


func _ready() -> void:
	if not realm_buttons.is_empty() and is_inside_tree():
		realm_buttons[0].grab_focus()


## The side, map and territory picked so far: [side, map, whether the player has territory A].
func selection() -> Array:
	return [_realm, _map, _has_a]


## A labelled row of tabs.
static func _row(heading: String, tabs: Control) -> VBoxContainer:
	var label := UIBuilder.label(heading.to_upper(), "StatNameLabel")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return UIBuilder.vbox([label, tabs], 6)


func _pick_realm(realm: RealmBattlefield) -> void:
	_realm = realm
	_refresh()


func _pick_map(map: DeploymentMap) -> void:
	_map = map
	_refresh()


func _pick_territory(is_a: bool) -> void:
	_has_a = is_a
	_refresh()


func _confirm() -> void:
	if _realm and _map:
		chosen.emit(_realm, _map, _has_a)


func _refresh() -> void:
	for i in realm_buttons.size():
		realm_buttons[i].set_pressed_no_signal(battle.battlepack.realms[i] == _realm)
	for i in map_buttons.size():
		map_buttons[i].set_pressed_no_signal(battle.battlepack.deployment_maps[i] == _map)
	territory_a_button.set_pressed_no_signal(_has_a)
	territory_b_button.set_pressed_no_signal(not _has_a)
	for child in preview_holder.get_children():
		preview_holder.remove_child(child)
		child.queue_free()
	if _map and _realm:
		var preview := RealmMap.new(battle.battlepack, _realm, true, _map)
		preview.custom_minimum_size = Vector2(480, 352)
		preview.size_flags_horizontal = Control.SIZE_FILL
		preview_holder.add_child(preview)
	confirm_button.disabled = _map == null or _realm == null
	confirm_button.text = "Confirm: %s, %s, territory %s" % [_realm.name if _realm else "-", _map.name if _map else "-", "A" if _has_a else "B"]
