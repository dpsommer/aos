class_name TerrainPlaceholder
extends RefCounted
## Draws terrain features: a faction terrain feature's 3D model when [ModelLibrary] has one, and
## otherwise a block the size of the feature's footprint, its height and colour by kind. A faction
## terrain feature's block is the size of its base (or its best-guess footprint). See
## docs/design/battle.md.

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


## The 3D model of a faction terrain feature, from [param library], or null.
static func model_of(feature: BattleTerrain, library: ModelLibrary) -> Mesh:
	if feature.kind != BattleTerrain.Kind.FACTION or library == null:
		return null
	var names := PackedStringArray([feature.name])
	if feature.warscroll:
		names.append(feature.warscroll.name)
	var meshes := library.meshes_for(names)
	return meshes[0] if not meshes.is_empty() else null


## [param feature]'s model or placeholder, with its name floating above it for faction and
## Spearhead features.
static func build(feature: BattleTerrain, library := ModelLibrary.shared()) -> Node3D:
	var root := Node3D.new()
	root.name = feature.name.validate_node_name() if not feature.name.is_empty() else "Terrain"
	var height := height_of(feature)
	var mesh_instance := MeshInstance3D.new()
	var model := model_of(feature, library)
	if model:
		mesh_instance.mesh = model
		if not ModelLibrary.is_textured(model):
			mesh_instance.material_override = MODEL
		mesh_instance.rotation.y = -PI / 2
		mesh_instance.position.y = -model.get_aabb().position.y
		height = model.get_aabb().size.y
		root.add_child(mesh_instance)
		_place(root, feature, height)
		return root
	if is_round(feature):
		var disc := CylinderMesh.new()
		disc.top_radius = 0.5
		disc.bottom_radius = 0.5
		disc.height = 1.0
		mesh_instance.mesh = disc
	else:
		var block := BoxMesh.new()
		block.size = Vector3.ONE
		mesh_instance.mesh = block
	mesh_instance.material_override = material_of(feature)
	mesh_instance.scale = Vector3(feature.footprint.x, height, feature.footprint.y)
	mesh_instance.position.y = height / 2
	root.add_child(mesh_instance)
	_place(root, feature, height)
	return root


static func _place(root: Node3D, feature: BattleTerrain, height: float) -> void:
	root.position = ModelPlaceholder.to_world(feature.position)
	root.rotation.y = ModelPlaceholder.yaw(feature.rotation)
	if feature.kind in [BattleTerrain.Kind.FACTION, BattleTerrain.Kind.SPEARHEAD]:
		root.add_child(ModelPlaceholder.label(feature.name, Vector3(0, height + 1.0, 0)))
