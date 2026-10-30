import os, sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import dump


def test_ability_header_has_frequency_timing_name_and_colour():
    a = {"name": "Bloody Rite", "frequency": "Once Per Turn", "timing": "Your Hero Phase", "colour": "green"}
    assert dump.ability(a) == ["  [Once Per Turn, Your Hero Phase] Bloody Rite (green)"]


def test_ability_header_omits_missing_frequency_and_colour():
    assert dump.ability({"name": "Rite", "timing": "Any Phase"}) == ["  [Any Phase] Rite"]


def test_ability_body_lines_in_order():
    a = {"name": "X", "text": "T", "declare": "D", "effect": "E", "keywords": ["A", "B"],
         "options": [{"name": "One", "text": "first"}], "casting_value": 6}
    assert dump.ability(a)[1:] == ["    Casting value: 6", "    Text: T", "    Declare: D", "    Effect: E",
                                   "    One: first", "    Keywords: A, B"]


def test_ability_omits_absent_body_lines():
    assert len(dump.ability({"name": "X"})) == 1


def weapon_dict(**kw):
    w = {"name": "Knife", "range": "", "attacks": 2, "hit": 3, "wound": 4, "rend": 0, "damage": 1}
    w.update(kw)
    return w


def test_melee_weapon_range_is_dash():
    assert dump.weapon(weapon_dict()).split(" | ")[1] == "-"


def test_ranged_weapon_range_has_inch_mark():
    assert dump.weapon(weapon_dict(range=12)).split(" | ")[1] == '12"'


def test_zero_rend_is_dash_and_nonzero_is_shown():
    assert dump.weapon(weapon_dict()).split(" | ")[5] == "-"
    assert dump.weapon(weapon_dict(rend=1)).split(" | ")[5] == "1"


def test_weapon_abilities_joined_or_dash():
    assert dump.weapon(weapon_dict()).endswith("| -")
    assert dump.weapon(weapon_dict(abilities=["Crit (Mortal)", "Anti-X"])).endswith("Crit (Mortal), Anti-X")


def spearhead_dict(**warscroll):
    ws = {"name": "Hero", "move": 6, "health": 5, "save": 4, "control": 2, "keywords": ["HERO"],
          "melee_weapons": [weapon_dict()]}
    ws.update(warscroll)
    return {"name": "Troupe", "general": "Hero",
            "units": [{"count": 1, "name": "Hero", "notes": "General"}, {"count": 3, "name": "Grunt"}],
            "battle_traits": [{"name": "Trait"}], "regiment_abilities": [], "enhancements": [],
            "warscrolls": [ws]}


def test_dump_lists_units_with_notes_only_when_present():
    out = dump.dump(spearhead_dict()).splitlines()
    assert "  1 Hero (General)" in out
    assert "  3 Grunt" in out


def test_dump_stat_line_includes_ward_only_when_present():
    assert "Ward" not in dump.dump(spearhead_dict())
    assert "| Ward 5+" in dump.dump(spearhead_dict(ward=5))


def test_dump_header_and_weapon_headings():
    out = dump.dump(spearhead_dict())
    assert out.startswith("TROUPE\nGeneral: Hero")
    assert "WARSCROLL HERO" in out
    assert " MELEE WEAPONS" in out
    assert "RANGED WEAPONS" not in out


def test_spearhead_matches_name_case_insensitively():
    s = dump.spearhead("daughters_of_khaine", "heartflayer TROUPE")
    assert s["name"] == "Heartflayer Troupe"


def test_spearhead_unknown_name_exits():
    with pytest.raises(SystemExit):
        dump.spearhead("daughters_of_khaine", "No Such Spearhead")
