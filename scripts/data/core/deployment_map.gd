class_name DeploymentMap
extends Resource
## A Spearhead deployment map: the battlefield split into territories A and B. The defender picks
## the map and which territory is theirs.

@export var name: String
## Corners of territory A in order, in inches from the battlefield's north-west corner.
@export var territory_a: PackedVector2Array
@export var territory_b: PackedVector2Array


## Whether [param point] is in territory A, edges included.
func in_territory_a(point: Vector2) -> bool:
	return _contains(territory_a, point)


## Whether [param point] is in territory B, edges included.
func in_territory_b(point: Vector2) -> bool:
	return _contains(territory_b, point)


func _contains(polygon: PackedVector2Array, point: Vector2) -> bool:
	if Geometry2D.is_point_in_polygon(point, polygon):
		return true
	for i in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])
		if closest.is_equal_approx(point):
			return true
	return false
