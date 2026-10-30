class_name SpearheadLoader
extends CoreRulesLoader
## Builds a [SpearheadBattlepack] from one of the JSON files in data/core/spearhead; see
## docs/technical/core-rules-data.md. Problems are collected in [member errors].


## Returns the battlepack in [param file_path], or null if it is missing or invalid.
func load_battlepack(file_path: String) -> SpearheadBattlepack:
	errors = PackedStringArray()
	var pack := SpearheadBattlepack.new()
	var data := _read(file_path.get_base_dir(), file_path.get_file(), true)
	if data.is_empty():
		return null

	pack.name = _string(data, "name", "", true)
	pack.battle_rounds = _int(data, "battle_rounds", "", true)
	if not data.has("battlefield"):
		_error("battlefield", "is required")
	elif _is_object(data.battlefield, "battlefield"):
		pack.battlefield_size = Vector2(_float(data.battlefield, "width", "battlefield", true),
				_float(data.battlefield, "depth", "battlefield", true))
	pack.sections = _rules_sections(data, "sections")
	pack.abilities = _abilities(data, "abilities", "")
	pack.terrain_abilities = _abilities(data, "terrain_abilities", "")
	var terrain := _array(data, "terrain_features", "")
	for i in terrain.size():
		pack.terrain_features.append(_terrain(terrain[i], "terrain_features[%d]" % i, pack))
	var groups := _array(data, "terrain_groups", "")
	for i in groups.size():
		pack.terrain_groups.append(_terrain_group(groups[i], "terrain_groups[%d]" % i, pack))
	pack.objective_names = _strings(data, "objective_names", "")
	pack.objective_radius = _float(data, "objective_radius", "", true)
	var realms := _array(data, "realms", "")
	for i in realms.size():
		pack.realms.append(_realm(realms[i], "realms[%d]" % i, pack))
	var maps := _array(data, "deployment_maps", "")
	for i in maps.size():
		pack.deployment_maps.append(_deployment_map(maps[i], "deployment_maps[%d]" % i))
	if not data.has("battleplan"):
		_error("battleplan", "is required")
	elif _is_object(data.battleplan, "battleplan"):
		pack.battleplan_name = _string(data.battleplan, "name", "battleplan", true)
		var sections := _array(data.battleplan, "sections", "battleplan")
		for i in sections.size():
			pack.battleplan_sections.append(_rules_section(sections[i], "battleplan.sections[%d]" % i))
		pack.scoring = _strings(data.battleplan, "scoring", "battleplan")
	var cards := _array(data, "battle_tactic_cards", "")
	for i in cards.size():
		pack.battle_tactic_cards.append(_tactic_card(cards[i], "battle_tactic_cards[%d]" % i))
	pack.faqs = _faqs(data, "")

	return null if not errors.is_empty() else pack


## Each of the terrain feature's abilities must be one of [param pack]'s terrain abilities.
func _terrain(data: Variant, path: String, pack: SpearheadBattlepack) -> SpearheadTerrain:
	var terrain := SpearheadTerrain.new()
	if not _is_object(data, path):
		return terrain
	terrain.name = _string(data, "name", path, true)
	terrain.size = _string(data, "size", path, true)
	if not terrain.size.is_empty() and not terrain.size in SpearheadTerrain.SIZES:
		_error(_join(path, "size"), "must be one of %s" % ", ".join(SpearheadTerrain.SIZES))
	terrain.mystical = _bool(data, "mystical", path)
	terrain.abilities = _strings(data, "abilities", path)
	for i in terrain.abilities.size():
		if pack.get_terrain_ability(terrain.abilities[i]) == null:
			_error(_join(path, "abilities[%d]" % i), "names no terrain ability")
	return terrain


## Each of the group's features must be one of [param pack]'s terrain features.
func _terrain_group(data: Variant, path: String, pack: SpearheadBattlepack) -> Dictionary:
	var group := {"name": "", "features": PackedStringArray()}
	if not _is_object(data, path):
		return group
	group.name = _string(data, "name", path, true)
	group.features = _strings(data, "features", path)
	for i in group.features.size():
		if pack.get_terrain_feature(group.features[i]) == null:
			_error(_join(path, "features[%d]" % i), "names no terrain feature")
	return group


func _realm(data: Variant, path: String, pack: SpearheadBattlepack) -> RealmBattlefield:
	var realm := RealmBattlefield.new()
	if not _is_object(data, path):
		return realm
	realm.name = _string(data, "name", path, true)
	realm.objectives = _map_features(data, "objectives", path, pack.objective_names, false)
	var feature_names := PackedStringArray()
	for feature in pack.terrain_features:
		feature_names.append(feature.name)
	realm.terrain = _map_features(data, "terrain", path, feature_names, false)
	var twists := _array(data, "twists", path)
	for i in twists.size():
		var twist_path := _join(path, "twists[%d]" % i)
		var twist := TwistCard.new()
		if _is_object(twists[i], twist_path):
			twist.name = _string(twists[i], "name", twist_path, true)
			twist.text = _string(twists[i], "text", twist_path, true)
			twist.options = _options(twists[i], twist_path)
		realm.twists.append(twist)
	return realm


func _deployment_map(data: Variant, path: String) -> DeploymentMap:
	var map := DeploymentMap.new()
	if not _is_object(data, path):
		return map
	map.name = _string(data, "name", path, true)
	map.territory_a = _polygon(data, "territory_a", path)
	map.territory_b = _polygon(data, "territory_b", path)
	return map


## A territory: at least 3 corners, each {"x", "y"}.
func _polygon(data: Dictionary, key: String, path: String) -> PackedVector2Array:
	var result := PackedVector2Array()
	if not data.has(key):
		_error(_join(path, key), "is required")
		return result
	var items := _array(data, key, path)
	if items.size() < 3:
		_error(_join(path, key), "must have at least 3 corners")
	for i in items.size():
		var item_path := _join(path, "%s[%d]" % [key, i])
		if _is_object(items[i], item_path):
			result.append(Vector2(_float(items[i], "x", item_path, true), _float(items[i], "y", item_path, true)))
	return result


func _tactic_card(data: Variant, path: String) -> SpearheadTacticCard:
	var card := SpearheadTacticCard.new()
	if not _is_object(data, path):
		return card
	card.name = _string(data, "name", path, true)
	card.condition = _string(data, "condition", path, true)
	if not data.has("command"):
		_error(_join(path, "command"), "is required")
	else:
		card.command = _ability(data.command, _join(path, "command"))
	return card
