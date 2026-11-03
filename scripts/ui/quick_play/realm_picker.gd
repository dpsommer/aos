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


func _init(packs: Array[SpearheadBattlepack], chosen := "") -> void:
	battlepacks = packs
	selected = chosen
	add_theme_constant_override("separation", 8)
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
	var card := _card("Random", "")
	var art := UIBuilder.icon_art(UITheme.icon("aos/white/fighters/gargantuan"), 36, 6)
	art.get_child(0).modulate = UITheme.TEXT
	art.custom_minimum_size = Vector2(96, 70)
	var text := UIBuilder.vbox([UIBuilder.label("Random", "TitleLabel"),
			UIBuilder.label("One of the %d realm battlefields below, picked when the battle starts." % battlepacks.size(), "MutedLabel", true)], 4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIBuilder.hbox([art, text], 12)
	if selected.is_empty():
		row.add_child(BattleplanPicker.check_mark())
	card.add_child(row)
	card.make_pressable("Pick a realm battlefield at random when the battle starts")
	return card


## [param pack]'s card, in brief or, if it's open, in full.
func _pack_card(pack: SpearheadBattlepack) -> PressableCard:
	var full: bool = _open.has(pack.name)
	var card := _card(pack.name, pack.name)
	var sides := PackedStringArray()
	var maps := UIBuilder.hbox([], 6)
	for realm in pack.realms:
		sides.append(realm.name)
		maps.add_child(RealmMap.new(pack, realm))
	var text := UIBuilder.vbox([UIBuilder.label(pack.name, "TitleLabel", true),
			UIBuilder.label("Sides: %s · the defender picks one" % " or ".join(sides), "MutedLabel", true)], 4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIBuilder.hbox([maps, text], 12)
	if selected == pack.name:
		row.add_child(BattleplanPicker.check_mark())
	var eye := UIBuilder.icon_toggle("eye", ("Hide " if full else "Show ") + pack.name + " rules", full,
			func(_on: bool) -> void: pass, "pack:" + pack.name)
	eye.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(eye)
	var content := UIBuilder.vbox([row], 12)
	if full:
		_add_details(content, pack)
	card.add_child(content)
	card.make_pressable("Choose %s" % pack.name)
	card.set_meta(&"eye", eye)
	eye.toggled.connect(_on_eye_toggled.bind(pack))
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
			content.add_child(AbilityCard.new(relic))
	if not realm.twists.is_empty():
		content.add_child(_twists(realm))


## The battlepack's deployment maps on [param realm], next to each other.
static func _deployment_maps(pack: SpearheadBattlepack, realm: RealmBattlefield) -> VBoxContainer:
	var title := _heading("Deployment maps")
	var maps := UIBuilder.hbox([], 16)
	for deployment in pack.deployment_maps:
		maps.add_child(UIBuilder.vbox([RealmMap.new(pack, realm, false, deployment),
				UIBuilder.label(deployment.name, "MutedLabel")], 4))
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
		box.add_child(UIBuilder.vbox([UIBuilder.label(twist.name, "AbilityNameLabel", true),
				UIBuilder.label("\n".join(lines), "BodyLabel", true)], 2))
	return box


func _card(card_name: String, pack_name: String) -> PressableCard:
	var card := PressableCard.new()
	card.card_name = card_name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if pack_name == selected:
		card.theme_type_variation = "PickedCardPanel"
	card.pressed.connect(_pick.bind(pack_name))
	return card


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
