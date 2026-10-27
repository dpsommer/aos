extends GutTest
## Unit tests for the army resources' lookups (scripts/army/army.gd, army_regiment.gd).

const Kit := preload("res://test/support/army_kit.gd")


## Regiment r1 holds u1 (leader) and u2; r2 holds u3; u4 is auxiliary.
func _army() -> Army:
	var army := Kit.army()
	army.regiments.append(Kit.regiment("r1", [Kit.unit("u1", "a"), Kit.unit("u2", "b")]))
	army.regiments.append(Kit.regiment("r2", [Kit.unit("u3", "c")]))
	army.auxiliary.append(Kit.unit("u4", "d"))
	return army


func test_all_units_lists_regiments_before_auxiliary() -> void:
	var uids := _army().all_units().map(func(u: ArmyUnit) -> String: return u.uid)
	assert_eq(uids, ["u1", "u2", "u3", "u4"])


func test_all_units_of_empty_army_is_empty() -> void:
	assert_eq(Kit.army().all_units().size(), 0)


func test_find_unit_finds_regiment_and_auxiliary_units() -> void:
	var army := _army()
	assert_eq(army.find_unit("u2").warscroll_id, "b")
	assert_eq(army.find_unit("u4").warscroll_id, "d")


func test_find_unit_is_null_for_unknown_uid() -> void:
	assert_null(_army().find_unit("nope"))


func test_regiment_of_returns_the_holding_regiment() -> void:
	assert_eq(_army().regiment_of("u3").id, "r2")


func test_regiment_of_auxiliary_unit_is_null() -> void:
	assert_null(_army().regiment_of("u4"))


func test_regiment_of_unknown_unit_is_null() -> void:
	assert_null(_army().regiment_of("nope"))


func test_find_regiment_by_id() -> void:
	assert_eq(_army().find_regiment("r2").units.size(), 1)


func test_find_regiment_is_null_for_unknown_id() -> void:
	assert_null(_army().find_regiment("nope"))


func test_leader_is_the_first_unit() -> void:
	assert_eq(_army().find_regiment("r1").leader().uid, "u1")


func test_leader_of_empty_regiment_is_null() -> void:
	assert_null(Kit.regiment("r", []).leader())


func test_regiment_of_renown_has_no_leader() -> void:
	var regiment := Kit.ror_regiment("r", "Some Renown", [Kit.unit("u1", "a")])
	assert_null(regiment.leader())


func test_regiment_is_of_renown_only_when_it_names_one() -> void:
	assert_false(Kit.regiment("r", []).is_regiment_of_renown())
	assert_true(Kit.ror_regiment("r", "Some Renown", []).is_regiment_of_renown())
