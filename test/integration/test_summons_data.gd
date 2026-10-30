extends GutTest
## Integration test of summons with the shipped data in data/: every ability's summons resolve
## through ArmyCatalog.summoned to manifestations or summoned units, every manifestation is summoned
## by something and every SUMMON ability links to one.

var _entries: Array[Dictionary] = []
var _manifestations: Array[Warscroll] = []
var _summoned_ids := {}


func before_all() -> void:
	var core := CoreRulesCatalog.get_rules()
	var core_catalog := ArmyCatalog.new(Faction.new(), core)
	for ability in _core_abilities(core):
		_entries.append({where = "core > " + ability.name, ability = ability, catalog = core_catalog})
	_manifestations.append_array(core.manifestations)
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		for faction_name in FactionCatalog.factions_for(alliance):
			if not FactionCatalog.is_available(faction_name):
				continue
			var faction := FactionCatalog.load_faction(faction_name)
			if not faction:
				continue
			var catalog := ArmyCatalog.new(faction, core)
			for ability in _faction_abilities(faction):
				_entries.append({where = "%s > %s" % [faction.id, ability.name], ability = ability, catalog = catalog})
			for warscroll in faction.warscrolls:
				if warscroll.has_keyword("MANIFESTATION"):
					_manifestations.append(warscroll)
	for entry in _entries:
		for id in entry.ability.summons:
			_summoned_ids[id] = true


func after_all() -> void:
	_entries.clear()
	_manifestations.clear()
	_summoned_ids.clear()


func _core_abilities(core: CoreRules) -> Array[Ability]:
	var result: Array[Ability] = []
	result.append_array(core.abilities)
	for lore in core.manifestation_lores:
		result.append_array(lore.entries)
	for warscroll in core.manifestations:
		result.append_array(warscroll.abilities)
	return result


func _faction_abilities(faction: Faction) -> Array[Ability]:
	var result: Array[Ability] = []
	result.append_array(faction.battle_traits)
	for formation in faction.battle_formations:
		result.append_array(formation.abilities)
	for table in faction.enhancement_tables:
		result.append_array(table.entries)
	for lore in faction.lores:
		result.append_array(lore.entries)
	for army in faction.armies_of_renown:
		result.append_array(army.battle_traits)
		for table in army.enhancement_tables:
			result.append_array(table.entries)
		for lore in army.lores:
			result.append_array(lore.entries)
	var warscrolls: Array[Warscroll] = []
	warscrolls.append_array(faction.warscrolls)
	for regiment in faction.regiments_of_renown:
		result.append_array(regiment.abilities)
		warscrolls.append_array(regiment.warscrolls)
	for spearhead in faction.spearheads:
		result.append_array(spearhead.battle_traits)
		result.append_array(spearhead.regiment_abilities)
		result.append_array(spearhead.enhancements)
		warscrolls.append_array(spearhead.warscrolls)
	for warscroll in warscrolls:
		result.append_array(warscroll.abilities)
	return result


func _summoning_entries() -> Array[Dictionary]:
	return _entries.filter(func(e: Dictionary) -> bool: return not e.ability.summons.is_empty())


func test_some_abilities_summon() -> void:
	assert_gt(_summoning_entries().size(), 0)


func test_every_summons_id_resolves() -> void:
	for entry in _summoning_entries():
		var ability: Ability = entry.ability
		assert_eq(entry.catalog.summoned(ability).size(), ability.summons.size(),
				"%s: summons %s not all found" % [entry.where, ability.summons])


func test_every_summoned_warscroll_is_a_manifestation_or_a_summoned_unit() -> void:
	for entry in _summoning_entries():
		for warscroll: Warscroll in entry.catalog.summoned(entry.ability):
			assert_true(warscroll.has_keyword("MANIFESTATION") or warscroll.summoned,
					"%s summons %s" % [entry.where, warscroll.id])


func test_every_manifestation_is_summoned_by_an_ability() -> void:
	for manifestation in _manifestations:
		assert_true(_summoned_ids.has(manifestation.id), "nothing summons %s" % manifestation.id)


func test_every_ability_with_the_summon_keyword_has_summons() -> void:
	for entry in _entries:
		var ability: Ability = entry.ability
		if "SUMMON" in ability.keywords:
			assert_false(ability.summons.is_empty(), "%s has SUMMON but no summons" % entry.where)


func _ability_on(faction_name: String, unit_name: String, ability_name: String) -> Ability:
	for warscroll in FactionCatalog.load_faction(faction_name).warscrolls:
		if warscroll.name == unit_name:
			for ability in warscroll.abilities:
				if ability.name == ability_name:
					return ability
	return null


func test_jacobus_vyne_summons_the_wisper() -> void:
	var ability := _ability_on("Cities of Sigmar", "Jacobus Vyne, the Jade Wizard", "Summon Wisper")
	assert_eq(ability.summons, PackedStringArray(["wisper"]))


func test_bloodwrack_shrine_summons_the_avatar_of_khaine() -> void:
	var ability := _ability_on("Daughters of Khaine", "Bloodwrack Shrine", "Born of Slaughter")
	assert_eq(ability.summons, PackedStringArray(["avatar_of_khaine"]))


func test_zontari_endrin_dock_summons_the_auto_endrins() -> void:
	var ability := _ability_on("Kharadron Overlords", "Zontari Endrin Dock", "Release the Auto-Endrins")
	assert_eq(ability.summons, PackedStringArray(["auto_endrin"]))


func test_ossiarch_army_of_renown_spell_summons_three_manifestations() -> void:
	var faction := FactionCatalog.load_faction("Ossiarch Bonereapers")
	var found: Ability = null
	for army in faction.armies_of_renown:
		for lore in army.lores:
			for ability in lore.entries:
				if ability.name == "Summon Horror of the Necropolis":
					found = ability
	assert_eq(found.summons.size(), 3)


func test_manifestation_faction_finds_the_faction_with_the_manifestation() -> void:
	assert_eq(FactionCatalog.manifestation_faction("wisper"), "cities_of_sigmar")
