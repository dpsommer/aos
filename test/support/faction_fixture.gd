extends RefCounted
## Lists a fixture faction that has no rules data, so tests can check how factions without data are
## shown now that every real faction has some.
## Call list_beside() or list_alone() in a test and end() in after_each.
## Preload it: const FactionFixture := preload("res://test/support/faction_fixture.gd")

const NAME := "Fixture Faction"


## Lists the fixture faction last among [param alliance]'s real factions.
static func list_beside(alliance: GrandAlliance.Type) -> void:
	var listed := FactionCatalog.real_listing()
	listed[alliance].append(NAME)
	FactionCatalog.set_listed(listed)


## Lists the fixture faction as [param alliance]'s only faction, so none of its factions have data.
static func list_alone(alliance: GrandAlliance.Type) -> void:
	var listed := FactionCatalog.real_listing()
	listed[alliance] = [NAME]
	FactionCatalog.set_listed(listed)


## Lists the real factions again.
static func end() -> void:
	FactionCatalog.set_listed({})
