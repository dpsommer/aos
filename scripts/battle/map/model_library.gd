class_name ModelLibrary
extends RefCounted
## Finds the 3D models for warscrolls in [code]res://assets/3d/models/[/code], by name: a model's
## file is its warscroll's name as a slug ([method slug]), e.g. "Vulkite Berzerkers" is
## [code]vulkite_berzerkers.obj[/code], or [code]vulkite_berzerkers_1.obj[/code],
## [code]_2[/code] and so on for a unit whose models differ. Files are found in any folder under
## the root, so where a model lives (by Grand Alliance and faction) doesn't matter. See
## docs/technical/models.md.

const ROOT := "res://assets/3d/models"
const EXTENSIONS: PackedStringArray = ["obj", "glb", "gltf", "res", "tres", "mesh"]

static var _shared: ModelLibrary

var root: String
## Slug to file path, built the first time a model is looked up.
var _paths := {}
var _scanned := false
var _meshes := {}


func _init(at := ROOT) -> void:
	root = at


## The library of the game's models.
static func shared() -> ModelLibrary:
	if _shared == null:
		_shared = ModelLibrary.new()
	return _shared


## [param text] as a model's file name: lower case, apostrophes dropped, and every run of other
## characters that aren't letters or digits an underscore, e.g. "Skabbik's Plaguepack" is
## [code]skabbiks_plaguepack[/code].
static func slug(text: String) -> String:
	var result := ""
	var gap := false
	for character in text.to_lower().replace("'", "").replace("’", ""):
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			if gap and not result.is_empty():
				result += "_"
			result += character
			gap = false
		else:
			gap = true
	return result


## The model files for the first of [param names] that has any: its own file, or its numbered
## variants in order. A name with a weapon option, e.g. "Vulkite Berzerkers with Fyresteel
## Weapons", falls back to the name before " with " when it has no model of its own.
func paths_for(names: PackedStringArray) -> PackedStringArray:
	_scan()
	for each in names:
		for candidate in _candidates(each):
			var found := _variants(candidate)
			if not found.is_empty():
				return found
	return PackedStringArray()


## The meshes of [method paths_for], loaded once each, their materials made ready by
## [method prepare].
func meshes_for(names: PackedStringArray) -> Array[Mesh]:
	var result: Array[Mesh] = []
	for path in paths_for(names):
		if not _meshes.has(path):
			_meshes[path] = load(path) as Mesh
			prepare(_meshes[path])
		if _meshes[path] != null:
			result.append(_meshes[path])
	return result


## Whether any of [param names] has a model.
func has_model(names: PackedStringArray) -> bool:
	return not paths_for(names).is_empty()


## Whether every surface of [param mesh] has its own material (from its [code].mtl[/code]), so it
## needs no placeholder material.
static func is_textured(mesh: Mesh) -> bool:
	if mesh == null or mesh.get_surface_count() == 0:
		return false
	for surface in mesh.get_surface_count():
		if mesh.surface_get_material(surface) == null:
			return false
	return true


## Makes [param mesh]'s materials ready to draw: both sides of each face, as some scans have
## flipped faces, and alpha scissor for a material whose name ends in [code]_cutout[/code]
## (its texture has see-through parts, such as leaves or a banner's edge).
static func prepare(mesh: Mesh) -> void:
	if mesh == null:
		return
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface) as BaseMaterial3D
		if material == null:
			continue
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if material.resource_name.ends_with("_cutout"):
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR


func _candidates(model_name: String) -> PackedStringArray:
	var result := PackedStringArray([slug(model_name)])
	var cut := model_name.findn(" with ")
	if cut > 0:
		result.append(slug(model_name.substr(0, cut)))
	return result


func _variants(stem: String) -> PackedStringArray:
	if stem.is_empty():
		return PackedStringArray()
	if _paths.has(stem):
		return PackedStringArray([_paths[stem]])
	var result := PackedStringArray()
	var n := 1
	while _paths.has("%s_%d" % [stem, n]):
		result.append(_paths["%s_%d" % [stem, n]])
		n += 1
	return result


func _scan() -> void:
	if _scanned:
		return
	_scanned = true
	_scan_dir(root)


func _scan_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for entry in ResourceLoader.list_directory(path):
		if entry.ends_with("/"):
			_scan_dir(path.path_join(entry.trim_suffix("/")))
		elif entry.get_extension().to_lower() in EXTENSIONS:
			_paths[entry.get_basename()] = path.path_join(entry)
