class_name Coherency
extends RefCounted
## Unit coherency (Core Rules): a unit's models must be in one group, each within ½" of at least
## one other model of the unit, or of at least two others in a unit of 7 or more models. Distances
## are between bases, edge to edge, in inches. See docs/gameplay/deployment.md.

const MAX_GAP := 0.5
## Units of this many models or more need each model near two others.
const LARGE_UNIT := 7
## Slack for bases exactly ½" apart.
const EPSILON := 0.001


## How many other models each model needs within [constant MAX_GAP] in a unit of
## [param model_count].
static func neighbours_needed(model_count: int) -> int:
	return 2 if model_count >= LARGE_UNIT else 1


## Indices of the models at [param positions] on [param bases], all facing [param facing], that
## break coherency: those with too few close neighbours, and those outside the largest group.
## Empty for a coherent unit, and always for a single model.
static func failing(positions: PackedVector2Array, bases: Array[BaseSize], facing: float) -> PackedInt32Array:
	var count := positions.size()
	var result := PackedInt32Array()
	if count < 2:
		return result
	var near: Array[PackedInt32Array] = []
	for i in count:
		near.append(PackedInt32Array())
	for i in count:
		for j in range(i + 1, count):
			if DeploymentRules.base_gap(bases[i], positions[i], facing, bases[j], positions[j], facing) <= MAX_GAP + EPSILON:
				near[i].append(j)
				near[j].append(i)
	var needed := neighbours_needed(count)
	var largest := _largest_group(near)
	for i in count:
		if near[i].size() < needed or not largest.has(i):
			result.append(i)
	return result


static func is_coherent(positions: PackedVector2Array, bases: Array[BaseSize], facing: float) -> bool:
	return failing(positions, bases, facing).is_empty()


## The biggest set of models linked to each other through close neighbours, as a set of indices.
static func _largest_group(near: Array[PackedInt32Array]) -> Dictionary:
	var seen := {}
	var best := {}
	for start in near.size():
		if seen.has(start):
			continue
		var group := {start: true}
		var queue := [start]
		seen[start] = true
		while not queue.is_empty():
			var current: int = queue.pop_back()
			for next in near[current]:
				if not seen.has(next):
					seen[next] = true
					group[next] = true
					queue.append(next)
		if group.size() > best.size():
			best = group
	return best
