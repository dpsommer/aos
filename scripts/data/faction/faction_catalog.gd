class_name FactionCatalog
extends RefCounted
## Faction names grouped by Grand Alliance.
##
## Placeholder until factions are defined as resources with their own units and rules.

const _FACTIONS := {
	GrandAlliance.Type.ORDER: [
		"Cities of Sigmar",
		"Daughters of Khaine",
		"Fyreslayers",
		"Idoneth Deepkin",
		"Kharadron Overlords",
		"Khazalite Holds",
		"Lumineth Realm-lords",
		"Seraphon",
		"Stormcast Eternals",
		"Sylvaneth",
	],
	GrandAlliance.Type.CHAOS: [
		"Beasts of Chaos",
		"Blades of Khorne",
		"Disciples of Tzeentch",
		"Hedonites of Slaanesh",
		"Helsmiths of Hashut",
		"Maggotkin of Nurgle",
		"Skaven",
		"Slaves to Darkness",
	],
	GrandAlliance.Type.DEATH: [
		"Flesh-eater Courts",
		"Nighthaunt",
		"Ossiarch Bonereapers",
		"Soulblight Gravelords",
	],
	GrandAlliance.Type.DESTRUCTION: [
		"Bonesplitterz",
		"Gloomspite Gitz",
		"Ironjawz",
		"Kruleboyz",
		"Ogor Mawtribes",
		"Sons of Behemat",
	],
}


## Data directories for factions whose rules have been added. See docs/technical/faction-data.md.
const _DATA_DIRS := {
	"Beasts of Chaos": "res://data/factions/beasts_of_chaos",
	"Blades of Khorne": "res://data/factions/blades_of_khorne",
	"Bonesplitterz": "res://data/factions/bonesplitterz",
	"Cities of Sigmar": "res://data/factions/cities_of_sigmar",
	"Daughters of Khaine": "res://data/factions/daughters_of_khaine",
	"Disciples of Tzeentch": "res://data/factions/disciples_of_tzeentch",
	"Flesh-eater Courts": "res://data/factions/flesh_eater_courts",
	"Fyreslayers": "res://data/factions/fyreslayers",
	"Gloomspite Gitz": "res://data/factions/gloomspite_gitz",
	"Hedonites of Slaanesh": "res://data/factions/hedonites_of_slaanesh",
	"Helsmiths of Hashut": "res://data/factions/helsmiths_of_hashut",
	"Idoneth Deepkin": "res://data/factions/idoneth_deepkin",
	"Ironjawz": "res://data/factions/ironjawz",
	"Kharadron Overlords": "res://data/factions/kharadron_overlords",
	"Khazalite Holds": "res://data/factions/khazalite_holds",
	"Kruleboyz": "res://data/factions/kruleboyz",
	"Lumineth Realm-lords": "res://data/factions/lumineth_realm_lords",
	"Maggotkin of Nurgle": "res://data/factions/maggotkin_of_nurgle",
	"Nighthaunt": "res://data/factions/nighthaunt",
	"Ogor Mawtribes": "res://data/factions/ogor_mawtribes",
	"Ossiarch Bonereapers": "res://data/factions/ossiarch_bonereapers",
	"Seraphon": "res://data/factions/seraphon",
	"Skaven": "res://data/factions/skaven",
	"Slaves to Darkness": "res://data/factions/slaves_to_darkness",
	"Sons of Behemat": "res://data/factions/sons_of_behemat",
	"Soulblight Gravelords": "res://data/factions/soulblight_gravelords",
	"Stormcast Eternals": "res://data/factions/stormcast_eternals",
	"Sylvaneth": "res://data/factions/sylvaneth",
}

## Factions moved to Legends as a whole. Matches the [code]legends[/code] flag in their faction.json,
## so the Forge can label them without loading their data.
const _LEGENDS := ["Beasts of Chaos", "Bonesplitterz", "Fyreslayers"]

static var _loaded := {}
## Faction ids by the ids of their manifestation warscrolls, read on first use.
static var _manifestation_factions := {}
## Every faction's Spearheads, read on first use by [method spearheads].
static var _spearheads: Array[Dictionary] = []
## The factions listed for each Grand Alliance: [constant _FACTIONS], or what [method set_listed] gave.
static var _listed: Dictionary = _FACTIONS


## Returns a copy of the faction names for [param alliance], in display order.
static func factions_for(alliance: GrandAlliance.Type) -> PackedStringArray:
	return PackedStringArray(_listed[alliance])


## Lists [param listed] (names by [enum GrandAlliance.Type], as [constant _FACTIONS]) in place of the
## real factions, or the real ones again if it's empty. For tests, e.g. to list a faction without data;
## see test/support/faction_fixture.gd.
static func set_listed(listed: Dictionary) -> void:
	_listed = listed if not listed.is_empty() else _FACTIONS
	_spearheads.clear()


## The real factions listed for each Grand Alliance, whatever [method set_listed] gave.
static func real_listing() -> Dictionary:
	return _FACTIONS.duplicate(true)


## Whether [param faction] has rules data and can be opened.
static func is_available(faction: String) -> bool:
	return _DATA_DIRS.has(faction)


## Whether [param faction] has been moved to Legends.
static func is_legends(faction: String) -> bool:
	return faction in _LEGENDS


## The Grand Alliance [param faction] belongs to, or -1 if it isn't a known faction.
static func alliance_of(faction: String) -> int:
	for alliance: GrandAlliance.Type in _FACTIONS:
		if faction in _FACTIONS[alliance]:
			return alliance
	return -1


## Name of the faction whose data directory is named [param faction_id], or empty if none is.
static func name_for_id(faction_id: String) -> String:
	for faction: String in _DATA_DIRS:
		if _DATA_DIRS[faction].get_file() == faction_id:
			return faction
	return ""


## The id of a faction whose warscrolls include the manifestation [param warscroll_id], or ""
## if none does. Reads the factions' warscrolls.json without loading them.
static func manifestation_faction(warscroll_id: String) -> String:
	if _manifestation_factions.is_empty():
		for faction: String in _DATA_DIRS:
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_DATA_DIRS[faction].path_join("warscrolls.json")))
			if not data is Dictionary:
				continue
			for warscroll: Variant in data.get("warscrolls", []):
				if warscroll is Dictionary and "MANIFESTATION" in warscroll.get("keywords", []):
					_manifestation_factions[warscroll.id] = _DATA_DIRS[faction].get_file()
	return _manifestation_factions.get(warscroll_id, "")


## Every faction's Spearheads, by Grand Alliance then faction in display order, each
## {"name": String, "faction": String, "alliance": GrandAlliance.Type, "units": int}, where
## [code]units[/code] counts the general too. Reads the factions' spearhead.json without loading
## them.
static func spearheads() -> Array[Dictionary]:
	if _spearheads.is_empty():
		for alliance: GrandAlliance.Type in GrandAlliance.Type.values():
			for faction: String in _listed[alliance]:
				if not is_available(faction):
					continue
				var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_DATA_DIRS[faction].path_join("spearhead.json")))
				if not data is Dictionary:
					continue
				for spearhead: Variant in data.get("spearheads", []):
					if spearhead is Dictionary and spearhead.get("name") is String:
						var units: Variant = spearhead.get("units", [])
						_spearheads.append({"name": spearhead.name, "faction": faction, "alliance": alliance,
								"units": 1 + (units.size() if units is Array else 0)})
	return _spearheads.duplicate()


## Loads [param faction]'s data, caching it. Returns null and reports errors if it can't be loaded.
static func load_faction(faction: String) -> Faction:
	if _loaded.has(faction):
		return _loaded[faction]
	if not is_available(faction):
		push_error("No data for faction '%s'" % faction)
		return null
	var loader := FactionLoader.new()
	var core := CoreRulesCatalog.get_rules()
	if core and core.battlepack:
		loader.scourge = core.battlepack.scourge
	var data := loader.load_faction(_DATA_DIRS[faction])
	for error in loader.errors:
		push_error(error)
	if data:
		_loaded[faction] = data
	return data
