class_name ArmyStore
extends RefCounted
## Saves armies as JSON files, one per army, named by the army's id. See docs/design/forge.md.

## Where armies are saved. Tests point this elsewhere.
static var directory := "user://armies"


## A saved army file, read for the saved armies list.
class Entry:
	var id := ""
	## The army, or null if the file can't be read.
	var army: Army
	## Problems reading the file: why it can't be read, or fields that were skipped.
	var errors := PackedStringArray()
	## When it was saved, in seconds since the Unix epoch.
	var saved_at := 0.0


## Saves [param army], giving it an id first if it has none. Returns the error, if any.
static func save(army: Army) -> Error:
	if army.id.is_empty():
		army.id = new_id()
	var made := DirAccess.make_dir_recursive_absolute(directory)
	if made != OK:
		return made
	var data := ArmySerializer.to_dict(army)
	data.saved_at = Time.get_unix_time_from_system()
	var file := FileAccess.open(path(army.id), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	return OK


## The saved armies, most recently saved first.
static func list() -> Array[Entry]:
	var entries: Array[Entry] = []
	if not DirAccess.dir_exists_absolute(directory):
		return entries
	for file_name in DirAccess.get_files_at(directory):
		if file_name.get_extension() == "json":
			entries.append(read(file_name.get_basename()))
	entries.sort_custom(func(a: Entry, b: Entry) -> bool: return a.saved_at > b.saved_at)
	return entries


## Reads the saved army with [param id].
static func read(id: String) -> Entry:
	var entry := Entry.new()
	entry.id = id
	var json := JSON.new()
	var data: Variant = json.data if json.parse(FileAccess.get_file_as_string(path(id))) == OK else null
	if not data is Dictionary:
		entry.errors.append("The file isn't a saved army.")
		return entry
	var saved_at: Variant = data.get("saved_at", 0.0)
	entry.saved_at = float(saved_at) if saved_at is float or saved_at is int else 0.0
	var serializer := ArmySerializer.new()
	entry.army = serializer.from_dict(data)
	entry.errors = serializer.errors
	if entry.army:
		entry.army.id = id
	return entry


static func load_army(id: String) -> Army:
	return read(id).army


static func delete(id: String) -> Error:
	return DirAccess.remove_absolute(path(id))


## Saves a copy of the army with [param id] under a new id, named "<name> (copy)". Returns the copy,
## or null if the army can't be read or saved.
static func copy(id: String) -> Army:
	var army := load_army(id)
	if army == null:
		return null
	army.id = new_id()
	army.name = "%s (copy)" % army.name
	return army if save(army) == OK else null


static func path(id: String) -> String:
	return directory.path_join(id + ".json")


## A random id, 32 hex digits.
static func new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()
