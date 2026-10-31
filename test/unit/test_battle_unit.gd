extends GutTest
## Unit tests for units on the battlefield (scripts/battle/battle_unit.gd).

const BattleKit := preload("res://test/support/battle_kit.gd")


func test_create_gives_one_base_per_model() -> void:
	assert_eq(BattleUnit.create("U", BattleKit.warscroll("U"), 7).model_count(), 7)


func test_create_takes_the_bases_from_the_warscroll() -> void:
	var scroll := BattleKit.warscroll("U", 5, 50.0)
	var unit := BattleUnit.create("U", scroll, 2)
	assert_eq(unit.bases[0], scroll.base_size)


func test_create_without_a_base_falls_back_to_a_round_base() -> void:
	var unit := BattleUnit.create("U", BattleKit.warscroll("U", 5, 0.0), 1)
	assert_eq(unit.bases[0].shape, BaseSize.Shape.ROUND)


func test_create_without_a_warscroll_still_has_a_base() -> void:
	var unit := BattleUnit.create("U", null, 3)
	assert_eq(unit.bases.size(), 3)
	assert_gt(unit.bases[0].footprint().x, 0.0)


func test_create_prefers_the_base_source_for_the_base() -> void:
	var own := BattleKit.warscroll("Own", 1, 0.0)
	var source := BattleKit.warscroll("Source", 1, 60.0)
	var unit := BattleUnit.create("U", own, 1, source)
	assert_eq(unit.bases[0], source.base_size)


func test_create_keeps_its_own_warscroll_when_there_is_a_base_source() -> void:
	var own := BattleKit.warscroll("Own", 1, 0.0)
	var unit := BattleUnit.create("U", own, 1, BattleKit.warscroll("Source", 1, 60.0))
	assert_eq(unit.warscroll, own)


func test_create_with_a_base_source_that_has_no_base_falls_back() -> void:
	var unit := BattleUnit.create("U", BattleKit.warscroll("Own", 1, 40.0), 1, BattleKit.warscroll("Source", 1, 0.0))
	assert_eq(unit.bases[0].shape, BaseSize.Shape.ROUND)
	assert_ne(unit.bases[0], unit.warscroll.base_size)


func test_create_has_at_least_one_model() -> void:
	assert_eq(BattleUnit.create("U", BattleKit.warscroll("U"), 0).model_count(), 1)


func test_create_expands_mixed_bases() -> void:
	var scroll := BattleKit.warscroll("U", 3, 0.0)
	var boss := BaseSizeGroup.new()
	boss.name = "Boss"
	boss.count = 1
	boss.base = BaseSize.round_base(50)
	var grunts := BaseSizeGroup.new()
	grunts.name = "Grunts"
	grunts.count = 2
	grunts.base = BaseSize.round_base(25)
	scroll.base_size = BaseSize.mixed([boss, grunts] as Array[BaseSizeGroup])
	var unit := BattleUnit.create("U", scroll, 3)
	assert_eq(unit.bases, [boss.base, grunts.base, grunts.base] as Array[BaseSize])


func test_new_unit_is_not_deployed() -> void:
	assert_eq(BattleKit.unit("U", 3).positions.size(), 0)


func test_copy_keeps_name_warscroll_and_bases() -> void:
	var unit := BattleKit.unit("U", 3)
	var copy := unit.copy()
	assert_eq([copy.name, copy.warscroll, copy.bases], [unit.name, unit.warscroll, unit.bases])


func test_copy_is_not_deployed() -> void:
	var unit := BattleKit.unit("U", 2)
	unit.positions = PackedVector2Array([Vector2(1, 1), Vector2(2, 2)])
	assert_eq(unit.copy().positions.size(), 0)


func test_copy_has_its_own_bases_array() -> void:
	var unit := BattleKit.unit("U", 3)
	var copy := unit.copy()
	copy.bases.clear()
	assert_eq(unit.model_count(), 3)
