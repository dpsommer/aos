class_name BattleBuilder
extends RefCounted
## Makes a [Battle] from what the player chose in Quick Play ([BattleSetup]): picks the battleplan
## or realm battlefield if it's Random, the Spearhead deployment map and territories, and who is
## the attacker, and builds both armies. The AI's army mirrors the player's for now. See
## docs/design/battle.md.


## The battle for [param setup], or null without the data it needs. [param core], [param packs]
## and [param faction] default to the game data: the core rules, the Spearhead battlepacks, and the
## army's or Spearhead's faction.
static func build(setup: BattleSetup, rng: RandomNumberGenerator, core: CoreRules = null,
		packs: Array[SpearheadBattlepack] = [], faction: Faction = null) -> Battle:
	if setup == null:
		return null
	if setup.mode == BattleSetup.Mode.MATCHED_PLAY:
		return _matched_play(setup, rng, core if core else CoreRulesCatalog.get_rules(), faction)
	return _spearhead(setup, rng, packs if not packs.is_empty() else CoreRulesCatalog.spearhead_battlepacks(), faction)


static func _matched_play(setup: BattleSetup, rng: RandomNumberGenerator, core: CoreRules, faction: Faction) -> Battle:
	if core == null or core.battlepack == null or core.battlepack.battleplans.is_empty() or setup.army == null:
		return null
	if faction == null:
		var faction_name := FactionCatalog.name_for_id(setup.army.faction_id)
		faction = FactionCatalog.load_faction(faction_name) if not faction_name.is_empty() else null
	if faction == null:
		return null
	var pack := core.battlepack
	var battle := Battle.new()
	battle.mode = BattleSetup.Mode.MATCHED_PLAY
	battle.battlefield_size = pack.battlefield_size if pack.battlefield_size != Vector2.ZERO else Battle.MATCHED_PLAY_BATTLEFIELD
	var plan := pack.get_battleplan(setup.battleplan) if not setup.battleplan.is_empty() else null
	battle.was_random = plan == null
	if plan == null:
		plan = pack.battleplans[rng.randi_range(0, pack.battleplans.size() - 1)]
	battle.battleplan = plan
	battle.title = plan.name
	battle.twist = plan.twist
	battle.table = plan.table
	battle.objectives = plan.objectives.duplicate()
	for feature in plan.terrain:
		battle.terrain.append(BattleTerrain.from_battleplan(feature))
	battle.player = army_of(setup.army, ArmyCatalog.new(faction, core))
	battle.opponent = battle.player.mirror()
	battle.player_is_attacker = rng.randi_range(0, 1) == 0
	var attacker := merge_rects(plan.attacker_territory)
	var defender := merge_rects(plan.defender_territory)
	battle.player_territory = attacker if battle.player_is_attacker else defender
	battle.opponent_territory = defender if battle.player_is_attacker else attacker
	return battle


static func _spearhead(setup: BattleSetup, rng: RandomNumberGenerator, packs: Array[SpearheadBattlepack], faction: Faction) -> Battle:
	if packs.is_empty():
		return null
	if faction == null and not setup.faction.is_empty():
		faction = FactionCatalog.load_faction(setup.faction)
	var spearhead: Spearhead = null
	if faction:
		for army in faction.spearheads:
			if army.name == setup.spearhead:
				spearhead = army
	if spearhead == null:
		return null
	var pack: SpearheadBattlepack = null
	for candidate in packs:
		if candidate.name == setup.battlepack:
			pack = candidate
	var realm := pack.get_realm(setup.realm) if pack and not setup.realm.is_empty() else null
	var battle := Battle.new()
	battle.was_random = realm == null
	if realm == null:
		pack = packs[rng.randi_range(0, packs.size() - 1)]
		realm = pack.realms[rng.randi_range(0, pack.realms.size() - 1)] if not pack.realms.is_empty() else null
	if realm == null or pack.deployment_maps.is_empty():
		return null
	battle.mode = BattleSetup.Mode.SPEARHEAD
	battle.battlepack = pack
	battle.realm = realm
	battle.battlefield_size = pack.battlefield_size if pack.battlefield_size != Vector2.ZERO else Battle.SPEARHEAD_BATTLEFIELD
	battle.title = realm.name
	battle.objectives = realm.objectives.duplicate()
	battle.roads = realm.roads.duplicate()
	for feature in realm.terrain:
		var known := pack.get_terrain_feature(feature.type)
		var terrain := BattleTerrain.from_spearhead(known) if known else BattleTerrain.new()
		terrain.name = feature.type
		terrain.position = feature.position
		terrain.placed = true
		battle.terrain.append(terrain)
	battle.deployment = pack.deployment_maps[rng.randi_range(0, pack.deployment_maps.size() - 1)]
	var player_has_a := rng.randi_range(0, 1) == 0
	battle.player_territory = [battle.deployment.territory_a if player_has_a else battle.deployment.territory_b]
	battle.opponent_territory = [battle.deployment.territory_b if player_has_a else battle.deployment.territory_a]
	battle.player_is_attacker = rng.randi_range(0, 1) == 0
	battle.player = spearhead_army(spearhead, faction)
	battle.opponent = battle.player.mirror()
	# The defender sets up the first terrain group (or every feature), then the attacker the second.
	battle.player.terrain = spearhead_terrain(pack, 1 if battle.player_is_attacker else 0)
	battle.opponent.terrain = spearhead_terrain(pack, 0 if battle.player_is_attacker else 1)
	return battle


## A Forge army's units and faction terrain, with its points.
static func army_of(army: Army, catalog: ArmyCatalog) -> BattleArmy:
	var result := BattleArmy.new()
	result.name = army.name
	result.faction_name = catalog.faction.name
	result.points = ArmyPoints.total(army, catalog)
	for regiment in army.regiments:
		for unit in regiment.units:
			result.units.append(_unit(unit, regiment, catalog))
	for unit in army.auxiliary:
		result.units.append(_unit(unit, null, catalog))
	var terrain := catalog.faction.get_warscroll(army.faction_terrain) if not army.faction_terrain.is_empty() else null
	if terrain:
		result.terrain.append(BattleTerrain.from_warscroll(terrain))
	return result


static func _unit(unit: ArmyUnit, regiment: ArmyRegiment, catalog: ArmyCatalog) -> BattleUnit:
	var warscroll := catalog.warscroll(unit, regiment)
	var count := (warscroll.unit_size if warscroll else 1) * (2 if unit.reinforced else 1)
	return BattleUnit.create(warscroll.name if warscroll else unit.warscroll_id, warscroll, count)


## A Spearhead's general and units. Their bases come from the faction's warscrolls of the same
## names, as a Spearhead's own have no battle profile.
static func spearhead_army(spearhead: Spearhead, faction: Faction) -> BattleArmy:
	var result := BattleArmy.new()
	result.name = spearhead.name
	result.faction_name = faction.name
	var entries: Array = [[spearhead.general, 1]]
	for unit in spearhead.units:
		entries.append([unit.name, unit.count])
	for entry: Array in entries:
		var unit_name: String = entry[0]
		result.units.append(BattleUnit.create(unit_name, spearhead.get_warscroll(unit_name), entry[1], faction.find_warscroll(unit_name)))
	return result


## The Spearhead terrain features one player sets up: terrain group [param group] if the
## battlepack has groups, else every feature that isn't mystical (set up before the battle).
static func spearhead_terrain(pack: SpearheadBattlepack, group: int) -> Array[BattleTerrain]:
	var result: Array[BattleTerrain] = []
	if not pack.terrain_groups.is_empty():
		var chosen: Dictionary = pack.terrain_groups[group % pack.terrain_groups.size()]
		for feature_name: String in chosen.get("features", []):
			var feature := pack.get_terrain_feature(feature_name)
			if feature:
				result.append(BattleTerrain.from_spearhead(feature))
		return result
	for feature in pack.terrain_features:
		if not feature.mystical:
			result.append(BattleTerrain.from_spearhead(feature))
	return result


## [param rects] as polygons, rects that touch merged into one.
static func merge_rects(rects: Array[Rect2]) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	for rect in rects:
		polygons.append(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]))
	var merged := true
	while merged and polygons.size() > 1:
		merged = false
		for i in polygons.size():
			for j in range(i + 1, polygons.size()):
				var union := Geometry2D.merge_polygons(polygons[i], polygons[j])
				if union.size() == 1:
					polygons[i] = union[0]
					polygons.remove_at(j)
					merged = true
					break
			if merged:
				break
	return polygons
