class_name RealmPicker
extends VBoxContainer
## Spearhead's battleplans to choose from: Random, then each side of each battlepack's realm
## battlefield, grouped by battlepack, with a small map. Each battlepack has one battleplan, fought
## on the side the players choose, so choosing a side chooses the battleplan. An eye shows a side
## in full: a larger map, the deployment maps, the setup, starting relics, twist deck and scoring.
## Pressing a card chooses it.

## The player chose [param realm] in [param battlepack], or Random if both are empty.
signal picked(battlepack: String, realm: String)

var battlepacks: Array[SpearheadBattlepack]
## The chosen side's name, or empty for Random. Side names are unique across battlepacks.
var selected := ""
## The cards by side name, Random's under "".
var cards := {}
## Names of the sides shown in full.
var _open := {}


func _init(packs: Array[SpearheadBattlepack], chosen := "") -> void:
	battlepacks = packs
	selected = chosen
	add_theme_constant_override("separation", 8)
	cards[""] = _random_card()
	add_child(cards[""])
	for pack in battlepacks:
		add_child(_heading(pack.name))
		for realm in pack.realms:
			cards[realm.name] = _realm_card(pack, realm)
			add_child(cards[realm.name])


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
	var count := _side_count()
	var text := UIBuilder.vbox([UIBuilder.label("Random", "TitleLabel"),
			UIBuilder.label("One of the %d realm battlefields below, picked when the battle starts." % count, "MutedLabel", true)], 4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIBuilder.hbox([art, text], 12)
	if selected.is_empty():
		row.add_child(BattleplanPicker.check_mark())
	card.add_child(row)
	card.make_pressable("Pick a realm battlefield at random when the battle starts")
	return card


## How many sides there are to choose from.
func _side_count() -> int:
	var count := 0
	for pack in battlepacks:
		count += pack.realms.size()
	return count


## [param realm]'s card, in brief or, if it's open, in full.
func _realm_card(pack: SpearheadBattlepack, realm: RealmBattlefield) -> PressableCard:
	var full: bool = _open.has(realm.name)
	var card := _card(realm.name, realm.name)
	var facts := PackedStringArray(["%d objectives" % realm.objectives.size(), "%d twists" % realm.twists.size()])
	if not realm.starting_relics.is_empty():
		facts.append("%d starting relics" % realm.starting_relics.size())
	var text := UIBuilder.vbox([UIBuilder.label(realm.name, "TitleLabel", true),
			UIBuilder.label(" · ".join(facts), "MutedLabel", true)], 4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIBuilder.hbox([RealmMap.new(pack, realm), text], 12)
	if selected == realm.name:
		row.add_child(BattleplanPicker.check_mark())
	var eye := UIBuilder.icon_toggle("eye", ("Hide " if full else "Show ") + realm.name + " rules", full,
			func(_on: bool) -> void: pass, "realm:" + realm.name)
	eye.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(eye)
	var content := UIBuilder.vbox([row], 12)
	if full:
		_add_details(content, pack, realm)
	card.add_child(content)
	card.make_pressable("Choose %s (%s)" % [realm.name, pack.name])
	card.set_meta(&"eye", eye)
	eye.toggled.connect(_on_eye_toggled.bind(pack, realm))
	return card


func _add_details(content: VBoxContainer, pack: SpearheadBattlepack, realm: RealmBattlefield) -> void:
	content.add_child(HSeparator.new())
	content.add_child(RealmMap.new(pack, realm, true))
	var key := PackedStringArray(["%d\" × %d\"" % [pack.battlefield_size.x, pack.battlefield_size.y],
			"gold: objectives, contested by models on them"])
	if not realm.roads.is_empty():
		key.append("grey: roads")
	if not realm.terrain.is_empty():
		key.append("dashed: %s" % ", ".join(realm.terrain.map(func(feature: MapFeature) -> String: return feature.type)))
	content.add_child(UIBuilder.label(" · ".join(key), "MutedLabel", true))
	if not pack.deployment_maps.is_empty():
		content.add_child(_deployment_maps(pack, realm))
	for section in pack.battleplan_sections:
		if section.name == "Pre-battle Sequence":
			content.add_child(BattleplanPicker.rules_block("Setup", section.text))
	if not realm.starting_relics.is_empty():
		content.add_child(_heading("Starting relics"))
	for relic_name in realm.starting_relics:
		var relic := pack.get_relic(relic_name)
		if relic:
			content.add_child(AbilityCard.new(relic))
	if not realm.twists.is_empty():
		content.add_child(_twists(realm))
	if not pack.scoring.is_empty():
		content.add_child(BattleplanPicker.rules_block("Scoring", "\n".join(pack.scoring)))


## The battlepack's deployment maps on [param realm], side by side.
static func _deployment_maps(pack: SpearheadBattlepack, realm: RealmBattlefield) -> VBoxContainer:
	var title := _heading("Deployment maps")
	var maps := UIBuilder.hbox([], 16)
	for deployment in pack.deployment_maps:
		maps.add_child(UIBuilder.vbox([RealmMap.new(pack, realm, false, deployment),
				UIBuilder.label(deployment.name, "MutedLabel")], 4))
	return UIBuilder.vbox([title, maps,
			UIBuilder.label("The defender picks a map and which territory is theirs.", "MutedLabel", true)], 6)


## [param realm]'s twist deck: each card's name, rules and options.
static func _twists(realm: RealmBattlefield) -> VBoxContainer:
	var title := _heading("Twist deck")
	var box := UIBuilder.vbox([title], 8)
	for twist in realm.twists:
		var lines := PackedStringArray([twist.text])
		for option in twist.options:
			lines.append("• %s: %s" % [option.name, option.text])
		box.add_child(UIBuilder.vbox([UIBuilder.label(twist.name, "AbilityNameLabel", true),
				UIBuilder.label("\n".join(lines), "BodyLabel", true)], 2))
	return box


func _card(card_name: String, realm: String) -> PressableCard:
	var card := PressableCard.new()
	card.card_name = card_name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if realm == selected:
		card.theme_type_variation = "PickedCardPanel"
	card.pressed.connect(_pick.bind(realm))
	return card


func _pick(realm: String) -> void:
	selected = realm
	var pack := battlepack_of(battlepacks, realm)
	picked.emit(pack.name if pack else "", realm)


## Swaps [param realm]'s card for the other form in place, so the list keeps its scroll, and keeps
## focus on its eye.
func _on_eye_toggled(on: bool, pack: SpearheadBattlepack, realm: RealmBattlefield) -> void:
	if on:
		_open[realm.name] = true
	else:
		_open.erase(realm.name)
	var old: Control = cards[realm.name]
	var index := old.get_index()
	remove_child(old)
	old.queue_free()
	cards[realm.name] = _realm_card(pack, realm)
	add_child(cards[realm.name])
	move_child(cards[realm.name], index)
	(cards[realm.name].get_meta(&"eye") as Button).grab_focus()


## A heading in the style of [method BattleplanPicker.rules_block]'s.
static func _heading(text: String) -> Label:
	var title := UIBuilder.label(text.to_upper(), "StatNameLabel")
	title.add_theme_color_override("font_color", UITheme.TEXT)
	return title
