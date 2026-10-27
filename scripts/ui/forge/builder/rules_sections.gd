class_name RulesSections
extends RefCounted
## The Rules tab of the army builder's info pane: the rules an army uses, in sections of groups,
## and the search filter over them. See docs/design/forge.md.

const LORE_KINDS := {"spell": "Spell Lore", "prayer": "Prayer Lore", "manifestation": "Manifestation Lore"}


## A titled (or untitled) set of rules in a section: abilities, warscrolls or battle tactics cards.
class Group:
	var title := ""
	## Identifies the group within its section, e.g. for folding it: its title, with "#2", "#3"…
	## added when an earlier group in the section has the same title.
	var key := ""
	var note := ""
	## Expansion the group's rules come from, e.g. "Scourge of Ghyran". Empty for the battletome.
	var source := ""
	## Whether the group's rules are Legends, e.g. an enhancement table from a retired Scourge.
	var legends := false
	## Points, or -1 to show none.
	var points := -1
	## Whether the army has picked this group, e.g. its battle formation or a lore.
	var selected := false
	## Lores start folded, other groups open.
	var lore := false
	var abilities: Array[Ability] = []
	var warscrolls: Array[Warscroll] = []
	var cards: Array[BattleTacticCard] = []
	## The manifestations ([code]Array[Warscroll][/code]) each of [member abilities] summons, by
	## ability, from [method ArmyCatalog.summoned].
	var summons := {}

	func size() -> int:
		return abilities.size() + warscrolls.size() + cards.size()

	func copy() -> Group:
		var group := Group.new()
		for property in ["title", "key", "note", "source", "legends", "points", "selected", "lore"]:
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
## enhancements and lores replace the faction's, and it has no battle formations. Legends enhancement
## tables and lores are left out unless the army shows Legends, though its picked lores stay.
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
		if table.legends and not army.show_legends:
			continue
		var group := Group.new()
		group.title = table.name
		group.note = table.group
		group.source = table.source
		group.legends = table.legends
		group.abilities = table.entries
		enhancements.append(group)
	_add(sections, "Enhancements", enhancements)

	var lores: Array[Group] = []
	var core := catalog.core
	for kind: String in LORE_KINDS:
		var picked: String = army.get("%s_lore" % kind)
		for lore in catalog.lore_choices(army, kind, picked):
			var group := Group.new()
			group.title = lore.name
			group.note = "Universal Manifestation Lore" if core and lore in core.manifestation_lores else LORE_KINDS[kind]
			group.source = lore.source
			group.legends = lore.legends
			group.points = lore.points
			group.selected = lore.name == picked
			group.lore = true
			group.abilities = lore.entries
			for ability in lore.entries:
				var summoned := catalog.summoned(ability)
				if not summoned.is_empty():
					group.summons[ability] = summoned
			lores.append(group)
	_add(sections, "Lores", lores)

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
	var seen := {}
	for group: Group in groups:
		if group.size() > 0:
			seen[group.title] = seen.get(group.title, 0) + 1
			group.key = group.title if seen[group.title] == 1 else "%s#%d" % [group.title, seen[group.title]]
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
			if not group.title.is_empty() and RulesSearch.matches(" ".join([group.title, group.note, group.source]), query_words):
				kept.groups.append(group)
				continue
			var found := group.copy()
			for ability in group.abilities:
				var summoned: Array = group.summons.get(ability, [])
				if RulesSearch.matches(RulesSearch.ability_text(ability), query_words) \
						or summoned.any(func(w: Warscroll) -> bool: return RulesSearch.matches(RulesSearch.warscroll_text(w), query_words)):
					found.abilities.append(ability)
					if not summoned.is_empty():
						found.summons[ability] = summoned
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
