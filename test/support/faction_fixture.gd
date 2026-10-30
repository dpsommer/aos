extends RefCounted
## Lists the factions of a fixture in test/fixtures/catalog/ in place of the real ones, so tests can
## check how factions without rules data are shown now that every real faction has some. Each
## fixture's factions.json lists faction names by Grand Alliance id; alliances it leaves out keep
## their real factions.
## Call use() in a test and end() in after_each.
## Preload it: const FactionFixture := preload("res://test/support/faction_fixture.gd")

const DIRECTORY := "res://test/fixtures/catalog"
## The faction the fixtures list without data.
const NAME := "Fixture Faction"


## Lists the factions of the fixture named [param fixture], e.g. "faction_without_data".
static func use(fixture: String) -> void:
	var path := DIRECTORY.path_join(fixture).path_join("factions.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(data is Dictionary, "%s isn't a JSON object" % path)
	var listed := FactionCatalog.real_listing()
	for id: String in data:
		var alliance := GrandAlliance.from_id(id)
		assert(alliance >= 0, "%s lists an unknown Grand Alliance '%s'" % [path, id])
		listed[alliance] = data[id]
	FactionCatalog.set_listed(listed)


## Lists the real factions again.
static func end() -> void:
	FactionCatalog.set_listed({})
