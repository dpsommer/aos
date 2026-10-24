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
