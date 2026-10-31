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
	result.player_territory = [rect_polygon(0, 0, 10, 22)] as Array[PackedVector2Array]
	result.opponent_territory = [rect_polygon(20, 0, 10, 22)] as Array[PackedVector2Array]
	result.player = army("Player Unit")
	result.opponent = army("Opponent Unit")
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
