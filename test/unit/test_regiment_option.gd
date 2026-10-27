extends GutTest
## Unit tests for parsing and matching Hero regiment options (scripts/army/regiment_option.gd).

const Kit := preload("res://test/support/army_kit.gd")


func _scroll(keywords: PackedStringArray, scroll_name := "Some Unit") -> Warscroll:
	var scroll := Kit.warscroll("some_unit", keywords, 100, scroll_name)
	return scroll


# Counts

func test_any_has_no_minimum_and_no_maximum() -> void:
	var option := RegimentOption.parse("Any WARRIOR CHAMBER")
	assert_eq([option.min, option.max], [0, RegimentOption.ANY])


func test_zero_to_one_caps_at_one_without_minimum() -> void:
	var option := RegimentOption.parse("0-1 STORMCAST EXEMPLAR")
	assert_eq([option.min, option.max], [0, 1])


func test_one_requires_exactly_one() -> void:
	var option := RegimentOption.parse("1 Toll’s Companions")
	assert_eq([option.min, option.max], [1, 1])


func test_required_suffix_requires_exactly_one() -> void:
	var option := RegimentOption.parse("Lorai (required)")
	assert_eq([option.min, option.max], [1, 1])


func test_text_keeps_the_option_as_written() -> void:
	assert_eq(RegimentOption.parse("0-1 Gryph-hounds").text, "0-1 Gryph-hounds")


func test_unit_suffix_is_dropped_from_subject() -> void:
	assert_eq(RegimentOption.parse("Any SKINK units").subject, "SKINK")


func test_required_suffix_is_dropped_from_subject() -> void:
	assert_eq(RegimentOption.parse("Lorai (required)").subject, "Lorai")


# Subjects

func test_capitalised_words_make_a_unit_name() -> void:
	var option := RegimentOption.parse("0-1 Gryph-hounds")
	assert_eq(option.unit, "Gryph-hounds")
	assert_eq(option.keywords.size(), 0)


func test_all_capitals_make_a_keyword_run() -> void:
	var option := RegimentOption.parse("Any WARRIOR CHAMBER")
	assert_eq(option.keywords, PackedStringArray(["WARRIOR CHAMBER"]))
	assert_true(option.unit.is_empty())


func test_negated_keyword_is_split_from_keywords() -> void:
	var option := RegimentOption.parse("Any non-MONSTER SKINK")
	assert_eq(option.not_keywords, PackedStringArray(["MONSTER"]))
	assert_eq(option.keywords, PackedStringArray(["SKINK"]))


func test_negation_alone_leaves_no_keywords() -> void:
	var option := RegimentOption.parse("Any non-HERO")
	assert_eq(option.not_keywords, PackedStringArray(["HERO"]))
	assert_eq(option.keywords.size(), 0)


# parse_all

func test_parse_all_splits_a_list_of_required_units() -> void:
	var options := RegimentOption.parse_all(PackedStringArray(["Neave’s Companions (required), Lorai (required)"]))
	assert_eq(options.size(), 2)
	assert_eq([options[0].subject, options[1].subject], ["Neave’s Companions", "Lorai"])


func test_parse_all_keeps_a_comma_list_that_is_not_all_required() -> void:
	var options := RegimentOption.parse_all(PackedStringArray(["Any Foo, Bar (required)"]))
	assert_eq(options.size(), 1)


func test_parse_all_parses_every_string() -> void:
	var options := RegimentOption.parse_all(PackedStringArray(["Any WARRIOR CHAMBER", "0-1 Gryph-hounds"]))
	assert_eq(options.size(), 2)


func test_parse_all_of_nothing_is_empty() -> void:
	assert_eq(RegimentOption.parse_all(PackedStringArray()).size(), 0)


# Real option strings

func test_real_option_strings_parse_to_expected_shapes() -> void:
	var exemplar := RegimentOption.parse("0-1 STORMCAST EXEMPLAR")
	var chamber := RegimentOption.parse("Any WARRIOR CHAMBER")
	var skink := RegimentOption.parse("non-MONSTER SKINK")
	var toll := RegimentOption.parse("1 Toll’s Companions")
	var hounds := RegimentOption.parse("0-1 Gryph-hounds")
	var pair := RegimentOption.parse_all(PackedStringArray(["Neave’s Companions (required), Lorai (required)"]))
	assert_eq(exemplar.keywords, PackedStringArray(["STORMCAST EXEMPLAR"]))
	assert_eq(chamber.keywords, PackedStringArray(["WARRIOR CHAMBER"]))
	assert_eq([skink.not_keywords, skink.keywords], [PackedStringArray(["MONSTER"]), PackedStringArray(["SKINK"])])
	assert_eq([toll.unit, toll.min], ["Toll’s Companions", 1])
	assert_eq([hounds.unit, hounds.max], ["Gryph-hounds", 1])
	assert_eq(pair.size(), 2)
	assert_eq([pair[0].unit, pair[1].unit], ["Neave’s Companions", "Lorai"])


# role_of

func test_role_is_read_from_notes() -> void:
	var scroll := Kit.hero("lord")
	scroll.notes = "This HERO can join an eligible regiment as a STORMCAST EXEMPLAR."
	assert_eq(RegimentOption.role_of(scroll), "STORMCAST EXEMPLAR")


func test_role_is_empty_without_a_matching_note() -> void:
	var scroll := Kit.hero("lord")
	scroll.notes = "Some other note."
	assert_eq(RegimentOption.role_of(scroll), "")


# matches

func test_keyword_option_matches_unit_with_the_keyword() -> void:
	assert_true(RegimentOption.parse("Any INFANTRY").matches(_scroll(PackedStringArray(["INFANTRY"]))))


func test_keyword_option_rejects_unit_without_the_keyword() -> void:
	assert_false(RegimentOption.parse("Any INFANTRY").matches(_scroll(PackedStringArray(["CAVALRY"]))))


func test_keyword_run_matches_when_each_word_is_a_keyword() -> void:
	var scroll := _scroll(PackedStringArray(["SYLVANETH", "MONSTER"]))
	assert_true(RegimentOption.parse("Any SYLVANETH MONSTER").matches(scroll))


func test_keyword_run_fails_when_one_word_is_missing() -> void:
	var scroll := _scroll(PackedStringArray(["SYLVANETH"]))
	assert_false(RegimentOption.parse("Any SYLVANETH MONSTER").matches(scroll))


func test_negated_keyword_rejects_unit_with_it() -> void:
	var scroll := _scroll(PackedStringArray(["SKINK", "MONSTER"]))
	assert_false(RegimentOption.parse("Any non-MONSTER SKINK").matches(scroll))


func test_negated_keyword_accepts_unit_without_it() -> void:
	assert_true(RegimentOption.parse("Any non-MONSTER SKINK").matches(_scroll(PackedStringArray(["SKINK"]))))


func test_named_option_matches_by_name_ignoring_case() -> void:
	assert_true(RegimentOption.parse("0-1 Gryph-hounds").matches(_scroll(PackedStringArray(), "gryph-hounds")))


func test_named_option_matches_a_size_variant() -> void:
	var scroll := _scroll(PackedStringArray(), "Stormdrake Guard (1 model)")
	assert_true(RegimentOption.parse("0-1 Stormdrake Guard").matches(scroll))


func test_named_option_matches_a_name_with_an_epithet() -> void:
	var scroll := _scroll(PackedStringArray(), "Lorai, Child of the Abyss")
	assert_true(RegimentOption.parse("Lorai (required)").matches(scroll))


func test_named_option_ignores_apostrophe_style() -> void:
	var scroll := _scroll(PackedStringArray(), "Neave's Companions")
	assert_true(RegimentOption.parse("Neave’s Companions (required)").matches(scroll))


func test_named_option_rejects_other_names() -> void:
	assert_false(RegimentOption.parse("0-1 Gryph-hounds").matches(_scroll(PackedStringArray(), "Gryph-charger")))


func test_name_prefix_without_a_variant_bracket_does_not_match() -> void:
	assert_false(RegimentOption.parse("0-1 Guard").matches(_scroll(PackedStringArray(), "Guardians")))


func test_hero_does_not_match_a_keyword_option() -> void:
	var scroll := Kit.hero("lord", PackedStringArray(), PackedStringArray(["INFANTRY"]))
	assert_false(RegimentOption.parse("Any INFANTRY").matches(scroll))


func test_hero_matches_an_option_naming_it() -> void:
	var scroll := Kit.warscroll("lorai", PackedStringArray(["HERO"]), 100, "Lorai")
	assert_true(RegimentOption.parse("Lorai (required)").matches(scroll))


func test_hero_matches_an_option_naming_its_role() -> void:
	var scroll := Kit.hero("praetor")
	scroll.notes = "This HERO can join an eligible regiment as a STORMCAST EXEMPLAR."
	assert_true(RegimentOption.parse("0-1 STORMCAST EXEMPLAR").matches(scroll))


func test_hero_does_not_match_a_different_role() -> void:
	var scroll := Kit.hero("praetor")
	scroll.notes = "This HERO can join an eligible regiment as a STORMCAST EXEMPLAR."
	assert_false(RegimentOption.parse("0-1 ROYAL ATTENDANT").matches(scroll))
