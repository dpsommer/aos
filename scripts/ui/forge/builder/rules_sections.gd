class_name RulesSections
extends RefCounted
## The Rules tab of the army builder's info pane: the rules an army uses, in sections of groups,
## and the search filter over them. See docs/design/forge.md.

const LORE_KINDS := {"spell": "Spell Lore", "prayer": "Prayer Lore", "manifestation": "Manifestation Lore"}


## A titled (or untitled) set of rules in a section: abilities, warscrolls or battle tactics cards.
class Group:
	var title := ""
	var note := ""
	## Points, or -1 to show none.
	var points := -1
	## Whether the army has picked this group, e.g. its battle formation or a lore.
	var selected := false
	## Lores start folded, other groups open.
	var lore := false
	var abilities: Array[Ability] = []
	var warscrolls: Array[Warscroll] = []
	var cards: Array[BattleTacticCard] = []

	func size() -> int:
		return abilities.size() + warscrolls.size() + cards.size()

	func copy() -> Group:
		var group := Group.new()
		for property in ["title", "note", "points", "selected", "lore"]:
			group.set(property, get(property))
		return group


class Section:
	var title := ""
	var groups: Array[Group] = []

	## Lore groups, or rules for other sections.
	func count() -> int:
		if title == "Lores":
			return groups.size()
		var total := 0
		for group in groups:
			total += group.size()
		return total


## The rules [param army] uses, from [param catalog]: an Army of Renown's battle traits,
## enhancements and lores replace the faction's, and it has no battle formations.
static func build(army: Army, catalog: ArmyCatalog) -> Array[Section]:
	var faction := catalog.faction
	var renown := catalog.army_of_renown(army.army_of_renown)
	var sections: Array[Section] = []

	var traits := Group.new()
	traits.abilities = renown.battle_traits if renown else faction.battle_traits
	_add(sections, "Battle Traits", [traits])

	var formations: Array[Group] = []
	for formation in catalog.battle_formations(army):
		var group := Group.new()
		group.title = formation.name
		group.points = formation.points
		group.selected = formation.name == army.formation
		group.abilities = formation.abilities
		formations.append(group)
	_add(sections, "Battle Formations", formations)

	var enhancements: Array[Group] = []
	for table in catalog.enhancement_tables(army):
		var group := Group.new()
		group.title = table.name
		group.note = table.group
		group.abilities = table.entries
		enhancements.append(group)
	_add(sections, "Enhancements", enhancements)

	var lores: Array[Group] = []
	var core := catalog.core
	for kind: String in LORE_KINDS:
		var picked: String = army.get("%s_lore" % kind)
		for lore in catalog.lores(army, kind):
			var group := Group.new()
			group.title = lore.name
			group.note = "Universal Manifestation Lore" if core and lore in core.manifestation_lores else LORE_KINDS[kind]
			group.points = lore.points
			group.selected = lore.name == picked
			group.lore = true
			group.abilities = lore.entries
			lores.append(group)
	_add(sections, "Lores", lores)

	var manifestations := Group.new()
	for warscroll in faction.warscrolls:
		if warscroll.has_keyword("MANIFESTATION"):
			manifestations.warscrolls.append(warscroll)
	if core:
		manifestations.warscrolls.append_array(core.manifestations)
	_add(sections, "Manifestations", [manifestations])

	var terrain := Group.new()
	var army_roster := catalog.roster(army)
	if not army_roster or army_roster.faction_terrain:
		terrain.warscrolls = catalog.terrain_warscrolls()
	_add(sections, "Faction Terrain", [terrain])

	var tactics := Group.new()
	if core and core.battlepack:
		tactics.cards = core.battlepack.battle_tactic_cards
	_add(sections, "Battle Tactics", [tactics])
	return sections


static func _add(sections: Array[Section], title: String, groups: Array) -> void:
	var section := Section.new()
	section.title = title
	for group: Group in groups:
		if group.size() > 0:
			section.groups.append(group)
	if not section.groups.is_empty():
		sections.append(section)


## The parts of [param sections] matching [param query]. A section or group whose title matches
## keeps all its rules; otherwise only matching rules stay, and empty groups and sections go.
static func filter(sections: Array[Section], query: String) -> Array[Section]:
	var query_words := RulesSearch.words(query)
	if query_words.is_empty():
		return sections
	var result: Array[Section] = []
	for section in sections:
		if RulesSearch.matches(section.title, query_words):
			result.append(section)
			continue
		var kept := Section.new()
		kept.title = section.title
		for group in section.groups:
			if not group.title.is_empty() and RulesSearch.matches(group.title + " " + group.note, query_words):
				kept.groups.append(group)
				continue
			var found := group.copy()
			for ability in group.abilities:
				if RulesSearch.matches(RulesSearch.ability_text(ability), query_words):
					found.abilities.append(ability)
			for warscroll in group.warscrolls:
				if RulesSearch.matches(RulesSearch.warscroll_text(warscroll), query_words):
					found.warscrolls.append(warscroll)
			for card in group.cards:
				if RulesSearch.matches(RulesSearch.tactic_text(card), query_words):
					found.cards.append(card)
			if found.size() > 0:
				kept.groups.append(found)
		if not kept.groups.is_empty():
			result.append(kept)
	return result
