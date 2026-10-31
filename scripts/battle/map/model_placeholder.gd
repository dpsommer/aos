class_name ModelPlaceholder
extends RefCounted
## Stands in for models until there are 3D models: each model is drawn as its base, a disc (round
## or oval) or, for a model with no base, a slab its best-guess footprint in size. One
## [MultiMeshInstance3D] per kind of base keeps big armies cheap. Units are inches: 1 Godot unit is
## 1". See docs/design/battle.md.

## A base's thickness: about 4mm.
const BASE_HEIGHT := 0.16
## How tall the slab is for a model with no base.
const MODEL_HEIGHT := 0.75
## How high a unit's name floats above it.
const LABEL_HEIGHT := 2.0

const PLAYER_MATERIAL := preload("res://assets/3d/placeholders/p_base_player.tres")
const OPPONENT_MATERIAL := preload("res://assets/3d/placeholders/p_base_opponent.tres")

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


## [param unit]'s models, one [MultiMeshInstance3D] per kind of base, and its name above them.
static func build_unit(unit: BattleUnit, facing: float, is_player: bool) -> Node3D:
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
	if not unit.positions.is_empty():
		var middle := Vector2.ZERO
		for position in unit.positions:
			middle += position
		root.add_child(label(unit.name, to_world(middle / unit.positions.size(), LABEL_HEIGHT)))
	return root


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
