class_name BaseSize
extends Resource
## The base a warscroll's models stand on: round, oval, none ("Use model", with a best-guess
## footprint) or a mix of those. Sizes are in millimetres, as printed on warscrolls. See
## docs/technical/faction-data.md#base-sizes.

enum Shape { ROUND, OVAL, MODEL, MIXED }

const MM_PER_INCH := 25.4
## Footprint of a model with no base whose data has no best guess.
const DEFAULT_MODEL_FOOTPRINT := Vector2(1.0, 1.0)

@export var shape: Shape
## Diameter of a round base.
@export var diameter: float
## Long side of an oval base, or of a model's footprint.
@export var length: float
## Short side of an oval base, or of a model's footprint.
@export var width: float
## The groups of models with different bases, for [constant MIXED].
@export var groups: Array[BaseSizeGroup]


static func round_base(diameter_mm: float) -> BaseSize:
	var base := BaseSize.new()
	base.shape = Shape.ROUND
	base.diameter = diameter_mm
	return base


static func oval(length_mm: float, width_mm: float) -> BaseSize:
	var base := BaseSize.new()
	base.shape = Shape.OVAL
	base.length = maxf(length_mm, width_mm)
	base.width = minf(length_mm, width_mm)
	return base


## A model with no base, with a best-guess footprint (zero when unknown).
static func model(length_mm := 0.0, width_mm := 0.0) -> BaseSize:
	var base := BaseSize.new()
	base.shape = Shape.MODEL
	base.length = maxf(length_mm, width_mm)
	base.width = minf(length_mm, width_mm)
	return base


static func mixed(of: Array[BaseSizeGroup]) -> BaseSize:
	var base := BaseSize.new()
	base.shape = Shape.MIXED
	base.groups = of
	return base


## The base's size in inches: x along its long side, y across it. A mixed base's is its largest
## group's.
func footprint() -> Vector2:
	match shape:
		Shape.ROUND:
			return Vector2(diameter, diameter) / MM_PER_INCH
		Shape.OVAL:
			return Vector2(length, width) / MM_PER_INCH
		Shape.MODEL:
			return Vector2(length, width) / MM_PER_INCH if length > 0.0 else DEFAULT_MODEL_FOOTPRINT
	var largest := Vector2.ZERO
	for group in groups:
		var size := group.base.footprint()
		if size.x * size.y > largest.x * largest.y:
			largest = size
	return largest


## One base per model of a unit of [param model_count] models. A mixed base's groups are
## counted for the warscroll's unit size: a unit that's a whole multiple of that (reinforced)
## multiplies every group, other extra models take the smallest base, and a smaller unit drops
## the last groups' models.
func bases_for(model_count: int) -> Array[BaseSize]:
	var result: Array[BaseSize] = []
	if model_count <= 0:
		return result
	if shape != Shape.MIXED or groups.is_empty():
		for i in model_count:
			result.append(self)
		return result
	var total := 0
	for group in groups:
		total += group.count
	@warning_ignore("integer_division")
	var times := model_count / total if model_count > total and model_count % total == 0 else 1
	for group in groups:
		for i in group.count * times:
			result.append(group.base)
	if result.size() > model_count:
		result.resize(model_count)
	var smallest := _smallest_group_base()
	while result.size() < model_count:
		result.append(smallest)
	return result


## The base as warscrolls write it: "32mm", "60 × 35mm", "Use model", or each group's, e.g.
## "Knight-Judicator: 90 × 52mm, 2 × Gryph-hounds: 40mm" or "1 × 32mm (Champion), 9 × 28.5mm".
func text() -> String:
	match shape:
		Shape.ROUND:
			return "%smm" % _mm(diameter)
		Shape.OVAL:
			return "%s × %smm" % [_mm(length), _mm(width)]
		Shape.MODEL:
			return "Use model"
	var parts := PackedStringArray()
	for group in groups:
		var part := group.base.text()
		if group.name.is_empty():
			part = "%d × %s" % [group.count, part]
		elif group.count > 1 and not ("," in group.name or " and " in group.name):
			part = "%d × %s: %s" % [group.count, group.name, part]
		else:
			part = "%s: %s" % [group.name, part]
		if not group.note.is_empty():
			part += " (%s)" % group.note
		parts.append(part)
	return ", ".join(parts)


func _smallest_group_base() -> BaseSize:
	var smallest: BaseSize = groups[0].base
	for group in groups:
		var size := group.base.footprint()
		var best := smallest.footprint()
		if size.x * size.y < best.x * best.y:
			smallest = group.base
	return smallest


## "32" for 32.0, "28.5" for 28.5.
static func _mm(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(value)
