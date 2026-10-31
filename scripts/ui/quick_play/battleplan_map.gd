class_name BattleplanMap
extends Control
## A battleplan's map, drawn from its data: the attacker's territory in red and the defender's in
## blue, the objectives as gold rings and, when [member detailed], the terrain features as dashed
## outlines and each objective's control zone.

const GROUND := Color("#2A2F38")
const ATTACKER := Color(0.722, 0.267, 0.231, 0.55)
const DEFENDER := Color(0.239, 0.455, 0.659, 0.6)
## Territories on a [member neutral] map: who is attacker isn't known yet.
const NEUTRAL_ATTACKER := Color(0.788, 0.8, 0.827, 0.28)
const NEUTRAL_DEFENDER := Color(0.788, 0.8, 0.827, 0.12)
const OBJECTIVE := Color("#F0C46A")
const TERRAIN := Color(0.925, 0.906, 0.863, 0.55)
## Units within this many inches of an objective contest it.
const CONTROL_RANGE := 3.0
## An objective's diameter in pixels on a map that isn't [member detailed].
const SMALL_OBJECTIVE := 7.0

var battleplan: Battleplan
## The battlefield's width and depth in inches.
var battlefield := Vector2(60, 44)
## Whether to draw the terrain and the objectives' control zones. A detailed map is as wide as its
## container, and as tall as the battlefield's shape makes it.
var detailed := false
## Whether to shade the territories grey instead of red and blue, before the roll-off decides
## who is the attacker.
var neutral := false


func _init(plan: Battleplan, battlefield_size: Vector2, show_detail := false) -> void:
	battleplan = plan
	if battlefield_size.x > 0 and battlefield_size.y > 0:
		battlefield = battlefield_size
	detailed = show_detail
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	accessibility_name = "Map of %s" % plan.name
	if detailed:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resized.connect(_fit_height)
	else:
		custom_minimum_size = Vector2(96, 70)


func _fit_height() -> void:
	custom_minimum_size.y = roundf(size.x * battlefield.y / battlefield.x)


## Where [param inches] on the battlefield is on the map.
func to_map(inches: Vector2) -> Vector2:
	return inches * size / battlefield


func _draw() -> void:
	draw_style_box(UITheme.box(GROUND, UITheme.CONTROL_BORDER, 4), Rect2(Vector2.ZERO, size))
	for area in battleplan.attacker_territory:
		draw_rect(Rect2(to_map(area.position), to_map(area.size)), NEUTRAL_ATTACKER if neutral else ATTACKER)
	for area in battleplan.defender_territory:
		draw_rect(Rect2(to_map(area.position), to_map(area.size)), NEUTRAL_DEFENDER if neutral else DEFENDER)
	if detailed:
		for feature in battleplan.terrain:
			var width: float = MapFeature.TERRAIN_WIDTHS.get(feature.size, MapFeature.TERRAIN_WIDTHS.medium)
			_dashed_rect(Rect2(to_map(feature.position - Vector2(width, width) / 2), to_map(Vector2(width, width))))
	var radius := to_map(Vector2(CONTROL_RANGE, 0)).x if detailed else SMALL_OBJECTIVE / 2
	for objective in battleplan.objectives:
		var centre := to_map(objective.position)
		draw_circle(centre, radius, Color(OBJECTIVE, 0.25))
		draw_arc(centre, radius - 1, 0, TAU, 32, OBJECTIVE, 2, true)


func _dashed_rect(rect: Rect2) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], TERRAIN, 1.5, 4)
