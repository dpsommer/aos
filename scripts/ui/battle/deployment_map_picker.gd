class_name DeploymentMapPicker
extends Control
## Spearhead: the defender picks the side of the realm battlefield (Pre-battle Sequence, step 3),
## then the deployment map and which territory is theirs (step 4), over the dimmed battlefield.
## Each map is shown on the chosen side with its territories marked A and B. The map is on the
## left and the choices on the right, so it fits a short screen. See docs/design/battle.md.

## The player picked [param side] of the realm battlefield and [param map], taking territory A if
## [param player_has_a].
signal chosen(side: RealmBattlefield, map: DeploymentMap, player_has_a: bool)

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


static func create(of: Battle) -> DeploymentMapPicker:
	var picker: DeploymentMapPicker = load("res://scenes/ui/battle/deployment_map_picker.tscn").instantiate()
	picker._fill(of)
	return picker


func _init() -> void:
	theme = UITheme.get_theme()


func _fill(of: Battle) -> void:
	battle = of
	territory_a_button = %TerritoryA
	territory_b_button = %TerritoryB
	confirm_button = %Confirm
	preview_holder = %Preview
	var pack := battle.battlepack
	_realm = battle.realm if battle.realm else (pack.realms[0] if not pack.realms.is_empty() else null)
	_map = pack.deployment_maps[0] if not pack.deployment_maps.is_empty() else null
	(%Subtitle as Label).text = "You're the defender: pick the side of the %s realm battlefield, the deployment map and which territory is yours." % pack.name
	for realm in pack.realms:
		var button := UIBuilder.button(realm.name, _pick_realm.bind(realm), "realm_" + realm.name, "TabButton")
		button.toggle_mode = true
		button.accessibility_name = "Side: %s" % realm.name
		realm_buttons.append(button)
		%Realms.add_child(button)
	for map in pack.deployment_maps:
		var button := UIBuilder.button(map.name, _pick_map.bind(map), "map_" + map.name, "TabButton")
		button.toggle_mode = true
		button.accessibility_name = "Deployment map: %s" % map.name
		map_buttons.append(button)
		%Maps.add_child(button)
	_refresh()


func _ready() -> void:
	if not realm_buttons.is_empty() and is_inside_tree():
		realm_buttons[0].grab_focus()


## The side, map and territory picked so far: [side, map, whether the player has territory A].
func selection() -> Array:
	return [_realm, _map, _has_a]


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
	UIBuilder.clear(preview_holder)
	if _map and _realm:
		var preview := RealmMap.new(battle.battlepack, _realm, true, _map)
		preview.custom_minimum_size = Vector2(480, 352)
		preview.size_flags_horizontal = Control.SIZE_FILL
		preview_holder.add_child(preview)
	confirm_button.disabled = _map == null or _realm == null
	confirm_button.text = "Confirm: %s, %s, territory %s" % [_realm.name if _realm else "-", _map.name if _map else "-", "A" if _has_a else "B"]
