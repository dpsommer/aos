import pytest

import build


def ability(name):
    return {"name": name, "category": "", "timing": "Passive", "effect": "X."}


def data():
    """A minimal merged faction with a warscroll referenced from a Spearhead."""
    return {
        "faction": {"battle_traits": [ability("Steady Ranks")], "battle_formations": [],
                    "enhancement_tables": [{"name": "Heroic Traits", "entries": [ability("Bold Leader")]}], "lores": []},
        "warscrolls": [
            {"id": "test_captian", "name": "Test Captian", "abilities": [ability("Rally Cry")], "keywords": []},
            {"id": "scourge_of_aqshy_test_captian", "name": "Test Captian", "source": "Scourge of Aqshy",
             "abilities": [], "keywords": []},
            {"id": "test_riders", "name": "Test Riders", "abilities": [], "keywords": []},
        ],
        "armies_of_renown": [{"name": "Host", "battle_traits": [ability("Shared Resolve")],
                              "enhancement_tables": [], "lores": []}],
        "spearheads": [{"name": "Vanguard", "general": "Test Captian",
                        "units": [{"count": 1, "name": "Test Captian"}, {"count": 2, "name": "Test Riders"}],
                        "battle_traits": [], "regiment_abilities": [ability("Drill")], "enhancements": [],
                        "warscrolls": [{"id": "", "name": "Test Captian", "abilities": [], "keywords": []}]}],
        "path_to_glory": [],
    }


RENAME = {"warscroll_names": {"Test Captian": "Test Captain"}}


def test_rename_changes_warscroll_names():
    d = data()
    build.apply_overrides(d, RENAME)
    assert [w["name"] for w in d["warscrolls"][:2]] == ["Test Captain", "Test Captain"]


def test_rename_updates_ids_keeping_scourge_prefix():
    d = data()
    build.apply_overrides(d, RENAME)
    assert [w["id"] for w in d["warscrolls"][:2]] == ["test_captain", "scourge_of_aqshy_test_captain"]


def test_rename_leaves_empty_id_empty():
    d = data()
    build.apply_overrides(d, RENAME)
    assert d["spearheads"][0]["warscrolls"][0]["id"] == ""


def test_rename_updates_spearhead_warscroll():
    d = data()
    build.apply_overrides(d, RENAME)
    assert d["spearheads"][0]["warscrolls"][0]["name"] == "Test Captain"


def test_rename_updates_spearhead_general():
    d = data()
    build.apply_overrides(d, RENAME)
    assert d["spearheads"][0]["general"] == "Test Captain"


def test_rename_updates_only_matching_spearhead_units():
    d = data()
    build.apply_overrides(d, RENAME)
    assert [u["name"] for u in d["spearheads"][0]["units"]] == ["Test Captain", "Test Riders"]


def test_rename_matching_no_warscroll_exits():
    with pytest.raises(SystemExit):
        build.apply_overrides(data(), {"warscroll_names": {"Nobody": "Somebody"}})


def test_field_override_by_warscroll_id():
    d = data()
    build.apply_overrides(d, {"fields": {"scourge_of_aqshy_test_captian": {"keywords": ["HERO"]}}})
    assert [w["keywords"] for w in d["warscrolls"][:2]] == [[], ["HERO"]]


def test_field_override_by_warscroll_name_applies_to_every_version():
    d = data()
    build.apply_overrides(d, {"fields": {"Test Captian": {"keywords": ["HERO"]}}})
    assert [w["keywords"] for w in d["warscrolls"][:2]] == [["HERO"], ["HERO"]]


@pytest.mark.parametrize("path", [
    lambda d: d["faction"]["battle_traits"][0],
    lambda d: d["faction"]["enhancement_tables"][0]["entries"][0],
    lambda d: d["warscrolls"][0]["abilities"][0],
    lambda d: d["armies_of_renown"][0]["battle_traits"][0],
    lambda d: d["spearheads"][0]["regiment_abilities"][0],
])
def test_field_override_by_ability_name(path):
    d = data()
    build.apply_overrides(d, {"fields": {path(d)["name"]: {"timing": "Any Hero Phase"}}})
    assert path(d)["timing"] == "Any Hero Phase"


def test_field_override_matching_nothing_exits():
    with pytest.raises(SystemExit):
        build.apply_overrides(data(), {"fields": {"Nothing": {"health": 1}}})


def test_field_override_applies_after_rename():
    d = data()
    build.apply_overrides(d, dict(RENAME, fields={"test_captain": {"health": 6}}))
    assert d["warscrolls"][0]["health"] == 6


def test_no_overrides_changes_nothing():
    d = data()
    build.apply_overrides(d, {})
    assert d == data()
