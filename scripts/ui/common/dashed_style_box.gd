@tool
class_name DashedStyleBox
extends StyleBox
## A rounded box with a dashed border, e.g. for an empty slot waiting to be filled.

@export var bg_color := Color.TRANSPARENT
@export var border_color := Color.WHITE
@export var border_width := 1.0
@export var corner_radius := 8.0
@export var dash := 6.0
@export var gap := 4.0

## Points per rounded corner.
const CORNER_STEPS := 6


func _init(border := Color.WHITE, radius := 8.0, padding := 0, width := 1.0) -> void:
	border_color = border
	corner_radius = radius
	border_width = width
	set_content_margin_all(padding)


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var inset := rect.grow(-border_width / 2.0)
	var outline := outline_points(inset, minf(corner_radius, minf(inset.size.x, inset.size.y) / 2.0))
	if bg_color.a > 0:
		RenderingServer.canvas_item_add_polygon(to_canvas_item, outline, [bg_color])
	for segment in dashes(outline, dash, gap):
		RenderingServer.canvas_item_add_polyline(to_canvas_item, segment, [border_color], border_width, true)


## The points around [param rect]'s rounded outline, clockwise from the top-left corner's end.
static func outline_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners := [
		[Vector2(rect.end.x - radius, rect.position.y + radius), -PI / 2],
		[rect.end - Vector2(radius, radius), 0.0],
		[Vector2(rect.position.x + radius, rect.end.y - radius), PI / 2],
		[rect.position + Vector2(radius, radius), PI],
	]
	for corner: Array in corners:
		for step in CORNER_STEPS + 1:
			var angle: float = corner[1] + PI / 2 * step / CORNER_STEPS
			points.append(corner[0] + Vector2(cos(angle), sin(angle)) * radius)
	return points


## The closed [param outline] cut into dashes [param dash] long with [param gap] between them, each
## a polyline that follows the outline round corners.
static func dashes(outline: PackedVector2Array, dash: float, gap: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if outline.size() < 2 or dash <= 0:
		return result
	var current := PackedVector2Array()
	var drawing := true
	var left := dash
	for i in outline.size():
		var from := outline[i]
		var to := outline[(i + 1) % outline.size()]
		if drawing and current.is_empty():
			current.append(from)
		var length := from.distance_to(to)
		var done := 0.0
		while length - done > left:
			done += left
			var point := from.lerp(to, done / length)
			if drawing:
				current.append(point)
				result.append(current)
				current = PackedVector2Array()
			else:
				current.append(point)
			drawing = not drawing
			left = dash if drawing else gap
		left -= length - done
		if drawing:
			current.append(to)
	if current.size() > 1:
		result.append(current)
	return result
