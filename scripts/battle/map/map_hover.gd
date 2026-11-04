class_name MapHover
extends Node
## Shows the name of what the mouse is over on the battlefield: a unit, a terrain feature or an
## objective. Their names ([method ModelPlaceholder.hover_label]) are otherwise hidden. Runs every
## frame, as the camera can move what's under a mouse that stays still. See docs/design/battle.md.

var _camera: BattleCamera
## The nodes whose children can be hovered, each child a thing on the battlefield.
var _groups: Array[Node3D]
var _shown: Label3D


func _init(camera: BattleCamera, groups: Array[Node3D]) -> void:
	name = "MapHover"
	_camera = camera
	_groups = groups


func _process(_delta: float) -> void:
	var viewport := get_viewport()
	_show(null if viewport.gui_get_hovered_control() else label_at(viewport.get_mouse_position()))


## The name to show for [param screen_position]: that of the nearest thing there, or null if there's
## nothing there or the nearest thing has no name.
func label_at(screen_position: Vector2) -> Label3D:
	var from := _camera.camera.project_ray_origin(screen_position)
	var direction := _camera.camera.project_ray_normal(screen_position)
	var nearest := INF
	var result: Label3D = null
	for group in _groups:
		for root: Node3D in group.get_children():
			var distance := hit_distance(root, from, direction)
			if distance < nearest:
				nearest = distance
				result = root.get_node_or_null(ModelPlaceholder.HOVER_LABEL) as Label3D
	return result


## How far along the ray from [param from] the nearest of [param root]'s meshes and models is, or
## [constant @GDScript.INF] if the ray misses them all. Each is tested as its bounding box.
static func hit_distance(root: Node3D, from: Vector3, direction: Vector3) -> float:
	var nearest := INF
	for child in root.get_children():
		if child is MeshInstance3D and child.is_visible_in_tree() and child.mesh:
			nearest = minf(nearest, _box_distance(child.global_transform, child.mesh.get_aabb(), from, direction))
		# Only bases and models have indices: a unit's placement rings don't count as the unit.
		elif child is MultiMeshInstance3D and child.is_visible_in_tree() and child.has_meta(&"indices"):
			var multimesh: MultiMesh = child.multimesh
			var bounds := multimesh.mesh.get_aabb()
			for n in multimesh.instance_count:
				var placed: Transform3D = child.global_transform * multimesh.get_instance_transform(n)
				nearest = minf(nearest, _box_distance(placed, bounds, from, direction))
	return nearest


## How far along the ray the box [param bounds], placed by [param placed], is. The ray is tested in
## the box's own space, so a turned box is tested as turned.
static func _box_distance(placed: Transform3D, bounds: AABB, from: Vector3, direction: Vector3) -> float:
	var local := placed.affine_inverse()
	var hit: Variant = bounds.intersects_ray(local * from, local.basis * direction)
	return from.distance_to(placed * (hit as Vector3)) if hit != null else INF


func _show(label: Label3D) -> void:
	if label == _shown:
		return
	# What was shown goes when the realm's redrawn or a unit is taken back.
	if is_instance_valid(_shown):
		_shown.visible = false
	_shown = label
	if label:
		label.visible = true
