class_name CoreRulesLoader
extends FactionLoader
## Builds [CoreRules] from data/core, reading its abilities, lores and warscrolls as a faction's.
##
## The directory holds abilities.json and manifestation_lores.json; see
## docs/technical/core-rules-data.md. Problems are collected in [member errors].


## Returns the core rules in [param dir_path], or null if either file is missing or invalid.
func load_core_rules(dir_path := "res://data/core") -> CoreRules:
	errors = PackedStringArray()
	var rules := CoreRules.new()

	var data := _read(dir_path, "abilities.json", true)
	rules.abilities = _abilities(data, "abilities", "")
	rules.weapon_abilities = _abilities(data, "weapon_abilities", "")
	rules.terrain_abilities = _abilities(data, "terrain_abilities", "")

	data = _read(dir_path, "manifestation_lores.json", true)
	rules.manifestation_lores = _lores(data, "")
	for i in _array(data, "warscrolls", "").size():
		rules.manifestations.append(_warscroll(data.warscrolls[i], "warscrolls[%d]" % i, true))

	return null if not errors.is_empty() else rules
