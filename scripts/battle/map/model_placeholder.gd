class_name ModelPlaceholder
extends RefCounted
## Draws each unit's models: each model's base, a disc (round or oval) or, for a model with no base,
## a slab its best-guess footprint in size, and standing on it the unit's 3D model when
## [ModelLibrary] has one. One [MultiMeshInstance3D] per kind of base and per model mesh keeps big
## armies cheap. Units are inches: 1 Godot unit is 1". See docs/design/battle.md.

## A base's thickness: about 4mm.
const BASE_HEIGHT := 0.16
## How tall the slab is for a model with no base.
const MODEL_HEIGHT := 0.75
## How high a unit's name floats above it.
const LABEL_HEIGHT := 2.0

const PLAYER_MATERIAL := preload("res://assets/3d/placeholders/p_base_player.tres")
const OPPONENT_MATERIAL := preload("res://assets/3d/placeholders/p_base_opponent.tres")
const PLAYER_MODEL_MATERIAL := preload("res://assets/3d/placeholders/p_model_player.tres")
const OPPONENT_MODEL_MATERIAL := preload("res://assets/3d/placeholders/p_model_opponent.tres")
## How far a unit's name floats above its tallest model.
const LABEL_CLEARANCE := 0.75

static var _disc: CylinderMesh
static var _slab: BoxMesh


## A point on the battlefield, in inches from its north-west corner, as a position in the world.
static func to_world(inches: Vector2, height := 0.0) -> Vector3:
	return Vector3(inches.x, height, inches.y)


## The turn about the vertical axis that points a mesh's +X along [param angle] (radians clockwise
## from east on the battlefield).
static func yaw(angle: float) -> float:
	return -angle


## The size of [param base]'s placeholder: its footprint across, its height up.
static func size_of(base: BaseSize) -> Vector3:
	var footprint := base.footprint()
	return Vector3(footprint.x, MODEL_HEIGHT if base.shape == BaseSize.Shape.MODEL else BASE_HEIGHT, footprint.y)


## The mesh for [param base]: a unit disc or slab, scaled per model by [method transform_of].
static func mesh_of(base: BaseSize) -> Mesh:
	if base.shape == BaseSize.Shape.MODEL:
		if _slab == null:
			_slab = BoxMesh.new()
			_slab.size = Vector3.ONE
		return _slab
	if _disc == null:
		_disc = CylinderMesh.new()
		_disc.top_radius = 0.5
		_disc.bottom_radius = 0.5
		_disc.height = 1.0
		_disc.radial_segments = 32
		_disc.rings = 1
	return _disc


## Where a model on [param base] at [param inches], facing [param facing], goes: sized, turned and
## standing on the battlefield.
static func transform_of(base: BaseSize, inches: Vector2, facing: float) -> Transform3D:
	var size := size_of(base)
	var basis := Basis(Vector3.UP, yaw(facing)).scaled_local(size)
	return Transform3D(basis, to_world(inches, size.y / 2))


## Where a model's [param mesh] goes for a model at [param inches], facing [param facing]: its
## origin, the middle of its own base, over the model's position, its lowest point on top of the
## base, and its front (-Z, as the model files have it) turned to [param facing].
static func model_transform(mesh: Mesh, inches: Vector2, facing: float) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw(facing) - PI / 2)
	return Transform3D(basis, to_world(inches, BASE_HEIGHT - mesh.get_aabb().position.y))


## The names [param unit]'s 3D model can go by: the unit's own, then its warscroll's.
static func model_names(unit: BattleUnit) -> PackedStringArray:
	var names := PackedStringArray([unit.name])
	if unit.warscroll and unit.warscroll.name != unit.name:
		names.append(unit.warscroll.name)
	return names


## [param unit]'s models, one [MultiMeshInstance3D] per kind of base and per model mesh from
## [param library], and its name above them. A unit with several model meshes gives them to its
## models in turn.
static func build_unit(unit: BattleUnit, facing: float, is_player: bool, library := ModelLibrary.shared()) -> Node3D:
	var root := Node3D.new()
	root.name = _node_name(unit.name)
	var kinds := {}
	for i in mini(unit.bases.size(), unit.positions.size()):
		var key := "%d:%s" % [unit.bases[i].shape, unit.bases[i].footprint()]
		if not kinds.has(key):
			kinds[key] = []
		kinds[key].append(i)
	for key: String in kinds:
		var indices: Array = kinds[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh_of(unit.bases[indices[0]])
		multimesh.instance_count = indices.size()
		for n in indices.size():
			var i: int = indices[n]
			multimesh.set_instance_transform(n, transform_of(unit.bases[i], unit.positions[i], facing))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = PLAYER_MATERIAL if is_player else OPPONENT_MATERIAL
		root.add_child(instance)
	var tallest := _add_models(root, unit, facing, is_player, library)
	if not unit.positions.is_empty():
		var middle := Vector2.ZERO
		for position in unit.positions:
			middle += position
		var height := maxf(LABEL_HEIGHT, tallest + LABEL_CLEARANCE)
		root.add_child(label(unit.name, to_world(middle / unit.positions.size(), height)))
	return root


## Adds [param unit]'s 3D models to [param root], one [MultiMeshInstance3D] per mesh, and returns
## how high the tallest stands (0 with no models).
static func _add_models(root: Node3D, unit: BattleUnit, facing: float, is_player: bool, library: ModelLibrary) -> float:
	if library == null:
		return 0.0
	var meshes := library.meshes_for(model_names(unit))
	if meshes.is_empty():
		return 0.0
	var count := mini(unit.bases.size(), unit.positions.size())
	var tallest := 0.0
	for m in mini(meshes.size(), count):
		var mesh := meshes[m]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		@warning_ignore("integer_division")
		multimesh.instance_count = (count - m + meshes.size() - 1) / meshes.size()
		var n := 0
		for i in range(m, count, meshes.size()):
			multimesh.set_instance_transform(n, model_transform(mesh, unit.positions[i], facing))
			n += 1
		var instance := MultiMeshInstance3D.new()
		instance.name = "Model%d" % (m + 1)
		instance.multimesh = multimesh
		if not ModelLibrary.is_textured(mesh):
			instance.material_override = PLAYER_MODEL_MATERIAL if is_player else OPPONENT_MODEL_MATERIAL
		root.add_child(instance)
		tallest = maxf(tallest, BASE_HEIGHT + mesh.get_aabb().size.y)
	return tallest


## A name that floats over the battlefield, facing the camera, hidden from far away.
static func label(text: String, at: Vector3, font_size := 48) -> Label3D:
	var result := Label3D.new()
	result.text = text
	result.position = at
	result.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	result.pixel_size = 0.01
	result.font_size = font_size
	result.outline_size = 12
	result.modulate = UITheme.TEXT
	result.outline_modulate = Color(0.047, 0.051, 0.063, 0.9)
	result.no_depth_test = false
	result.visibility_range_end = 40.0
	return result


static func _node_name(text: String) -> String:
	return text.validate_node_name() if not text.is_empty() else "Unit"
