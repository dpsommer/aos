class_name BoardBuilder
extends RefCounted
## Builds the battlefield from a [Battle]: the board at tabletop size (1 Godot unit is 1"), each
## side's territory, roads and the objectives. Its origin is the battlefield's north-west corner,
## x east and z south. See docs/design/battle.md.

const BOARD := preload("res://assets/3d/placeholders/p_battlefield.tres")
const OBJECTIVE := preload("res://assets/3d/placeholders/p_objective.tres")
const OBJECTIVE_ZONE := preload("res://assets/3d/placeholders/p_objective_zone.tres")
const ROAD := preload("res://assets/3d/placeholders/p_road.tres")
const LINE := preload("res://assets/3d/placeholders/p_line.tres")
const TERRITORY_SHADER := preload("res://assets/shaders/p_territory.gdshader")

const BOARD_THICKNESS := 1.0
## Heights above the board that keep overlays from flickering into each other.
const ROAD_HEIGHT := 0.01
const TERRITORY_HEIGHT := 0.02
const ZONE_HEIGHT := 0.03
const OBJECTIVE_HEIGHT := 0.12
## Territory stripes and edges: [stripe, gap, edge] for each side.
const PLAYER_COLOURS := [Color(0.376, 0.62, 0.886, 0.22), Color(0.239, 0.455, 0.659, 0.08), Color(0.431, 0.667, 0.922)]
const OPPONENT_COLOURS := [Color(0.91, 0.408, 0.361, 0.2), Color(0.722, 0.267, 0.231, 0.08), Color(0.922, 0.431, 0.384)]
const OBJECTIVE_EDGE := Color("#F0C46A")


## The board: a slab [param size] wide and deep, its top at height 0.
static func board(size: Vector2) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, BOARD_THICKNESS, size.y)
	var result := MeshInstance3D.new()
	result.name = "Board"
	result.mesh = mesh
	result.material_override = BOARD
	result.position = Vector3(size.x / 2, -BOARD_THICKNESS / 2, size.y / 2)
	return result


## A side's territory: striped polygons with their edges outlined.
static func territory(polygons: Array[PackedVector2Array], is_player: bool) -> Node3D:
	var colours: Array = PLAYER_COLOURS if is_player else OPPONENT_COLOURS
	var root := Node3D.new()
	root.name = "PlayerTerritory" if is_player else "OpponentTerritory"
	var material := ShaderMaterial.new()
	material.shader = TERRITORY_SHADER
	material.set_shader_parameter("stripe_color", colours[0])
	material.set_shader_parameter("gap_color", colours[1])
	material.set_shader_parameter("speed", 0.5 if is_player else -0.5)
	for polygon in polygons:
		var fill := flat_polygon(polygon, TERRITORY_HEIGHT)
		if fill:
			fill.material_override = material
			root.add_child(fill)
		root.add_child(outline(polygon, TERRITORY_HEIGHT, colours[2]))
	return root


## The roads printed on a realm battlefield.
static func roads(polygons: Array[PackedVector2Array]) -> Node3D:
	var root := Node3D.new()
	root.name = "Roads"
	for polygon in polygons:
		var fill := flat_polygon(polygon, ROAD_HEIGHT)
		if fill:
			fill.material_override = ROAD
			root.add_child(fill)
	return root


## An objective: its marker, its zone (Matched Play's 3" control range, or a Spearhead objective
## itself) and its name.
static func objective(feature: MapFeature, radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Objective"
	root.position = ModelPlaceholder.to_world(feature.position)
	if feature.is_rectangle():
		var local := PackedVector2Array()
		for corner in feature.corners():
			local.append(corner - feature.position)
		var fill := flat_polygon(local, ZONE_HEIGHT)
		if fill:
			fill.material_override = OBJECTIVE_ZONE
			root.add_child(fill)
		root.add_child(outline(local, ZONE_HEIGHT, OBJECTIVE_EDGE))
	else:
		var zone := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.01
		disc.radial_segments = 64
		disc.rings = 1
		zone.mesh = disc
		zone.material_override = OBJECTIVE_ZONE
		zone.position.y = ZONE_HEIGHT
		root.add_child(zone)
		root.add_child(outline(circle(Vector2.ZERO, radius), ZONE_HEIGHT, OBJECTIVE_EDGE))
	var marker := MeshInstance3D.new()
	var coin := CylinderMesh.new()
	coin.top_radius = Battle.OBJECTIVE_MARKER / 2
	coin.bottom_radius = Battle.OBJECTIVE_MARKER / 2
	coin.height = OBJECTIVE_HEIGHT
	marker.mesh = coin
	marker.material_override = OBJECTIVE
	marker.position.y = OBJECTIVE_HEIGHT / 2
	root.add_child(marker)
	var name_label := ModelPlaceholder.label(feature.type, Vector3(0, 2.5, 0), 56)
	name_label.modulate = Color("#F8DFA2")
	name_label.visibility_range_end = 0.0
	root.add_child(name_label)
	return root


## [param polygon] (in inches) as a flat mesh at [param height], or null if it can't be filled.
static func flat_polygon(polygon: PackedVector2Array, height: float) -> MeshInstance3D:
	var indices := Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty():
		return null
	var vertices := PackedVector3Array()
	for point in polygon:
		vertices.append(ModelPlaceholder.to_world(point, height))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var result := MeshInstance3D.new()
	result.mesh = mesh
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result


## A closed line around [param polygon] at [param height].
static func outline(polygon: PackedVector2Array, height: float, colour: Color) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var colours := PackedColorArray()
	for i in polygon.size():
		vertices.append(ModelPlaceholder.to_world(polygon[i], height))
		vertices.append(ModelPlaceholder.to_world(polygon[(i + 1) % polygon.size()], height))
		colours.append(colour)
		colours.append(colour)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colours
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var result := MeshInstance3D.new()
	result.mesh = mesh
	result.material_override = LINE
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result


## Points around a circle, for outlining it.
static func circle(centre: Vector2, radius: float, segments := 64) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in segments:
		result.append(centre + Vector2.from_angle(TAU * i / segments) * radius)
	return result
