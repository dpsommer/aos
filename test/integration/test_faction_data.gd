extends GutTest
## Integration test of FactionCatalog with the shipped faction data in data/factions.
##
## FactionLoader returns null if it finds any error, so a faction that loads has no loader errors.
## Any errors are pushed by FactionCatalog and would also fail the suite.

## Warscrolls whose Health and Save are "-": the Dais Arcanum is a platform for another unit.
const Kit := preload("res://test/support/army_kit.gd")
const _NO_HEALTH_OR_SAVE := ["Dais Arcanum"]

var _factions: Array[Faction] = []
var _unloaded := PackedStringArray()
var _available_count := 0


func before_all() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		for faction_name in FactionCatalog.factions_for(alliance):
			if not FactionCatalog.is_available(faction_name):
				continue
			_available_count += 1
			var faction := FactionCatalog.load_faction(faction_name)
			if faction:
				_factions.append(faction)
			else:
				_unloaded.append(faction_name)


func after_all() -> void:
	_factions.clear()
	_unloaded.clear()
	_available_count = 0


func test_at_least_one_faction_is_available() -> void:
	assert_gt(_available_count, 0)


func test_every_available_faction_loads_without_errors() -> void:
	assert_eq(_unloaded.size(), 0, "failed to load: %s" % ", ".join(_unloaded))


func test_every_loaded_faction_has_the_name_it_was_listed_under() -> void:
	var listed := PackedStringArray()
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		listed.append_array(FactionCatalog.factions_for(alliance))
	for faction in _factions:
		assert_has(listed, faction.name)


func test_every_faction_is_in_the_alliance_that_lists_it() -> void:
	for faction in _factions:
		assert_has(FactionCatalog.factions_for(faction.grand_alliance), faction.name)


func test_every_faction_is_legends_in_its_data_only_if_the_catalog_says_so() -> void:
	for faction in _factions:
		assert_eq(faction.legends, FactionCatalog.is_legends(faction.name), faction.name)


func test_every_main_warscroll_has_health() -> void:
	for faction in _factions:
		for unit in faction.warscrolls:
			if unit.name in _NO_HEALTH_OR_SAVE:
				assert_eq(unit.health, 0, "%s: %s" % [faction.name, unit.name])
				continue
			assert_gt(unit.health, 0, "%s: %s" % [faction.name, unit.name])


func test_every_main_warscroll_has_save() -> void:
	for faction in _factions:
		for unit in faction.warscrolls:
			if unit.name in _NO_HEALTH_OR_SAVE:
				assert_eq(unit.save, 0, "%s: %s" % [faction.name, unit.name])
				continue
			assert_gt(unit.save, 0, "%s: %s" % [faction.name, unit.name])


func test_every_main_warscroll_has_weapon_or_ability() -> void:
	for faction in _factions:
		for unit in faction.warscrolls:
			var rules := unit.ranged_weapons.size() + unit.melee_weapons.size() + unit.abilities.size()
			assert_gt(rules, 0, "%s: %s" % [faction.name, unit.name])


func test_warscroll_ids_are_unique() -> void:
	for faction in _factions:
		var seen := {}
		for unit in faction.warscrolls:
			assert_false(seen.has(unit.id), "%s: duplicate id %s" % [faction.name, unit.id])
			seen[unit.id] = true


func test_every_spearhead_general_has_a_warscroll() -> void:
	for faction in _factions:
		for spearhead in faction.spearheads:
			assert_not_null(spearhead.get_warscroll(spearhead.general),
					"%s: %s general %s" % [faction.name, spearhead.name, spearhead.general])


func test_every_spearhead_unit_has_a_warscroll() -> void:
	for faction in _factions:
		for spearhead in faction.spearheads:
			for unit in spearhead.units:
				assert_not_null(spearhead.get_warscroll(unit.name),
						"%s: %s unit %s" % [faction.name, spearhead.name, unit.name])


func _faction_with_id(faction_id: String) -> Faction:
	for faction in _factions:
		if faction.id == faction_id:
			return faction
	return null


func test_some_faction_has_a_regiment_of_renown() -> void:
	var count := 0
	for faction in _factions:
		count += faction.regiments_of_renown.size()
	assert_gt(count, 0)


func test_every_regiment_of_renown_faction_is_a_loaded_faction() -> void:
	for faction in _factions:
		for regiment in faction.regiments_of_renown:
			for faction_id in regiment.factions:
				assert_not_null(_faction_with_id(faction_id), "%s: no faction %s" % [regiment.name, faction_id])


func test_every_regiment_of_renown_unit_has_a_warscroll() -> void:
	for faction in _factions:
		for regiment in faction.regiments_of_renown:
			for unit in regiment.units:
				var where := "%s: %s unit %s" % [faction.name, regiment.name, unit.name]
				if unit.faction_id.is_empty():
					assert_not_null(regiment.get_warscroll(unit.warscroll_id), where)
					continue
				var home := _faction_with_id(unit.faction_id)
				assert_not_null(home, "%s: no faction %s" % [where, unit.faction_id])
				if home:
					assert_not_null(home.get_warscroll(unit.warscroll_id), "%s: no warscroll %s" % [where, unit.warscroll_id])


func test_every_regiment_of_renown_unit_warscroll_has_its_name() -> void:
	for faction in _factions:
		for regiment in faction.regiments_of_renown:
			for unit in regiment.units:
				var home := _faction_with_id(unit.faction_id)
				var warscroll := regiment.get_warscroll(unit.warscroll_id) if unit.faction_id.is_empty() \
						else (home.get_warscroll(unit.warscroll_id) if home else null)
				if warscroll:
					assert_eq(warscroll.name, unit.name, "%s: %s" % [faction.name, regiment.name])


func test_no_faction_lists_a_regiment_of_renown_of_its_own_units_only() -> void:
	# A Regiment of Renown is for other factions' armies; a faction never includes one made only
	# of its own units.
	for faction in _factions:
		for regiment in faction.regiments_of_renown:
			var own := true
			for unit in regiment.units:
				own = own and unit.faction_id == faction.id
			assert_false(own, "%s: %s" % [faction.name, regiment.name])


## Returns every lore in [param faction], including those of its armies of renown.
func _all_lores(faction: Faction) -> Array[Lore]:
	var lores: Array[Lore] = faction.lores.duplicate()
	for army in faction.armies_of_renown:
		lores.append_array(army.lores)
	return lores


func test_every_spell_lore_entry_has_a_casting_value() -> void:
	for faction in _factions:
		for lore in _all_lores(faction):
			if lore.kind != "spell":
				continue
			for entry in lore.entries:
				assert_gt(entry.casting_value, 0, "%s: %s %s" % [faction.name, lore.name, entry.name])


func test_every_prayer_lore_entry_has_a_chanting_value() -> void:
	for faction in _factions:
		for lore in _all_lores(faction):
			if lore.kind != "prayer":
				continue
			for entry in lore.entries:
				assert_gt(entry.chanting_value, 0, "%s: %s %s" % [faction.name, lore.name, entry.name])


# Ability types

func _collect(out: Array, where: String, abilities: Array) -> void:
	for ability: Ability in abilities:
		out.append([where, ability])


func _collect_tables(out: Array, where: String, tables: Array[EnhancementTable]) -> void:
	for table in tables:
		_collect(out, "%s: %s" % [where, table.name], table.entries)


func _collect_lores(out: Array, where: String, lores: Array[Lore]) -> void:
	for lore in lores:
		_collect(out, "%s: %s" % [where, lore.name], lore.entries)


func _collect_warscrolls(out: Array, where: String, warscrolls: Array[Warscroll]) -> void:
	for unit in warscrolls:
		_collect(out, "%s: %s" % [where, unit.name], unit.abilities)


## Returns [[where, Ability], ...] for every ability in every loaded faction.
func _all_abilities() -> Array:
	var out := []
	for faction in _factions:
		var where := faction.name
		_collect(out, where, faction.battle_traits)
		for formation in faction.battle_formations:
			_collect(out, "%s: %s" % [where, formation.name], formation.abilities)
		_collect_tables(out, where, faction.enhancement_tables)
		_collect_lores(out, where, faction.lores)
		_collect_warscrolls(out, where, faction.warscrolls)
		for army in faction.armies_of_renown:
			var army_where := "%s: %s" % [where, army.name]
			_collect(out, army_where, army.battle_traits)
			_collect_tables(out, army_where, army.enhancement_tables)
			_collect_lores(out, army_where, army.lores)
		for regiment in faction.regiments_of_renown:
			var regiment_where := "%s: %s" % [where, regiment.name]
			_collect(out, regiment_where, regiment.abilities)
			_collect_warscrolls(out, regiment_where, regiment.warscrolls)
		for spearhead in faction.spearheads:
			var spearhead_where := "%s: %s" % [where, spearhead.name]
			_collect(out, spearhead_where, spearhead.battle_traits)
			_collect(out, spearhead_where, spearhead.regiment_abilities)
			_collect(out, spearhead_where, spearhead.enhancements)
			_collect_warscrolls(out, spearhead_where, spearhead.warscrolls)
	return out


func _find(abilities: Array, where_prefix: String, ability_name: String) -> Ability:
	for pair: Array in abilities:
		if (pair[0] as String).begins_with(where_prefix) and pair[1].name == ability_name:
			return pair[1]
	return null


func test_abilities_were_collected() -> void:
	assert_gt(_all_abilities().size(), 0)


func test_every_faction_ability_has_a_known_type() -> void:
	for pair: Array in _all_abilities():
		assert_has(Ability.TYPES, pair[1].type, "%s: %s" % [pair[0], pair[1].name])


func test_every_faction_ability_with_command_points_is_a_command() -> void:
	for pair: Array in _all_abilities():
		if pair[1].command_points > 0:
			assert_eq(pair[1].type, "command", "%s: %s" % [pair[0], pair[1].name])


func test_every_faction_command_has_command_points() -> void:
	for pair: Array in _all_abilities():
		if pair[1].type == "command":
			assert_gt(pair[1].command_points, 0, "%s: %s" % [pair[0], pair[1].name])


func test_every_faction_spell_has_a_casting_value_or_spell_keyword() -> void:
	for pair: Array in _all_abilities():
		var ability: Ability = pair[1]
		if ability.type == "spell":
			assert_true(ability.casting_value > 0 or "SPELL" in ability.keywords, "%s: %s" % [pair[0], ability.name])


func test_alarielle_the_goddess_of_life_is_a_two_point_command() -> void:
	var ability := _find(_all_abilities(), "Sylvaneth: Alarielle the Everqueen", "The Goddess Of Life")
	assert_not_null(ability)
	assert_eq([ability.type, ability.command_points], ["command", 2])


func test_summon_loyal_subjects_is_a_one_point_command() -> void:
	var ability := _find(_all_abilities(), "Flesh-eater Courts", "Summon Loyal Subjects")
	assert_not_null(ability)
	assert_eq([ability.type, ability.command_points], ["command", 1])


# Weapon options and Army of Renown rosters

func _weapon_names(unit: Warscroll) -> Array:
	return (unit.melee_weapons + unit.ranged_weapons).map(func(w: Weapon) -> String: return w.name)


func test_some_faction_has_weapon_options() -> void:
	var count := 0
	for faction in _factions:
		for unit in faction.warscrolls:
			count += unit.weapon_options.size()
	assert_gt(count, 0)


func test_every_weapon_option_replaces_a_weapon_on_its_warscroll() -> void:
	for faction in _factions:
		for unit in faction.warscrolls:
			for option in unit.weapon_options:
				assert_has(_weapon_names(unit), option.replaces, "%s: %s replaces %s" % [faction.name, unit.name, option.replaces])


func test_every_weapon_option_names_a_weapon_on_its_warscroll() -> void:
	for faction in _factions:
		for unit in faction.warscrolls:
			for option in unit.weapon_options:
				assert_has(_weapon_names(unit), option.name, "%s: %s option %s" % [faction.name, unit.name, option.name])


func test_some_army_of_renown_has_a_roster() -> void:
	var count := 0
	for faction in _factions:
		for army in faction.armies_of_renown:
			count += 1 if army.roster else 0
	assert_gt(count, 0)


## The names of the units [param army] can draw from: its faction's and those it includes from others,
## before its roster filters them.
func _roster_names(faction: Faction, army: ArmyOfRenown) -> Array:
	var army_data := Army.new()
	army_data.army_of_renown = army.name
	army_data.override_constraints = true
	var catalog := ArmyCatalog.new(faction, null)
	return (faction.warscrolls + catalog.unit_warscrolls(army_data)).map(func(w: Warscroll) -> String: return w.name)


func test_every_army_of_renown_roster_unit_has_a_warscroll() -> void:
	for faction in _factions:
		for army in faction.armies_of_renown:
			if not army.roster:
				continue
			var names := _roster_names(faction, army)
			for entry in army.roster.entries:
				for unit_name in ([entry.unit] if not entry.unit.is_empty() else []) + Array(entry.one_of):
					assert_has(names, unit_name, "%s: %s roster unit %s" % [faction.name, army.name, unit_name])
			for unit_name in army.roster.excluded_units:
				assert_has(names, unit_name, "%s: %s excluded unit %s" % [faction.name, army.name, unit_name])


func test_some_army_of_renown_includes_units_from_another_faction() -> void:
	var count := 0
	for faction in _factions:
		for army in faction.armies_of_renown:
			count += army.roster.included_units.size() if army.roster else 0
	assert_gt(count, 0)


func test_every_army_of_renown_included_unit_has_a_warscroll_in_its_faction() -> void:
	for faction in _factions:
		for army in faction.armies_of_renown:
			if not army.roster:
				continue
			for inclusion in army.roster.included_units:
				var home := FactionCatalog.load_faction(FactionCatalog.name_for_id(inclusion.faction))
				assert_not_null(home, "%s: %s includes unknown faction %s" % [faction.name, army.name, inclusion.faction])
				if home == null:
					continue
				var names := home.warscrolls.map(func(w: Warscroll) -> String: return w.name)
				for unit_name in inclusion.units:
					assert_has(names, unit_name, "%s: %s included unit %s" % [faction.name, army.name, unit_name])


func test_some_enhancement_table_is_for_certain_units() -> void:
	var count := 0
	for faction in _factions:
		for table in faction.enhancement_tables:
			count += 1 if not table.units.is_empty() else 0
	assert_gt(count, 0)


func test_every_enhancement_table_unit_has_a_warscroll() -> void:
	for faction in _factions:
		var names := faction.warscrolls.map(func(w: Warscroll) -> String: return w.name)
		var tables: Array[EnhancementTable] = faction.enhancement_tables.duplicate()
		for army in faction.armies_of_renown:
			tables.append_array(army.enhancement_tables)
		for table in tables:
			for unit_name in table.units:
				assert_has(names, unit_name, "%s: %s unit %s" % [faction.name, table.name, unit_name])


func test_only_warscrolls_from_the_battlepack_scourge_are_current() -> void:
	var scourge := CoreRulesCatalog.get_rules().battlepack.scourge
	assert_ne(scourge, "")
	for faction in _factions:
		for warscroll in faction.warscrolls:
			if warscroll.source.begins_with("Scourge of"):
				assert_eq(warscroll.legends, warscroll.source != scourge, "%s: %s" % [faction.name, warscroll.id])


## Each roster entry matching by keywords allows at least one of the faction's units.
func test_every_army_of_renown_roster_keyword_entry_matches_a_warscroll() -> void:
	for faction in _factions:
		for army in faction.armies_of_renown:
			if not army.roster:
				continue
			for entry in army.roster.entries:
				if entry.unit.is_empty() and entry.one_of.is_empty():
					var found := faction.warscrolls.any(func(w: Warscroll) -> bool: return ArmyValidator.roster_matches(entry, w))
					assert_true(found, "%s: %s roster entry %s matches no warscroll" % [faction.name, army.name, entry.keywords])


func test_every_army_of_renown_roster_per_item_matches_a_warscroll() -> void:
	for faction in _factions:
		for army in faction.armies_of_renown:
			if not army.roster:
				continue
			for entry in army.roster.entries:
				if entry.per.is_empty():
					continue
				var found := faction.warscrolls.any(func(w: Warscroll) -> bool: return ArmyValidator.names_or_keywords(w, entry.per))
				assert_true(found, "%s: %s roster per %s matches no warscroll" % [faction.name, army.name, entry.per])

## Each leader an Army of Renown gives extra regiment options is the name or keyword of a warscroll
## in the faction (or one it includes).
## Leaders can be named by the keywords units gain from the Army of Renown, such as GORECHOSEN
## CHAMPIONS.
func test_every_army_of_renown_regiment_options_leader_matches_a_warscroll() -> void:
	for faction in _factions:
		for army in faction.armies_of_renown:
			if not army.roster:
				continue
			var army_data := Army.new()
			army_data.army_of_renown = army.name
			army_data.override_constraints = true
			var catalog := ArmyCatalog.new(faction, null)
			var scrolls := faction.warscrolls + catalog.unit_warscrolls(army_data)
			for added in army.roster.regiment_options:
				for leader in added.leaders:
					var found := scrolls.any(func(w: Warscroll) -> bool:
						return ArmyValidator.names_or_keywords(w, PackedStringArray([leader]), catalog.gained_keywords(army_data, w)))
					assert_true(found, "%s: %s regiment options leader %s matches no warscroll" % [faction.name, army.name, leader])


func test_every_army_of_renown_regiment_options_entry_has_options() -> void:
	for faction in _factions:
		for army in faction.armies_of_renown:
			if army.roster:
				for added in army.roster.regiment_options:
					assert_gt(added.options.size(), 0, "%s: %s has regiment options without options" % [faction.name, army.name])


# Armies of Renown that add regiment options

## The regiment option problems (units outside the options, or over an option's limit) of an army
## of one regiment of [param leader] and [param others] in [param faction_name], in the Army of
## Renown [param renown] (none if empty).
func _regiment_problems(faction_name: String, renown: String, leader: String, others: Array[String]) -> PackedStringArray:
	var faction := FactionCatalog.load_faction(faction_name)
	var catalog := ArmyCatalog.new(faction, CoreRulesCatalog.get_rules())
	var army := Army.new()
	army.faction_id = faction.id
	army.army_of_renown = renown
	var units: Array[ArmyUnit] = []
	for warscroll_id in [leader] + others:
		var unit := ArmyUnit.new()
		unit.uid = "%s_%d" % [warscroll_id, units.size()]
		unit.warscroll_id = warscroll_id
		units.append(unit)
	var regiment := ArmyRegiment.new()
	regiment.id = "r"
	regiment.name = "r"
	regiment.units = units
	army.regiments.append(regiment)
	var found := PackedStringArray()
	for problem in ArmyValidator.validate(army, catalog).problems:
		if "regiment options" in problem or "can't include another" in problem:
			found.append(problem)
	return found


func test_gorechosen_champions_let_a_bloodstoker_join_a_skullgrinder_regiment() -> void:
	assert_eq(_regiment_problems("Blades of Khorne", "Gorechosen Champions", "skullgrinder", ["bloodstoker"] as Array[String]), PackedStringArray())


func test_a_bloodstoker_cannot_join_a_skullgrinder_regiment_without_gorechosen_champions() -> void:
	assert_gt(_regiment_problems("Blades of Khorne", "", "skullgrinder", ["bloodstoker"] as Array[String]).size(), 0)


func test_pyrofane_cult_lets_a_fusil_major_join_a_magister_regiment() -> void:
	assert_eq(_regiment_problems("Disciples of Tzeentch", "Pyrofane Cult", "magister", ["pyrofane_fusil_major_on_ogor_warhulk"] as Array[String]), PackedStringArray())


func test_a_fusil_major_cannot_join_a_magister_regiment_without_the_pyrofane_cult() -> void:
	assert_gt(_regiment_problems("Disciples of Tzeentch", "", "magister", ["pyrofane_fusil_major_on_ogor_warhulk"] as Array[String]).size(), 0)


func test_scions_of_nulahmia_let_a_vampire_lord_join_sekhars_regiment() -> void:
	assert_eq(_regiment_problems("Soulblight Gravelords", "Scions of Nulahmia", "sekhar_fang_of_nulahmia", ["vampire_lord"] as Array[String]), PackedStringArray())


func test_a_vampire_lord_cannot_join_sekhars_regiment_without_the_scions_of_nulahmia() -> void:
	assert_gt(_regiment_problems("Soulblight Gravelords", "", "sekhar_fang_of_nulahmia", ["vampire_lord"] as Array[String]).size(), 0)


func test_lofnir_drothkeepers_keep_a_runefather_on_magmadroth_to_one_grimnirs_chosen() -> void:
	var others: Array[String] = ["auric_runeson", "auric_runesmiter"]
	assert_gt(_regiment_problems("Fyreslayers", "Lofnir Drothkeepers", "auric_runefather_on_magmadroth", others).size(), 0)



# The Magnate's Crew's non-Hero general

## The problems of a Magnate's Crew army whose general, an Arkanaut Ironclad, leads a regiment of
## [param others], plus a second regiment led by [param extra_leader] if given.
func _magnate_problems(others: Array[String], extra_leader := "") -> PackedStringArray:
	var faction := FactionCatalog.load_faction("Kharadron Overlords")
	var catalog := ArmyCatalog.new(faction, CoreRulesCatalog.get_rules())
	var army := Army.new()
	army.faction_id = faction.id
	army.army_of_renown = "The Magnate's Crew"
	var units: Array[ArmyUnit] = []
	for warscroll_id in ["arkanaut_ironclad"] + others:
		var unit := ArmyUnit.new()
		unit.uid = "u%d" % units.size()
		unit.warscroll_id = warscroll_id
		units.append(unit)
	army.general_uid = "u0"
	army.regiments.append(Kit.regiment("r1", units, "Fleet"))
	if not extra_leader.is_empty():
		army.regiments.append(Kit.regiment("r2", [Kit.unit("x", extra_leader)] as Array[ArmyUnit], "Second"))
	var found := PackedStringArray()
	for problem in ArmyValidator.validate(army, catalog).problems:
		if "Hero leader" in problem or "regiment options" in problem or "can't include another" in problem:
			found.append(problem)
	return found


func test_the_magnates_crew_ironclad_general_leads_skywardens_and_a_frigate() -> void:
	var others: Array[String] = ["skywardens", "arkanaut_frigate"]
	assert_eq(_magnate_problems(others), PackedStringArray())


func test_the_magnates_crew_ironclad_cannot_lead_while_brokk_is_included() -> void:
	var others: Array[String] = ["skywardens"]
	var problems := _magnate_problems(others, "brokk_grungsson_lord_magnate_of_barak_nar")
	assert_true(problems.size() > 0 and "can't be your general while your army includes Brokk Grungsson" in problems[0], str(problems))


# Armies of Renown that give their keyword to units

func test_the_magnates_crew_gives_its_keyword_to_its_units() -> void:
	var faction := FactionCatalog.load_faction("Kharadron Overlords")
	var catalog := ArmyCatalog.new(faction, CoreRulesCatalog.get_rules())
	var army := Army.new()
	army.army_of_renown = "The Magnate's Crew"
	assert_gt(catalog.gained_keywords(army, faction.get_warscroll("skywardens")).size(), 0)


func test_the_magnates_crew_ironclad_leads_an_endrinmaster_in_a_dirigible_suit_and_a_null_khemist() -> void:
	var others: Array[String] = ["endrinmaster_with_dirigible_suit", "null_khemist", "skywardens", "arkanaut_frigate"]
	assert_eq(_magnate_problems(others), PackedStringArray())


func test_scions_of_nulahmia_let_a_vampire_lord_join_a_vampire_lord_on_nightmare_steed() -> void:
	var others: Array[String] = ["vampire_lord"]
	assert_eq(_regiment_problems("Soulblight Gravelords", "Scions of Nulahmia", "vampire_lord_on_nightmare_steed", others), PackedStringArray())
