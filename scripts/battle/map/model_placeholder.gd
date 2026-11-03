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
## How far a unit's name floats above its tallest model.
const LABEL_CLEARANCE := 0.75

const PLAYER_MATERIAL := preload("res://assets/3d/placeholders/p_base_player.tres")
const OPPONENT_MATERIAL := preload("res://assets/3d/placeholders/p_base_opponent.tres")
const PLAYER_MODEL_MATERIAL := preload("res://assets/3d/placeholders/p_model_player.tres")
const OPPONENT_MODEL_MATERIAL := preload("res://assets/3d/placeholders/p_model_opponent.tres")

## A model's ring while it's being placed: green where it can go, red where it can't, and blue
## where it can go while it's picked up.
const VALID_RING := Color("#8FD4B0")
const INVALID_RING := Color("#FF6B5B")
const HELD_RING := Color("#7FB2E8")
## How wide a terrain feature's outline is while it's being placed, in inches.
const OUTLINE_WIDTH := 0.3
## How far a ring stands out from its base, across, and how high it floats.
const RING_MARGIN := 0.25
const RING_HEIGHT := 0.2

static var _disc: CylinderMesh
static var _slab: BoxMesh
static var _ring: TorusMesh


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
	_add_bases(root, unit, facing, is_player)
	var tallest := _add_models(root, unit, facing, is_player, library)
	if not unit.positions.is_empty():
		var height := maxf(LABEL_HEIGHT, tallest + LABEL_CLEARANCE)
		var name_label := label(unit.name, to_world(_middle_of(unit.positions), height))
		name_label.name = "Label"
		root.add_child(name_label)
	return root


## Moves [param root]'s models, built by [method build_unit] for [param unit], to the unit's
## current positions and facing, without rebuilding them.
static func update_unit(root: Node3D, unit: BattleUnit) -> void:
	for child in root.get_children():
		if child is MultiMeshInstance3D and child.has_meta(&"indices"):
			var indices: PackedInt32Array = child.get_meta(&"indices")
			var multimesh: MultiMesh = child.multimesh
			for n in indices.size():
				var i := indices[n]
				if i >= unit.positions.size():
					continue
				if child.has_meta(&"model"):
					multimesh.set_instance_transform(n, model_transform(multimesh.mesh, unit.positions[i], unit.facing))
				else:
					multimesh.set_instance_transform(n, transform_of(unit.bases[i], unit.positions[i], unit.facing))
	var name_label := root.get_node_or_null("Label") as Label3D
	if name_label and not unit.positions.is_empty():
		name_label.position = to_world(_middle_of(unit.positions), name_label.position.y)


## Rings around [param unit]'s models in [param root] while it's being placed: green (blue while
## [param held]), or red for the models in [param invalid]. [param show] off removes them.
static func show_rings(root: Node3D, unit: BattleUnit, invalid: PackedInt32Array, show := true, held := false) -> void:
	var rings := root.get_node_or_null("Rings") as MultiMeshInstance3D
	if not show:
		if rings:
			rings.queue_free()
			root.remove_child(rings)
		return
	if rings == null:
		rings = MultiMeshInstance3D.new()
		rings.name = "Rings"
		rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rings.material_override = marker_material()
		rings.material_override.vertex_color_use_as_albedo = true
		root.add_child(rings)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = ring_mesh()
	multimesh.instance_count = unit.positions.size()
	for i in unit.positions.size():
		var footprint := unit.bases[i].footprint() + Vector2(RING_MARGIN, RING_MARGIN)
		var basis := Basis(Vector3.UP, yaw(unit.facing)).scaled_local(Vector3(footprint.x, 1.0, footprint.y))
		multimesh.set_instance_transform(i, Transform3D(basis, to_world(unit.positions[i], RING_HEIGHT)))
		multimesh.set_instance_color(i, INVALID_RING if i in invalid else ring_colour(true, held))
	rings.multimesh = multimesh


## The colour of something being placed: blue if it can go there while [param held], green if it
## can when set down, red if it can't.
static func ring_colour(valid: bool, held: bool) -> Color:
	if not valid:
		return INVALID_RING
	return HELD_RING if held else VALID_RING


## The material for a placement ring or outline: unshaded and drawn over everything, so it shows
## through the model or feature it marks.
static func marker_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 1
	return material


## A flat band [constant OUTLINE_WIDTH] wide just outside [param outline] (points around the
## origin, in inches), at [param height], for a terrain feature's outline while it's placed.
static func outline_mesh(outline: PackedVector2Array, height: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var count := outline.size()
	for i in count + 1:
		var point := outline[i % count]
		var out := point + point.normalized() * OUTLINE_WIDTH
		vertices.append(to_world(point, height))
		vertices.append(to_world(out, height))
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	return mesh


## A flat ring 1 wide, scaled per model.
static func ring_mesh() -> Mesh:
	if _ring == null:
		_ring = TorusMesh.new()
		_ring.inner_radius = 0.46
		_ring.outer_radius = 0.5
		_ring.rings = 32
		_ring.ring_segments = 4
	return _ring


## Adds [param unit]'s bases to [param root], one [MultiMeshInstance3D] per kind of base (shape
## and size).
static func _add_bases(root: Node3D, unit: BattleUnit, facing: float, is_player: bool) -> void:
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
		instance.set_meta(&"indices", PackedInt32Array(indices))
		instance.multimesh = multimesh
		instance.material_override = PLAYER_MATERIAL if is_player else OPPONENT_MATERIAL
		root.add_child(instance)


## The middle of [param positions] (not empty): their average.
static func _middle_of(positions: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for position in positions:
		sum += position
	return sum / positions.size()


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
		var indices := PackedInt32Array()
		for i in range(m, count, meshes.size()):
			multimesh.set_instance_transform(n, model_transform(mesh, unit.positions[i], facing))
			indices.append(i)
			n += 1
		var instance := MultiMeshInstance3D.new()
		instance.name = "Model%d" % (m + 1)
		instance.set_meta(&"indices", indices)
		instance.set_meta(&"model", true)
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
