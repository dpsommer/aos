extends RefCounted
## Builders for small in-code battles and the data they come from, shared by the battle tests so
## they don't depend on the real faction or battlepack data.
## Preload it: const BattleKit := preload("res://test/support/battle_kit.gd")

const Kit := preload("res://test/support/army_kit.gd")


static func rect_polygon(x: float, y: float, width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + width, y), Vector2(x + width, y + height), Vector2(x, y + height)])


## A warscroll with a round base of [param base_mm] (none if zero) and [param size] models.
static func warscroll(scroll_name: String, size := 5, base_mm := 32.0) -> Warscroll:
	var scroll := Kit.warscroll(scroll_name.to_snake_case(), PackedStringArray(), 100, scroll_name)
	scroll.unit_size = size
	if base_mm > 0.0:
		scroll.base_size = BaseSize.round_base(base_mm)
	return scroll


static func unit(unit_name: String, count: int, base_mm := 32.0) -> BattleUnit:
	return BattleUnit.create(unit_name, warscroll(unit_name, count, base_mm), count)


## A unit whose models have the bases of [param groups], each `[count, diameter_mm]` for a round
## base or `[count, length_mm, width_mm]` for an oval, e.g. `[[2, 40.0], [3, 28.5], [6, 25.0]]`.
static func mixed_unit(unit_name: String, groups: Array) -> BattleUnit:
	var of: Array[BaseSizeGroup] = []
	var total := 0
	for entry: Array in groups:
		var group := BaseSizeGroup.new()
		group.count = entry[0]
		group.base = BaseSize.round_base(entry[1]) if entry.size() == 2 else BaseSize.oval(entry[1], entry[2])
		of.append(group)
		total += group.count
	var scroll := Kit.warscroll(unit_name.to_snake_case(), PackedStringArray(), 100, unit_name)
	scroll.unit_size = total
	scroll.base_size = BaseSize.mixed(of)
	return BattleUnit.create(unit_name, scroll, total)


## A unit of one model on an oval base of [param length_mm] by [param width_mm].
static func oval_unit(unit_name: String, length_mm: float, width_mm: float) -> BattleUnit:
	return mixed_unit(unit_name, [[1, length_mm, width_mm]])


static func army(unit_name := "Unit", count := 5) -> BattleArmy:
	var result := BattleArmy.new()
	result.name = "Army"
	result.faction_name = "Faction"
	result.units.append(unit(unit_name, count))
	return result


static func terrain(kind := BattleTerrain.Kind.AREA_OR_OBSTACLE, width := 4.0, at := Vector2.ZERO, placed := true) -> BattleTerrain:
	var result := BattleTerrain.new()
	result.kind = kind
	result.name = "Terrain"
	result.footprint = Vector2(width, width)
	result.position = at
	result.placed = placed
	return result


## A Spearhead-sized battle, the player's territory on the west and the opponent's on the east,
## each with a small army.
static func battle() -> Battle:
	var result := Battle.new()
	result.mode = BattleSetup.Mode.SPEARHEAD
	result.battlefield_size = Vector2(30, 22)
	result.title = "Test Battle"
	result.player_is_attacker = true
	result.roles_assigned = true
	result.player_territory = [rect_polygon(0, 0, 10, 22)] as Array[PackedVector2Array]
	result.opponent_territory = [rect_polygon(20, 0, 10, 22)] as Array[PackedVector2Array]
	result.player = army("Player Unit")
	result.opponent = army("Opponent Unit")
	result.face_armies()
	return result


static func feature(type: String, at: Vector2, size := "") -> MapFeature:
	var result := MapFeature.new()
	result.type = type
	result.position = at
	result.size = size
	return result


static func battleplan(plan_name: String) -> Battleplan:
	var plan := Battleplan.new()
	plan.name = plan_name
	plan.twist = plan_name + " twist"
	plan.table = 1
	plan.attacker_territory = [Rect2(0, 0, 60, 10)] as Array[Rect2]
	plan.defender_territory = [Rect2(0, 34, 60, 10), Rect2(0, 24, 20, 10)] as Array[Rect2]
	plan.objectives = [feature("Sun Seekers", Vector2(30, 22))] as Array[MapFeature]
	plan.terrain = [feature("obscuring", Vector2(10, 22), "medium"), feature("place_of_power", Vector2(50, 22), "small")] as Array[MapFeature]
	return plan


static func core(plans: Array[Battleplan]) -> CoreRules:
	var rules := Kit.core()
	rules.battlepack.battleplans = plans
	return rules


## A faction with one unit, `Unit` with five models on a 32mm base.
static func faction() -> Faction:
	return Kit.faction([warscroll("Unit")] as Array[Warscroll])


static func matched_play_setup(plan_name := "") -> BattleSetup:
	var setup := BattleSetup.new()
	setup.mode = BattleSetup.Mode.MATCHED_PLAY
	setup.battleplan = plan_name
	setup.army = Kit.army()
	setup.army.auxiliary = [Kit.unit("u1", "unit")] as Array[ArmyUnit]
	return setup


static func terrain_feature(feature_name: String, size: String, mystical := false) -> SpearheadTerrain:
	var result := SpearheadTerrain.new()
	result.name = feature_name
	result.size = size
	result.mystical = mystical
	return result


static func realm(realm_name: String) -> RealmBattlefield:
	var result := RealmBattlefield.new()
	result.name = realm_name
	result.objectives = [feature("Objective", Vector2(15, 11))] as Array[MapFeature]
	result.terrain = [feature("Wall", Vector2(7, 5))] as Array[MapFeature]
	return result


static func deployment(map_name: String) -> DeploymentMap:
	var result := DeploymentMap.new()
	result.name = map_name
	result.territory_a = rect_polygon(0, 0, 10, 22)
	result.territory_b = rect_polygon(20, 0, 10, 22)
	return result


## A battlepack with realms named [param realm_names], one deployment map and terrain features:
## `Wall` (small, one in group 0), `Ruin` and `Tower` (large, group 1) and a mystical `Portal`.
static func spearhead_pack(pack_name: String, realm_names: Array[String]) -> SpearheadBattlepack:
	var pack := SpearheadBattlepack.new()
	pack.name = pack_name
	for realm_name in realm_names:
		pack.realms.append(realm(realm_name))
	pack.deployment_maps = [deployment("Map")] as Array[DeploymentMap]
	pack.terrain_features = [terrain_feature("Wall", "small"), terrain_feature("Ruin", "large"),
			terrain_feature("Tower", "large"), terrain_feature("Portal", "large", true)] as Array[SpearheadTerrain]
	pack.terrain_groups = [{"features": ["Wall"]}, {"features": ["Ruin", "Tower"]}] as Array[Dictionary]
	return pack


## A faction with a Spearhead `Test Spearhead` of a general and two units, and warscrolls with
## bases for the units but not the general.
static func spearhead_faction() -> Faction:
	var spearhead := Spearhead.new()
	spearhead.name = "Test Spearhead"
	spearhead.general = "General"
	for entry: Array in [["Alpha", 3], ["Beta", 2]]:
		var unit_entry := SpearheadUnit.new()
		unit_entry.name = entry[0]
		unit_entry.count = entry[1]
		spearhead.units.append(unit_entry)
	var result := Kit.faction([warscroll("Alpha", 3, 40.0), warscroll("Beta", 2, 25.0)] as Array[Warscroll])
	result.spearheads = [spearhead] as Array[Spearhead]
	return result


## A Spearhead of a `General` and one unit `Alpha`, with a `Trait` battle trait, the regiment
## abilities `Charge` and `Ambush` and the enhancements `Banner` and `Crown`, all used in the
## deployment phase.
static func spearhead_with_options() -> Spearhead:
	var spearhead := Spearhead.new()
	spearhead.name = "Optioned"
	spearhead.general = "General"
	var deploy := PackedStringArray(["DEPLOY"])
	spearhead.battle_traits = [ability("Trait", deploy)] as Array[Ability]
	spearhead.regiment_abilities = [ability("Charge", deploy), ability("Ambush", deploy)] as Array[Ability]
	spearhead.enhancements = [ability("Banner", deploy), ability("Crown", deploy)] as Array[Ability]
	return spearhead


## An army of [param spearhead] as [BattleBuilder] makes one: the general then a unit `Alpha`,
## nothing chosen yet.
static func spearhead_army(spearhead: Spearhead) -> BattleArmy:
	var result := BattleArmy.new()
	result.name = spearhead.name
	result.spearhead = spearhead
	result.units.append(unit(spearhead.general, 1))
	result.units.append(unit("Alpha", 3))
	DeploymentAbilities.for_spearhead_choices(result, spearhead, "", "", null)
	return result


static func spearhead_setup(pack_name := "", realm_name := "") -> BattleSetup:
	var setup := BattleSetup.new()
	setup.mode = BattleSetup.Mode.SPEARHEAD
	setup.spearhead = "Test Spearhead"
	setup.battlepack = pack_name
	setup.realm = realm_name
	return setup


## A Spearhead setup from the first real Spearhead, or null if the data has none.
static func real_spearhead_setup() -> BattleSetup:
	var entries := FactionCatalog.spearheads()
	if entries.is_empty():
		return null
	var setup := BattleSetup.new()
	setup.mode = BattleSetup.Mode.SPEARHEAD
	setup.faction = entries[0].faction
	setup.spearhead = entries[0].name
	return setup


## An ability used in the deployment phase: [param keywords] such as "DEPLOY" or "DEPLOY TERRAIN",
## and [param effect] and [param declare] text.
static func ability(ability_name: String, keywords := PackedStringArray(["DEPLOY"]), effect := "", declare := "", frequency := "") -> Ability:
	var result := Ability.new()
	result.name = ability_name
	result.keywords = keywords
	result.effect = effect
	result.declare = declare
	result.frequency = frequency
	return result


## A [DeploymentAbility] of [param of] from [param source], optionally owned by a unit or tied to a
## Regiment of Renown.
static func deploy_entry(of: Ability, source := "Warscroll", owner: BattleUnit = null, regiment: BattleRegiment = null) -> DeploymentAbility:
	return DeploymentAbility.create(of, source, owner, regiment)


## A [BattleRegiment] of [param units] named [param regiment_name], the units pointed back at it.
static func regiment(regiment_name: String, units: Array[BattleUnit], renown := false) -> BattleRegiment:
	var result := BattleRegiment.new()
	result.name = regiment_name
	result.is_renown = renown
	result.units = units
	for unit in units:
		unit.regiment = result
	return result


## A Matched Play battle for the deployment phase: territories at the top and bottom of a 60" x 44"
## board, the player the attacker. Each army has the universal abilities and two regiments of two
## units each (`A1`, `A2` and `B1`, `B2`) beside an auxiliary `Aux`, all with 3 models; the opponent's
## is a [method BattleArmy.mirror] of the player's.
static func deployment_battle() -> Battle:
	var result := Battle.new()
	result.mode = BattleSetup.Mode.MATCHED_PLAY
	result.battlefield_size = Vector2(60, 44)
	result.title = "Test Battle"
	result.player_is_attacker = true
	result.roles_assigned = true
	result.player_territory = [rect_polygon(0, 0, 60, 18)] as Array[PackedVector2Array]
	result.opponent_territory = [rect_polygon(0, 26, 60, 18)] as Array[PackedVector2Array]
	var army := BattleArmy.new()
	army.name = "Army"
	army.faction_name = "Faction"
	for names: Array in [["A1", "A2"], ["B1", "B2"]]:
		var members: Array[BattleUnit] = []
		for unit_name: String in names:
			var member := unit(unit_name, 3)
			members.append(member)
			army.units.append(member)
		army.regiments.append(regiment("Regiment %s" % names[0][0], members))
	army.units.append(unit("Aux", 3))
	army.deployment_abilities.append_array(DeploymentAbilities.universal(DeploymentAbilities.MATCHED_PLAY_UNIVERSAL, null))
	result.player = army
	result.opponent = army.mirror()
	result.face_armies()
	return result


## A Spearhead battle for the deployment phase: the board and territories of [method deployment_battle],
## the player the attacker. Each army has no regiments and three units of three models (`A1`, `A2`
## and `B1`) with only the Deploy Unit ability; the opponent's is a [method BattleArmy.mirror] of the
## player's.
static func spearhead_deployment_battle() -> Battle:
	var result := deployment_battle()
	result.mode = BattleSetup.Mode.SPEARHEAD
	var army := BattleArmy.new()
	army.name = "Army"
	army.faction_name = "Faction"
	for unit_name in ["A1", "A2", "B1"]:
		army.units.append(unit(unit_name, 3))
	army.deployment_abilities.append_array(DeploymentAbilities.universal(DeploymentAbilities.SPEARHEAD_UNIVERSAL, null))
	result.player = army
	result.opponent = army.mirror()
	result.face_armies()
	return result


## A Spearhead battle on a 30" x 22" board with territories 30" x 11" at the top (the player's) and
## bottom, so each side's deployable zone is 30" x 5". Each army is a mirror of [param units] and
## the player is the attacker unless [param player_first] is false.
static func cramped_spearhead_battle(units: Array[BattleUnit], player_first := true) -> Battle:
	var result := spearhead_deployment_battle()
	result.battlefield_size = Vector2(30, 22)
	result.player_is_attacker = player_first
	result.player_territory = [rect_polygon(0, 0, 30, 11)] as Array[PackedVector2Array]
	result.opponent_territory = [rect_polygon(0, 11, 30, 11)] as Array[PackedVector2Array]
	result.player.units.assign(units)
	result.opponent = result.player.mirror()
	result.face_armies()
	return result


## Units that don't all fit a 30" x 5" zone spread out 1" apart, but do packed in tight: a mix of
## bases, a big oval single model (which only fits with its centre about 2.5" deep), and two blocks.
static func cramped_units() -> Array[BattleUnit]:
	var units: Array[BattleUnit] = [
		mixed_unit("Hunters", [[2, 40.0], [3, 28.5], [6, 25.0]]),
		oval_unit("Beast", 120.0, 92.0),
		unit("Guard", 10, 40.0),
		unit("Rats", 10, 25.0),
	]
	return units
