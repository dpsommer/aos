extends RefCounted
## Builders for small in-code factions, core rules and armies, shared by the army tests so they don't
## depend on the real faction data. Preload it: const Kit := preload("res://test/support/army_kit.gd")


static func warscroll(id: String, keywords := PackedStringArray(), points := 100, ws_name := "") -> Warscroll:
	var scroll := Warscroll.new()
	scroll.id = id
	scroll.name = id.capitalize() if ws_name.is_empty() else ws_name
	scroll.keywords = keywords
	scroll.points = points
	scroll.unit_size = 5
	return scroll


static func hero(id: String, regiment_options := PackedStringArray(), extra_keywords := PackedStringArray()) -> Warscroll:
	var scroll := warscroll(id, PackedStringArray(["HERO"]) + extra_keywords, 100)
	scroll.regiment_options = regiment_options
	return scroll


static func weapon_option(option_name: String, max_models := 1, per := 5, choice := false) -> WeaponOption:
	var option := WeaponOption.new()
	option.name = option_name
	option.max = max_models
	option.per = per
	option.choice = choice
	return option


static func ability(ability_name: String, points := 0) -> Ability:
	var entry := Ability.new()
	entry.name = ability_name
	entry.points = points
	return entry


static func table(type: String, entries: Array[Ability]) -> EnhancementTable:
	var result := EnhancementTable.new()
	result.name = type
	result.entries = entries
	return result


static func lore(lore_name: String, kind: String, points := 0) -> Lore:
	var result := Lore.new()
	result.name = lore_name
	result.kind = kind
	result.points = points
	return result


static func formation(formation_name: String, points := 0) -> BattleFormation:
	var result := BattleFormation.new()
	result.name = formation_name
	result.points = points
	return result


static func renown_unit(unit_name: String, warscroll_id: String, faction_id := "", count := 1) -> RegimentUnit:
	var result := RegimentUnit.new()
	result.name = unit_name
	result.warscroll_id = warscroll_id
	result.faction_id = faction_id
	result.count = count
	return result


static func regiment_of_renown(ror_name: String, points: int, units: Array[RegimentUnit],
		own_warscrolls: Array[Warscroll] = []) -> RegimentOfRenown:
	var result := RegimentOfRenown.new()
	result.name = ror_name
	result.points = points
	result.units = units
	result.warscrolls = own_warscrolls
	return result


static func roster_entry(unit_name := "", keywords := PackedStringArray()) -> RosterEntry:
	var entry := RosterEntry.new()
	entry.unit = unit_name
	entry.keywords = keywords
	return entry


static func army_of_renown(aor_name: String, entries: Array[RosterEntry] = []) -> ArmyOfRenown:
	var result := ArmyOfRenown.new()
	result.name = aor_name
	result.roster = ArmyRoster.new()
	result.roster.entries = entries
	return result


static func faction(scrolls: Array[Warscroll], faction_id := "test_faction") -> Faction:
	var result := Faction.new()
	result.id = faction_id
	result.name = faction_id.capitalize()
	result.warscrolls = scrolls
	return result


static func card(card_name: String) -> BattleTacticCard:
	var result := BattleTacticCard.new()
	result.name = card_name
	return result


static func core(card_names := PackedStringArray(), manifestation_lores: Array[Lore] = []) -> CoreRules:
	var result := CoreRules.new()
	result.battlepack = Battlepack.new()
	for card_name in card_names:
		result.battlepack.battle_tactic_cards.append(card(card_name))
	result.manifestation_lores = manifestation_lores
	return result


static func catalog(faction_data: Faction, core_rules: CoreRules = null, load_faction := Callable()) -> ArmyCatalog:
	return ArmyCatalog.new(faction_data, core_rules if core_rules else core(), load_faction)


static func unit(uid: String, warscroll_id: String) -> ArmyUnit:
	var result := ArmyUnit.new()
	result.uid = uid
	result.warscroll_id = warscroll_id
	return result


static func regiment(id: String, units: Array[ArmyUnit], regiment_name := "") -> ArmyRegiment:
	var result := ArmyRegiment.new()
	result.id = id
	result.name = id if regiment_name.is_empty() else regiment_name
	result.units = units
	return result


static func ror_regiment(id: String, ror_name: String, units: Array[ArmyUnit]) -> ArmyRegiment:
	var result := regiment(id, units, ror_name)
	result.regiment_of_renown = ror_name
	return result


## An army in the faction `test_faction` with no regiments.
static func army() -> Army:
	var result := Army.new()
	result.faction_id = "test_faction"
	result.name = "Test"
	result.tactics = PackedStringArray(["", ""])
	return result
