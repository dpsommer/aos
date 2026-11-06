extends RefCounted
## Sets up real battles for the rules engine's tests: a Spearhead or a Forge army, both sides deployed
## automatically, ready for a [GameController]. Reads the real faction data, not the models.
## Preload it: const BattleSim := preload("res://test/support/battle_sim.gd")

const FACTION := "Ironjawz"
const SPEARHEAD := "Ironjawz Bigmob"
const PACK := "Fire and Jade"
const REGIMENT := "NATURAL DISASTER"
const ENHANCEMENT := "AMBERSTONE WHETSTONE"


## A battle between two [param spearhead] armies on [param pack], deployed, from [param seed_value].
static func spearhead_battle(seed_value: int, pack := PACK, faction := FACTION, spearhead := SPEARHEAD, regiment := REGIMENT, enhancement := ENHANCEMENT) -> Battle:
	var rng := seeded(seed_value)
	var setup := BattleSetup.new()
	setup.mode = BattleSetup.Mode.SPEARHEAD
	setup.faction = faction
	setup.spearhead = spearhead
	setup.battlepack = pack
	setup.regiment_ability = regiment
	setup.enhancement = enhancement
	var battle := BattleBuilder.build(setup, rng)
	battle.assign_roles(true)
	battle.choose_realm(battle.battlepack.realms[0])
	battle.choose_deployment(battle.battlepack.deployment_maps[0], true)
	deploy(battle)
	return battle


## Puts every army's terrain and units on the battlefield, straight from [PlaceholderDeployment].
static func deploy(battle: Battle) -> void:
	for army: BattleArmy in [battle.player, battle.opponent]:
		for feature in army.terrain:
			var spot := PlaceholderDeployment.spot_for_terrain(battle, army, feature)
			if not spot.is_empty():
				feature.position = spot.at
				feature.rotation = spot.get("rotation", 0.0)
				feature.placed = true
		var spots := PlaceholderDeployment.spots_for_army(battle, army, army.undeployed_units())
		for unit: BattleUnit in spots:
			unit.positions = spots[unit]
			unit.facing = army.facing
			unit.deployed = true


static func seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Plays [param game] to its end with [param ai] on both sides. Returns why it stopped, or empty if
## it finished. An error is any answer the engine refused.
static func play_out(game: GameController, ai: Participant, on_step := Callable()) -> String:
	var request := game.next_decision()
	var guard := 0
	while request:
		var reason := game.answer(ai.decide(request, game))
		if not reason.is_empty():
			return "Refused (%s): %s" % [request.prompt, reason]
		if on_step.is_valid():
			on_step.call()
		request = game.next_decision()
		guard += 1
		if guard > 20000:
			return "It never finished."
	return ""


## A battle between two Forge armies of Ironjawz with a general, a wizard, a priest and every kind of
## unit in the regiments, taking [param battleplan], deployed.
static func matched_battle(seed_value: int, battleplan := "Into the Fire") -> Battle:
	var army := Army.new()
	army.name = "Test Ironjawz"
	army.faction_id = "ironjawz"
	army.points_limit = 3000
	army.override_constraints = true
	army.spell_lore = "Lore of the Weird"
	army.prayer_lore = "Warbeats"
	army.manifestation_lore = "Manifestations of Gorkamorka"
	army.tactics = PackedStringArray(["Smokescreen", "Siege of Ashes"])
	var regiment := ArmyRegiment.new()
	regiment.name = "First Mob"
	var uid := 0
	for id: String in ["megaboss", "weirdnob_shaman", "warchanter", "ardboyz", "brutes", "brute_ragerz"]:
		var unit := ArmyUnit.new()
		unit.uid = "u%d" % uid
		uid += 1
		unit.warscroll_id = id
		regiment.units.append(unit)
	army.regiments.append(regiment)
	army.general_uid = "u0"
	var setup := BattleSetup.new()
	setup.mode = BattleSetup.Mode.MATCHED_PLAY
	setup.army = army
	setup.battleplan = battleplan
	var battle := BattleBuilder.build(setup, seeded(seed_value))
	battle.assign_roles(true)
	deploy(battle)
	return battle
