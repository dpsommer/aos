class_name BattleBuilder
extends RefCounted
## Makes a [Battle] from what the player chose in Quick Play ([BattleSetup]): picks the battleplan
## or realm battlefield if it's Random and builds both armies, with their regiments and deployment
## abilities. The roll-off decides who is the attacker later ([method Battle.assign_roles]). The
## AI's army mirrors the player's for now. See docs/design/battle.md.


## The battle for [param setup], or null without the data it needs. [param core], [param packs]
## and [param faction] default to the game data: the core rules, the Spearhead battlepacks, and the
## army's or Spearhead's faction.
static func build(setup: BattleSetup, rng: RandomNumberGenerator, core: CoreRules = null,
		packs: Array[SpearheadBattlepack] = [], faction: Faction = null) -> Battle:
	if setup == null:
		return null
	if setup.mode == BattleSetup.Mode.MATCHED_PLAY:
		return _matched_play(setup, rng, core if core else CoreRulesCatalog.get_rules(), faction)
	return _spearhead(setup, rng, packs if not packs.is_empty() else CoreRulesCatalog.spearhead_battlepacks(), faction,
			core if core else CoreRulesCatalog.get_rules())


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
	return battle


static func _spearhead(setup: BattleSetup, rng: RandomNumberGenerator, packs: Array[SpearheadBattlepack], faction: Faction, core: CoreRules) -> Battle:
	if packs.is_empty():
		return null
	if faction == null and not setup.faction.is_empty():
		faction = FactionCatalog.load_faction(setup.faction)
	var spearhead := _find_spearhead(faction, setup.spearhead)
	if spearhead == null:
		return null
	var pack := _find_battlepack(packs, setup.battlepack)
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
		battle.terrain.append(_realm_terrain(feature, pack))
	battle.player = spearhead_army(spearhead, faction, setup, core)
	battle.opponent = battle.player.mirror()
	return battle


## [param faction]'s Spearhead named [param spearhead_name] (the last if several are), or null.
static func _find_spearhead(faction: Faction, spearhead_name: String) -> Spearhead:
	var found: Spearhead = null
	if faction:
		for army in faction.spearheads:
			if army.name == spearhead_name:
				found = army
	return found


## The battlepack in [param packs] named [param pack_name] (the last if several are), or null.
static func _find_battlepack(packs: Array[SpearheadBattlepack], pack_name: String) -> SpearheadBattlepack:
	var found: SpearheadBattlepack = null
	for candidate in packs:
		if candidate.name == pack_name:
			found = candidate
	return found


## A realm battlefield's terrain feature, placed where its map shows it, with [param pack]'s rules
## for its type if the battlepack has them.
static func _realm_terrain(feature: MapFeature, pack: SpearheadBattlepack) -> BattleTerrain:
	var known := pack.get_terrain_feature(feature.type)
	var terrain := BattleTerrain.from_spearhead(known) if known else BattleTerrain.new()
	terrain.name = feature.type
	terrain.position = feature.position
	terrain.placed = true
	return terrain


## A Forge army's units, regiments, faction terrain and deployment abilities, with its points.
static func army_of(army: Army, catalog: ArmyCatalog) -> BattleArmy:
	var result := BattleArmy.new()
	result.name = army.name
	result.faction_name = catalog.faction.name
	result.points = ArmyPoints.total(army, catalog)
	for regiment in army.regiments:
		var battle_regiment := BattleRegiment.new()
		battle_regiment.name = _regiment_name(regiment, result.regiments.size())
		battle_regiment.is_renown = regiment.is_regiment_of_renown()
		for unit in regiment.units:
			var battle_unit := _unit(unit, regiment, catalog)
			battle_unit.regiment = battle_regiment
			battle_regiment.units.append(battle_unit)
			result.units.append(battle_unit)
		result.regiments.append(battle_regiment)
	for unit in army.auxiliary:
		result.units.append(_unit(unit, null, catalog))
	DeploymentAbilities.for_army(result, army, catalog)
	var terrain := catalog.faction.get_warscroll(army.faction_terrain) if not army.faction_terrain.is_empty() else null
	if terrain:
		result.terrain.append(BattleTerrain.from_warscroll(terrain))
	return result


## The regiment's name: a Regiment of Renown's, the player's, or "Regiment N".
static func _regiment_name(regiment: ArmyRegiment, index: int) -> String:
	if regiment.is_regiment_of_renown():
		return regiment.regiment_of_renown
	return regiment.name if not regiment.name.is_empty() else "Regiment %d" % (index + 1)


static func _unit(unit: ArmyUnit, regiment: ArmyRegiment, catalog: ArmyCatalog) -> BattleUnit:
	var warscroll := catalog.warscroll(unit, regiment)
	var count := (warscroll.unit_size if warscroll else 1) * (2 if unit.reinforced else 1)
	return BattleUnit.create(warscroll.name if warscroll else unit.warscroll_id, warscroll, count)


## A Spearhead's general and units, and its deployment abilities. Their bases come from the
## faction's warscrolls of the same names, as a Spearhead's own have no battle profile.
static func spearhead_army(spearhead: Spearhead, faction: Faction, setup: BattleSetup = null, core: CoreRules = null) -> BattleArmy:
	var result := BattleArmy.new()
	result.name = spearhead.name
	result.faction_name = faction.name
	var entries: Array = [[spearhead.general, 1]]
	for unit in spearhead.units:
		entries.append([unit.name, unit.count])
	for entry: Array in entries:
		var unit_name: String = entry[0]
		result.units.append(BattleUnit.create(unit_name, spearhead.get_warscroll(unit_name), entry[1], faction.find_warscroll(unit_name)))
	DeploymentAbilities.for_spearhead(result, spearhead, setup, core)
	return result


## The Spearhead terrain features one player sets up: terrain group [param group] if the
## battlepack has groups, else every feature that isn't mystical (set up before the battle). Their
## [member BattleTerrain.variant] is [param group], so each player's copies look different.
static func spearhead_terrain(pack: SpearheadBattlepack, group: int) -> Array[BattleTerrain]:
	var result: Array[BattleTerrain] = []
	for feature in _group_features(pack, group):
		var terrain := BattleTerrain.from_spearhead(feature)
		terrain.variant = group
		result.append(terrain)
	return result


## The Spearhead terrain features in [param pack]'s terrain group [param group], or every feature
## that isn't mystical if it has no groups.
static func _group_features(pack: SpearheadBattlepack, group: int) -> Array[SpearheadTerrain]:
	var features: Array[SpearheadTerrain] = []
	if pack.terrain_groups.is_empty():
		for feature in pack.terrain_features:
			if not feature.mystical:
				features.append(feature)
		return features
	var chosen: Dictionary = pack.terrain_groups[group % pack.terrain_groups.size()]
	for feature_name: String in chosen.get("features", []):
		var feature := pack.get_terrain_feature(feature_name)
		if feature:
			features.append(feature)
	return features


## [param rects] as polygons, rects that touch merged into one.
static func merge_rects(rects: Array[Rect2]) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	for rect in rects:
		polygons.append(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]))
	while polygons.size() > 1 and _merge_first_pair(polygons):
		pass
	return polygons


## Merges the first two of [param polygons] that touch into one, in place. False if none touch.
static func _merge_first_pair(polygons: Array[PackedVector2Array]) -> bool:
	for i in polygons.size():
		for j in range(i + 1, polygons.size()):
			var union := Geometry2D.merge_polygons(polygons[i], polygons[j])
			if union.size() == 1:
				polygons[i] = union[0]
				polygons.remove_at(j)
				return true
	return false
