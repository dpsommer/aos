class_name CoreRulesLoader
extends FactionLoader
## Builds [CoreRules] from data/core, reading its abilities, lores and warscrolls as a faction's.
##
## The directory holds abilities.json and manifestation_lores.json, plus the General's Handbook
## battlepack in battlepack.json, battle_tactics.json and battleplans.json; see
## docs/technical/core-rules-data.md. Problems are collected in [member errors].


## Returns the core rules in [param dir_path], or null if any file is missing or invalid.
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

	rules.battlepack = _battlepack(dir_path)

	return null if not errors.is_empty() else rules


func _battlepack(dir_path: String) -> Battlepack:
	var pack := Battlepack.new()

	var data := _read(dir_path, "battlepack.json", true)
	if not data.is_empty():
		pack.name = _string(data, "name", "", true)
		pack.battle_rounds = _int(data, "battle_rounds", "", true)
	if data.has("battlefield") and _is_object(data.battlefield, "battlefield"):
		pack.battlefield_size = Vector2(_float(data.battlefield, "width", "battlefield", true),
				_float(data.battlefield, "depth", "battlefield", true))
	pack.sections = _rules_sections(data, "sections")
	var tables := _array(data, "battleplan_tables", "")
	for i in tables.size():
		var names := PackedStringArray()
		if not tables[i] is Array:
			_error("battleplan_tables[%d]" % i, "must be a list")
		else:
			for j in tables[i].size():
				if tables[i][j] is String:
					names.append(tables[i][j])
				else:
					_error("battleplan_tables[%d][%d]" % [i, j], "must be a string")
		pack.battleplan_tables.append(names)
	pack.season_rules = _abilities(data, "season_rules", "")
	pack.updated_abilities = _abilities(data, "updated_abilities", "")
	pack.faqs = _faqs(data, "")

	data = _read(dir_path, "battle_tactics.json", true)
	pack.battle_tactic_rules = _rules_sections(data, "sections")
	for i in _array(data, "cards", "").size():
		pack.battle_tactic_cards.append(_battle_tactic_card(data.cards[i], "cards[%d]" % i))

	data = _read(dir_path, "battleplans.json", true)
	pack.battleplan_rules = _rules_sections(data, "sections")
	for i in _array(data, "battleplans", "").size():
		pack.battleplans.append(_battleplan(data.battleplans[i], "battleplans[%d]" % i))

	return pack


func _rules_sections(data: Dictionary, key: String) -> Array[RulesSection]:
	var result: Array[RulesSection] = []
	for i in _array(data, key, "").size():
		result.append(_rules_section(data[key][i], "%s[%d]" % [key, i]))
	return result


func _battle_tactic_card(data: Variant, path: String) -> BattleTacticCard:
	var card := BattleTacticCard.new()
	if not _is_object(data, path):
		return card
	card.number = _int(data, "number", path, true)
	card.name = _string(data, "name", path, true)
	card.text = _string(data, "text", path)
	var tactics := _array(data, "tactics", path)
	for i in tactics.size():
		var tactic_path := "%s.tactics[%d]" % [path, i]
		var tactic := BattleTactic.new()
		if _is_object(tactics[i], tactic_path):
			tactic.name = _string(tactics[i], "name", tactic_path, true)
			tactic.kind = _string(tactics[i], "kind", tactic_path, true)
			if not tactic.kind.is_empty() and not tactic.kind in BattleTactic.KINDS:
				_error(_join(tactic_path, "kind"), "must be one of %s" % ", ".join(BattleTactic.KINDS))
			tactic.condition = _string(tactics[i], "condition", tactic_path, true)
			tactic.victory_points = _int(tactics[i], "victory_points", tactic_path, true)
		card.tactics.append(tactic)
	card.faqs = _faqs(data, path)
	return card


func _battleplan(data: Variant, path: String) -> Battleplan:
	var battleplan := Battleplan.new()
	if not _is_object(data, path):
		return battleplan
	battleplan.number = _int(data, "number", path, true)
	battleplan.table = _int(data, "table", path, true)
	battleplan.name = _string(data, "name", path, true)
	battleplan.text = _string(data, "text", path)
	battleplan.twist = _string(data, "twist", path)
	battleplan.abilities = _abilities(data, "abilities", path)
	battleplan.scoring = _strings(data, "scoring", path)
	battleplan.objectives = _map_features(data, "objectives", path, true)
	battleplan.terrain = _map_features(data, "terrain", path, false)
	battleplan.attacker_territory = _rects(data, "attacker_territory", path)
	battleplan.defender_territory = _rects(data, "defender_territory", path)
	battleplan.faqs = _faqs(data, path)
	return battleplan


## Objectives when [param objectives] is true, else terrain features, which also have a size.
func _map_features(data: Dictionary, key: String, path: String, objectives: bool) -> Array[MapFeature]:
	var result: Array[MapFeature] = []
	var items := _array(data, key, path)
	var types := MapFeature.OBJECTIVE_TYPES if objectives else MapFeature.TERRAIN_TYPES
	for i in items.size():
		var item_path := _join(path, "%s[%d]" % [key, i])
		var feature := MapFeature.new()
		if _is_object(items[i], item_path):
			feature.type = _string(items[i], "type", item_path, true)
			if not feature.type.is_empty() and not feature.type in types:
				_error(_join(item_path, "type"), "must be one of %s" % ", ".join(types))
			if not objectives:
				feature.size = _string(items[i], "size", item_path, true)
				if not feature.size.is_empty() and not feature.size in MapFeature.TERRAIN_SIZES:
					_error(_join(item_path, "size"), "must be one of %s" % ", ".join(MapFeature.TERRAIN_SIZES))
			feature.position = Vector2(_float(items[i], "x", item_path, true), _float(items[i], "y", item_path, true))
		result.append(feature)
	return result


func _rects(data: Dictionary, key: String, path: String) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var items := _array(data, key, path)
	for i in items.size():
		var item_path := _join(path, "%s[%d]" % [key, i])
		if _is_object(items[i], item_path):
			result.append(Rect2(_float(items[i], "x", item_path, true), _float(items[i], "y", item_path, true),
					_float(items[i], "width", item_path, true), _float(items[i], "depth", item_path, true)))
	return result


func _faqs(data: Dictionary, path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var items := _array(data, "faqs", path)
	for i in items.size():
		var item_path := _join(path, "faqs[%d]" % i)
		if _is_object(items[i], item_path):
			result.append({
				"about": _string(items[i], "about", item_path),
				"question": _string(items[i], "question", item_path, true),
				"answer": _string(items[i], "answer", item_path, true),
			})
	return result


func _float(data: Dictionary, key: String, path: String, required := false) -> float:
	if not data.has(key):
		if required:
			_error(_join(path, key), "is required")
		return 0.0
	if not (data[key] is float or data[key] is int):
		_error(_join(path, key), "must be a number")
		return 0.0
	return float(data[key])
