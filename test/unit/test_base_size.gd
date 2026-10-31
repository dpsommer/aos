extends GutTest
## Unit tests for warscroll bases (scripts/data/rules/base_size.gd and base_size_group.gd).


func _group(group_name: String, count: int, base: BaseSize, note := "") -> BaseSizeGroup:
	var group := BaseSizeGroup.new()
	group.name = group_name
	group.count = count
	group.base = base
	group.note = note
	return group


func _mixed(groups: Array[BaseSizeGroup]) -> BaseSize:
	return BaseSize.mixed(groups)


# Footprint

func test_round_footprint_is_square_of_the_diameter_in_inches() -> void:
	var footprint := BaseSize.round_base(50.8).footprint()
	assert_almost_eq(footprint, Vector2(2, 2), Vector2(0.001, 0.001))


func test_oval_footprint_is_length_by_width_in_inches() -> void:
	var footprint := BaseSize.oval(101.6, 50.8).footprint()
	assert_almost_eq(footprint, Vector2(4, 2), Vector2(0.001, 0.001))


func test_oval_puts_the_longer_side_as_length() -> void:
	var base := BaseSize.oval(25, 50)
	assert_gt(base.length, base.width)


func test_model_with_a_best_guess_uses_it_for_footprint() -> void:
	var footprint := BaseSize.model(50.8, 25.4).footprint()
	assert_almost_eq(footprint, Vector2(2, 1), Vector2(0.001, 0.001))


func test_model_without_a_size_uses_the_default_footprint() -> void:
	assert_eq(BaseSize.model().footprint(), BaseSize.DEFAULT_MODEL_FOOTPRINT)


func test_mixed_footprint_is_the_largest_groups() -> void:
	var big := BaseSize.round_base(60)
	var base := _mixed([_group("Small", 5, BaseSize.round_base(25)), _group("Big", 1, big)])
	assert_eq(base.footprint(), big.footprint())


func test_mixed_without_groups_has_no_footprint() -> void:
	assert_eq(_mixed([]).footprint(), Vector2.ZERO)


# bases_for

func test_plain_base_repeats_for_every_model() -> void:
	var base := BaseSize.round_base(32)
	var bases := base.bases_for(4)
	assert_eq(bases.size(), 4)
	assert_true(bases.all(func(each: BaseSize) -> bool: return each == base))


func test_no_models_gives_no_bases() -> void:
	assert_eq(BaseSize.round_base(32).bases_for(0).size(), 0)


func test_negative_models_gives_no_bases() -> void:
	assert_eq(_mixed([_group("A", 1, BaseSize.round_base(32))]).bases_for(-2).size(), 0)


func test_mixed_expands_each_groups_count() -> void:
	var boss := BaseSize.round_base(40)
	var grunt := BaseSize.round_base(25)
	var bases := _mixed([_group("Boss", 1, boss), _group("Grunts", 3, grunt)]).bases_for(4)
	assert_eq(bases, [boss, grunt, grunt, grunt] as Array[BaseSize])


func test_reinforced_mixed_multiplies_every_group() -> void:
	var boss := BaseSize.round_base(40)
	var grunt := BaseSize.round_base(25)
	var bases := _mixed([_group("Boss", 1, boss), _group("Grunts", 3, grunt)]).bases_for(8)
	assert_eq(bases, [boss, boss, grunt, grunt, grunt, grunt, grunt, grunt] as Array[BaseSize])


func test_extra_models_take_the_smallest_base() -> void:
	var boss := BaseSize.round_base(40)
	var grunt := BaseSize.round_base(25)
	var bases := _mixed([_group("Boss", 1, boss), _group("Grunts", 3, grunt)]).bases_for(6)
	assert_eq(bases.slice(4), [grunt, grunt] as Array[BaseSize])


func test_fewer_models_than_the_groups_truncate() -> void:
	var boss := BaseSize.round_base(40)
	var grunt := BaseSize.round_base(25)
	var bases := _mixed([_group("Boss", 1, boss), _group("Grunts", 3, grunt)]).bases_for(2)
	assert_eq(bases, [boss, grunt] as Array[BaseSize])


func test_mixed_with_exactly_the_group_total_is_not_multiplied() -> void:
	var base := _mixed([_group("A", 2, BaseSize.round_base(30)), _group("B", 2, BaseSize.round_base(40))])
	assert_eq(base.bases_for(4).size(), 4)


# text

func test_round_text_drops_a_trailing_zero() -> void:
	assert_eq(BaseSize.round_base(32).text(), "32mm")


func test_round_text_keeps_decimals() -> void:
	assert_eq(BaseSize.round_base(28.5).text(), "28.5mm")


func test_oval_text_is_length_by_width() -> void:
	assert_eq(BaseSize.oval(35, 60).text(), "60 × 35mm")


func test_model_text_says_to_use_the_model() -> void:
	assert_eq(BaseSize.model().text(), "Use model")


func test_mixed_text_counts_a_named_group_of_many() -> void:
	var base := _mixed([_group("Knight", 1, BaseSize.oval(52, 90)), _group("Gryph-hounds", 2, BaseSize.round_base(40))])
	assert_eq(base.text(), "Knight: 90 × 52mm, 2 × Gryph-hounds: 40mm")


func test_mixed_text_counts_an_unnamed_group() -> void:
	var base := _mixed([_group("", 9, BaseSize.round_base(28.5))])
	assert_eq(base.text(), "9 × 28.5mm")


func test_mixed_text_puts_the_note_in_parentheses() -> void:
	var base := _mixed([_group("", 1, BaseSize.round_base(32), "Champion"), _group("", 9, BaseSize.round_base(28.5))])
	assert_eq(base.text(), "1 × 32mm (Champion), 9 × 28.5mm")


func test_mixed_text_does_not_count_a_group_naming_several_models() -> void:
	var base := _mixed([_group("A and B", 2, BaseSize.round_base(32))])
	assert_eq(base.text(), "A and B: 32mm")
