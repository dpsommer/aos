extends RefCounted
## Points the saved armies, the info pane's favourites and the settings at temporary locations, so
## tests never read or write the player's real data. Settings start at their defaults.
## Call begin() in before_each and end() in after_each.
## Preload it: const Sandbox := preload("res://test/support/sandbox.gd")

const FAVOURITES := "user://test_sandbox_favourites.cfg"
const SETTINGS := "user://test_sandbox_settings.cfg"

static var _real_directory := ""
static var _real_favourites := ""
static var _real_settings := ""
static var _active := false


static func armies_directory() -> String:
	return "user://test_sandbox_armies"


## Redirects [ArmyStore], [InfoPane] and [GameSettings] to empty temporary locations.
static func begin() -> void:
	if not _active:
		_real_directory = ArmyStore.directory
		_real_favourites = InfoPane.favourites_path
		_real_settings = GameSettings.path
		_active = true
	ArmyStore.directory = armies_directory()
	InfoPane.favourites_path = FAVOURITES
	GameSettings.path = SETTINGS
	_wipe()
	GameSettings.reset_current()


## Deletes the temporary data, restores the real locations, and puts the keys and volumes back to
## their defaults.
static func end() -> void:
	_wipe()
	if _active:
		ArmyStore.directory = _real_directory
		InfoPane.favourites_path = _real_favourites
		GameSettings.path = _real_settings
		_active = false
	GameSettings.reset_current()
	# The Settings screen remaps keys and sets volumes as it saves them.
	var defaults := GameSettings.new()
	defaults.apply_input()
	defaults.apply_sound()


static func _wipe() -> void:
	if DirAccess.dir_exists_absolute(armies_directory()):
		for file_name in DirAccess.get_files_at(armies_directory()):
			DirAccess.remove_absolute(armies_directory().path_join(file_name))
	DirAccess.remove_absolute(armies_directory())
	DirAccess.remove_absolute(FAVOURITES)
	DirAccess.remove_absolute(SETTINGS)
