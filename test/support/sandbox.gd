extends RefCounted
## Points the saved armies and the info pane's favourites at temporary locations, so tests never read
## or write the player's real data. Call begin() in before_each and end() in after_each.
## Preload it: const Sandbox := preload("res://test/support/sandbox.gd")

const FAVOURITES := "user://test_sandbox_favourites.cfg"

static var _real_directory := ""
static var _real_favourites := ""
static var _active := false


static func armies_directory() -> String:
	return "user://test_sandbox_armies"


## Redirects [ArmyStore] and [InfoPane] to empty temporary locations.
static func begin() -> void:
	if not _active:
		_real_directory = ArmyStore.directory
		_real_favourites = InfoPane.favourites_path
		_active = true
	ArmyStore.directory = armies_directory()
	InfoPane.favourites_path = FAVOURITES
	_wipe()


## Deletes the temporary data and restores the real locations.
static func end() -> void:
	_wipe()
	if _active:
		ArmyStore.directory = _real_directory
		InfoPane.favourites_path = _real_favourites
		_active = false


static func _wipe() -> void:
	if DirAccess.dir_exists_absolute(armies_directory()):
		for file_name in DirAccess.get_files_at(armies_directory()):
			DirAccess.remove_absolute(armies_directory().path_join(file_name))
	DirAccess.remove_absolute(armies_directory())
	DirAccess.remove_absolute(FAVOURITES)
