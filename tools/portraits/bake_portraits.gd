extends SceneTree
## Renders each unit's first model from the front, or from the side for a long war machine or beast
## ([method is_side_on_keywords], [method is_long]), to a transparent PNG in assets/2d/portraits/, for
## the game's unit icons (see UnitPortraits and docs/technical/models.md). Needs a window, as
## --headless has no renderer to draw with:
##
##     godot --path . -s tools/portraits/bake_portraits.gd -- [--only "<warscroll>"]...
##     godot --headless --import

const RENDER_SIZE := 512
const PORTRAIT_SIZE := 256
## The most of a model's height a portrait shows, measured from its top, which leaves out its base.
const MOST_SHOWN := 0.75
## The least of a model's height a portrait shows, so a tall, narrow model still shows its top half.
const LEAST_SHOWN := 0.5
## The empty space above a model, as a fraction of the portrait's height.
const TOP_MARGIN := 0.03
## How much empty space or other parts of the model a close-up can show above the head, as a fraction
## of the portrait's height, which keeps the face in the upper half of every portrait.
const HEAD_ROOM := 0.18
## The side of the picture [method find_head] looks at, small enough to read every pixel quickly.
const PROBE_SIZE := 128
## How far behind the model's middle a pixel can be and still count as its body, as a fraction of
## the model's depth. Anything further back is on its back, like a pack or wings.
const BODY_DEPTH := 0.12
## How wide the part of a model searched for a head is, as a fraction of its body's width. Anything
## further out to the sides is a weapon or an arm.
const HEAD_BAND := 0.6
## How much of the widest row of that part a row must fill to be the head. Anything thinner is a
## spear, a staff or a plume.
const HEAD_WIDTH := 0.3
## Draws how far back each point is in red, from 0 at the model's front to 1 at its back, for
## [method find_head]. The power undoes the viewport's conversion to sRGB.
const DEPTH_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float front;
uniform float back;
varying float depth;
void vertex() { depth = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() { ALBEDO = vec3(pow(clamp((depth - front) / (back - front), 0.0, 1.0), 2.2)); }
"""
## The bottom of a model's height that a side view leaves out, where its base is.
const SIDE_VIEW_BASE := 0.15
## How much bigger than a model's height a side view can be, which cuts off the ends of only the
## longest, lowest models.
const SIDE_VIEW_MOST := 1.5
## How long a model must be, in inches, to be drawn from the side.
const SIDE_VIEW_LENGTH := 4.5
## How many times longer than wide a model must be to be drawn from the side.
const SIDE_VIEW_RATIO := 1.25
const DATA_FOLDERS: PackedStringArray = ["res://data/factions", "res://data/shared"]
## Spearhead terrain is drawn on the battlefield and has no icon.
const SKIPPED_FOLDER := "shared/spearhead"
## Lossless, with mipmaps so that a 256 px portrait stays crisp at 40 px.
const IMPORT_FILE := '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\ndetect_3d/compress_to=0\n'

var _viewport: SubViewport
## Holds the camera and lights, and turns to look at a model from the front or the side.
var _rig: Node3D
var _camera: Camera3D
var _model: MeshInstance3D
var _depth_material: ShaderMaterial


func _initialize() -> void:
	_run.call_deferred()


## The point a camera should look at and the height it should see to zoom in on the top of a model
## with [param bounds], seen from the front. The view is as wide as the model, so the model fills
## it, but between [constant LEAST_SHOWN] and [constant MOST_SHOWN] of its height, so a wide model
## is cut off at the sides rather than showing its base. With a [param head] from [method find_head],
## the view is measured from the head and centred on the body, and has at most
## [constant HEAD_ROOM] above the head, so anything taller is cut off.
static func framing(bounds: AABB, head := {}) -> Dictionary:
	var center := bounds.get_center()
	var top := bounds.end.y
	var height := bounds.size.y
	var width := bounds.size.x
	if not head.is_empty():
		height = head.top - bounds.position.y
		width = head.width
		center.x = head.x
	var size := clampf(width, height * LEAST_SHOWN, height * MOST_SHOWN)
	top += size * TOP_MARGIN
	if not head.is_empty():
		top = minf(top, head.top + size * HEAD_ROOM)
	center.y = top - size / 2.0
	return {"center": center, "size": size}


## Whether [param stem], a model file's name without its extension, is a unit's only model or the
## first of its numbered variants: true for [code]x[/code] and [code]x_1[/code], not [code]x_2[/code].
static func is_first_variant(stem: String) -> bool:
	var suffix := stem.get_slice("_", stem.get_slice_count("_") - 1)
	return not suffix.is_valid_int() or suffix.to_int() == 1


## The point a camera should look at and the height it should see to show the middle of a long
## model with [param bounds], seen from the side. The view is as wide as the model is long, up to
## [constant SIDE_VIEW_MOST] of its height. A big view stays above [constant SIDE_VIEW_BASE] of its
## height, with the space left over above the model.
static func side_framing(bounds: AABB) -> Dictionary:
	var height := bounds.size.y
	var size := clampf(bounds.size.z, height * LEAST_SHOWN, height * SIDE_VIEW_MOST)
	var center := bounds.get_center()
	center.y = maxf(center.y, bounds.position.y + height * SIDE_VIEW_BASE + size / 2.0)
	return {"center": center, "size": size}


## The view of the whole of a model with [param bounds] that [method find_head] looks at.
static func silhouette_framing(bounds: AABB) -> Dictionary:
	return {"center": bounds.get_center(), "size": maxf(bounds.size.x, bounds.size.y)}


## Estimates where the head of a model with [param bounds] is, from [param probe]: the model from
## the front in the view of [method silhouette_framing], drawn with [constant DEPTH_SHADER]. It leaves
## out what's behind the body and to its sides, then takes the highest row wide enough to be a head.
## Returns the head's top as [code]top[/code], the middle of the body as [code]x[/code] and how
## wide the model is from the head down as [code]width[/code], or nothing for an empty picture.
static func find_head(bounds: AABB, probe: Image) -> Dictionary:
	var image := probe.duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	image.resize(PROBE_SIZE, PROBE_SIZE, Image.INTERPOLATE_NEAREST)
	var data := image.get_data()
	var depths := PackedByteArray()
	for i in range(0, data.size(), 4):
		if data[i + 3] > 128:
			depths.append(data[i])
	if depths.is_empty():
		return {}
	depths.sort()
	var deepest: int = depths[depths.size() / 2] + int(BODY_DEPTH * 255.0)
	var columns := PackedInt32Array()
	for row in PROBE_SIZE:
		for column in PROBE_SIZE:
			var i := (row * PROBE_SIZE + column) * 4
			if data[i + 3] > 128 and data[i] <= deepest:
				columns.append(column)
	if columns.is_empty():
		return {}
	columns.sort()
	var middle: int = columns[columns.size() / 2]
	var half_band := maxf((columns[columns.size() * 9 / 10] - columns[columns.size() / 10]) * HEAD_BAND / 2.0, 1.0)
	var counts := PackedInt32Array()
	counts.resize(PROBE_SIZE)
	var most := 0
	for row in PROBE_SIZE:
		for column in range(maxi(int(middle - half_band), 0), mini(int(middle + half_band) + 1, PROBE_SIZE)):
			var i := (row * PROBE_SIZE + column) * 4
			if data[i + 3] > 128 and data[i] <= deepest:
				counts[row] += 1
		most = maxi(most, counts[row])
	var head_row := 0
	while counts[head_row] < most * HEAD_WIDTH:
		head_row += 1
	var frame := silhouette_framing(bounds)
	var pixel: float = frame.size / PROBE_SIZE
	var used := image.get_region(Rect2i(0, head_row, PROBE_SIZE, PROBE_SIZE - head_row)).get_used_rect()
	return {
		"top": frame.center.y + frame.size / 2.0 - head_row * pixel,
		# From the front, the model's +X is on the left of the picture.
		"x": frame.center.x + frame.size / 2.0 - (middle + 0.5) * pixel,
		"width": used.size.x * pixel,
	}


## Whether a warscroll with [param keywords] could be drawn from the side: a war machine or monster
## that isn't a character, as a Hero keeps its close-up.
static func is_side_on_keywords(keywords: Array) -> bool:
	return "HERO" not in keywords and ("WAR MACHINE" in keywords or "MONSTER" in keywords)


## Whether a model with [param bounds] is big and long enough that its side shows more of it.
static func is_long(bounds: AABB) -> bool:
	return bounds.size.z >= SIDE_VIEW_LENGTH and bounds.size.z >= bounds.size.x * SIDE_VIEW_RATIO


## [param stem], a model file's name without its extension, without a variant's number.
static func unit_stem(stem: String) -> String:
	var suffix := stem.get_slice("_", stem.get_slice_count("_") - 1)
	return stem.trim_suffix("_" + suffix) if suffix.is_valid_int() else stem


## Adds to [param into], as model file names, the warscrolls anywhere in [param data], a faction's
## parsed JSON, that could be drawn from the side. "X with Y" adds X too, as its model may be X's.
static func collect_side_on_names(data: Variant, into: Dictionary) -> void:
	if data is Dictionary:
		if data.get("keywords") is Array and data.get("name") is String and is_side_on_keywords(data.keywords):
			into[ModelLibrary.slug(data.name)] = true
			var cut: int = data.name.findn(" with ")
			if cut > 0:
				into[ModelLibrary.slug(data.name.substr(0, cut))] = true
		for value: Variant in data.values():
			collect_side_on_names(value, into)
	elif data is Array:
		for value: Variant in data:
			collect_side_on_names(value, into)


func _run() -> void:
	_build_stage()
	var side_on := _side_on_names()
	var portraits := UnitPortraits.new(ModelLibrary.new())
	var models := _models_to_bake(portraits.models)
	var failed := PackedStringArray()
	for i in models.size():
		print("[%d/%d] %s" % [i + 1, models.size(), models[i]])
		if not await _bake(models[i], portraits.portrait_path(models[i]), side_on):
			failed.append(models[i])
	print("Baked %d portraits." % (models.size() - failed.size()))
	if not failed.is_empty():
		printerr("Failed:\n  " + "\n  ".join(failed))
	quit(1 if not failed.is_empty() else 0)


func _side_on_names() -> Dictionary:
	var names := {}
	for folder in DATA_FOLDERS:
		_collect_data(folder, names)
	return names


func _collect_data(folder: String, names: Dictionary) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() == "json":
			collect_side_on_names(JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(file))), names)
	for child in DirAccess.get_directories_at(folder):
		_collect_data(folder.path_join(child), names)


## The models named by --only, or every unit's first model.
func _models_to_bake(library: ModelLibrary) -> PackedStringArray:
	var args := OS.get_cmdline_user_args()
	var result := PackedStringArray()
	var only := false
	for i in args.size():
		if args[i] == "--only" and i + 1 < args.size():
			only = true
			var found := library.paths_for(PackedStringArray([args[i + 1]]))
			if found.is_empty():
				printerr("No model for " + args[i + 1])
			else:
				result.append(found[0])
	if not only:
		_collect(library.root, result)
	return result


func _collect(folder: String, into: PackedStringArray) -> void:
	for entry in ResourceLoader.list_directory(folder):
		var path := folder.path_join(entry.trim_suffix("/"))
		if entry.ends_with("/"):
			if not path.ends_with(SKIPPED_FOLDER):
				_collect(path, into)
		elif entry.get_extension().to_lower() in ModelLibrary.EXTENSIONS and ModelLibrary.is_imported(path) \
				and is_first_variant(entry.get_basename()):
			into.append(path)


func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(RENDER_SIZE, RENDER_SIZE)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(_viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.4
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)

	_rig = Node3D.new()
	_viewport.add_child(_rig)

	_add_light(Vector3(-0.4, -0.6, 1.0), 0.7)
	_add_light(Vector3(0.7, -0.2, 1.0), 0.2)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# The models face -Z, so from the front the camera stands on that side and looks towards +Z.
	_camera.rotation_degrees.y = 180.0
	_rig.add_child(_camera)

	_model = MeshInstance3D.new()
	_viewport.add_child(_model)

	var shader := Shader.new()
	shader.code = DEPTH_SHADER
	_depth_material = ShaderMaterial.new()
	_depth_material.shader = shader


func _add_light(direction: Vector3, energy: float) -> void:
	var light := DirectionalLight3D.new()
	light.basis = Basis.looking_at(direction.normalized())
	light.light_energy = energy
	_rig.add_child(light)


## Renders [param model] to [param portrait], and returns whether it could. A long model whose name
## is in [param side_on] is drawn from the side.
func _bake(model: String, portrait: String, side_on: Dictionary) -> bool:
	# Loaded here rather than by ModelLibrary.meshes_for(), which would keep every model in memory.
	var mesh := load(model) as Mesh
	if mesh == null or mesh.get_aabb().size == Vector3.ZERO:
		return false
	ModelLibrary.prepare(mesh)
	_model.mesh = mesh
	var bounds := mesh.get_aabb()
	var side_view: bool = side_on.has(unit_stem(model.get_file().get_basename())) and is_long(bounds)
	var frame := side_framing(bounds)
	if not side_view:
		frame = framing(bounds, await _probe_head(bounds))
	_aim(frame, bounds, side_view)
	var image := await _render()
	_model.mesh = null
	# Gives see-through pixels the colour of their neighbours, or resizing leaves a dark outline.
	image.fix_alpha_edges()
	image.resize(PORTRAIT_SIZE, PORTRAIT_SIZE, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(portrait.get_base_dir())
	if image.save_png(portrait) != OK:
		return false
	_write_import_file(portrait)
	return true


func _probe_head(bounds: AABB) -> Dictionary:
	_depth_material.set_shader_parameter("front", bounds.position.z)
	_depth_material.set_shader_parameter("back", bounds.end.z)
	_model.material_override = _depth_material
	_aim(silhouette_framing(bounds), bounds, false)
	var probe := await _render()
	_model.material_override = null
	return find_head(bounds, probe)


func _render() -> Image:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	return _viewport.get_texture().get_image()


## Points the camera at [param frame], for a model with [param bounds].
func _aim(frame: Dictionary, bounds: AABB, side_view: bool) -> void:
	var center: Vector3 = frame.center
	# From the side, the camera looks towards -X, so the model faces right.
	_rig.rotation_degrees.y = -90.0 if side_view else 0.0
	var distance := bounds.get_longest_axis_size() + 10.0
	_camera.size = frame.size
	_camera.global_position = center - _rig.basis * Vector3.BACK * distance
	_camera.far = distance * 2.0


## Writes [param portrait]'s import settings, once: Godot adds its own lines to the file.
func _write_import_file(portrait: String) -> void:
	var path := portrait + ".import"
	if not FileAccess.file_exists(path):
		FileAccess.open(path, FileAccess.WRITE).store_string(IMPORT_FILE)
