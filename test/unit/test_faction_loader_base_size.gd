extends GutTest
## Unit tests for loading a warscroll's base_size object (FactionLoader._base_size) and
## Faction.find_warscroll. Each test writes a one-warscroll faction to a temporary folder.

const DIR := "user://test_base_size_faction"

var _loader: FactionLoader


func after_each() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)


func _write(file_name: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(DIR.path_join(file_name), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


## The warscroll loaded from a faction whose only warscroll has [param base] as its base_size.
func _load_with(base: Variant) -> Warscroll:
	_write("faction.json", {"id": "t", "name": "T", "grand_alliance": "death"})
	var scroll := {"id": "u", "name": "Unit", "unit_size": 1, "points": 100, "move": "4", "health": 1, "save": 4, "control": 1}
	if base != null:
		scroll["base_size"] = base
	_write("warscrolls.json", {"warscrolls": [scroll]})
	_loader = FactionLoader.new()
	var faction := _loader.load_faction(DIR)
	return faction.warscrolls[0] if faction and not faction.warscrolls.is_empty() else null


func _group(group_name: String, count: int, base: Dictionary) -> Dictionary:
	return {"name": group_name, "count": count, "base": base}


func test_missing_base_size_is_null() -> void:
	assert_null(_load_with(null).base_size)


func test_round_base_loads() -> void:
	var base := _load_with({"shape": "round", "diameter": 28.5}).base_size
	assert_eq([base.shape, base.diameter], [BaseSize.Shape.ROUND, 28.5])


func test_oval_base_loads() -> void:
	var base := _load_with({"shape": "oval", "length": 60, "width": 35}).base_size
	assert_eq([base.shape, base.length, base.width], [BaseSize.Shape.OVAL, 60.0, 35.0])


func test_model_base_loads_without_a_size() -> void:
	assert_eq(_load_with({"shape": "model"}).base_size.shape, BaseSize.Shape.MODEL)


func test_model_base_keeps_its_best_guess() -> void:
	var base := _load_with({"shape": "model", "length": 80, "width": 40}).base_size
	assert_eq([base.length, base.width], [80.0, 40.0])


func test_mixed_base_loads_its_groups() -> void:
	var base := _load_with({"shape": "mixed", "models": [
		_group("Boss", 1, {"shape": "round", "diameter": 40}),
		{"count": 3, "note": "Grunts", "base": {"shape": "oval", "length": 50, "width": 25}},
	]}).base_size
	assert_eq(base.groups.size(), 2)
	assert_eq([base.groups[0].name, base.groups[0].count, base.groups[0].base.shape], ["Boss", 1, BaseSize.Shape.ROUND])
	assert_eq([base.groups[1].count, base.groups[1].note, base.groups[1].base.shape], [3, "Grunts", BaseSize.Shape.OVAL])


func test_valid_bases_have_no_errors() -> void:
	_load_with({"shape": "round", "diameter": 32})
	assert_eq(_loader.errors.size(), 0)


func test_unknown_shape_is_an_error() -> void:
	_load_with({"shape": "hexagon"})
	assert_true(_has_error("shape"))


func test_missing_shape_is_an_error() -> void:
	_load_with({"diameter": 32})
	assert_true(_has_error("shape"))


func test_round_without_diameter_is_an_error() -> void:
	_load_with({"shape": "round"})
	assert_true(_has_error("diameter"))


func test_oval_without_width_is_an_error() -> void:
	_load_with({"shape": "oval", "length": 60})
	assert_true(_has_error("width"))


func test_zero_size_is_an_error() -> void:
	_load_with({"shape": "round", "diameter": 0})
	assert_true(_has_error("diameter"))


func test_negative_size_is_an_error() -> void:
	_load_with({"shape": "round", "diameter": -5})
	assert_true(_has_error("diameter"))


func test_non_numeric_size_is_an_error() -> void:
	_load_with({"shape": "round", "diameter": "32mm"})
	assert_true(_has_error("diameter"))


func test_base_size_that_is_not_an_object_is_an_error() -> void:
	_load_with("32mm")
	assert_true(_has_error("base_size"))


func test_mixed_nested_in_mixed_is_an_error() -> void:
	_load_with({"shape": "mixed", "models": [
		_group("A", 1, {"shape": "mixed", "models": [_group("B", 1, {"shape": "round", "diameter": 32})]}),
	]})
	assert_true(_has_error("shape"))


func test_mixed_group_without_a_base_is_an_error() -> void:
	_load_with({"shape": "mixed", "models": [{"name": "A", "count": 1}]})
	assert_true(_has_error("base"))


func test_mixed_group_without_a_count_is_an_error() -> void:
	_load_with({"shape": "mixed", "models": [{"name": "A", "base": {"shape": "round", "diameter": 32}}]})
	assert_true(_has_error("count"))


func test_mixed_without_groups_is_an_error() -> void:
	_load_with({"shape": "mixed", "models": []})
	assert_true(_has_error("models"))


func test_find_warscroll_matches_by_name() -> void:
	var scroll := _load_with({"shape": "model"})
	var faction := Faction.new()
	faction.warscrolls = [scroll] as Array[Warscroll]
	assert_eq(faction.find_warscroll(scroll.name), scroll)


func test_find_warscroll_does_not_match_by_id() -> void:
	var scroll := _load_with({"shape": "model"})
	var faction := Faction.new()
	faction.warscrolls = [scroll] as Array[Warscroll]
	assert_null(faction.find_warscroll(scroll.id))


func test_find_warscroll_unknown_is_null() -> void:
	assert_null(Faction.new().find_warscroll("Nobody"))


func _has_error(field: String) -> bool:
	for error in _loader.errors:
		if field in error:
			return true
	return false
