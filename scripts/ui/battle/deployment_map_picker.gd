class_name DeploymentMapPicker
extends Control
## Spearhead: the defender picks the deployment map and which territory is theirs (Pre-battle
## Sequence, step 4), over the dimmed battlefield. Each map is shown on the realm battlefield with
## territory A lighter than B. See docs/design/battle.md.

## The player picked [param map], taking territory A if [param player_has_a].
signal chosen(map: DeploymentMap, player_has_a: bool)

const DIM := Color(0.047, 0.051, 0.063, 0.72)

var battle: Battle
var map_buttons: Array[Button] = []
var territory_a_button: Button
var territory_b_button: Button
var confirm_button: Button
var preview_holder: Control
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
	_map = battle.battlepack.deployment_maps[0] if not battle.battlepack.deployment_maps.is_empty() else null
	var title := UIBuilder.label("Pick the deployment map", "DisplayTitleLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := UIBuilder.label("You're the defender: pick the map and which territory is yours. Territory A is the lighter one.", "DescriptionLabel")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var maps := UIBuilder.hbox([], 8)
	for map in battle.battlepack.deployment_maps:
		var button := UIBuilder.button(map.name, _pick_map.bind(map), "map_" + map.name, "TabButton")
		button.toggle_mode = true
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
	var card := UIBuilder.panel("CardPanel", UIBuilder.vbox([maps, preview_holder, territories, confirm_button], 16))
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var column := UIBuilder.vbox([title, subtitle, card], 20)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(column)
	add_child(center)
	_refresh()


func _ready() -> void:
	if not map_buttons.is_empty() and is_inside_tree():
		map_buttons[0].grab_focus()


## The map and territory picked so far.
func selection() -> Array:
	return [_map, _has_a]


func _pick_map(map: DeploymentMap) -> void:
	_map = map
	_refresh()


func _pick_territory(is_a: bool) -> void:
	_has_a = is_a
	_refresh()


func _confirm() -> void:
	if _map:
		chosen.emit(_map, _has_a)


func _refresh() -> void:
	for i in map_buttons.size():
		map_buttons[i].set_pressed_no_signal(battle.battlepack.deployment_maps[i] == _map)
	territory_a_button.set_pressed_no_signal(_has_a)
	territory_b_button.set_pressed_no_signal(not _has_a)
	for child in preview_holder.get_children():
		preview_holder.remove_child(child)
		child.queue_free()
	if _map and battle.realm:
		var preview := RealmMap.new(battle.battlepack, battle.realm, true, _map)
		preview.custom_minimum_size = Vector2(480, 352)
		preview.size_flags_horizontal = Control.SIZE_FILL
		preview_holder.add_child(preview)
	confirm_button.disabled = _map == null
	confirm_button.text = "Confirm: %s, territory %s" % [_map.name if _map else "-", "A" if _has_a else "B"]
