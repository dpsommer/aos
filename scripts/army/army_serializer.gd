class_name ArmySerializer
extends RefCounted
## Converts armies to and from JSON-compatible dictionaries for saving.

const VERSION := 1

## Problems found by the last [method from_dict] call.
var errors: PackedStringArray


static func to_dict(army: Army) -> Dictionary:
	var regiments := []
	for regiment in army.regiments:
		var data := {"id": regiment.id, "name": regiment.name, "units": _units(regiment.units)}
		if regiment.is_regiment_of_renown():
			data.regiment_of_renown = regiment.regiment_of_renown
		regiments.append(data)
	return {
		"version": VERSION,
		"faction": army.faction_id,
		"name": army.name,
		"army_of_renown": army.army_of_renown,
		"formation": army.formation,
		"points_limit": army.points_limit,
		"show_legends": army.show_legends,
		"override_constraints": army.override_constraints,
		"regiments": regiments,
		"auxiliary": _units(army.auxiliary),
		"general": army.general_uid,
		"tactics": Array(army.tactics),
		"lores": {"spell": army.spell_lore, "prayer": army.prayer_lore, "manifestation": army.manifestation_lore},
		"faction_terrain": army.faction_terrain,
	}


static func _units(units: Array[ArmyUnit]) -> Array:
	var result := []
	for unit in units:
		var data := {"uid": unit.uid, "warscroll": unit.warscroll_id}
		if not unit.faction_id.is_empty():
			data.faction = unit.faction_id
		if not unit.label.is_empty():
			data.label = unit.label
		if unit.reinforced:
			data.reinforced = true
		if not unit.enhancements.is_empty():
			data.enhancements = unit.enhancements.duplicate()
		if not unit.weapon_options.is_empty():
			data.weapon_options = unit.weapon_options.duplicate()
		result.append(data)
	return result


## Returns the army in [param data], or null if it isn't a saved army this version can read.
## Fields with the wrong type are reported in [member errors] and left at their defaults.
func from_dict(data: Dictionary) -> Army:
	errors = PackedStringArray()
	var version: Variant = data.get("version")
	if not (version is float or version is int) or int(version) < 1 or int(version) > VERSION:
		errors.append("version: unsupported saved army version %s" % str(version))
		return null
	var army := Army.new()
	army.faction_id = _string(data, "faction")
	if army.faction_id.is_empty():
		errors.append("faction: is required")
		return null
	army.name = _string(data, "name")
	army.army_of_renown = _string(data, "army_of_renown")
	army.formation = _string(data, "formation")
	army.points_limit = _int(data, "points_limit", Army.DEFAULT_POINTS_LIMIT)
	army.show_legends = _bool(data, "show_legends")
	army.override_constraints = _bool(data, "override_constraints")
	for i in _array(data, "regiments").size():
		var entry: Variant = data.regiments[i]
		if not entry is Dictionary:
			errors.append("regiments[%d]: must be an object" % i)
			continue
		var regiment := ArmyRegiment.new()
		regiment.id = _string(entry, "id", "regiments[%d]" % i)
		regiment.name = _string(entry, "name", "regiments[%d]" % i)
		regiment.regiment_of_renown = _string(entry, "regiment_of_renown", "regiments[%d]" % i)
		regiment.units = _read_units(entry, "units", "regiments[%d]." % i)
		army.regiments.append(regiment)
	army.auxiliary = _read_units(data, "auxiliary", "")
	army.general_uid = _string(data, "general")
	for i in _array(data, "tactics").size():
		army.tactics.append(data.tactics[i] if data.tactics[i] is String else "")
	var lores: Variant = data.get("lores", {})
	if lores is Dictionary:
		army.spell_lore = _string(lores, "spell", "lores")
		army.prayer_lore = _string(lores, "prayer", "lores")
		army.manifestation_lore = _string(lores, "manifestation", "lores")
	army.faction_terrain = _string(data, "faction_terrain")
	return army


func _read_units(data: Dictionary, key: String, path: String) -> Array[ArmyUnit]:
	var result: Array[ArmyUnit] = []
	var items := _array(data, key, path)
	for i in items.size():
		var unit_path := "%s%s[%d]" % [path, key, i]
		if not items[i] is Dictionary:
			errors.append("%s: must be an object" % unit_path)
			continue
		var unit := ArmyUnit.new()
		unit.uid = _string(items[i], "uid", unit_path)
		unit.warscroll_id = _string(items[i], "warscroll", unit_path)
		unit.faction_id = _string(items[i], "faction", unit_path)
		unit.label = _string(items[i], "label", unit_path)
		unit.reinforced = _bool(items[i], "reinforced", unit_path)
		var enhancements: Variant = items[i].get("enhancements", {})
		if enhancements is Dictionary:
			for type: Variant in enhancements:
				if type is String and enhancements[type] is String:
					unit.enhancements[type] = enhancements[type]
		var options: Variant = items[i].get("weapon_options", {})
		if options is Dictionary:
			for option: Variant in options:
				if option is String and (options[option] is float or options[option] is int):
					unit.weapon_options[option] = int(options[option])
		if unit.uid.is_empty() or unit.warscroll_id.is_empty():
			errors.append("%s: needs a uid and warscroll" % unit_path)
			continue
		result.append(unit)
	return result


func _string(data: Dictionary, key: String, path := "") -> String:
	var value: Variant = data.get(key, "")
	if value is String:
		return value
	errors.append("%s: must be a string" % _join(path, key))
	return ""


func _int(data: Dictionary, key: String, default: int) -> int:
	var value: Variant = data.get(key, default)
	if value is float or value is int:
		return int(value)
	errors.append("%s: must be a number" % key)
	return default


func _bool(data: Dictionary, key: String, path := "") -> bool:
	var value: Variant = data.get(key, false)
	if value is bool:
		return value
	errors.append("%s: must be true or false" % _join(path, key))
	return false


func _array(data: Dictionary, key: String, path := "") -> Array:
	var value: Variant = data.get(key, [])
	if value is Array:
		return value
	errors.append("%s: must be a list" % _join(path, key))
	return []


static func _join(path: String, key: String) -> String:
	return key if path.is_empty() else "%s.%s" % [path, key]
