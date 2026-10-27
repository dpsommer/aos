extends GutTest
## Unit tests for faction data (scripts/data/faction_catalog.gd, scripts/data/grand_alliance.gd).


func test_every_alliance_has_at_least_one_faction() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		assert_gt(FactionCatalog.factions_for(alliance).size(), 0,
				"%s has no factions" % GrandAlliance.display_name(alliance))


func test_no_faction_belongs_to_two_alliances() -> void:
	var owners := {}
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		for faction in FactionCatalog.factions_for(alliance):
			assert_false(owners.has(faction), "%s appears in more than one alliance" % faction)
			owners[faction] = alliance


func test_no_faction_is_listed_twice_within_an_alliance() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var factions := FactionCatalog.factions_for(alliance)
		for faction in factions:
			assert_eq(factions.count(faction), 1, "%s is listed twice" % faction)


func test_mutating_returned_factions_does_not_change_later_results() -> void:
	var alliance: GrandAlliance.Type = GrandAlliance.Type.values()[0]
	var original := FactionCatalog.factions_for(alliance)
	var returned := FactionCatalog.factions_for(alliance)
	returned.clear()
	returned.append("Not A Real Faction")
	assert_eq(FactionCatalog.factions_for(alliance), original)


func test_every_alliance_has_a_display_name() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		assert_ne(GrandAlliance.display_name(alliance), "", "alliance %d has no display name" % alliance)


func test_display_names_are_unique() -> void:
	var seen := {}
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		var display_name := GrandAlliance.display_name(alliance)
		assert_false(seen.has(display_name), "%s is used by two alliances" % display_name)
		seen[display_name] = true


## Returns every faction listed under any alliance.
func _all_factions() -> PackedStringArray:
	var all := PackedStringArray()
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		all.append_array(FactionCatalog.factions_for(alliance))
	return all


func _first_available() -> String:
	for faction in _all_factions():
		if FactionCatalog.is_available(faction):
			return faction
	return ""


func _first_unavailable() -> String:
	for faction in _all_factions():
		if not FactionCatalog.is_available(faction):
			return faction
	return ""


func test_at_least_one_listed_faction_is_available() -> void:
	assert_ne(_first_available(), "")


func test_unknown_faction_is_not_available() -> void:
	assert_false(FactionCatalog.is_available("Not A Real Faction"))


func test_load_faction_returns_faction_with_requested_name() -> void:
	var faction := _first_available()
	assert_eq(FactionCatalog.load_faction(faction).name, faction)


func test_load_faction_returns_faction_in_listing_alliance() -> void:
	var faction := _first_available()
	var loaded := FactionCatalog.load_faction(faction)
	assert_has(FactionCatalog.factions_for(loaded.grand_alliance), faction)


func test_load_faction_returns_same_instance_twice() -> void:
	var faction := _first_available()
	assert_same(FactionCatalog.load_faction(faction), FactionCatalog.load_faction(faction))


func test_load_unknown_faction_returns_null() -> void:
	var loaded := FactionCatalog.load_faction("Not A Real Faction")
	assert_push_error("Not A Real Faction")
	assert_null(loaded)


func test_load_listed_but_unavailable_faction_returns_null() -> void:
	var faction := _first_unavailable()
	if faction.is_empty():
		pending("every listed faction has data")
		return
	var loaded := FactionCatalog.load_faction(faction)
	assert_push_error(faction)
	assert_null(loaded)


func test_from_id_parses_lowercase_display_name() -> void:
	for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
		assert_eq(GrandAlliance.from_id(GrandAlliance.display_name(alliance).to_lower()), alliance)


func test_from_id_returns_negative_for_unknown_id() -> void:
	assert_lt(GrandAlliance.from_id("not_an_alliance"), 0)


func _first_legends() -> String:
	for faction in _all_factions():
		if FactionCatalog.is_legends(faction):
			return faction
	return ""


func _first_available_not_legends() -> String:
	for faction in _all_factions():
		if FactionCatalog.is_available(faction) and not FactionCatalog.is_legends(faction):
			return faction
	return ""


func test_unknown_faction_is_not_legends() -> void:
	assert_false(FactionCatalog.is_legends("Not A Real Faction"))


func test_legends_faction_matches_legends_flag_in_its_data() -> void:
	var faction := _first_legends()
	if faction.is_empty() or not FactionCatalog.is_available(faction):
		pending("no listed Legends faction has data")
		return
	assert_true(FactionCatalog.load_faction(faction).legends, "%s data is not flagged legends" % faction)


func test_non_legends_faction_matches_legends_flag_in_its_data() -> void:
	var faction := _first_available_not_legends()
	assert_false(FactionCatalog.load_faction(faction).legends, "%s data is flagged legends" % faction)


func test_name_for_unknown_id_is_empty() -> void:
	assert_eq(FactionCatalog.name_for_id("not_a_real_faction"), "")


func test_name_for_empty_id_is_empty() -> void:
	assert_eq(FactionCatalog.name_for_id(""), "")
