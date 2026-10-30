class_name FactionLoader
extends RefCounted
## Builds a [Faction] from a directory of JSON files.
##
## The directory holds faction.json plus optional warscrolls.json, armies_of_renown.json,
## spearhead.json and path_to_glory.json. Warscrolls and Armies of Renown that several factions use,
## such as Nagash, live once in [member shared_dir] and are referenced by the faction files. Every
## Regiment of Renown lives in [member shared_dir] too, listing the ids of the factions that can
## include it.
## See docs/technical/faction-data.md for the format. Problems are collected in [member errors]
## rather than reported, so callers decide how to surface them.

## Problems found by the last [method load_faction] call, each naming the file and field.
var errors: PackedStringArray
## Directory of the shared warscrolls.json, armies_of_renown.json and regiments_of_renown.json.
var shared_dir := "res://data/shared"
## The Scourge the battlepack uses (see [member Battlepack.scourge]). Warscrolls, enhancement tables
## and lores from any other Scourge are loaded as Legends, keeping their [code]source[/code]. Empty
## treats every Scourge as current.
var scourge := ""

var _file: String
## Shared entries read by the current [method load_faction] call, by file name, then by id
## (warscrolls) or name (Armies of Renown).
var _shared := {}


## Returns the faction in [param dir_path], or null if any file is missing or invalid.
func load_faction(dir_path: String) -> Faction:
	errors = PackedStringArray()
	_shared = {}
	var faction := Faction.new()

	var data := _read(dir_path, "faction.json", true)
	if data.is_empty():
		return null
	faction.id = _string(data, "id", "", true)
	faction.name = _string(data, "name", "", true)
	var alliance := GrandAlliance.from_id(_string(data, "grand_alliance", "", true))
	if alliance < 0:
		_error("grand_alliance", "is not a Grand Alliance")
	else:
		faction.grand_alliance = alliance
	faction.legends = _bool(data, "legends", "")
	faction.battle_traits = _abilities(data, "battle_traits", "")
	for i in _array(data, "battle_formations", "").size():
		faction.battle_formations.append(_battle_formation(data.battle_formations[i], "battle_formations[%d]" % i))
	faction.enhancement_tables = _enhancement_tables(data, "")
	faction.lores = _lores(data, "")

	data = _read(dir_path, "warscrolls.json")
	for i in _array(data, "warscrolls", "").size():
		var path := "warscrolls[%d]" % i
		var entry: Variant = _resolve_shared(data.warscrolls[i], path, "warscrolls.json", "warscrolls", "id")
		if entry != null:
			faction.warscrolls.append(_warscroll(entry, path, true))

	data = _read(dir_path, "armies_of_renown.json")
	for i in _array(data, "armies_of_renown", "").size():
		var path := "armies_of_renown[%d]" % i
		var entry: Variant = _resolve_shared(data.armies_of_renown[i], path, "armies_of_renown.json", "armies_of_renown", "name")
		if entry != null:
			faction.armies_of_renown.append(_army_of_renown(entry, path))

	data = _read(shared_dir, "regiments_of_renown.json", false, "shared/regiments_of_renown.json")
	var regiments := _array(data, "regiments_of_renown", "")
	for i in regiments.size():
		var path := "regiments_of_renown[%d]" % i
		if _is_object(regiments[i], path) and faction.id in _strings(regiments[i], "factions", path):
			faction.regiments_of_renown.append(_regiment_of_renown(regiments[i], path))

	data = _read(dir_path, "spearhead.json")
	for i in _array(data, "spearheads", "").size():
		faction.spearheads.append(_spearhead(data.spearheads[i], "spearheads[%d]" % i))

	data = _read(dir_path, "path_to_glory.json")
	for i in _array(data, "sections", "").size():
		faction.path_to_glory.append(_rules_section(data.sections[i], "sections[%d]" % i))

	_mark_summoned(faction)
	return null if not errors.is_empty() else faction


## Marks the faction's units (not manifestations) that its abilities summon as
## [member Warscroll.summoned].
func _mark_summoned(faction: Faction) -> void:
	var abilities: Array[Ability] = []
	abilities.append_array(faction.battle_traits)
	for formation in faction.battle_formations:
		abilities.append_array(formation.abilities)
	for table in faction.enhancement_tables:
		abilities.append_array(table.entries)
	for lore in faction.lores:
		abilities.append_array(lore.entries)
	for warscroll in faction.warscrolls:
		abilities.append_array(warscroll.abilities)
	for army in faction.armies_of_renown:
		abilities.append_array(army.battle_traits)
		for table in army.enhancement_tables:
			abilities.append_array(table.entries)
		for lore in army.lores:
			abilities.append_array(lore.entries)
	var ids := {}
	for ability in abilities:
		for warscroll_id in ability.summons:
			ids[warscroll_id] = true
	for warscroll in faction.warscrolls:
		warscroll.summoned = ids.has(warscroll.id) and not warscroll.has_keyword("MANIFESTATION")


## Whether [param source] is a Scourge other than [member scourge], so its rules are Legends.
func _is_retired(source: String) -> bool:
	return not scourge.is_empty() and source.begins_with("Scourge of") and source != scourge


## [param label] names the file in errors; it defaults to [param file_name].
func _read(dir_path: String, file_name: String, required := false, label := "") -> Dictionary:
	_file = label if not label.is_empty() else file_name
	var path := dir_path.path_join(file_name)
	if not FileAccess.file_exists(path):
		if required:
			_error("", "file not found at %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		_error("", "invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		_error("", "top level is not an object")
		return {}
	return json.data


## Returns [param data], or for a reference such as [code]{"shared": "nagash"}[/code] the shared
## entry it names with the reference's other fields applied: its keywords are added to the shared
## entry's, each of its abilities replaces the shared ability of the same name or is added, and any
## other field replaces the shared value. Returns null, having recorded the error, if the reference
## names no shared entry.
func _resolve_shared(data: Variant, path: String, file_name: String, list_key: String, key: String) -> Variant:
	if not data is Dictionary or not data.has("shared"):
		return data
	var shared_key := _string(data, "shared", path, true)
	var entries := _shared_entries(file_name, list_key, key)
	if not entries.has(shared_key):
		_error(_join(path, "shared"), "names no entry in shared %s" % file_name)
		return null
	var result: Dictionary = entries[shared_key].duplicate(true)
	for field: String in data:
		if field == "shared":
			continue
		if field == "keywords" and data[field] is Array and result.get(field) is Array:
			for keyword: Variant in data[field]:
				if not keyword in result[field]:
					result[field].append(keyword)
		elif field == "abilities" and data[field] is Array and result.get(field) is Array:
			result[field] = _merge_abilities(result[field], data[field])
		else:
			result[field] = data[field]
	return result


## [param shared] with each of [param own] replacing the ability of the same name, or added.
func _merge_abilities(shared: Array, own: Array) -> Array:
	var result := shared.duplicate()
	for ability: Variant in own:
		var index := -1
		for i in result.size():
			if result[i] is Dictionary and ability is Dictionary and result[i].get("name") == ability.get("name"):
				index = i
		if index < 0:
			result.append(ability)
		else:
			result[index] = ability
	return result


func _shared_entries(file_name: String, list_key: String, key: String) -> Dictionary:
	if _shared.has(file_name):
		return _shared[file_name]
	var faction_file := _file
	var entries := {}
	var data := _read(shared_dir, file_name, true, "shared/%s" % file_name)
	var items := _array(data, list_key, "")
	for i in items.size():
		if _is_object(items[i], "%s[%d]" % [list_key, i]):
			entries[_string(items[i], key, "%s[%d]" % [list_key, i], true)] = items[i]
	_file = faction_file
	_shared[file_name] = entries
	return entries


func _ability(data: Variant, path: String) -> Ability:
	var ability := Ability.new()
	if not _is_object(data, path):
		return ability
	ability.name = _string(data, "name", path, true)
	ability.type = _string(data, "type", path)
	if not ability.type.is_empty() and not ability.type in Ability.TYPES:
		_error(_join(path, "type"), "must be one of %s" % ", ".join(Ability.TYPES))
	ability.category = _string(data, "category", path)
	ability.colour = _string(data, "colour", path)
	if not ability.colour.is_empty() and not ability.colour in Ability.COLOURS:
		_error(_join(path, "colour"), "must be one of %s" % ", ".join(Ability.COLOURS))
	ability.timing = _string(data, "timing", path)
	ability.frequency = _string(data, "frequency", path)
	ability.declare = _string(data, "declare", path)
	ability.used_by = _string(data, "used_by", path)
	ability.effect = _string(data, "effect", path)
	ability.text = _string(data, "text", path)
	ability.keywords = _strings(data, "keywords", path)
	ability.points = _int(data, "points", path)
	ability.command_points = _int(data, "command_points", path)
	ability.casting_value = _int(data, "casting_value", path)
	ability.chanting_value = _int(data, "chanting_value", path)
	ability.source = _string(data, "source", path)
	ability.summons = _strings(data, "summons", path)
	var options := _array(data, "options", path)
	for i in options.size():
		var option_path := "%s.options[%d]" % [path, i]
		if _is_object(options[i], option_path):
			ability.options.append({
				"name": _string(options[i], "name", option_path, true),
				"text": _string(options[i], "text", option_path, true),
			})
	return ability


func _abilities(data: Dictionary, key: String, path: String) -> Array[Ability]:
	var result: Array[Ability] = []
	var items := _array(data, key, path)
	for i in items.size():
		result.append(_ability(items[i], _join(path, "%s[%d]" % [key, i])))
	return result


func _battle_formation(data: Variant, path: String) -> BattleFormation:
	var formation := BattleFormation.new()
	if _is_object(data, path):
		formation.name = _string(data, "name", path, true)
		formation.points = _int(data, "points", path)
		formation.abilities = _abilities(data, "abilities", path)
	return formation


func _enhancement_tables(data: Dictionary, path: String) -> Array[EnhancementTable]:
	var result: Array[EnhancementTable] = []
	var items := _array(data, "enhancement_tables", path)
	for i in items.size():
		var table_path := _join(path, "enhancement_tables[%d]" % i)
		var table := EnhancementTable.new()
		if _is_object(items[i], table_path):
			table.name = _string(items[i], "name", table_path, true)
			table.group = _string(items[i], "group", table_path)
			table.source = _string(items[i], "source", table_path)
			table.legends = _is_retired(table.source)
			table.units = _strings(items[i], "units", table_path)
			table.max = _int(items[i], "max", table_path) if items[i].has("max") else 1
			table.entries = _abilities(items[i], "entries", table_path)
		result.append(table)
	return result


func _lores(data: Dictionary, path: String) -> Array[Lore]:
	var result: Array[Lore] = []
	var items := _array(data, "lores", path)
	for i in items.size():
		var lore_path := _join(path, "lores[%d]" % i)
		var lore := Lore.new()
		if _is_object(items[i], lore_path):
			lore.name = _string(items[i], "name", lore_path, true)
			lore.kind = _string(items[i], "kind", lore_path)
			lore.points = _int(items[i], "points", lore_path)
			lore.source = _string(items[i], "source", lore_path)
			lore.legends = _is_retired(lore.source)
			lore.entries = _abilities(items[i], "entries", lore_path)
		result.append(lore)
	return result


func _weapon(data: Variant, path: String) -> Weapon:
	var weapon := Weapon.new()
	if _is_object(data, path):
		weapon.name = _string(data, "name", path, true)
		weapon.range = _int(data, "range", path)
		weapon.attacks = _string(data, "attacks", path, true)
		weapon.hit = _int(data, "hit", path, true)
		weapon.wound = _int(data, "wound", path, true)
		weapon.rend = _int(data, "rend", path)
		weapon.damage = _string(data, "damage", path, true)
		weapon.abilities = _strings(data, "abilities", path)
	return weapon


func _weapons(data: Dictionary, key: String, path: String) -> Array[Weapon]:
	var result: Array[Weapon] = []
	var items := _array(data, key, path)
	for i in items.size():
		result.append(_weapon(items[i], "%s.%s[%d]" % [path, key, i]))
	return result


## Spearhead and Path to Glory warscrolls have no battle profile, so [param with_profile]
## controls whether points and unit size are required.
func _warscroll(data: Variant, path: String, with_profile: bool) -> Warscroll:
	var warscroll := Warscroll.new()
	if not _is_object(data, path):
		return warscroll
	warscroll.id = _string(data, "id", path, true)
	warscroll.name = _string(data, "name", path, true)
	warscroll.source = _string(data, "source", path)
	warscroll.legends = _bool(data, "legends", path) or _is_retired(warscroll.source)
	warscroll.army_of_renown = _string(data, "army_of_renown", path)
	warscroll.points = _int(data, "points", path, with_profile)
	warscroll.unit_size = _int(data, "unit_size", path, with_profile)
	warscroll.base_size = _string(data, "base_size", path)
	warscroll.can_reinforce = _bool(data, "can_reinforce", path)
	warscroll.regiment_options = _strings(data, "regiment_options", path)
	warscroll.notes = _string(data, "notes", path)
	warscroll.move = _string(data, "move", path, true)
	warscroll.health = _int(data, "health", path, true)
	warscroll.save = _int(data, "save", path, true)
	warscroll.ward = _int(data, "ward", path)
	warscroll.control = _int(data, "control", path, true)
	warscroll.banishment = _int(data, "banishment", path)
	warscroll.ranged_weapons = _weapons(data, "ranged_weapons", path)
	warscroll.melee_weapons = _weapons(data, "melee_weapons", path)
	warscroll.abilities = _abilities(data, "abilities", path)
	warscroll.keywords = _strings(data, "keywords", path)
	warscroll.composition = _string(data, "composition", path)
	var options := _array(data, "weapon_options", path)
	for i in options.size():
		warscroll.weapon_options.append(_weapon_option(options[i], "%s.weapon_options[%d]" % [path, i]))
	return warscroll


func _weapon_option(data: Variant, path: String) -> WeaponOption:
	var option := WeaponOption.new()
	if not _is_object(data, path):
		return option
	option.name = _string(data, "name", path, true)
	option.replaces = _string(data, "replaces", path, true)
	option.choice = _bool(data, "choice", path)
	option.max = _int(data, "max", path, not option.choice)
	option.per = _int(data, "per", path, not option.choice)
	if not option.choice and option.per <= 0:
		_error(_join(path, "per"), "must be more than 0")
	option.note = _string(data, "note", path)
	return option


func _army_of_renown(data: Variant, path: String) -> ArmyOfRenown:
	var army := ArmyOfRenown.new()
	if _is_object(data, path):
		army.name = _string(data, "name", path, true)
		army.source = _string(data, "source", path)
		army.legends = _bool(data, "legends", path)
		army.keyword = _string(data, "keyword", path)
		army.text = _string(data, "text", path)
		if data.has("roster"):
			army.roster = _roster(data.roster, _join(path, "roster"))
		army.battle_traits = _abilities(data, "battle_traits", path)
		army.enhancement_tables = _enhancement_tables(data, path)
		army.lores = _lores(data, path)
	return army


func _roster(data: Variant, path: String) -> ArmyRoster:
	var roster := ArmyRoster.new()
	if not _is_object(data, path):
		return roster
	var entries := _array(data, "entries", path)
	for i in entries.size():
		var entry_path := _join(path, "entries[%d]" % i)
		var entry := RosterEntry.new()
		if _is_object(entries[i], entry_path):
			entry.unit = _string(entries[i], "unit", entry_path)
			entry.one_of = _strings(entries[i], "one_of", entry_path)
			entry.keywords = _strings(entries[i], "keywords", entry_path)
			entry.not_keywords = _strings(entries[i], "not_keywords", entry_path)
			if [entry.unit.is_empty(), entry.one_of.is_empty(), entry.keywords.is_empty()].count(false) != 1:
				_error(entry_path, "needs exactly one of unit, one_of or keywords")
			entry.per = _strings(entries[i], "per", entry_path)
			entry.max = _int(entries[i], "max", entry_path)
			entry.required = _bool(entries[i], "required", entry_path)
			entry.general = _bool(entries[i], "general", entry_path)
			entry.gains_keywords = _strings(entries[i], "gains_keywords", entry_path)
		roster.entries.append(entry)
	roster.regiments_of_renown = _bool(data, "regiments_of_renown", path, true)
	roster.faction_terrain = _bool(data, "faction_terrain", path, true)
	roster.manifestations = _bool(data, "manifestations", path, true)
	roster.excluded_units = _strings(data, "excluded_units", path)
	roster.paired_leaders = _strings(data, "paired_leaders", path)
	if roster.paired_leaders.size() not in [0, 2]:
		_error(_join(path, "paired_leaders"), "needs exactly 2 keywords")
	var included := _array(data, "included_units", path)
	for i in included.size():
		var inclusion_path := _join(path, "included_units[%d]" % i)
		if _is_object(included[i], inclusion_path):
			var inclusion := RosterInclusion.new()
			inclusion.faction = _string(included[i], "faction", inclusion_path, true)
			inclusion.units = _strings(included[i], "units", inclusion_path)
			roster.included_units.append(inclusion)
	if data.has("non_hero_general"):
		var general_path := _join(path, "non_hero_general")
		if _is_object(data.non_hero_general, general_path):
			roster.non_hero_general = _string(data.non_hero_general, "unit", general_path, true)
			roster.non_hero_general_unless = _strings(data.non_hero_general, "unless", general_path)
	roster.non_hero_leaders = _strings(data, "non_hero_leaders", path)
	var added := _array(data, "regiment_options", path)
	for i in added.size():
		var added_path := _join(path, "regiment_options[%d]" % i)
		if _is_object(added[i], added_path):
			var regiment_options := RosterRegimentOptions.new()
			regiment_options.leaders = _strings(added[i], "leaders", added_path)
			regiment_options.options = _strings(added[i], "options", added_path)
			regiment_options.heroes = _bool(added[i], "heroes", added_path)
			if regiment_options.options.is_empty():
				_error(_join(added_path, "options"), "needs at least 1 option")
			roster.regiment_options.append(regiment_options)
	return roster


func _regiment_of_renown(data: Variant, path: String) -> RegimentOfRenown:
	var regiment := RegimentOfRenown.new()
	if not _is_object(data, path):
		return regiment
	regiment.name = _string(data, "name", path, true)
	regiment.source = _string(data, "source", path)
	regiment.legends = _bool(data, "legends", path)
	regiment.points = _int(data, "points", path, true)
	regiment.factions = _strings(data, "factions", path)
	regiment.text = _string(data, "text", path)
	var units := _array(data, "units", path)
	for i in units.size():
		var unit_path := "%s.units[%d]" % [path, i]
		var unit := RegimentUnit.new()
		if _is_object(units[i], unit_path):
			unit.count = _int(units[i], "count", unit_path, true)
			unit.name = _string(units[i], "name", unit_path, true)
			unit.faction_id = _string(units[i], "faction", unit_path)
			unit.warscroll_id = _string(units[i], "warscroll", unit_path, true)
			unit.notes = _string(units[i], "notes", unit_path)
		regiment.units.append(unit)
	regiment.abilities = _abilities(data, "abilities", path)
	var warscrolls := _array(data, "warscrolls", path)
	for i in warscrolls.size():
		regiment.warscrolls.append(_warscroll(warscrolls[i], "%s.warscrolls[%d]" % [path, i], true))
	return regiment


func _spearhead(data: Variant, path: String) -> Spearhead:
	var spearhead := Spearhead.new()
	if not _is_object(data, path):
		return spearhead
	spearhead.name = _string(data, "name", path, true)
	spearhead.text = _string(data, "text", path)
	spearhead.general = _string(data, "general", path, true)
	var units := _array(data, "units", path)
	for i in units.size():
		var unit_path := "%s.units[%d]" % [path, i]
		var unit := SpearheadUnit.new()
		if _is_object(units[i], unit_path):
			unit.count = _int(units[i], "count", unit_path, true)
			unit.name = _string(units[i], "name", unit_path, true)
			unit.notes = _string(units[i], "notes", unit_path)
		spearhead.units.append(unit)
	spearhead.battle_traits = _abilities(data, "battle_traits", path)
	spearhead.regiment_abilities = _abilities(data, "regiment_abilities", path)
	spearhead.enhancements = _abilities(data, "enhancements", path)
	var warscrolls := _array(data, "warscrolls", path)
	for i in warscrolls.size():
		spearhead.warscrolls.append(_warscroll(warscrolls[i], "%s.warscrolls[%d]" % [path, i], false))
	return spearhead


func _rules_section(data: Variant, path: String) -> RulesSection:
	var section := RulesSection.new()
	if not _is_object(data, path):
		return section
	section.name = _string(data, "name", path, true)
	section.text = _string(data, "text", path)
	var warscrolls := _array(data, "warscrolls", path)
	for i in warscrolls.size():
		section.warscrolls.append(_warscroll(warscrolls[i], "%s.warscrolls[%d]" % [path, i], false))
	return section


# Field readers. Each records an error and returns a default when the field is missing
# (and required) or has the wrong type.

func _string(data: Dictionary, key: String, path: String, required := false) -> String:
	if not data.has(key):
		if required:
			_error(_join(path, key), "is required")
		return ""
	if not data[key] is String:
		_error(_join(path, key), "must be a string")
		return ""
	return data[key]


func _int(data: Dictionary, key: String, path: String, required := false) -> int:
	if not data.has(key):
		if required:
			_error(_join(path, key), "is required")
		return 0
	# JSON numbers are floats; reject fractional values rather than truncating them.
	var value: Variant = data[key]
	if not (value is float or value is int) or value != floorf(value):
		_error(_join(path, key), "must be a whole number")
		return 0
	return int(value)


func _bool(data: Dictionary, key: String, path: String, default := false) -> bool:
	if not data.has(key):
		return default
	if not data[key] is bool:
		_error(_join(path, key), "must be true or false")
		return default
	return data[key]


func _array(data: Dictionary, key: String, path: String) -> Array:
	if not data.has(key):
		return []
	if not data[key] is Array:
		_error(_join(path, key), "must be a list")
		return []
	return data[key]


func _strings(data: Dictionary, key: String, path: String) -> PackedStringArray:
	var result := PackedStringArray()
	var items := _array(data, key, path)
	for i in items.size():
		if items[i] is String:
			result.append(items[i])
		else:
			_error(_join(path, "%s[%d]" % [key, i]), "must be a string")
	return result


func _is_object(data: Variant, path: String) -> bool:
	if data is Dictionary:
		return true
	_error(path, "must be an object")
	return false


func _join(path: String, key: String) -> String:
	return key if path.is_empty() else "%s.%s" % [path, key]


func _error(field: String, message: String) -> void:
	errors.append("%s: %s %s" % [_file, field, message] if not field.is_empty() else "%s: %s" % [_file, message])
