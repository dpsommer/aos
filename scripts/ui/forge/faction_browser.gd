class_name FactionBrowser
extends Control
## Read-only view of a faction's rules, warscrolls, Armies of Renown, Regiments of Renown, Spearheads
## and Path to Glory.

signal back_pressed

var faction: Faction

@onready var title: Label = %Title
@onready var back_button: Button = %BackButton
@onready var tabs: TabContainer = %Tabs
@onready var rules_tab: ScrollContainer = %RulesTab
## Holds the Rules tab's battle traits, battle formations, enhancements and lores.
@onready var rules: VBoxContainer = %Rules
@onready var warscrolls: RulesListView = %Warscrolls
@onready var armies_of_renown: RulesListView = %ArmiesOfRenown
@onready var regiments_of_renown: RulesListView = %RegimentsOfRenown
@onready var spearheads: RulesListView = %Spearheads
@onready var path_to_glory: RulesListView = %PathToGlory


func _ready() -> void:
	theme = UITheme.get_theme()
	back_button.icon = UITheme.icon("back")
	var titles := {
		rules_tab: "Rules",
		warscrolls: "Warscrolls",
		armies_of_renown: "Armies of Renown",
		regiments_of_renown: "Regiments of Renown",
		spearheads: "Spearhead",
		path_to_glory: "Path to Glory",
	}
	for tab: Control in titles:
		tabs.set_tab_title(tab.get_index(), titles[tab])
	back_button.pressed.connect(back_pressed.emit)
	back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_pressed.emit()


func show_faction(data: Faction) -> void:
	faction = data
	title.text = data.name + (" (Legends)" if data.legends else "")
	var catalog := ArmyCatalog.new(data, CoreRulesCatalog.get_rules())
	for child in rules.get_children():
		rules.remove_child(child)
		child.queue_free()
	rules.add_child(RulesView.faction_rules(data, catalog.summoned))

	var labels := PackedStringArray()
	for unit in data.warscrolls:
		labels.append(_warscroll_label(unit))
	# A summoned unit's short card, e.g. the Zontari Endrin Dock's Auto-Endrin, selects its warscroll.
	var show_summoned := func(unit: Warscroll) -> void: warscrolls.select(data.warscrolls.find(unit))
	warscrolls.populate(labels,
			func(i: int) -> Control: return RulesView.warscroll(data.warscrolls[i], catalog.summoned, show_summoned))

	labels = PackedStringArray()
	for army in data.armies_of_renown:
		labels.append(army.name + (" (Legends)" if army.legends else ""))
	armies_of_renown.populate(labels,
			func(i: int) -> Control: return RulesView.army_of_renown(data.armies_of_renown[i], catalog.summoned))

	labels = PackedStringArray()
	for regiment in data.regiments_of_renown:
		labels.append("%s%s - %d pts" % [regiment.name, " (Legends)" if regiment.legends else "", regiment.points])
	regiments_of_renown.populate(labels,
			func(i: int) -> Control: return RulesView.regiment_of_renown(data.regiments_of_renown[i], catalog.summoned))

	labels = PackedStringArray()
	for army in data.spearheads:
		labels.append(army.name)
	spearheads.populate(labels, func(i: int) -> Control: return RulesView.spearhead(data.spearheads[i], catalog.summoned))

	labels = PackedStringArray()
	for section in data.path_to_glory:
		labels.append(section.name)
	path_to_glory.populate(labels, func(i: int) -> Control: return RulesView.rules_section(data.path_to_glory[i]))

func _warscroll_label(unit: Warscroll) -> String:
	var label := unit.name
	if not unit.source.is_empty():
		label += " (%s)" % unit.source
	if unit.legends:
		label += " (Legends)"
	return "%s - %d pts" % [label, unit.points] if unit.points > 0 else label
