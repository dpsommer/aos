class_name EffectCatalog
extends RefCounted
## What abilities do, as data: data/effects/*.json, keyed by a namespace and path, and separate from
## the faction data so rebuilding a faction doesn't touch it. Each entry holds a hash of the rules
## text it was written from: if the text changes, the entry is stale and its ability counts as not
## supported until someone checks it. See docs/technical/effect-data.md.

const DIRECTORY := "res://data/effects"

static var _entries := {}
static var _loaded := false


## The effect data for the ability at [param key], or empty if it's missing or stale.
static func descriptor(key: String, ability: Ability) -> Dictionary:
	var found := raw(key)
	if found.is_empty():
		return {}
	return found if found.get("hash", "") == hash_of(ability) else {}


## The entry at [param key], stale or not, or empty.
static func raw(key: String) -> Dictionary:
	_ensure_loaded()
	return _entries.get(key, {})


## Every entry's key.
static func keys() -> Array:
	_ensure_loaded()
	return _entries.keys()


## The rules text an entry is checked against, hashed.
static func hash_of(ability: Ability) -> String:
	return ("%s\n%s\n%s\n%s" % [ability.timing, ability.declare, ability.effect, ability.text]).md5_text().substr(0, 8)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for file_name in DirAccess.get_files_at(DIRECTORY):
		if file_name.ends_with(".json"):
			load_file("%s/%s" % [DIRECTORY, file_name])


static func load_file(path: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		_entries.merge(data, true)
	else:
		push_error("Bad effect data: %s" % path)


## Adds entries by hand, for tests.
static func add_entries(entries: Dictionary) -> void:
	_ensure_loaded()
	_entries.merge(entries, true)
