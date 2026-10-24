extends GutTest
## Integration test of FactionCatalog with the shipped faction data in data/factions.
##
## FactionLoader returns null if it finds any error, so a faction that loads has no loader errors.
## Any errors are pushed by FactionCatalog and would also fail the suite.

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


func test_every_main_warscroll_has_health() -> void:
	for faction in _factions:
		for unit in faction.warscrolls:
			assert_gt(unit.health, 0, "%s: %s" % [faction.name, unit.name])


func test_every_main_warscroll_has_save() -> void:
	for faction in _factions:
		for unit in faction.warscrolls:
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
