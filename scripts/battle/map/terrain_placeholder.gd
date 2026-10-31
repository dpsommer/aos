class_name TerrainPlaceholder
extends RefCounted
## Stands in for terrain features until there are 3D models: a block the size of the feature's
## footprint, its height and colour by kind. A faction terrain feature is the size of its base
## (or its best-guess footprint). See docs/design/battle.md.

const AREA := preload("res://assets/3d/placeholders/p_terrain_area.tres")
const OBSCURING := preload("res://assets/3d/placeholders/p_terrain_obscuring.tres")
const PLACE_OF_POWER := preload("res://assets/3d/placeholders/p_terrain_place_of_power.tres")
const FACTION := preload("res://assets/3d/placeholders/p_terrain_faction.tres")

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


## [param feature]'s placeholder, with its name floating above it for faction and Spearhead
## features.
static func build(feature: BattleTerrain) -> Node3D:
	var root := Node3D.new()
	root.name = feature.name.validate_node_name() if not feature.name.is_empty() else "Terrain"
	var height := height_of(feature)
	var mesh_instance := MeshInstance3D.new()
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
	root.position = ModelPlaceholder.to_world(feature.position)
	root.rotation.y = ModelPlaceholder.yaw(feature.rotation)
	if feature.kind in [BattleTerrain.Kind.FACTION, BattleTerrain.Kind.SPEARHEAD]:
		root.add_child(ModelPlaceholder.label(feature.name, Vector3(0, height + 1.0, 0)))
	return root
