import pytest

import schema


def ws(**kw):
    w = {"name": "Test Riders", "move": "10", "health": 4, "save": 4, "control": 1,
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


def test_ability_type_is_second_key():
    assert list(schema.ability({"name": "A", "timing": "Passive"}))[:2] == ["name", "type"]


@pytest.mark.parametrize("fields,expected", [
    ({"timing": "Passive"}, "passive"),
    ({"timing": "Your Hero Phase", "casting_value": 6}, "spell"),
    ({"timing": "Your Hero Phase", "keywords": ["SPELL"]}, "spell"),
    ({"timing": "Your Hero Phase", "chanting_value": 4}, "prayer"),
    ({"timing": "Your Hero Phase", "keywords": ["PRAYER"]}, "prayer"),
    ({"timing": "Your Hero Phase", "command_points": 1}, "command"),
    ({"timing": "Your Hero Phase"}, "active"),
    ({}, "active"),
], ids=["passive", "casting_value", "spell_keyword", "chanting_value", "prayer_keyword", "command", "active", "empty"])
def test_ability_type(fields, expected):
    assert schema.ability_type(dict({"name": "A"}, **fields)) == expected


def test_passive_timing_beats_spell_keyword():
    assert schema.ability_type({"timing": "Passive", "keywords": ["SPELL"]}) == "passive"


def test_spell_beats_command_points():
    assert schema.ability_type({"timing": "Your Hero Phase", "casting_value": 5, "command_points": 1}) == "spell"


def test_prayer_beats_command_points():
    assert schema.ability_type({"timing": "Your Hero Phase", "chanting_value": 4, "command_points": 1}) == "prayer"


def test_ability_writes_computed_type():
    assert schema.ability({"name": "A", "timing": "Your Hero Phase", "command_points": 2})["type"] == "command"


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


def test_warscroll_keeps_weapon_options_after_composition():
    options = [{"name": "Grandhammer", "replaces": "Warhammer", "max": 1, "per": 5}]
    out = schema.warscroll(ws(weapon_options=options, composition="Armed with a Warhammer."))
    assert out["weapon_options"] == options and list(out)[-2:] == ["composition", "weapon_options"]


def test_warscroll_omits_empty_weapon_options():
    assert "weapon_options" not in schema.warscroll(ws(weapon_options=[]))


def test_table_keeps_units():
    out = schema.table({"name": "Great Endrinworks", "units": ["Arkanaut Frigate"], "entries": []})
    assert out["units"] == ["Arkanaut Frigate"]


def test_table_without_units_has_no_units_key():
    assert "units" not in schema.table({"name": "Heroic Traits", "units": [], "entries": []})


def test_table_drops_empty_group_and_source():
    out = schema.table({"name": "Heroic Traits", "group": "", "source": "", "entries": []})
    assert "group" not in out and "source" not in out


def test_faction_lore_points_default_to_zero():
    out = schema.faction(fac(lores=[{"name": "Lore of Shadows", "kind": "spell", "entries": []}]))
    assert out["lores"][0]["points"] == 0


def test_faction_lore_keeps_points():
    out = schema.faction(fac(lores=[{"name": "Bloodshadow Rites", "kind": "prayer", "points": 20, "entries": []}]))
    assert out["lores"][0]["points"] == 20


def test_faction_lore_points_come_after_kind():
    keys = list(schema.faction(fac(lores=[{"name": "Lore", "kind": "spell", "entries": []}]))["lores"][0])
    assert keys == ["name", "kind", "points", "entries"]


def test_army_of_renown_text_defaults_to_empty():
    out = schema.army_of_renown({"name": "Host", "battle_traits": [], "enhancement_tables": [], "lores": []})
    assert out["text"] == ""


def aor(**kw):
    a = {"name": "Host", "battle_traits": [], "enhancement_tables": [], "lores": []}
    a.update(kw)
    return a


def test_army_of_renown_keeps_legends_when_set():
    assert schema.army_of_renown(aor(legends=True))["legends"] is True


@pytest.mark.parametrize("army", [aor(), aor(legends=False), aor(legends=None)], ids=["absent", "false", "none"])
def test_army_of_renown_omits_legends_when_not_set(army):
    assert "legends" not in schema.army_of_renown(army)


def test_army_of_renown_legends_comes_between_source_and_text():
    keys = list(schema.army_of_renown(aor(source="Expansion", legends=True, text="Roster.")))
    assert keys.index("source") < keys.index("legends") < keys.index("text")


def test_army_of_renown_keeps_roster_after_text():
    roster = {"entries": [{"unit": "Hamilcar Bear-Eater"}], "regiments_of_renown": False}
    out = schema.army_of_renown(aor(text="Roster.", roster=roster))
    assert out["roster"] == roster and list(out).index("roster") == list(out).index("text") + 1


def test_army_of_renown_omits_missing_roster():
    assert "roster" not in schema.army_of_renown(aor())


def fac(**kw):
    f = {"id": "test", "name": "Test", "grand_alliance": "Order", "battle_traits": [],
         "battle_formations": [], "enhancement_tables": [], "lores": []}
    f.update(kw)
    return f


def test_faction_keeps_legends_when_set():
    assert schema.faction(fac(legends=True))["legends"] is True


@pytest.mark.parametrize("f", [fac(), fac(legends=False), fac(legends=None)], ids=["absent", "false", "none"])
def test_faction_omits_legends_when_not_set(f):
    assert "legends" not in schema.faction(f)


def test_faction_legends_comes_right_after_grand_alliance():
    keys = list(schema.faction(fac(legends=True)))
    assert keys.index("legends") == keys.index("grand_alliance") + 1


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


# split_frequency()

@pytest.mark.parametrize("timing, expected", [
    ("Once Per Turn (Army), Any Combat Phase", ("Once Per Turn (Army)", "Any Combat Phase")),
    ("Once Per Battle, Deployment Phase", ("Once Per Battle", "Deployment Phase")),
    ("Once Per Phase, Reaction: You declared a FIGHT ability", ("Once Per Phase", "Reaction: You declared a FIGHT ability")),
    ("Once Per Turn (Army, Each Player), Any Hero Phase", ("Once Per Turn (Army, Each Player)", "Any Hero Phase")),
])
def test_split_frequency_separates_frequency_from_timing(timing, expected):
    assert schema.split_frequency(timing) == expected


@pytest.mark.parametrize("timing, expected", [
    ("Once Per Battle Round, Start of Battle Round", ("Once Per Battle Round", "Start of Battle Round")),
    ("Once Per Battle Round (Army), Start of Battle Round", ("Once Per Battle Round (Army)", "Start of Battle Round")),
])
def test_split_frequency_keeps_battle_round_whole(timing, expected):
    assert schema.split_frequency(timing) == expected


@pytest.mark.parametrize("timing, expected", [
    ("Once Per Battle, (Army) Your Movement Phase", ("Once Per Battle (Army)", "Your Movement Phase")),
    ("Once Per Turn, (Army) Any Combat Phase", ("Once Per Turn (Army)", "Any Combat Phase")),
    ("Once Per Battle Round, (Army) Start of Battle Round", ("Once Per Battle Round (Army)", "Start of Battle Round")),
    ("Once Per Turn, (Army, Each Player) Any Hero Phase", ("Once Per Turn (Army, Each Player)", "Any Hero Phase")),
    ("Once Per Battle, (army) Your Movement Phase", ("Once Per Battle (Army)", "Your Movement Phase")),
])
def test_split_frequency_accepts_comma_before_army(timing, expected):
    assert schema.split_frequency(timing) == expected


def test_split_frequency_with_army_and_no_timing_has_empty_timing():
    assert schema.split_frequency("Once Per Battle (Army)") == ("Once Per Battle (Army)", "")


def test_split_frequency_leaves_other_brackets_in_timing():
    assert schema.split_frequency("Once Per Battle, (Reaction) Any Phase") == ("Once Per Battle", "(Reaction) Any Phase")


@pytest.mark.parametrize("timing, frequency", [
    ("Once per Battle, Start of the First Battle Round", "Once Per Battle"),
    ("Once Per Turn (army), Any Hero Phase", "Once Per Turn (Army)"),
    ("ONCE PER PHASE, Any Shooting Phase", "Once Per Phase"),
])
def test_split_frequency_title_cases_frequency(timing, frequency):
    assert schema.split_frequency(timing)[0] == frequency


def test_split_frequency_leaves_timing_case_alone():
    assert schema.split_frequency("Once per Battle, Start of the First Battle Round")[1] == "Start of the First Battle Round"


def test_split_frequency_of_frequency_alone_has_empty_timing():
    assert schema.split_frequency("Once Per Battle") == ("Once Per Battle", "")


@pytest.mark.parametrize("timing", ["Any Combat Phase", "Passive", "End of Any Turn", ""])
def test_split_frequency_without_frequency_returns_timing_unchanged(timing):
    assert schema.split_frequency(timing) == ("", timing)


def test_split_frequency_ignores_frequency_not_at_start():
    timing = "Any Combat Phase, Once Per Turn"
    assert schema.split_frequency(timing) == ("", timing)


def test_move_drops_inch_mark():
    assert schema.move('6"') == "6"


def test_move_keeps_dice():
    assert schema.move('d6+3"') == "D6+3"


def test_move_keeps_multiple_dice():
    assert schema.move("2D6") == "2D6"


def test_move_of_unmoving_unit_is_zero():
    assert [schema.move("-"), schema.move(None)] == ["0", "0"]


def test_ability_writes_used_by_and_command_points_when_set():
    out = schema.ability({"name": "A", "used_by": "The unit.", "command_points": 2})
    assert (out["used_by"], out["command_points"]) == ("The unit.", 2)


def test_ability_omits_used_by_and_command_points_when_unset():
    out = schema.ability({"name": "A", "used_by": "", "command_points": 0})
    assert "used_by" not in out and "command_points" not in out


def test_ability_orders_used_by_after_declare_and_command_points_after_points():
    out = schema.ability({"name": "A", "command_points": 1, "points": 20, "used_by": "U", "declare": "D", "effect": "E"})
    keys = list(out)
    assert keys.index("used_by") == keys.index("declare") + 1
    assert keys.index("command_points") == keys.index("points") + 1


def test_tidy_converts_fraction_slash_half_to_half_sign():
    assert schema.tidy({"effect": "within 1⁄2\" of it"}) == {"effect": "within ½\" of it"}


def test_ability_keeps_summons():
    assert schema.ability({"name": "A", "summons": ["x"]})["summons"] == ["x"]


def test_ability_omits_empty_summons():
    assert "summons" not in schema.ability({"name": "A", "summons": []})
