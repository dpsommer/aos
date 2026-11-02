class_name TerrainPlaceholder
extends RefCounted
## Draws terrain features: a faction or Spearhead terrain feature's 3D model when [ModelLibrary]
## has one, and otherwise a block the size of the feature's footprint, its height and colour by
## kind. A faction terrain feature's block is the size of its base (or its best-guess footprint). A
## Spearhead feature's model is fitted to its footprint. See docs/design/battle.md.

const AREA := preload("res://assets/3d/placeholders/p_terrain_area.tres")
const OBSCURING := preload("res://assets/3d/placeholders/p_terrain_obscuring.tres")
const PLACE_OF_POWER := preload("res://assets/3d/placeholders/p_terrain_place_of_power.tres")
const FACTION := preload("res://assets/3d/placeholders/p_terrain_faction.tres")
const MODEL := preload("res://assets/3d/placeholders/p_model.tres")

## Height in inches by kind; Spearhead features by size.
const HEIGHTS := {
	BattleTerrain.Kind.AREA_OR_OBSTACLE: 0.75,
	BattleTerrain.Kind.OBSCURING: 3.0,
	BattleTerrain.Kind.PLACE_OF_POWER: 0.4,
	BattleTerrain.Kind.FACTION: 2.0,
}
const SPEARHEAD_HEIGHTS := {"small": 1.0, "large": 2.5}


static func height_of(feature: BattleTerrain) -> float:
	if feature.kind == BattleTerrain.Kind.SPEARHEAD:
		return SPEARHEAD_HEIGHTS.get(feature.size, SPEARHEAD_HEIGHTS.large)
	return HEIGHTS.get(feature.kind, 1.0)


static func material_of(feature: BattleTerrain) -> Material:
	match feature.kind:
		BattleTerrain.Kind.OBSCURING:
			return OBSCURING
		BattleTerrain.Kind.PLACE_OF_POWER:
			return PLACE_OF_POWER
		BattleTerrain.Kind.FACTION:
			return FACTION
	return AREA


## Whether the feature is drawn round: a Place of Power, or faction terrain on a round base.
static func is_round(feature: BattleTerrain) -> bool:
	return feature.kind == BattleTerrain.Kind.PLACE_OF_POWER or (feature.base != null and feature.base.shape != BaseSize.Shape.MODEL)


## Whether [param feature] is a faction or Spearhead feature, which can have a 3D model and a name
## label.
static func _has_model(feature: BattleTerrain) -> bool:
	return feature.kind in [BattleTerrain.Kind.FACTION, BattleTerrain.Kind.SPEARHEAD]


## The 3D model of a faction or Spearhead terrain feature, from [param library], or null. A
## feature with several models has its [member BattleTerrain.variant]'s.
static func model_of(feature: BattleTerrain, library: ModelLibrary) -> Mesh:
	if not _has_model(feature) or library == null:
		return null
	var names := PackedStringArray([feature.name])
	if feature.warscroll:
		names.append(feature.warscroll.name)
	var meshes := library.meshes_for(names)
	return meshes[posmod(feature.variant, meshes.size())] if not meshes.is_empty() else null


## [param feature]'s model or placeholder, with its name floating above it for faction and
## Spearhead features.
static func build(feature: BattleTerrain, library := ModelLibrary.shared()) -> Node3D:
	var root := Node3D.new()
	root.name = feature.name.validate_node_name() if not feature.name.is_empty() else "Terrain"
	var model := model_of(feature, library)
	var instance: MeshInstance3D
	if model == null:
		instance = _block_instance(feature, height_of(feature))
	elif feature.kind == BattleTerrain.Kind.SPEARHEAD:
		instance = _fitted_instance(model, feature.footprint)
	else:
		instance = _model_instance(model)
	var height := model.get_aabb().size.y * instance.scale.y if model else height_of(feature)
	root.add_child(instance)
	_place(root, feature, height)
	return root


## [param model] standing on the ground, its front (-Z) turned to face the way the feature does
## (+X), in [constant MODEL] if it has no materials of its own.
static func _model_instance(model: Mesh) -> MeshInstance3D:
	var instance := _mesh_instance(model)
	instance.rotation.y = -PI / 2
	instance.position.y = -model.get_aabb().position.y
	return instance


## [param model] fitted to [param footprint]: its longer side along the footprint's length (x),
## the middle of its bounds on the feature's centre, standing on the ground, and scaled evenly to
## fit inside the footprint, so it covers the ground the rules use. In [constant MODEL] if it has
## no materials of its own.
static func _fitted_instance(model: Mesh, footprint: Vector2) -> MeshInstance3D:
	var instance := _mesh_instance(model)
	var bounds := model.get_aabb()
	var along_z := bounds.size.z > bounds.size.x
	var length := maxf(bounds.size.x, bounds.size.z)
	var width := minf(bounds.size.x, bounds.size.z)
	var fit := 1.0
	if length > 0.0 and width > 0.0 and footprint.x > 0.0 and footprint.y > 0.0:
		fit = minf(footprint.x / length, footprint.y / width)
	# Turning -Z to +X lays a model that's long along z along the footprint's length.
	var basis := Basis(Vector3.UP, -PI / 2 if along_z else 0.0).scaled(Vector3.ONE * fit)
	var bottom := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	instance.transform = Transform3D(basis, -(basis * bottom))
	return instance


## [param model] in [constant MODEL] if it has no materials of its own.
static func _mesh_instance(model: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = model
	if not ModelLibrary.is_textured(model):
		instance.material_override = MODEL
	return instance


## The placeholder for [param feature]: a disc or block its footprint across and [param height]
## tall, in its kind's material.
static func _block_instance(feature: BattleTerrain, height: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	if is_round(feature):
		var disc := CylinderMesh.new()
		disc.top_radius = 0.5
		disc.bottom_radius = 0.5
		disc.height = 1.0
		instance.mesh = disc
	else:
		var block := BoxMesh.new()
		block.size = Vector3.ONE
		instance.mesh = block
	instance.material_override = material_of(feature)
	instance.scale = Vector3(feature.footprint.x, height, feature.footprint.y)
	instance.position.y = height / 2
	return instance


static func _place(root: Node3D, feature: BattleTerrain, height: float) -> void:
	root.position = ModelPlaceholder.to_world(feature.position)
	root.rotation.y = ModelPlaceholder.yaw(feature.rotation)
	if _has_model(feature):
		root.add_child(ModelPlaceholder.label(feature.name, Vector3(0, height + 1.0, 0)))
