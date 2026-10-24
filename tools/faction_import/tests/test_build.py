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


def weapon(name):
    return {"name": name, "attacks": "2", "hit": "4+", "wound": "4+", "rend": "-", "damage": "1"}


def armed():
    """Two warscrolls that each have a weapon and an ability called Hellblade."""
    d = data()
    for w in d["warscrolls"][:2]:
        w.update(ranged_weapons=[], melee_weapons=[weapon("Hellblade")], abilities=[ability("Hellblade")])
    return d


def test_field_override_by_weapon_name():
    d = data()
    d["warscrolls"][2].update(ranged_weapons=[weapon("Lance")], melee_weapons=[])
    build.apply_overrides(d, {"fields": {"Lance": {"rend": "1"}}})
    assert d["warscrolls"][2]["ranged_weapons"][0]["rend"] == "1"


def test_unscoped_field_override_prefers_ability_over_weapon():
    d = armed()
    build.apply_overrides(d, {"fields": {"Hellblade": {"damage": "3"}}})
    ws = d["warscrolls"][0]
    assert (ws["abilities"][0].get("damage"), ws["melee_weapons"][0]["damage"]) == ("3", "1")


def test_scoped_field_override_changes_only_that_warscroll():
    d = armed()
    build.apply_overrides(d, {"fields": {"scourge_of_aqshy_test_captian > Hellblade": {"timing": "Deployment"}}})
    assert [w["abilities"][0]["timing"] for w in d["warscrolls"][:2]] == ["Passive", "Deployment"]


def test_scoped_field_override_reaches_weapon_and_ability_of_same_name():
    d = armed()
    build.apply_overrides(d, {"fields": {"test_captian > Hellblade": {"note": "n"}}})
    ws = d["warscrolls"][0]
    assert [x.get("note") for x in ws["melee_weapons"] + ws["abilities"]] == ["n", "n"]


@pytest.mark.parametrize("target", ["test_captian > Nothing", "nobody > Hellblade"])
def test_unmatched_scoped_field_override_exits(target):
    with pytest.raises(SystemExit):
        build.apply_overrides(armed(), {"fields": {target: {"note": "n"}}})


# replace_with_wahapedia()

def wh_ability(name, effect):
    return {"name": name, "category": "", "timing": "Any Hero Phase", "effect": effect, "keywords": ["CORE"]}


def test_replacement_takes_wahapedia_ability_content():
    d = data()
    wh = wh_ability("Rally Cry", "Better rule.")
    build.replace_with_wahapedia(d, {"Rally Cry": "Rally Cry"}, [wh])
    assert d["warscrolls"][0]["abilities"][0] == wh


def test_replacement_uses_given_wahapedia_name_and_matches_it_normalised():
    d = data()
    build.replace_with_wahapedia(d, {"Bold Leader": "Bold Leader!"}, [wh_ability("BOLD LEADER", "Y.")])
    assert d["faction"]["enhancement_tables"][0]["entries"][0]["name"] == "Bold Leader!"


def test_replacement_drops_bsdata_only_fields():
    d = data()
    d["faction"]["battle_traits"][0]["options"] = [{"name": "A", "text": "B"}]
    build.replace_with_wahapedia(d, {"Steady Ranks": "Steady Ranks"}, [wh_ability("Steady Ranks", "Y.")])
    assert "options" not in d["faction"]["battle_traits"][0]


def test_replacement_applies_to_every_ability_with_the_name():
    d = data()
    d["warscrolls"][2]["abilities"] = [ability("Rally Cry")]
    build.replace_with_wahapedia(d, {"Rally Cry": "Rally Cry"}, [wh_ability("Rally Cry", "Better rule.")])
    assert [w["abilities"][0]["effect"] for w in (d["warscrolls"][0], d["warscrolls"][2])] == ["Better rule."] * 2


def test_replacements_are_independent_copies():
    d = data()
    wh = wh_ability("Drill", "Y.")
    build.replace_with_wahapedia(d, {"Drill": "Drill"}, [wh])
    d["spearheads"][0]["regiment_abilities"][0]["effect"] = "changed"
    assert wh["effect"] == "Y."


def test_replacement_leaves_other_abilities_alone():
    d = data()
    build.replace_with_wahapedia(d, {"Drill": "Drill"}, [wh_ability("Drill", "Y.")])
    assert d["faction"]["battle_traits"][0] == ability("Steady Ranks")


def test_replacement_without_wahapedia_ability_exits():
    with pytest.raises(SystemExit):
        build.replace_with_wahapedia(data(), {"Drill": "Drill"}, [wh_ability("Other", "Y.")])


def test_replacement_without_bsdata_ability_exits():
    with pytest.raises(SystemExit):
        build.replace_with_wahapedia(data(), {"Nothing": "Drill"}, [wh_ability("Drill", "Y.")])


def test_army_of_renown_scoped_replacement_changes_that_army_ability():
    d = data()
    build.replace_with_wahapedia(d, {"Host > Shared Resolve": "Shared Resolve"}, [wh_ability("Shared Resolve", "Y.")])
    assert d["armies_of_renown"][0]["battle_traits"][0]["effect"] == "Y."


@pytest.mark.parametrize("group", ["enhancement_tables", "lores"])
def test_army_of_renown_scoped_replacement_reaches_table_entries(group):
    d = data()
    d["armies_of_renown"][0][group] = [{"name": "Table", "entries": [ability("Gift")]}]
    build.replace_with_wahapedia(d, {"Host > Gift": "Gift"}, [wh_ability("Gift", "Y.")])
    assert d["armies_of_renown"][0][group][0]["entries"][0]["effect"] == "Y."


def test_army_of_renown_scoped_replacement_leaves_same_named_ability_elsewhere_alone():
    d = data()
    d["faction"]["battle_traits"].append(ability("Shared Resolve"))
    build.replace_with_wahapedia(d, {"Host > Shared Resolve": "Shared Resolve"}, [wh_ability("Shared Resolve", "Y.")])
    assert d["faction"]["battle_traits"][1] == ability("Shared Resolve")


def test_warscroll_scoped_replacement_changes_that_warscroll_ability():
    d = data()
    build.replace_with_wahapedia(d, {"test_captian > Rally Cry": "Rally Cry"}, [wh_ability("Rally Cry", "Y.")])
    assert d["warscrolls"][0]["abilities"][0]["effect"] == "Y."


def test_warscroll_scoped_replacement_leaves_same_named_ability_elsewhere_alone():
    d = data()
    d["warscrolls"][2]["abilities"] = [ability("Rally Cry")]
    build.replace_with_wahapedia(d, {"test_captian > Rally Cry": "Rally Cry"}, [wh_ability("Rally Cry", "Y.")])
    assert d["warscrolls"][2]["abilities"][0] == ability("Rally Cry")


@pytest.mark.parametrize("bs_name", ["nobody > Rally Cry", "test_riders > Rally Cry", "Host > Rally Cry"])
def test_unmatched_scoped_replacement_exits(bs_name):
    with pytest.raises(SystemExit):
        build.replace_with_wahapedia(data(), {bs_name: "Rally Cry"}, [wh_ability("Rally Cry", "Y.")])


# wahapedia_abilities()

def wh_page():
    """A Wahapedia faction page with one ability in every place one can be."""
    def table(n):
        return [{"name": "Table", "entries": [ability(n)]}]
    return {
        "faction": {"battle_traits": [ability("Trait")], "battle_formations": [{"name": "F", "abilities": [ability("Formation")]}],
                    "enhancement_tables": table("Enhancement"), "lores": table("Lore")},
        "armies_of_renown": [{"name": "Host", "battle_traits": [ability("AoR Trait")],
                              "enhancement_tables": table("AoR Enhancement"), "lores": table("AoR Lore")}],
        "spearheads": [{"name": "Vanguard", "battle_traits": [ability("SH Trait")],
                        "regiment_abilities": [ability("SH Regiment")], "enhancements": [ability("SH Enhancement")]}],
    }


@pytest.mark.parametrize("name", ["Trait", "Formation", "Enhancement", "Lore", "AoR Trait", "AoR Enhancement",
                                  "AoR Lore", "SH Trait", "SH Regiment", "SH Enhancement"])
def test_wahapedia_abilities_collects_faction_page_ability(name):
    assert name in [a["name"] for a in build.wahapedia_abilities(wh_page(), [])]


def test_wahapedia_abilities_collects_unit_abilities():
    units = [{"name": "Test Riders", "abilities": [ability("Charge")]}]
    assert "Charge" in [a["name"] for a in build.wahapedia_abilities(wh_page(), units)]


def test_wahapedia_abilities_collects_each_ability_once():
    names = [a["name"] for a in build.wahapedia_abilities(wh_page(), [])]
    assert len(names) == len(set(names))

