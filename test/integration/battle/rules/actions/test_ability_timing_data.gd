extends GutTest
## Every timing in the real data is one the rules engine can read.

const DIRECTORIES: Array[String] = ["res://data/factions", "res://data/shared", "res://data/core"]
## Timings that aren't one on purpose: text the data has in the timing field that isn't a timing.
const KNOWN_EXCEPTIONS: PackedStringArray = [
	# A rules sentence BSData put in the timing field of a Legends warscroll.
	"Pick a friendly LETHIS unit that has had models slain this battle to be the target.",
]


func _json_files(path: String) -> Array[String]:
	var result: Array[String] = []
	for file_name in DirAccess.get_files_at(path):
		if file_name.ends_with(".json"):
			result.append("%s/%s" % [path, file_name])
	for directory in DirAccess.get_directories_at(path):
		result.append_array(_json_files("%s/%s" % [path, directory]))
	return result


func _collect(node: Variant, into: Dictionary) -> void:
	if node is Dictionary:
		for key: Variant in node:
			if key == "timing" and node[key] is String:
				into[node[key]] = true
			else:
				_collect(node[key], into)
	elif node is Array:
		for each: Variant in node:
			_collect(each, into)


func test_every_timing_in_the_data_is_known() -> void:
	var timings := {}
	for directory in DIRECTORIES:
		for path in _json_files(directory):
			_collect(JSON.parse_string(FileAccess.get_file_as_string(path)), timings)
	assert_gt(timings.size(), 10, "The data was found")
	var unknown: Array[String] = []
	for text: String in timings:
		if text.is_empty() or text in KNOWN_EXCEPTIONS:
			continue
		if not AbilityTiming.parse(text).is_known():
			unknown.append(text)
	assert_eq(unknown, [] as Array[String], "Timings the engine can't read")
