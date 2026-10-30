class_name ArmyCatalog
extends RefCounted
## Looks up the rules an army's choices refer to: its faction's warscrolls, enhancements, lores and
## Regiments of Renown, or its Army of Renown's, plus the core rules' manifestation lores and battle
## tactics.

var faction: Faction
var core: CoreRules
## Takes a faction id and returns that [Faction], for units in Regiments of Renown and units an
## Army of Renown includes from other factions.
var _load_faction: Callable
## Army of Renown name -> {warscroll id: [faction id, Warscroll]} of the units it includes from
## other factions.
var _included := {}


## [param load_faction] defaults to loading from [FactionCatalog].
func _init(faction_data: Faction, core_rules: CoreRules, load_faction := Callable()) -> void:
	faction = faction_data
	core = core_rules
	_load_faction = load_faction if load_faction.is_valid() else _from_catalog


static func _from_catalog(faction_id: String) -> Faction:
	var faction_name := FactionCatalog.name_for_id(faction_id)
	return FactionCatalog.load_faction(faction_name) if not faction_name.is_empty() else null


func army_of_renown(army_name: String) -> ArmyOfRenown:
	for army in faction.armies_of_renown:
		if army.name == army_name:
			return army
	return null


## The roster restrictions of [param army]'s Army of Renown, or null if it has none.
func roster(army: Army) -> ArmyRoster:
	var renown := army_of_renown(army.army_of_renown)
	return renown.roster if renown else null


## An Army of Renown uses its own enhancements and lores instead of the faction's.
func enhancement_tables(army: Army) -> Array[EnhancementTable]:
	var renown := army_of_renown(army.army_of_renown)
	return renown.enhancement_tables if renown else faction.enhancement_tables


## Enhancement types in table order, e.g. ["Heroic Traits", "Artefacts of Power"].
func enhancement_types(army: Army) -> PackedStringArray:
	var types := PackedStringArray()
	for table in enhancement_tables(army):
		if not table.name in types:
			types.append(table.name)
	return types


## How many enhancements of [param type] the army can include: 1 (Core Rules 4.1) unless one of its
## tables of that type allows more, as the Swords of Chaos' First Circle Titles do.
func enhancement_limit(army: Army, type: String) -> int:
	var limit := 1
	for table in enhancement_tables(army):
		if table.name == type:
			limit = maxi(limit, table.max)
	return limit


## The enhancement called [param enhancement_name] in a table of [param type], or null.
func enhancement(army: Army, type: String, enhancement_name: String) -> Ability:
	var table := enhancement_table(army, type, enhancement_name)
	if table:
		for entry in table.entries:
			if entry.name == enhancement_name:
				return entry
	return null


## The table of [param type] holding the enhancement called [param enhancement_name], or null.
func enhancement_table(army: Army, type: String, enhancement_name: String) -> EnhancementTable:
	for table in enhancement_tables(army):
		if table.name == type:
			for entry in table.entries:
				if entry.name == enhancement_name:
					return table
	return null


## Whether a unit with [param warscroll] can be given enhancements from [param table]: one of the
## table's [member EnhancementTable.units] if it lists any, and a Hero for Heroic Traits and
## Artefacts of Power. Unique units and units in Regiments of Renown are checked separately.
## [param hero] counts the unit as a Hero without the keyword, as a non-Hero general can be.
static func can_take(table: EnhancementTable, warscroll: Warscroll, hero := false) -> bool:
	if not table.units.is_empty():
		return warscroll.name in table.units
	return not table.name in ArmyValidator.HERO_ENHANCEMENTS or hero or warscroll.has_keyword("HERO")


## The tables of [param type] to offer a unit with [param warscroll]: those it [method can_take],
## leaving out Legends tables unless the army shows Legends. The table holding [param selected], the
## unit's current enhancement of the type, is always included, so it can still be seen and cleared.
## With [param unit], a non-Hero general that [method is_hero] can take Hero enhancements.
func enhancement_choices(army: Army, warscroll: Warscroll, type: String, selected := "", unit: ArmyUnit = null) -> Array[EnhancementTable]:
	var hero := unit != null and is_hero(army, unit, warscroll)
	var current: EnhancementTable = enhancement_table(army, type, selected) if not selected.is_empty() else null
	var result: Array[EnhancementTable] = []
	for table in enhancement_tables(army):
		if table.name != type:
			continue
		if table == current or (can_take(table, warscroll, hero) and (army.show_legends or not table.legends)):
			result.append(table)
	return result


## Lores of [param kind] ("spell", "prayer" or "manifestation") the army can pick. Manifestation
## lores include the universal ones, unless the Army of Renown forbids manifestations.
func lores(army: Army, kind: String) -> Array[Lore]:
	var renown := army_of_renown(army.army_of_renown)
	var result: Array[Lore] = []
	if kind == "manifestation" and renown and renown.roster and not renown.roster.manifestations:
		return result
	for lore in (renown.lores if renown else faction.lores):
		if lore.kind == kind:
			result.append(lore)
	if kind == "manifestation" and core:
		result.append_array(core.manifestation_lores)
	return result


## The lores of [param kind] to offer: [method lores] without Legends lores unless the army shows
## Legends, though the picked lore, [param selected], is always included.
func lore_choices(army: Army, kind: String, selected := "") -> Array[Lore]:
	var result: Array[Lore] = []
	for candidate in lores(army, kind):
		if army.show_legends or not candidate.legends or candidate.name == selected:
			result.append(candidate)
	return result


func lore(army: Army, kind: String, lore_name: String) -> Lore:
	for candidate in lores(army, kind):
		if candidate.name == lore_name:
			return candidate
	return null


## Armies of Renown have no battle formations.
func battle_formations(army: Army) -> Array[BattleFormation]:
	var none: Array[BattleFormation] = []
	return none if army_of_renown(army.army_of_renown) else faction.battle_formations


func battle_formation(army: Army, formation_name: String) -> BattleFormation:
	for formation in battle_formations(army):
		if formation.name == formation_name:
			return formation
	return null


## Warscrolls that can be units in the army: not manifestations, faction terrain or units only an
## ability sets up ([member Warscroll.summoned]). With
## [param army], they include the units its Army of Renown draws from other factions and, unless the
## army overrides its constraints, leave out those its roster doesn't allow and those only another
## Army of Renown can include.
func unit_warscrolls(army: Army = null) -> Array[Warscroll]:
	var result: Array[Warscroll] = []
	for warscroll in faction.warscrolls:
		if _is_unit(warscroll):
			result.append(warscroll)
	if army == null:
		return result
	for pair: Array in _included_units(army).values():
		result.append(pair[1])
	if army.override_constraints:
		return result
	result = result.filter(func(w: Warscroll) -> bool: return w.army_of_renown.is_empty() or w.army_of_renown == army.army_of_renown)
	var army_roster := roster(army)
	if army_roster:
		result = result.filter(func(w: Warscroll) -> bool: return ArmyValidator.roster_allows(army_roster, w))
	return result


static func _is_unit(warscroll: Warscroll) -> bool:
	return not warscroll.has_keyword("MANIFESTATION") and not warscroll.has_keyword("FACTION TERRAIN") \
			and not warscroll.summoned


## The warscroll called [param warscroll_id] in the army's faction, or among the units its Army of
## Renown includes from other factions. Null if neither has it.
func find_warscroll(army: Army, warscroll_id: String) -> Warscroll:
	var own := faction.get_warscroll(warscroll_id)
	if own:
		return own
	var pair: Array = _included_units(army).get(warscroll_id, [])
	return pair[1] if not pair.is_empty() else null


## Id of the other faction [param warscroll_id] comes from, when the army's Army of Renown includes
## it from one. Empty for the army's own faction's warscrolls and ones it can't include.
func included_faction_id(army: Army, warscroll_id: String) -> String:
	if faction.get_warscroll(warscroll_id):
		return ""
	var pair: Array = _included_units(army).get(warscroll_id, [])
	return pair[0] if not pair.is_empty() else ""


## {warscroll id: [faction id, Warscroll]} for the units [param army]'s Army of Renown includes from
## other factions, leaving out the army's own faction and warscrolls it already has (a shared
## warscroll such as Grombrindal).
func _included_units(army: Army) -> Dictionary:
	if _included.has(army.army_of_renown):
		return _included[army.army_of_renown]
	var result := {}
	_included[army.army_of_renown] = result
	var army_roster := roster(army)
	if army_roster == null:
		return result
	for inclusion in army_roster.included_units:
		if inclusion.faction == faction.id:
			continue
		var home: Faction = _load_faction.call(inclusion.faction)
		if home == null:
			continue
		for warscroll in home.warscrolls:
			if not _is_unit(warscroll) or faction.get_warscroll(warscroll.id) or result.has(warscroll.id):
				continue
			if inclusion.units.is_empty() or Array(inclusion.units).any(func(n: String) -> bool: return RegimentOption.is_named(warscroll, n)):
				result[warscroll.id] = [inclusion.faction, warscroll]
	return result


## The versions of [param leader]'s warscroll whose regiment options it can use: just [param leader],
## or for a Hero with both of the roster's [member ArmyRoster.paired_leaders] (Kragnos in a Big
## Waaagh!), also the version in each faction the army includes all units from, as it can lead for
## either faction.
func leader_versions(army: Army, leader: Warscroll) -> Array[Warscroll]:
	var result: Array[Warscroll] = [leader]
	var army_roster := roster(army)
	if army_roster == null or army_roster.paired_leaders.is_empty() \
			or not Array(army_roster.paired_leaders).all(func(k: String) -> bool: return leader.has_keyword(k)):
		return result
	for inclusion in army_roster.included_units:
		if inclusion.faction == faction.id or not inclusion.units.is_empty():
			continue
		var home: Faction = _load_faction.call(inclusion.faction)
		var version := home.get_warscroll(leader.id) if home else null
		if version and not version in result:
			result.append(version)
	return result


## Whether [param warscroll] can lead a regiment as the army's general without being a Hero: it's
## the Army of Renown's [member ArmyRoster.non_hero_general] (The Magnate's Crew's Arkanaut
## Ironclad), and the army includes none of the units that stop it.
func can_be_non_hero_general(army: Army, warscroll: Warscroll) -> bool:
	var army_roster := roster(army)
	if army_roster == null or army_roster.non_hero_general.is_empty() or warscroll.has_keyword("HERO"):
		return false
	return RegimentOption.is_named(warscroll, army_roster.non_hero_general) and non_hero_general_blocker(army).is_empty()


## Whether [param warscroll] can lead a regiment without being a Hero: it's one of the Army of
## Renown's [member ArmyRoster.non_hero_leaders] (a Stomper Tribe's Mancrusher Gargants).
func is_non_hero_leader(army: Army, warscroll: Warscroll) -> bool:
	var army_roster := roster(army)
	if army_roster == null or army_roster.non_hero_leaders.is_empty() or warscroll.has_keyword("HERO"):
		return false
	return ArmyValidator.names_or_keywords(warscroll, army_roster.non_hero_leaders, gained_keywords(army, warscroll))


## Whether a unit of [param warscroll] can lead a regiment: a Hero, the Army of Renown's
## [method can_be_non_hero_general] or one of its [method is_non_hero_leader] units.
func can_lead(army: Army, warscroll: Warscroll) -> bool:
	return warscroll.has_keyword("HERO") or can_be_non_hero_general(army, warscroll) or is_non_hero_leader(army, warscroll)


## The name of a unit in the army that stops the roster's [member ArmyRoster.non_hero_general] being
## the general, e.g. "Brokk Grungsson, Lord-Magnate of Barak-Nar". Empty if there's none.
func non_hero_general_blocker(army: Army) -> String:
	var army_roster := roster(army)
	if army_roster == null:
		return ""
	for unit in army.all_units():
		var unit_scroll := warscroll(unit, army.regiment_of(unit.uid))
		if unit_scroll and Array(army_roster.non_hero_general_unless).any(func(n: String) -> bool: return RegimentOption.is_named(unit_scroll, n)):
			return unit_scroll.name
	return ""


## Whether [param unit] is a Hero: its warscroll has the keyword, or it's the general and the
## roster's [member ArmyRoster.non_hero_general], which gains it.
func is_hero(army: Army, unit: ArmyUnit, unit_warscroll: Warscroll) -> bool:
	return unit_warscroll.has_keyword("HERO") or (unit.uid == army.general_uid and can_be_non_hero_general(army, unit_warscroll))


## [param leader]'s regiment options, plus those the army's Army of Renown gives it.
func leader_options(army: Army, leader: Warscroll) -> Array[RegimentOption]:
	var options := RegimentOption.parse_all(leader.regiment_options)
	var army_roster := roster(army)
	if army_roster:
		for added in army_roster.regiment_options:
			if added.leaders.is_empty() or ArmyValidator.names_or_keywords(leader, added.leaders, gained_keywords(army, leader)):
				for option in RegimentOption.parse_all(added.options):
					option.heroes = added.heroes
					options.append(option)
	return options


## Keywords units of [param warscroll] gain from the army's Army of Renown, if its roster allows
## them: the Army of Renown's [member ArmyOfRenown.keyword] ("MAGNATE’S CREW") and those its
## roster entries give, such as WARMASTER.
func gained_keywords(army: Army, unit_warscroll: Warscroll) -> PackedStringArray:
	var result := PackedStringArray()
	var renown := army_of_renown(army.army_of_renown)
	if renown == null or (renown.roster and not ArmyValidator.roster_allows(renown.roster, unit_warscroll)):
		return result
	if not renown.keyword.is_empty():
		result.append(renown.keyword)
	if renown.roster:
		for entry in renown.roster.entries:
			if ArmyValidator.roster_matches(entry, unit_warscroll):
				result.append_array(entry.gains_keywords)
	return result


## The regiment options a unit can be added to [param regiment] with: its leader's, or for a leader
## with several [method leader_versions], those of each version its units so far fit.
func regiment_options(army: Army, regiment: ArmyRegiment) -> Array[RegimentOption]:
	var result: Array[RegimentOption] = []
	var leader := regiment.leader()
	var leader_scroll := warscroll(leader, regiment) if leader else null
	if leader_scroll == null:
		return result
	var versions := leader_versions(army, leader_scroll)
	for version in versions:
		var options := leader_options(army, version)
		var fits := versions.size() == 1 or regiment.followers().all(func(u: ArmyUnit) -> bool:
			var unit_scroll := warscroll(u, regiment)
			return unit_scroll == null or options.any(func(o: RegimentOption) -> bool: return o.matches(unit_scroll, gained_keywords(army, unit_scroll))))
		if fits:
			result.append_array(options)
	return result


## Names of the Unique units in [param army], once for each unit, which it can't include again.
func unique_unit_names(army: Army) -> PackedStringArray:
	var result := PackedStringArray()
	for unit in army.all_units():
		var unit_scroll := warscroll(unit, army.regiment_of(unit.uid))
		if unit_scroll and unit_scroll.has_keyword("UNIQUE"):
			result.append(unit_scroll.name)
	return result


func terrain_warscrolls() -> Array[Warscroll]:
	var result: Array[Warscroll] = []
	for warscroll in faction.warscrolls:
		if warscroll.has_keyword("FACTION TERRAIN"):
			result.append(warscroll)
	return result


func regiment_of_renown(regiment_name: String) -> RegimentOfRenown:
	for regiment in faction.regiments_of_renown:
		if regiment.name == regiment_name:
			return regiment
	return null


## Regiments of Renown the army can include: none if its Army of Renown forbids them.
func regiments_of_renown(army: Army) -> Array[RegimentOfRenown]:
	var none: Array[RegimentOfRenown] = []
	var army_roster := roster(army)
	return none if army_roster and not army_roster.regiments_of_renown else faction.regiments_of_renown


## The warscroll of [param unit] in [param regiment] (null for an auxiliary unit), or null if the
## data no longer has it. A unit with a [member ArmyUnit.faction_id] is in a Regiment of Renown or
## was included from another faction by an Army of Renown, and takes its warscroll from there.
func warscroll(unit: ArmyUnit, regiment: ArmyRegiment = null) -> Warscroll:
	if not unit.faction_id.is_empty():
		var home: Faction = _load_faction.call(unit.faction_id)
		return home.get_warscroll(unit.warscroll_id) if home else null
	if regiment and regiment.is_regiment_of_renown():
		var renown := regiment_of_renown(regiment.regiment_of_renown)
		return renown.get_warscroll(unit.warscroll_id) if renown else null
	return faction.get_warscroll(unit.warscroll_id)


## The manifestations and units [param ability] sets up, from its [member Ability.summons]. A
## manifestation is the faction's own, the core rules' universal one, or another faction's, which a
## shared Army of Renown such as Legions of Nagash or a Regiment of Renown can summon. A unit, such
## as the Zontari Endrin Dock's Auto-Endrins, is the faction's own ([member Warscroll.summoned]).
## Ids that name neither are skipped.
func summoned(ability: Ability) -> Array[Warscroll]:
	var result: Array[Warscroll] = []
	for warscroll_id in ability.summons:
		var own := faction.get_warscroll(warscroll_id)
		if own and own.summoned:
			result.append(own)
			continue
		var found := own
		if (not found or not found.has_keyword("MANIFESTATION")) and core:
			found = core.get_manifestation(warscroll_id)
		if not found:
			var home_id := FactionCatalog.manifestation_faction(warscroll_id)
			var home: Faction = _load_faction.call(home_id) if not home_id.is_empty() else null
			found = home.get_warscroll(warscroll_id) if home else null
		if found and found.has_keyword("MANIFESTATION"):
			result.append(found)
	return result


func battle_tactic_card(card_name: String) -> BattleTacticCard:
	return core.battlepack.get_battle_tactic_card(card_name) if core and core.battlepack else null
