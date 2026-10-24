class_name FactionLoader
extends RefCounted
## Builds a [Faction] from a directory of JSON files.
##
## The directory holds faction.json plus optional warscrolls.json, armies_of_renown.json,
## spearhead.json and path_to_glory.json. See docs/technical/faction-data.md for the format.
## Problems are collected in [member errors] rather than reported, so callers decide how to
## surface them.

## Problems found by the last [method load_faction] call, each naming the file and field.
var errors: PackedStringArray

var _file: String


## Returns the faction in [param dir_path], or null if any file is missing or invalid.
func load_faction(dir_path: String) -> Faction:
	errors = PackedStringArray()
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
	faction.battle_traits = _abilities(data, "battle_traits", "")
	for i in _array(data, "battle_formations", "").size():
		faction.battle_formations.append(_battle_formation(data.battle_formations[i], "battle_formations[%d]" % i))
	faction.enhancement_tables = _enhancement_tables(data, "")
	faction.lores = _lores(data, "")

	data = _read(dir_path, "warscrolls.json")
	for i in _array(data, "warscrolls", "").size():
		faction.warscrolls.append(_warscroll(data.warscrolls[i], "warscrolls[%d]" % i, true))

	data = _read(dir_path, "armies_of_renown.json")
	for i in _array(data, "armies_of_renown", "").size():
		faction.armies_of_renown.append(_army_of_renown(data.armies_of_renown[i], "armies_of_renown[%d]" % i))

	data = _read(dir_path, "spearhead.json")
	for i in _array(data, "spearheads", "").size():
		faction.spearheads.append(_spearhead(data.spearheads[i], "spearheads[%d]" % i))

	data = _read(dir_path, "path_to_glory.json")
	for i in _array(data, "sections", "").size():
		faction.path_to_glory.append(_rules_section(data.sections[i], "sections[%d]" % i))

	return null if not errors.is_empty() else faction


func _read(dir_path: String, file_name: String, required := false) -> Dictionary:
	_file = file_name
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


func _ability(data: Variant, path: String) -> Ability:
	var ability := Ability.new()
	if not _is_object(data, path):
		return ability
	ability.name = _string(data, "name", path, true)
	ability.category = _string(data, "category", path)
	ability.timing = _string(data, "timing", path)
	ability.frequency = _string(data, "frequency", path)
	ability.declare = _string(data, "declare", path)
	ability.effect = _string(data, "effect", path)
	ability.text = _string(data, "text", path)
	ability.keywords = _strings(data, "keywords", path)
	ability.points = _int(data, "points", path)
	ability.casting_value = _int(data, "casting_value", path)
	ability.chanting_value = _int(data, "chanting_value", path)
	ability.source = _string(data, "source", path)
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
	warscroll.legends = _bool(data, "legends", path)
	warscroll.points = _int(data, "points", path, with_profile)
	warscroll.unit_size = _int(data, "unit_size", path, with_profile)
	warscroll.base_size = _string(data, "base_size", path)
	warscroll.can_reinforce = _bool(data, "can_reinforce", path)
	warscroll.regiment_options = _strings(data, "regiment_options", path)
	warscroll.notes = _string(data, "notes", path)
	warscroll.move = _int(data, "move", path, true)
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
	return warscroll


func _army_of_renown(data: Variant, path: String) -> ArmyOfRenown:
	var army := ArmyOfRenown.new()
	if _is_object(data, path):
		army.name = _string(data, "name", path, true)
		army.source = _string(data, "source", path)
		army.text = _string(data, "text", path)
		army.battle_traits = _abilities(data, "battle_traits", path)
		army.enhancement_tables = _enhancement_tables(data, path)
		army.lores = _lores(data, path)
	return army


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


func _bool(data: Dictionary, key: String, path: String) -> bool:
	if not data.has(key):
		return false
	if not data[key] is bool:
		_error(_join(path, key), "must be true or false")
		return false
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
