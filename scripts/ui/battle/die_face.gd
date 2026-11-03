class_name DieFace
extends Control
## A dice showing [member value] as pips, for the roll-off. While [member tumbling] it shows
## random faces and wobbles. See docs/design/battle.md.

## Where each face's pips go, as fractions of the face.
const PIPS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.3, 0.3), Vector2(0.7, 0.7)],
	3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
	4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	6: [Vector2(0.27, 0.25), Vector2(0.73, 0.25), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.75), Vector2(0.73, 0.75)],
}
const FACE := Color("#F4F0E6")
const EDGE := Color("#B4AD9E")
## How often a tumbling dice changes face, in seconds.
const TUMBLE_STEP := 0.08

var value := 1:
	set(to):
		value = clampi(to, 1, 6)
		queue_redraw()
var pip_colour := Color("#24527E")
var tumbling := false
var _since_change := 0.0


func _init(size_px: float, colour: Color) -> void:
	pip_colour = colour
	custom_minimum_size = Vector2(size_px, size_px)
	pivot_offset = Vector2(size_px, size_px) / 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not tumbling:
		rotation = 0.0
		return
	_since_change += delta
	if _since_change >= TUMBLE_STEP:
		_since_change = 0.0
		value = randi_range(1, 6)
		rotation = randf_range(-0.35, 0.35)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var face := StyleBoxFlat.new()
	face.bg_color = FACE
	face.set_corner_radius_all(int(size.x * 0.12))
	face.border_color = EDGE
	face.set_border_width_all(2)
	face.shadow_color = Color(0, 0, 0, 0.5)
	face.shadow_size = 8
	draw_style_box(face, rect)
	for pip: Vector2 in PIPS[value]:
		draw_circle(pip * size, size.x * 0.09, pip_colour, true, -1.0, true)
