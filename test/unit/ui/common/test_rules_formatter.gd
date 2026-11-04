extends GutTest
## Unit tests for turning an ability's rules into BBCode (scripts/ui/common/rules_formatter.gd).


func _ability(fields := {}) -> Ability:
	var rule := Ability.new()
	rule.name = "Made-up Ability"
	for key: String in fields:
		rule.set(key, fields[key])
	return rule


func test_ability_body_omits_name_timing_and_source() -> void:
	var rule := _ability({timing = "Some Phase", source = "Some Book", text = "Body text."})
	var body := RulesFormatter.ability_body(rule)
	assert_false(body.contains(rule.name))
	assert_false(body.contains(rule.timing))
	assert_false(body.contains(rule.source))


func test_ability_body_omits_keywords() -> void:
	var rule := _ability({keywords = PackedStringArray(["FIRSTWORD"]), text = "Body text."})
	assert_false(RulesFormatter.ability_body(rule).contains("FIRSTWORD"))


func test_ability_body_omits_points_and_casting_values() -> void:
	var rule := _ability({points = 35, casting_value = 7, chanting_value = 4, text = "Body text."})
	var body := RulesFormatter.ability_body(rule)
	assert_false(body.contains("pts"))
	assert_false(body.contains("Casting value"))
	assert_false(body.contains("Chanting value"))


func test_ability_body_includes_text_declare_and_effect() -> void:
	var rule := _ability({text = "Plain text.", declare = "Pick a unit.", effect = "It gets stronger."})
	var body := RulesFormatter.ability_body(rule)
	assert_string_contains(body, rule.text)
	assert_string_contains(body, rule.declare)
	assert_string_contains(body, rule.effect)


func test_ability_body_of_an_empty_ability_is_empty() -> void:
	assert_eq(RulesFormatter.ability_body(_ability()), "")


func test_ability_body_contains_every_option_name_and_text() -> void:
	var options: Array[Dictionary] = [{"name": "First Choice", "text": "First text."},
			{"name": "Second Choice", "text": "Second text."}]
	var body := RulesFormatter.ability_body(_ability({options = options}))
	for option in options:
		assert_string_contains(body, option.name)
		assert_string_contains(body, option.text)


func test_ability_body_omits_declare_label_when_declare_empty() -> void:
	var with_declare := RulesFormatter.ability_body(_ability({declare = "x", effect = "y"}))
	var without_declare := RulesFormatter.ability_body(_ability({effect = "y"}))
	assert_lt(without_declare.split("\n").size(), with_declare.split("\n").size())


func test_ability_body_does_not_leave_raw_bracket_from_effect() -> void:
	var body := RulesFormatter.ability_body(_ability({effect = "Gains [Crit (Mortal)]."}))
	assert_false("[Crit" in body)


func test_ability_body_does_not_leave_raw_bracket_from_text() -> void:
	var body := RulesFormatter.ability_body(_ability({text = "Gains [Crit (Mortal)]."}))
	assert_false("[Crit" in body)


func test_ability_body_does_not_leave_raw_bracket_from_options() -> void:
	var options: Array[Dictionary] = [{"name": "[Choice]", "text": "Gains [Crit (Mortal)]."}]
	var body := RulesFormatter.ability_body(_ability({options = options}))
	assert_false("[Crit" in body)
	assert_false("[Choice" in body)
