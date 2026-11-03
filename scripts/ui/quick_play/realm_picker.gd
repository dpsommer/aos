class_name RealmPicker
extends VBoxContainer
## Spearhead's battleplans to choose from: Random, then each battlepack's realm battlefield (Fire
## and Jade, Sand and Bone, City of Ash), with a small map of each of its sides. Each battlepack has
## one battleplan; the defender picks which side to fight on after the roll-off. An eye shows a
## battlepack in full: larger maps of its sides, the deployment maps, the setup, starting relics,
## twist decks and scoring. Pressing a card chooses it.

## The player chose the battlepack called [param battlepack], or Random if it's empty.
signal picked(battlepack: String)

var battlepacks: Array[SpearheadBattlepack]
## The chosen battlepack's name, or empty for Random.
var selected := ""
## The cards by battlepack name, Random's under "".
var cards := {}
## Names of the battlepacks shown in full.
var _open := {}


static func create(packs: Array[SpearheadBattlepack], chosen := "") -> RealmPicker:
	var picker: RealmPicker = load("res://scenes/ui/quick_play/realm_picker.tscn").instantiate()
	picker._fill(packs, chosen)
	return picker


func _fill(packs: Array[SpearheadBattlepack], chosen: String) -> void:
	battlepacks = packs
	selected = chosen
	cards[""] = _random_card()
	add_child(cards[""])
	for pack in battlepacks:
		cards[pack.name] = _pack_card(pack)
		add_child(cards[pack.name])


## The chosen card, to give it focus when the picker opens.
func selected_card() -> Control:
	return cards.get(selected, cards[""])


## The battlepack whose realm battlefield has a side named [param realm], or null.
static func battlepack_of(packs: Array[SpearheadBattlepack], realm: String) -> SpearheadBattlepack:
	for pack in packs:
		if pack.get_realm(realm):
			return pack
	return null


func _random_card() -> PressableCard:
	var card := BattleplanPicker.random_card(
			"One of the %d realm battlefields below, picked when the battle starts." % battlepacks.size(),
			selected.is_empty(), "Pick a realm battlefield at random when the battle starts")
	_set_up_card(card, "Random", "")
	return card


## [param pack]'s card, in brief or, if it's open, in full.
func _pack_card(pack: SpearheadBattlepack) -> PressableCard:
	var full: bool = _open.has(pack.name)
	var sides := PackedStringArray()
	var maps := UIBuilder.hbox([], 6)
	for realm in pack.realms:
		sides.append(realm.name)
		maps.add_child(RealmMap.new(pack, realm))
	var card := BattleplanPicker.choice_card(maps, pack.name, "Sides: %s · the defender picks one" % " or ".join(sides),
			selected == pack.name, full, "pack:" + pack.name)
	_set_up_card(card, pack.name, pack.name)
	if full:
		_add_details(card.get_node(^"%Stack"), pack)
	card.make_pressable("Choose %s" % pack.name)
	(card.get_meta(&"eye") as Button).toggled.connect(_on_eye_toggled.bind(pack))
	return card


func _add_details(content: VBoxContainer, pack: SpearheadBattlepack) -> void:
	content.add_child(HSeparator.new())
	for realm in pack.realms:
		_add_side(content, pack, realm)
	if not pack.deployment_maps.is_empty() and not pack.realms.is_empty():
		content.add_child(_deployment_maps(pack, pack.realms[0]))
	for section in pack.battleplan_sections:
		if section.name == "Pre-battle Sequence":
			content.add_child(BattleplanPicker.rules_block("Setup", section.text))
	if not pack.scoring.is_empty():
		content.add_child(BattleplanPicker.rules_block("Scoring", "\n".join(pack.scoring)))


## One side of [param pack]'s realm battlefield in full: its map, starting relics and twist deck.
func _add_side(content: VBoxContainer, pack: SpearheadBattlepack, realm: RealmBattlefield) -> void:
	content.add_child(_heading(realm.name))
	content.add_child(RealmMap.new(pack, realm, true))
	var key := PackedStringArray(["%d\" × %d\"" % [pack.battlefield_size.x, pack.battlefield_size.y],
			"gold: objectives, contested by models on them"])
	if not realm.roads.is_empty():
		key.append("grey: roads")
	if not realm.terrain.is_empty():
		key.append("dashed: %s" % ", ".join(realm.terrain.map(func(feature: MapFeature) -> String: return feature.type)))
	content.add_child(UIBuilder.label(" · ".join(key), "MutedLabel", true))
	if not realm.starting_relics.is_empty():
		content.add_child(_heading("Starting relics"))
	for relic_name in realm.starting_relics:
		var relic := pack.get_relic(relic_name)
		if relic:
			content.add_child(AbilityCard.create(relic))
	if not realm.twists.is_empty():
		content.add_child(_twists(realm))


## The battlepack's deployment maps on [param realm], next to each other.
static func _deployment_maps(pack: SpearheadBattlepack, realm: RealmBattlefield) -> VBoxContainer:
	var title := _heading("Deployment maps")
	var maps := UIBuilder.hbox([], 16)
	for deployment in pack.deployment_maps:
		maps.add_child(captioned_map(RealmMap.new(pack, realm, false, deployment), deployment.name))
	return UIBuilder.vbox([title, maps,
			UIBuilder.label("The defender picks the side, a map and which territory is theirs.", "MutedLabel", true)], 6)


## [param realm]'s twist deck: each card's name, rules and options.
static func _twists(realm: RealmBattlefield) -> VBoxContainer:
	var title := _heading("%s twist deck" % realm.name)
	var box := UIBuilder.vbox([title], 8)
	for twist in realm.twists:
		var lines := PackedStringArray([twist.text])
		for option in twist.options:
			lines.append("• %s: %s" % [option.name, option.text])
		var entry: VBoxContainer = load("res://scenes/ui/quick_play/twist_entry.tscn").instantiate()
		(entry.get_node(^"%Name") as Label).text = twist.name
		(entry.get_node(^"%Text") as Label).text = "\n".join(lines)
		box.add_child(entry)
	return box


## [param map] over [param caption].
static func captioned_map(map: Control, caption: String) -> VBoxContainer:
	var box: VBoxContainer = load("res://scenes/ui/quick_play/captioned_map.tscn").instantiate()
	(box.get_node(^"%Caption") as Label).text = caption
	box.add_child(map)
	box.move_child(map, 0)
	return box


func _set_up_card(card: PressableCard, card_name: String, pack_name: String) -> void:
	card.card_name = card_name
	if pack_name == selected:
		card.theme_type_variation = "PickedCardPanel"
	card.pressed.connect(_pick.bind(pack_name))


func _pick(pack_name: String) -> void:
	selected = pack_name
	picked.emit(pack_name)


## Swaps [param pack]'s card for the other form in place, so the list keeps its scroll, and keeps
## focus on its eye.
func _on_eye_toggled(on: bool, pack: SpearheadBattlepack) -> void:
	if on:
		_open[pack.name] = true
	else:
		_open.erase(pack.name)
	var old: Control = cards[pack.name]
	var index := old.get_index()
	remove_child(old)
	old.queue_free()
	cards[pack.name] = _pack_card(pack)
	add_child(cards[pack.name])
	move_child(cards[pack.name], index)
	(cards[pack.name].get_meta(&"eye") as Button).grab_focus()


## A heading in the style of [method BattleplanPicker.rules_block]'s.
static func _heading(text: String) -> Label:
	var title := UIBuilder.label(text.to_upper(), "StatNameLabel")
	title.add_theme_color_override("font_color", UITheme.TEXT)
	return title
