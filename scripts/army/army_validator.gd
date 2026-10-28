class_name ArmyValidator
extends RefCounted
## Checks an army against the Army Composition rules of the General's Handbook 2026-27 (Core Rules
## 3.1-3.5 and 4.1-4.2), the Scourge of Aqshy and Ghyran warscroll rules, battle tactics cards, its
## Army of Renown's roster and its points limit.

const MAX_REGIMENTS := 5
## Non-Hero units a regiment can include besides its leader (Core Rules 3.1).
const REGIMENT_UNITS := 3
## The general's regiment can include one more (Core Rules 3.2).
const GENERAL_REGIMENT_UNITS := 4
const MAX_TACTICS := 2
const MAX_REGIMENTS_OF_RENOWN := 1
## Enhancement types that only Heroes can be given.
const HERO_ENHANCEMENTS: PackedStringArray = ["Heroic Traits", "Artefacts of Power"]


## How many units besides its leader [param regiment] can include.
static func regiment_capacity(regiment: ArmyRegiment, army: Army) -> int:
	var leader := regiment.leader()
	return GENERAL_REGIMENT_UNITS if leader and leader.uid == army.general_uid else REGIMENT_UNITS


static func validate(army: Army, catalog: ArmyCatalog) -> ArmyValidation:
	var result := ArmyValidation.new()
	if army.override_constraints:
		result.overridden = true
		return result
	var entries := _entries(army, catalog, result)
	_check_regiments(army, catalog, result)
	_check_general(army, catalog, entries, result)
	_check_unique(entries, result)
	_check_scourge(entries, result)
	_check_regiments_of_renown(army, catalog, result)
	_check_enhancements(army, catalog, entries, result)
	_check_lores(army, catalog, entries, result)
	_check_formation_and_terrain(army, catalog, result)
	_check_tactics(army, catalog, result)
	_check_roster(army, catalog, entries, result)
	var points := ArmyPoints.total(army, catalog)
	if points > army.points_limit:
		result.problems.append("The army is %d pts over the %d pts limit." % [points - army.points_limit, army.points_limit])
	result.problems = _unique(result.problems)
	result.warnings = _unique(result.warnings)
	return result


## Two copies of a unit break a rule the same way; the message is shown once.
static func _unique(messages: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for message in messages:
		if not message in result:
			result.append(message)
	return result


## Each unit with its warscroll and regiment, as {unit, warscroll, regiment, keywords}. keywords
## includes those gained from the Army of Renown roster. Units whose warscroll is missing from the
## data are reported and left out.
static func _entries(army: Army, catalog: ArmyCatalog, result: ArmyValidation) -> Array[Dictionary]:
	var army_roster := catalog.roster(army)
	var entries: Array[Dictionary] = []
	var add := func(unit: ArmyUnit, regiment: ArmyRegiment) -> void:
		var warscroll := catalog.warscroll(unit, regiment)
		if warscroll == null:
			result.problems.append("%s's warscroll is no longer in the faction data." % _unit_name(unit, null))
			return
		var keywords := warscroll.keywords.duplicate()
		if army_roster:
			for entry in army_roster.entries:
				if _roster_matches(entry, warscroll):
					keywords.append_array(entry.gains_keywords)
		entries.append({"unit": unit, "warscroll": warscroll, "regiment": regiment, "keywords": keywords})
	for regiment in army.regiments:
		for unit in regiment.units:
			add.call(unit, regiment)
	for unit in army.auxiliary:
		add.call(unit, null)
	return entries


static func _unit_name(unit: ArmyUnit, warscroll: Warscroll) -> String:
	if not unit.label.is_empty():
		return unit.label
	return warscroll.name if warscroll else unit.warscroll_id


static func _is_ror(entry: Dictionary) -> bool:
	return entry.regiment != null and entry.regiment.is_regiment_of_renown()


static func _has(entry: Dictionary, keyword: String) -> bool:
	return keyword in entry.keywords


static func _check_regiments(army: Army, catalog: ArmyCatalog, result: ArmyValidation) -> void:
	var built := army.regiments.filter(func(r: ArmyRegiment) -> bool: return not r.is_regiment_of_renown())
	if built.is_empty():
		result.problems.append("Add at least 1 regiment.")
	if built.size() > MAX_REGIMENTS:
		result.problems.append("Your army can include at most %d regiments (%d included)." % [MAX_REGIMENTS, built.size()])
	for regiment: ArmyRegiment in built:
		var leader := regiment.leader()
		var leader_scroll := catalog.warscroll(leader, regiment) if leader else null
		if leader_scroll == null or not leader_scroll.has_keyword("HERO"):
			result.problems.append("%s needs a Hero leader." % regiment.name)
			continue
		var others := regiment.units.slice(1)
		var capacity := regiment_capacity(regiment, army)
		if others.size() > capacity:
			result.problems.append("%s has %d units besides its leader; the limit is %d%s." % [regiment.name, others.size(),
					capacity, "" if capacity == GENERAL_REGIMENT_UNITS else " (%d for the general's regiment)" % GENERAL_REGIMENT_UNITS])
		_check_regiment_options(regiment, leader_scroll, others, catalog, result)


## Fills each option with the units it allows: required options first, then unlimited ones, so a
## limited option (such as "0-1 Gryph-hounds") is only used by a unit nothing else allows.
static func _check_regiment_options(regiment: ArmyRegiment, leader: Warscroll, units: Array,
		catalog: ArmyCatalog, result: ArmyValidation) -> void:
	var options := RegimentOption.parse_all(leader.regiment_options)
	var used := {}
	for unit: ArmyUnit in units:
		var warscroll := catalog.warscroll(unit, regiment)
		if warscroll == null:
			continue
		var fitted: RegimentOption = null
		for option in options:
			if option.min > 0 and used.get(option, 0) < option.max and option.matches(warscroll):
				fitted = option
				break
		for option in options:
			if fitted == null and option.max == RegimentOption.ANY and option.matches(warscroll):
				fitted = option
				break
		if fitted == null:
			for option in options:
				if option.matches(warscroll) and used.get(option, 0) < option.max:
					fitted = option
					break
		if fitted == null:
			var limit := _matching_option(options, warscroll)
			if limit:
				result.problems.append("%s can't include another %s (%s)." % [regiment.name, warscroll.name, limit.text])
			else:
				result.problems.append("%s isn't in %s's regiment options." % [_unit_name(unit, warscroll), leader.name])
			continue
		used[fitted] = used.get(fitted, 0) + 1
	for option in options:
		if used.get(option, 0) < option.min:
			result.problems.append("%s must include %s." % [regiment.name, option.unit if not option.unit.is_empty() else option.text])


static func _matching_option(options: Array[RegimentOption], warscroll: Warscroll) -> RegimentOption:
	for option in options:
		if option.matches(warscroll):
			return option
	return null


## An Army of Renown's roster can name the general, overriding the Warmaster rule (Grombrindal leads
## a Duardin Ascendant army even with an Auric Runefather in it).
static func _check_general(army: Army, catalog: ArmyCatalog, entries: Array[Dictionary], result: ArmyValidation) -> void:
	var general: Dictionary = {}
	for entry in entries:
		if entry.unit.uid == army.general_uid:
			general = entry
	if general.is_empty():
		result.problems.append("Choose a general from your regiment leaders.")
		return
	if _is_ror(general):
		result.problems.append("A unit in a Regiment of Renown can't be your general.")
	elif general.regiment == null or general.regiment.leader() != general.unit:
		result.problems.append("Your general must lead a regiment.")
	if not _has(general, "WARMASTER") and not _is_roster_general(general.warscroll, catalog.roster(army)):
		for entry in entries:
			if _has(entry, "WARMASTER") and not _is_ror(entry):
				result.problems.append("%s is a Warmaster, so a Warmaster must be your general." % entry.warscroll.name)
				return


static func _check_unique(entries: Array[Dictionary], result: ArmyValidation) -> void:
	var counts := {}
	for entry in entries:
		if entry.warscroll.has_keyword("UNIQUE"):
			counts[entry.warscroll.name] = counts.get(entry.warscroll.name, 0) + 1
	for unit_name: String in counts:
		if counts[unit_name] > 1:
			result.problems.append("%s is Unique and is included %d times." % [unit_name, counts[unit_name]])


## Every instance of a unit must use the same warscroll: its printed version or one Scourge version.
static func _check_scourge(entries: Array[Dictionary], result: ArmyValidation) -> void:
	var versions := {}
	for entry in entries:
		var source: String = entry.warscroll.source
		if source.is_empty() or source.begins_with("Scourge of"):
			var seen: Array = versions.get_or_add(entry.warscroll.name, [])
			if not source in seen:
				seen.append(source)
	for unit_name: String in versions:
		var seen: Array = versions[unit_name]
		if seen.size() > 1:
			var names := PackedStringArray()
			for source: String in seen:
				names.append("printed" if source.is_empty() else source)
			result.problems.append("All %s units must use the same warscroll (%s versions included)." % [unit_name, " and ".join(names)])


static func _check_regiments_of_renown(army: Army, catalog: ArmyCatalog, result: ArmyValidation) -> void:
	var included := army.regiments.filter(func(r: ArmyRegiment) -> bool: return r.is_regiment_of_renown())
	if included.size() > MAX_REGIMENTS_OF_RENOWN:
		result.problems.append("Your army can include only %d Regiment of Renown (%d included)." % [MAX_REGIMENTS_OF_RENOWN, included.size()])
	var allowed := catalog.regiments_of_renown(army).map(func(r: RegimentOfRenown) -> String: return r.name)
	for regiment: ArmyRegiment in included:
		if not regiment.regiment_of_renown in allowed:
			var renown := catalog.army_of_renown(army.army_of_renown)
			result.problems.append("%s isn't available to this army%s" % [regiment.regiment_of_renown,
					": %s armies can't include Regiments of Renown." % renown.name if renown and allowed.is_empty() else "."])


## Core Rules 4.1: 1 enhancement of each type, never the same one twice, and none on UNIQUE units
## or units in a Regiment of Renown. Heroic Traits and Artefacts of Power need a Hero, and a table
## for certain units (Great Endrinworks for Skyvessels) can only go on them.
static func _check_enhancements(army: Army, catalog: ArmyCatalog, entries: Array[Dictionary], result: ArmyValidation) -> void:
	var by_type := {}
	for entry in entries:
		var unit: ArmyUnit = entry.unit
		for type: String in unit.enhancements:
			var enhancement_name: String = unit.enhancements[type]
			if enhancement_name.is_empty():
				continue
			var unit_name := _unit_name(unit, entry.warscroll)
			var table := catalog.enhancement_table(army, type, enhancement_name)
			if table == null:
				result.problems.append("%s isn't one of this army's %s." % [enhancement_name, type])
			if entry.warscroll.has_keyword("UNIQUE"):
				result.problems.append("%s is Unique, so it can't be given %s." % [unit_name, enhancement_name])
			elif _is_ror(entry):
				result.problems.append("%s is in a Regiment of Renown, so it can't be given %s." % [unit_name, enhancement_name])
			elif table and not table.units.is_empty() and not ArmyCatalog.can_take(table, entry.warscroll):
				result.problems.append("%s can't be given %s%s." % [unit_name, enhancement_name, _only_for(table)])
			elif type in HERO_ENHANCEMENTS and not entry.warscroll.has_keyword("HERO"):
				result.problems.append("Only Heroes can be given %s (%s isn't a Hero)." % [type, unit_name])
			by_type.get_or_add(type, []).append(enhancement_name)
	for type: String in by_type:
		var picked: Array = by_type[type]
		if picked.size() > 1:
			result.problems.append("Your army can include only 1 of the %s (%d given)." % [type, picked.size()])


## Which units [param table] is for, when there are few enough to name: ": only for Arkanaut
## Frigate, Arkanaut Ironclad or Grundstok Gunhauler".
static func _only_for(table: EnhancementTable) -> String:
	const MAX_NAMED := 4
	if table.units.size() > MAX_NAMED:
		return ""
	var names := Array(table.units)
	var last: String = names.pop_back()
	return ": only for %s" % (last if names.is_empty() else "%s or %s" % [", ".join(PackedStringArray(names)), last])


static func _check_lores(army: Army, catalog: ArmyCatalog, entries: Array[Dictionary], result: ArmyValidation) -> void:
	var picks := {"spell": army.spell_lore, "prayer": army.prayer_lore, "manifestation": army.manifestation_lore}
	for kind: String in picks:
		if not picks[kind].is_empty() and catalog.lore(army, kind, picks[kind]) == null:
			result.problems.append("%s isn't a %s lore this army can pick." % [picks[kind], kind])
	var wizard := false
	var priest := false
	for entry in entries:
		if _is_ror(entry):
			continue
		for keyword: String in entry.keywords:
			wizard = wizard or keyword.begins_with("WIZARD")
			priest = priest or keyword.begins_with("PRIEST")
	if wizard and army.spell_lore.is_empty() and not catalog.lores(army, "spell").is_empty():
		result.warnings.append("Your army has a Wizard but no spell lore.")
	if priest and army.prayer_lore.is_empty() and not catalog.lores(army, "prayer").is_empty():
		result.warnings.append("Your army has a Priest but no prayer lore.")
	if (wizard or priest) and army.manifestation_lore.is_empty() and not catalog.lores(army, "manifestation").is_empty():
		result.warnings.append("Your army has a Wizard or Priest but no manifestation lore.")


static func _check_formation_and_terrain(army: Army, catalog: ArmyCatalog, result: ArmyValidation) -> void:
	var formations := catalog.battle_formations(army)
	if army.formation.is_empty():
		if not formations.is_empty():
			result.problems.append("Choose a battle formation.")
	elif catalog.battle_formation(army, army.formation) == null:
		result.problems.append("%s isn't a battle formation this army can pick." % army.formation)
	if army.faction_terrain.is_empty():
		return
	var terrain := catalog.faction.get_warscroll(army.faction_terrain)
	var army_roster := catalog.roster(army)
	if terrain == null or not terrain.has_keyword("FACTION TERRAIN"):
		result.problems.append("The faction terrain feature is no longer in the faction data.")
	elif army_roster and not army_roster.faction_terrain:
		result.problems.append("%s armies can't include faction terrain." % army.army_of_renown)


static func _check_tactics(army: Army, catalog: ArmyCatalog, result: ArmyValidation) -> void:
	var picked := Array(army.tactics).filter(func(t: String) -> bool: return not t.is_empty())
	if picked.is_empty():
		result.problems.append("Choose your battle tactics cards.")
	elif picked.size() < MAX_TACTICS:
		result.warnings.append("You can pick %d battle tactics cards (%d chosen)." % [MAX_TACTICS, picked.size()])
	if picked.size() > MAX_TACTICS:
		result.problems.append("Your army can have at most %d battle tactics cards." % MAX_TACTICS)
	var seen := {}
	for card: String in picked:
		if catalog.battle_tactic_card(card) == null:
			result.problems.append("%s isn't a battle tactics card in this battlepack." % card)
		elif seen.has(card):
			result.problems.append("%s is picked twice." % card)
		seen[card] = true


static func _roster_matches(entry: RosterEntry, warscroll: Warscroll) -> bool:
	if not entry.unit.is_empty():
		return RegimentOption._names(warscroll, entry.unit)
	if not entry.one_of.is_empty():
		return Array(entry.one_of).any(func(unit_name: String) -> bool: return RegimentOption._names(warscroll, unit_name))
	for keyword in entry.not_keywords:
		if _has_keyword(warscroll, keyword):
			return false
	for keyword in entry.keywords:
		if not _has_keyword(warscroll, keyword):
			return false
	return true


## Rosters name keywords without their value: "WIZARD" matches "WIZARD (2)".
static func _has_keyword(warscroll: Warscroll, keyword: String) -> bool:
	if warscroll.has_keyword(keyword):
		return true
	for held in warscroll.keywords:
		if held.begins_with(keyword + " ("):
			return true
	return false


## Whether [param warscroll] matches one of [member RosterEntry.per]: a unit name, or keywords
## ("HERO MONSTER").
static func _per_matches(entry: RosterEntry, warscroll: Warscroll) -> bool:
	for item in entry.per:
		if RegimentOption._names(warscroll, item) or _has_keyword(warscroll, item):
			return true
		if Array(item.split(" ")).all(func(keyword: String) -> bool: return _has_keyword(warscroll, keyword)):
			return true
	return false


static func _is_limited(entry: RosterEntry) -> bool:
	return not entry.per.is_empty() or entry.max > 0


static func _is_roster_general(warscroll: Warscroll, army_roster: ArmyRoster) -> bool:
	return army_roster != null and army_roster.entries.any(func(e: RosterEntry) -> bool: return e.general and _roster_matches(e, warscroll))


## "Grombrindal", or "a GORECHOSEN CHAMPIONS unit" for an entry matching by keywords.
static func _describe(entry: RosterEntry) -> String:
	if not entry.unit.is_empty():
		return entry.unit
	if not entry.one_of.is_empty():
		return " or ".join(entry.one_of)
	var words := PackedStringArray()
	for keyword in entry.not_keywords:
		words.append("non-" + keyword)
	words.append_array(entry.keywords)
	return "a %s unit" % " ".join(words)


## Every unit must match a roster entry and not be one of its excluded units. Units only limited entries allow are limited to the entry's
## [member RosterEntry.max], or to 1 for each unit matching its [member RosterEntry.per]. Required
## units must be included, and some must be the general.
static func _check_roster(army: Army, catalog: ArmyCatalog, entries: Array[Dictionary], result: ArmyValidation) -> void:
	var army_roster := catalog.roster(army)
	if army_roster == null:
		return
	var built := entries.filter(func(e: Dictionary) -> bool: return not _is_ror(e))
	var limited := {}
	for entry in built:
		if Array(army_roster.excluded_units).any(func(unit_name: String) -> bool: return RegimentOption._names(entry.warscroll, unit_name)):
			result.problems.append("%s armies can't include %s." % [army.army_of_renown, entry.warscroll.name])
			continue
		var matching := army_roster.entries.filter(func(e: RosterEntry) -> bool: return _roster_matches(e, entry.warscroll))
		if matching.is_empty():
			result.problems.append("%s isn't in the %s roster." % [entry.warscroll.name, army.army_of_renown])
		elif matching.all(func(e: RosterEntry) -> bool: return _is_limited(e)):
			var roster_entry: RosterEntry = matching[0]
			limited[roster_entry] = limited.get(roster_entry, 0) + 1
	for roster_entry: RosterEntry in limited:
		if roster_entry.per.is_empty():
			if limited[roster_entry] > roster_entry.max:
				result.problems.append("%s armies can include at most %d of %s (%d included)."
						% [army.army_of_renown, roster_entry.max, _describe(roster_entry), limited[roster_entry]])
			continue
		var allowed := built.filter(func(e: Dictionary) -> bool: return _per_matches(roster_entry, e.warscroll)).size()
		if limited[roster_entry] > allowed:
			result.problems.append("%s armies can include only 1 of %s for each %s unit (%d included, %d allowed)."
					% [army.army_of_renown, _describe(roster_entry), " or ".join(roster_entry.per), limited[roster_entry], allowed])
	for roster_entry in army_roster.entries:
		if not roster_entry.required and not roster_entry.general:
			continue
		var found := built.filter(func(e: Dictionary) -> bool: return _roster_matches(roster_entry, e.warscroll))
		if roster_entry.required and found.is_empty():
			result.problems.append("%s armies must include %s." % [army.army_of_renown, _describe(roster_entry)])
		if roster_entry.general and not found.is_empty() and not found.any(func(e: Dictionary) -> bool: return e.unit.uid == army.general_uid):
			result.problems.append("%s must be your general." % _describe(roster_entry))
