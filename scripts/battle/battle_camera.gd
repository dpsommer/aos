class_name BattleCamera
extends Node3D
## The battlefield camera: it orbits a point on the board. The camera keys or a right-button drag
## move that point, Q/E or a middle-button drag turn the view, and the wheel zooms. It can't leave
## the battlefield. Distances are in inches. See docs/design/battle.md.

const MIN_DISTANCE := 6.0
const MAX_DISTANCE := 90.0
const MIN_PITCH := deg_to_rad(20.0)
const MAX_PITCH := deg_to_rad(85.0)
## Keyboard panning, in screen heights' worth of board per second.
const PAN_SPEED := 0.9
## Keyboard turning, in radians per second.
const TURN_SPEED := 1.6
## Mouse turning, in radians per pixel dragged.
const DRAG_TURN := 0.008
const ZOOM_STEP := 1.12

## The area the target point stays in: the battlefield, in inches.
var bounds := Rect2(0, 0, 60, 44)
## The point on the board the camera looks at.
var target := Vector3.ZERO
## Turn about the vertical axis, in radians.
var yaw := 0.0
## Angle down from the horizon, in radians.
var pitch := deg_to_rad(55.0)
var distance := 40.0

var camera: Camera3D
var _dragging := MOUSE_BUTTON_NONE


func _init() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 50.0
	camera.near = 0.1
	camera.far = 1000.0
	add_child(camera)


func _ready() -> void:
	_apply()


## Frames [param area] (inches) from the side facing [param facing], the way an army faces.
func frame(area: Rect2, facing: float) -> void:
	target = ModelPlaceholder.to_world(area.get_center())
	# Look the way the army faces: from behind it, towards the enemy.
	yaw = -facing - PI / 2
	distance = clampf(maxf(area.size.x, area.size.y) * 1.3, MIN_DISTANCE, MAX_DISTANCE)
	_clamp()
	_apply()


## Moves the target by [param amount] in view terms: x right, y forward, in inches.
func pan(amount: Vector2) -> void:
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	target += right * amount.x + forward * amount.y
	_clamp()
	_apply()


## Turns the view by [param yaw_amount] about the target and tilts it by [param pitch_amount].
func turn(yaw_amount: float, pitch_amount := 0.0) -> void:
	yaw = wrapf(yaw + yaw_amount, -PI, PI)
	pitch = clampf(pitch + pitch_amount, MIN_PITCH, MAX_PITCH)
	_apply()


## Zooms by [param steps]: positive closer, negative further away.
func zoom(steps: float) -> void:
	distance = clampf(distance / pow(ZOOM_STEP, steps), MIN_DISTANCE, MAX_DISTANCE)
	_apply()


func _process(delta: float) -> void:
	var move := Vector2(Input.get_axis("camera_left", "camera_right"), Input.get_axis("camera_back", "camera_forward"))
	if move != Vector2.ZERO:
		pan(move * PAN_SPEED * distance * delta)
	var spin := Input.get_axis("camera_rotate_left", "camera_rotate_right")
	if spin != 0.0:
		turn(spin * TURN_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom(1.0 * event.factor if event.factor > 0 else 1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom(-1.0 * event.factor if event.factor > 0 else -1.0)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_dragging = event.button_index if event.pressed else MOUSE_BUTTON_NONE
	elif event is InputEventMouseMotion and _dragging != MOUSE_BUTTON_NONE:
		if _dragging == MOUSE_BUTTON_RIGHT:
			var viewport_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
			var inches_per_pixel := 2.0 * distance * tan(deg_to_rad(camera.fov) / 2) / viewport_height
			pan(Vector2(-event.relative.x, event.relative.y) * inches_per_pixel)
		else:
			turn(-event.relative.x * DRAG_TURN, event.relative.y * DRAG_TURN)


func _clamp() -> void:
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.z = clampf(target.z, bounds.position.y, bounds.end.y)
	target.y = 0.0


func _apply() -> void:
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.transform = Transform3D(Basis.looking_at(-offset, Vector3.UP), target + offset)
