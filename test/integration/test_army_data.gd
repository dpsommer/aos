extends GutTest
## Integration test of the army model with the shipped faction and core rules data: an army built
## with ArmyEditor from FactionCatalog and CoreRulesCatalog data must validate, and every Hero's
## regiment options must be understood by RegimentOption.

const STORMCAST := "Stormcast Eternals"

var _faction: Faction
var _catalog: ArmyCatalog


func before_all() -> void:
	_faction = FactionCatalog.load_faction(STORMCAST)
	_catalog = ArmyCatalog.new(_faction, CoreRulesCatalog.get_rules())


func after_all() -> void:
	_faction = null
	_catalog = null


func _add_regiment(editor: ArmyEditor, leader: String, others: Array[String]) -> ArmyRegiment:
	var regiment := editor.add_regiment(leader)
	for warscroll_id in others:
		assert_not_null(editor.add_unit(regiment.id, warscroll_id), "%s didn't fit in %s's regiment" % [warscroll_id, leader])
	return regiment


func _stormcast_army() -> Army:
	var army := ArmyEditor.create_army(_catalog, "", _faction.battle_formations[0].name)
	var editor := ArmyEditor.new(army, _catalog)
	var lord_celestant := _add_regiment(editor, "lord_celestant_on_dracoth",
			["dracothian_guard_concussors", "liberators", "vindictors"])
	_add_regiment(editor, "lord_relictor", ["reclusians", "annihilators"])
	_add_regiment(editor, "knight_arcanum", ["praetors"])
	editor.set_general(lord_celestant.leader().uid)
	editor.set_enhancement(lord_celestant.leader().uid, "Heroic Traits", "Shock and Awe")
	editor.set_enhancement(army.regiments[1].leader().uid, "Artefacts of Power", "Mirrorshield")
	var cards := _catalog.core.battlepack.battle_tactic_cards
	editor.set_tactic(0, cards[0].name)
	editor.set_tactic(1, cards[1].name)
	editor.set_lore("spell", "Lore of the Storm")
	editor.set_lore("prayer", "Prayers of the Stormhosts")
	editor.set_lore("manifestation", "Manifestations of the Storm")
	return army


func test_stormcast_data_is_available() -> void:
	assert_not_null(_faction)
	assert_not_null(_catalog.core)


func test_stormcast_army_has_every_unit_it_was_built_with() -> void:
	var army := _stormcast_army()
	assert_eq(army.regiments.size(), 3)
	assert_eq(army.all_units().size(), 4 + 3 + 2)


func test_stormcast_army_has_no_problems() -> void:
	var result := ArmyValidator.validate(_stormcast_army(), _catalog)
	assert_eq(result.problems.size(), 0, "\n".join(result.problems))


func test_stormcast_army_is_within_its_points_limit() -> void:
	var army := _stormcast_army()
	assert_lte(ArmyPoints.total(army, _catalog), army.points_limit)


func test_stormcast_army_survives_saving_and_loading() -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(ArmySerializer.to_dict(_stormcast_army())))
	var loaded := ArmySerializer.new().from_dict(data)
	var result := ArmyValidator.validate(loaded, _catalog)
	assert_eq(result.problems.size(), 0, "\n".join(result.problems))


func test_faction_ids_map_back_to_their_faction_names() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		for faction_name in FactionCatalog.factions_for(alliance):
			if FactionCatalog.is_available(faction_name):
				var faction := FactionCatalog.load_faction(faction_name)
				assert_eq(FactionCatalog.name_for_id(faction.id), faction_name)


func test_every_heros_regiment_options_parse_to_options_with_a_subject() -> void:
	var checked := 0
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		for faction_name in FactionCatalog.factions_for(alliance):
			if not FactionCatalog.is_available(faction_name):
				continue
			for warscroll in FactionCatalog.load_faction(faction_name).warscrolls:
				if not warscroll.has_keyword("HERO"):
					continue
				var options := RegimentOption.parse_all(warscroll.regiment_options)
				assert_gte(options.size(), warscroll.regiment_options.size(),
						"%s: %s" % [warscroll.name, warscroll.regiment_options])
				for option in options:
					assert_false(option.subject.is_empty(), "%s / %s: '%s' has no subject" % [faction_name, warscroll.name, option.text])
					checked += 1
	assert_gt(checked, 0)
