import schema


def ws(**kw):
    w = {"name": "Test Riders", "move": 10, "health": 4, "save": 4, "control": 1,
         "ranged_weapons": [], "melee_weapons": [], "abilities": [], "keywords": []}
    w.update(kw)
    return w


def test_ability_drops_empty_optional_fields():
    out = schema.ability({"name": "A", "category": "", "timing": "", "frequency": "", "keywords": [], "effect": "X"})
    assert "frequency" not in out and "keywords" not in out


def test_ability_keeps_set_optional_fields():
    assert schema.ability({"name": "A", "casting_value": 7})["casting_value"] == 7


def test_ability_fills_category_and_timing():
    out = schema.ability({"name": "A"})
    assert (out["category"], out["timing"]) == ("", "")


def test_ability_drops_unknown_fields():
    assert "destiny_points" not in schema.ability({"name": "A", "destiny_points": 1})


def test_weapon_drops_empty_abilities():
    w = {"name": "Sword", "range": 0, "attacks": "2", "hit": 3, "wound": 4, "rend": 0, "damage": "1", "abilities": []}
    assert "abilities" not in schema.weapon(w)


def test_warscroll_id_defaults_to_slug_of_name():
    assert schema.warscroll(ws(name="Rider’s Champion"))["id"] == "riders_champion"


def test_warscroll_keeps_given_id():
    assert schema.warscroll(ws(id="scourge_of_aqshy_test_riders"))["id"] == "scourge_of_aqshy_test_riders"


def test_warscroll_fills_profile_defaults():
    out = schema.warscroll(ws())
    assert (out["points"], out["unit_size"], out["can_reinforce"]) == (0, 1, False)


def test_warscroll_drops_empty_optional_fields():
    out = schema.warscroll(ws(source="", legends=False, ward=0, base_size="", notes="", regiment_options=[], composition=""))
    assert not {"source", "legends", "ward", "base_size", "notes", "regiment_options", "composition"} & set(out)


def test_warscroll_without_profile_omits_battle_profile_fields():
    out = schema.warscroll(ws(points=100, unit_size=5, base_size="60mm", can_reinforce=True,
                              regiment_options=["Any"], notes="N"), with_profile=False)
    assert not {"points", "unit_size", "base_size", "can_reinforce", "regiment_options", "notes"} & set(out)


def test_warscroll_without_profile_keeps_stats():
    assert schema.warscroll(ws(), with_profile=False)["health"] == 4


def test_warscroll_keeps_set_banishment():
    assert schema.warscroll(ws(banishment=6))["banishment"] == 6


def test_warscroll_omits_zero_banishment():
    assert "banishment" not in schema.warscroll(ws(banishment=0))


def test_warscroll_drops_unknown_fields():
    assert "slug" not in schema.warscroll(ws(slug="test-riders"))


def test_table_drops_empty_group_and_source():
    out = schema.table({"name": "Heroic Traits", "group": "", "source": "", "entries": []})
    assert "group" not in out and "source" not in out


def test_army_of_renown_text_defaults_to_empty():
    out = schema.army_of_renown({"name": "Host", "battle_traits": [], "enhancement_tables": [], "lores": []})
    assert out["text"] == ""


def test_tidy_removes_space_inside_opening_quote():
    assert schema.tidy("the ‘ Tester’") == "the ‘Tester’"


def test_tidy_removes_space_before_closing_quote():
    assert schema.tidy("the ‘Tester ’ unit") == "the ‘Tester’ unit"


def test_tidy_keeps_space_before_apostrophe_s():
    assert schema.tidy("Tester ’s") == "Tester ’s"


def test_tidy_recurses_into_lists_and_dicts():
    assert schema.tidy({"a": ["‘ x’"]}) == {"a": ["‘x’"]}


def test_tidy_leaves_non_strings_alone():
    assert schema.tidy({"n": 3, "b": True}) == {"n": 3, "b": True}
