class_name RealmMap
extends Control
## One side of a Spearhead realm battlefield, drawn from its data: the roads printed on it, the
## objectives as gold circles or rectangles and the terrain features set up before the players'
## as dashed squares. With a [member deployment] map, its territories are shaded, A lighter than B,
## and marked "A" and "B", as the defender chooses which is theirs. A [member detailed] map names the objectives.

## Territory A's and B's shading, and the line between them.
const TERRITORY_A := Color(0.925, 0.906, 0.863, 0.3)
const TERRITORY_B := Color(0.0, 0.0, 0.0, 0.25)
const TERRITORY_EDGE := Color(0.925, 0.906, 0.863, 0.8)
const ROAD := Color(0.663, 0.678, 0.714, 0.22)
const NAME_FONT_SIZE := 11

var battlepack: SpearheadBattlepack
var realm: RealmBattlefield
## The deployment map whose territories are shaded, or null for none.
var deployment: DeploymentMap
## Whether to name the objectives. A detailed map is as wide as its container, and as tall as the
## battlefield's shape makes it.
var detailed := false


func _init(pack: SpearheadBattlepack, side: RealmBattlefield, show_detail := false, deployment_map: DeploymentMap = null) -> void:
	battlepack = pack
	realm = side
	detailed = show_detail
	deployment = deployment_map
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	accessibility_name = "Map of %s" % side.name + (", %s deployment" % deployment_map.name if deployment_map else "")
	if detailed:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resized.connect(_fit_height)
	else:
		custom_minimum_size = Vector2(96, 70)


## The battlefield's width and depth in inches.
func battlefield() -> Vector2:
	var area := battlepack.battlefield_size
	return area if area.x > 0 and area.y > 0 else Vector2(30, 22)


func _fit_height() -> void:
	custom_minimum_size.y = roundf(size.x * battlefield().y / battlefield().x)


## Where [param inches] on the battlefield is on the map.
func to_map(inches: Vector2) -> Vector2:
	return inches * size / battlefield()


func _polygon(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(to_map(point))
	return result


func _draw() -> void:
	draw_style_box(UITheme.box(BattleplanMap.GROUND, UITheme.CONTROL_BORDER, 4), Rect2(Vector2.ZERO, size))
	if deployment:
		_fill(_polygon(deployment.territory_a), TERRITORY_A)
		_fill(_polygon(deployment.territory_b), TERRITORY_B)
	for road in realm.roads:
		_fill(_polygon(road), ROAD)
	if deployment:
		var a := _polygon(deployment.territory_a)
		if a.size() >= 2:
			draw_polyline(a + PackedVector2Array([a[0]]), TERRITORY_EDGE, 1.5, true)
	for feature in realm.terrain:
		var terrain := battlepack.get_terrain_feature(feature.type)
		var footprint: Vector2 = terrain.footprint() if terrain else SpearheadTerrain.FOOTPRINTS.large
		BattleplanMap.dashed_rect(self, Rect2(to_map(feature.position - footprint / 2), to_map(footprint)))
	for objective in realm.objectives:
		_draw_objective(objective)
	if detailed:
		for objective in realm.objectives:
			_draw_name(objective)
	if deployment:
		_draw_territory_letter("A", deployment.territory_a)
		_draw_territory_letter("B", deployment.territory_b)


## Writes [param letter] in the middle of the territory [param points], sized to the map.
func _draw_territory_letter(letter: String, points: PackedVector2Array) -> void:
	if points.is_empty():
		return
	var middle := Vector2.ZERO
	for point in points:
		middle += point
	middle = to_map(middle / points.size())
	var font := get_theme_default_font()
	var font_size := clampi(roundi(size.y / 7), 10, 48)
	var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var at := middle + Vector2(-text_size.x / 2, font.get_ascent(font_size) / 2 - 1)
	draw_string_outline(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(font_size / 6, 2), BattleplanMap.GROUND)
	draw_string(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UITheme.TEXT)


func _draw_objective(objective: MapFeature) -> void:
	if objective.is_rectangle():
		var corners := _polygon(objective.corners())
		draw_colored_polygon(corners, Color(BattleplanMap.OBJECTIVE, 0.25))
		draw_polyline(corners + PackedVector2Array([corners[0]]), BattleplanMap.OBJECTIVE, 1.5, true)
		return
	var centre := to_map(objective.position)
	var radius := to_map(Vector2(battlepack.radius_of(objective), 0)).x
	draw_circle(centre, radius, Color(BattleplanMap.OBJECTIVE, 0.25))
	draw_arc(centre, maxf(radius - 1, 1), 0, TAU, 32, BattleplanMap.OBJECTIVE, 1.5, true)


## Writes [param objective]'s name across its centre.
func _draw_name(objective: MapFeature) -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(objective.type, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE)
	var at := to_map(objective.position) + Vector2(-text_size.x / 2, font.get_ascent(NAME_FONT_SIZE) / 2 - 1)
	at = at.clamp(Vector2(2, text_size.y), size - Vector2(text_size.x + 2, 2))
	draw_string_outline(font, at, objective.type, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, 3, BattleplanMap.GROUND)
	draw_string(font, at, objective.type, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, UITheme.TEXT)


func _fill(points: PackedVector2Array, color: Color) -> void:
	if points.size() >= 3:
		draw_colored_polygon(points, color)
