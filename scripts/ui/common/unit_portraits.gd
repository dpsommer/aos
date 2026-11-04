class_name UnitPortraits
extends RefCounted
## Finds a unit's icon: a render of its first model from the front, baked ahead of time by
## tools/portraits/bake_portraits.gd. A portrait has the same path under [constant ROOT] as its
## model has under the [ModelLibrary]'s root, so a unit's name finds it by the library's rules. See
## docs/technical/models.md.

const ROOT := "res://assets/2d/portraits"

static var _shared: UnitPortraits

var models: ModelLibrary
var root: String


func _init(library: ModelLibrary, at := ROOT) -> void:
	models = library
	root = at


## The portraits of the game's models.
static func shared() -> UnitPortraits:
	if _shared == null:
		_shared = UnitPortraits.new(ModelLibrary.shared())
	return _shared


## Makes [method shared] return [param portraits], so tests don't depend on the game's own art.
static func use(portraits: UnitPortraits) -> void:
	_shared = portraits


## Makes [method shared] return the game's portraits again, after [method use].
static func end() -> void:
	_shared = null


## The portrait of the first of [param names] that has a model, or null if there's no model, it
## hasn't been baked, or Godot failed to import it (a Git LFS pointer in a checkout without Git LFS).
func texture_for(names: PackedStringArray) -> Texture2D:
	var found := models.paths_for(names)
	if found.is_empty():
		return null
	var path := portrait_path(found[0])
	if not ResourceLoader.exists(path) or not ModelLibrary.is_imported(path):
		return null
	return load(path)


## Where the portrait of the model at [param model_path] goes.
func portrait_path(model_path: String) -> String:
	return root.path_join(model_path.trim_prefix(models.root + "/").get_basename() + ".png")
