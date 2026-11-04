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

## The realm battlefields' boards, from the Spearhead mod (see docs/technical/models.md), each
## named for its realm as a slug, e.g. [code]ashen_bastion.jpg[/code].
const BOARDS := "res://assets/3d/boards"

const BOARD_THICKNESS := 1.0
## The printed board lies just above the slab's top, under the overlays.
const PRINT_HEIGHT := 0.004
## Heights above the board that keep overlays from flickering into each other.
const ROAD_HEIGHT := 0.01
const TERRITORY_HEIGHT := 0.02
const ZONE_HEIGHT := 0.03
const OBJECTIVE_HEIGHT := 0.12
const NO_DEPLOY_HEIGHT := 0.025
## The shading over territory too close to the enemy to deploy in.
const NO_DEPLOY := Color(0.047, 0.051, 0.063, 0.5)
const NO_DEPLOY_EDGE := Color(0.961, 0.647, 0.557, 0.8)
## Territory stripes and edges: [stripe, gap, edge] for each side.
const PLAYER_COLOURS := [Color(0.376, 0.62, 0.886, 0.11), Color(0.239, 0.455, 0.659, 0.04), Color(0.431, 0.667, 0.922, 0.5)]
const OPPONENT_COLOURS := [Color(0.91, 0.408, 0.361, 0.1), Color(0.722, 0.267, 0.231, 0.04), Color(0.922, 0.431, 0.384, 0.5)]
const OBJECTIVE_EDGE := Color("#F0C46A")


## The board: a slab [param size] wide and deep, its top at height 0, with [param printed] (a realm
## battlefield's printed board, north at the top of the image) stretched over its top if given.
static func board(size: Vector2, printed: Texture2D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, BOARD_THICKNESS, size.y)
	var result := MeshInstance3D.new()
	result.name = "Board"
	result.mesh = mesh
	result.material_override = BOARD
	result.position = Vector3(size.x / 2, -BOARD_THICKNESS / 2, size.y / 2)
	if printed:
		result.add_child(_print(size, printed))
	return result


## [param printed] on a plane [param size] across, lying on top of the board's slab.
static func _print(size: Vector2, printed: Texture2D) -> MeshInstance3D:
	var top := MeshInstance3D.new()
	top.name = "Print"
	var plane := PlaneMesh.new()
	plane.size = size
	top.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_texture = printed
	material.roughness = 0.95
	top.material_override = material
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top.position.y = BOARD_THICKNESS / 2 + PRINT_HEIGHT
	return top


## The printed board of the realm battlefield [param realm_name], e.g. "Aqshy", from the folder
## [param root], or null if there's none (or it's a Git LFS pointer that didn't import).
static func board_print(realm_name: String, root := BOARDS) -> Texture2D:
	if realm_name.is_empty():
		return null
	var path := root.path_join(ModelLibrary.slug(realm_name) + ".jpg")
	if not ResourceLoader.exists(path) or not ModelLibrary.is_imported(path):
		return null
	return load(path) as Texture2D


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


## The part of a side's territory its units can't be set up in (too close to enemy territory),
## shaded dark: [param own] territory less the deployable [param zone], plus the parts of
## [param own] inside [param blocked] (e.g. too close to other terrain features).
## [param facing] is the way the side faces (radians clockwise from east): the label reads the right
## way up from behind it.
## [param text] labels each part, e.g. "Within 9\" of enemy territory"; empty leaves them unlabelled.
static func no_deploy(own: Array[PackedVector2Array], zone: Array[PackedVector2Array], text := "Too close to the enemy",
		facing := -PI / 2, blocked: Array[PackedVector2Array] = []) -> Node3D:
	var root := Node3D.new()
	root.name = "NoDeploy"
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = NO_DEPLOY
	var pieces: Array[PackedVector2Array] = []
	for polygon in own:
		pieces.append_array(_clip_all(polygon, zone))
		for area in blocked:
			pieces.append_array(Geometry2D.intersect_polygons(polygon, area))
	if not blocked.is_empty():
		pieces = _union(pieces)
	for piece in pieces:
		var fill := flat_polygon(piece, NO_DEPLOY_HEIGHT)
		if fill == null:
			continue
		fill.material_override = material
		root.add_child(fill)
		root.add_child(outline(piece, NO_DEPLOY_HEIGHT, NO_DEPLOY_EDGE))
		if not text.is_empty():
			root.add_child(_no_deploy_label(piece, text, facing))
	return root


## [param polygons] merged where they overlap, so overlaps aren't shaded twice. A hole left inside a
## merged polygon is filled in.
static func _union(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for polygon in polygons:
		var current := polygon
		var merged := true
		while merged:
			merged = false
			for i in result.size():
				var outers := _outers(Geometry2D.merge_polygons(current, result[i]))
				if outers.size() == 1:
					current = outers[0]
					result.remove_at(i)
					merged = true
					break
		result.append(current)
	return result


## [param polygons] less those inside another: the holes Geometry2D returns alongside outlines.
static func _outers(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for polygon in polygons:
		var hole := false
		for other in polygons:
			if other != polygon and Geometry2D.is_point_in_polygon(polygon[0], other):
				hole = true
				break
		if not hole:
			result.append(polygon)
	return result


## What's left of [param polygon] once each of [param cuts] is taken out of it.
static func _clip_all(polygon: PackedVector2Array, cuts: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [polygon]
	for cut in cuts:
		var next: Array[PackedVector2Array] = []
		for piece in pieces:
			next.append_array(Geometry2D.clip_polygons(piece, cut))
		pieces = next
	return pieces


## [param text] lying flat in the middle of [param piece], its top towards the enemy.
static func _no_deploy_label(piece: PackedVector2Array, text: String, facing: float) -> Label3D:
	var middle := Vector2.ZERO
	for point in piece:
		middle += point
	var label := ModelPlaceholder.label(text, ModelPlaceholder.to_world(middle / piece.size(), 0.5), 110)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.rotation = Vector3(-PI / 2, -(facing + PI / 2), 0)
	label.modulate = NO_DEPLOY_EDGE
	return label


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
## itself) and its name, shown while hovered.
static func objective(feature: MapFeature, radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Objective"
	root.position = ModelPlaceholder.to_world(feature.position)
	if feature.is_rectangle():
		_add_rectangle_zone(root, feature)
	else:
		_add_round_zone(root, radius)
	root.add_child(_objective_marker())
	var name_label := ModelPlaceholder.hover_label(feature.type, Vector3(0, 2.5, 0), 56)
	name_label.modulate = Color("#F8DFA2")
	root.add_child(name_label)
	return root


## A rectangular objective's zone, filled and outlined, relative to its centre.
static func _add_rectangle_zone(root: Node3D, feature: MapFeature) -> void:
	var local := PackedVector2Array()
	for corner in feature.corners():
		local.append(corner - feature.position)
	var fill := flat_polygon(local, ZONE_HEIGHT)
	if fill:
		fill.material_override = OBJECTIVE_ZONE
		root.add_child(fill)
	root.add_child(outline(local, ZONE_HEIGHT, OBJECTIVE_EDGE))


## A round objective zone [param radius] across from its centre, filled and outlined.
static func _add_round_zone(root: Node3D, radius: float) -> void:
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


## The objective marker: a coin standing on the board.
static func _objective_marker() -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var coin := CylinderMesh.new()
	coin.top_radius = Battle.OBJECTIVE_MARKER / 2
	coin.bottom_radius = Battle.OBJECTIVE_MARKER / 2
	coin.height = OBJECTIVE_HEIGHT
	marker.mesh = coin
	marker.material_override = OBJECTIVE
	marker.position.y = OBJECTIVE_HEIGHT / 2
	return marker


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
