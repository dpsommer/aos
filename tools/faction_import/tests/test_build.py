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


def test_field_override_by_army_of_renown_name():
    d = data()
    build.apply_overrides(d, {"fields": {"Host": {"legends": True}}})
    assert d["armies_of_renown"][0]["legends"] is True


def test_field_override_by_army_of_renown_name_leaves_other_armies_alone():
    d = data()
    d["armies_of_renown"].append({"name": "Other Host", "battle_traits": [], "enhancement_tables": [], "lores": []})
    build.apply_overrides(d, {"fields": {"Host": {"legends": True}}})
    assert "legends" not in d["armies_of_renown"][1]


def test_field_override_prefers_warscroll_over_army_of_renown_of_same_name():
    d = data()
    d["armies_of_renown"][0]["name"] = "Test Riders"
    build.apply_overrides(d, {"fields": {"Test Riders": {"legends": True}}})
    assert (d["warscrolls"][2].get("legends"), d["armies_of_renown"][0].get("legends")) == (True, None)


def test_field_override_prefers_army_of_renown_over_ability_of_same_name():
    d = data()
    d["armies_of_renown"][0]["name"] = "Steady Ranks"
    build.apply_overrides(d, {"fields": {"Steady Ranks": {"legends": True}}})
    assert (d["armies_of_renown"][0].get("legends"), d["faction"]["battle_traits"][0].get("legends")) == (True, None)


def test_field_override_matching_nothing_exit_message_mentions_army_of_renown():
    with pytest.raises(SystemExit) as exc:
        build.apply_overrides(data(), {"fields": {"Nothing": {"health": 1}}})
    assert "Army of Renown" in str(exc.value)


def test_field_override_applies_after_rename():
    d = data()
    build.apply_overrides(d, dict(RENAME, fields={"test_captain": {"health": 6}}))
    assert d["warscrolls"][0]["health"] == 6


def test_no_overrides_changes_nothing():
    d = data()
    build.apply_overrides(d, {})
    assert d == data()


def test_faction_override_sets_faction_field():
    d = data()
    build.apply_overrides(d, {"faction": {"legends": True}})
    assert d["faction"]["legends"] is True


def test_faction_override_keeps_other_faction_fields():
    d = data()
    build.apply_overrides(d, {"faction": {"legends": True}})
    del d["faction"]["legends"]
    assert d == data()


def test_faction_override_replaces_existing_faction_field():
    d = data()
    replacement = [ability("Iron Will")]
    build.apply_overrides(d, {"faction": {"battle_traits": replacement}})
    assert d["faction"]["battle_traits"] == replacement


def test_faction_override_leaves_warscrolls_and_armies_alone():
    d = data()
    build.apply_overrides(d, {"faction": {"legends": True}})
    assert "legends" not in d["armies_of_renown"][0]
    assert all("legends" not in w for w in d["warscrolls"])


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



# rename_armies()

def armies():
    return [{"name": "New Summercourt", "battle_traits": []}, {"name": "Other Host", "battle_traits": []}]


def test_rename_armies_renames_matching_army():
    a = armies()
    build.rename_armies(a, {"New Summercourt": "The Knights of New Summercourt"})
    assert a[0]["name"] == "The Knights of New Summercourt"


def test_rename_armies_leaves_other_armies_alone():
    a = armies()
    build.rename_armies(a, {"New Summercourt": "The Knights of New Summercourt"})
    assert a[1] == armies()[1]


def test_rename_armies_without_names_changes_nothing():
    a = armies()
    build.rename_armies(a, {})
    assert a == armies()


def test_rename_armies_matching_nothing_exits():
    with pytest.raises(SystemExit):
        build.rename_armies(armies(), {"Nowhere": "Somewhere"})


def test_build_renames_armies_before_merging(tmp_path, monkeypatch):
    (tmp_path / "faction.html").write_text("<html></html>", encoding="utf-8")
    merged = []
    monkeypatch.setattr(build.bsdata, "faction_files", lambda d, n: [])
    monkeypatch.setattr(build.bsdata, "Catalogues", lambda d, files: None)
    monkeypatch.setattr(build.bsdata, "read_faction", lambda cats, n: ({}, [], armies()))
    monkeypatch.setattr(build.wahapedia, "parse_faction_page", lambda p: {
        "faction": {}, "armies_of_renown": [], "spearheads": [], "path_to_glory": []})
    monkeypatch.setattr(build.wahapedia, "parse_unit_pages", lambda paths: [])
    monkeypatch.setattr(build, "wahapedia_abilities", lambda page, units: [])
    monkeypatch.setattr(build.merge, "merge_faction", lambda report, bs, wh: {})
    monkeypatch.setattr(build.merge, "merge_warscrolls", lambda report, bs, wh: [])
    monkeypatch.setattr(build.merge, "merge_armies", lambda report, bs, wh: merged.extend(a["name"] for a in bs) or bs)
    build.build("bs", str(tmp_path), "id", "Faction", {"army_names": {"New Summercourt": "The Knights"}})
    assert merged == ["The Knights", "Other Host"]


# rename_wahapedia_warscrolls()

def test_rename_wahapedia_warscrolls_renames_matching_unit():
    units = [{"name": "Monsta-killaz"}, {"name": "Gutrippaz"}]
    build.rename_wahapedia_warscrolls(units, {"Monsta-killaz": "Kruleboyz Monsta-killaz"})
    assert [u["name"] for u in units] == ["Kruleboyz Monsta-killaz", "Gutrippaz"]


def test_rename_wahapedia_warscrolls_renames_every_unit_with_that_name():
    units = [{"name": "Monsta-killaz"}, {"name": "Monsta-killaz"}]
    build.rename_wahapedia_warscrolls(units, {"Monsta-killaz": "Kruleboyz Monsta-killaz"})
    assert [u["name"] for u in units] == ["Kruleboyz Monsta-killaz"] * 2


def test_rename_wahapedia_warscrolls_without_names_changes_nothing():
    units = [{"name": "Gutrippaz"}]
    build.rename_wahapedia_warscrolls(units, {})
    assert units == [{"name": "Gutrippaz"}]


def test_rename_wahapedia_warscrolls_matching_nothing_exits():
    with pytest.raises(SystemExit):
        build.rename_wahapedia_warscrolls([{"name": "Gutrippaz"}], {"Nowhere": "Somewhere"})


def test_build_renames_wahapedia_warscrolls_before_merging(tmp_path, monkeypatch):
    (tmp_path / "faction.html").write_text("<html></html>", encoding="utf-8")
    merged = []
    monkeypatch.setattr(build.bsdata, "faction_files", lambda d, n: [])
    monkeypatch.setattr(build.bsdata, "Catalogues", lambda d, files: None)
    monkeypatch.setattr(build.bsdata, "read_faction", lambda cats, n: ({}, [], []))
    monkeypatch.setattr(build.wahapedia, "parse_faction_page", lambda p: {
        "faction": {}, "armies_of_renown": [], "spearheads": [], "path_to_glory": []})
    monkeypatch.setattr(build.wahapedia, "parse_unit_pages", lambda paths: [{"name": "Monsta-killaz", "abilities": []}])
    monkeypatch.setattr(build, "wahapedia_abilities", lambda page, units: [])
    monkeypatch.setattr(build.merge, "merge_faction", lambda report, bs, wh: {})
    monkeypatch.setattr(build.merge, "merge_warscrolls", lambda report, bs, wh: merged.extend(w["name"] for w in wh) or [])
    monkeypatch.setattr(build.merge, "merge_armies", lambda report, bs, wh: [])
    build.build("bs", str(tmp_path), "id", "Faction",
                {"wahapedia_warscroll_names": {"Monsta-killaz": "Kruleboyz Monsta-killaz"}})
    assert merged == ["Kruleboyz Monsta-killaz"]


# fields scoped to an Army of Renown

def test_army_of_renown_scoped_field_override_changes_that_army_battle_trait():
    d = data()
    build.apply_overrides(d, {"fields": {"Host > Shared Resolve": {"timing": "Deployment"}}})
    assert d["armies_of_renown"][0]["battle_traits"][0]["timing"] == "Deployment"


@pytest.mark.parametrize("group", ["enhancement_tables", "lores"])
def test_army_of_renown_scoped_field_override_reaches_table_entries(group):
    d = data()
    d["armies_of_renown"][0][group] = [{"name": "Table", "entries": [ability("Gift")]}]
    build.apply_overrides(d, {"fields": {"Host > Gift": {"timing": "Deployment"}}})
    assert d["armies_of_renown"][0][group][0]["entries"][0]["timing"] == "Deployment"


def test_army_of_renown_scoped_field_override_leaves_same_named_ability_in_other_army_alone():
    d = data()
    d["armies_of_renown"].append({"name": "Other Host", "battle_traits": [ability("Shared Resolve")],
                                  "enhancement_tables": [], "lores": []})
    build.apply_overrides(d, {"fields": {"Host > Shared Resolve": {"timing": "Deployment"}}})
    assert d["armies_of_renown"][1]["battle_traits"][0] == ability("Shared Resolve")


def test_army_of_renown_scoped_field_override_leaves_same_named_faction_ability_alone():
    d = data()
    d["faction"]["battle_traits"].append(ability("Shared Resolve"))
    build.apply_overrides(d, {"fields": {"Host > Shared Resolve": {"timing": "Deployment"}}})
    assert d["faction"]["battle_traits"][1] == ability("Shared Resolve")


def test_unmatched_army_of_renown_scoped_field_override_exits():
    with pytest.raises(SystemExit):
        build.apply_overrides(data(), {"fields": {"Host > Rally Cry": {"timing": "Deployment"}}})


# fields and replacements scoped to a faction enhancement table or lore

def with_sourced_lores(d):
    """[d] with two faction lores named "Gifts" that differ by source, each with an entry named "Ichor"."""
    d["faction"]["lores"] = [{"name": "Gifts", "entries": [ability("Ichor")]},
                             {"name": "Gifts", "source": "Scourge of Ghyran", "entries": [ability("Ichor")]}]
    return d


def test_lore_scoped_field_override_changes_that_lore_entry():
    d = data()
    d["faction"]["lores"] = [{"name": "Gifts", "entries": [ability("Ichor")]}]
    build.apply_overrides(d, {"fields": {"Gifts > Ichor": {"timing": "Deployment"}}})
    assert d["faction"]["lores"][0]["entries"][0]["timing"] == "Deployment"


def test_enhancement_table_scoped_field_override_changes_that_table_entry():
    d = data()
    build.apply_overrides(d, {"fields": {"Heroic Traits > Bold Leader": {"timing": "Deployment"}}})
    assert d["faction"]["enhancement_tables"][0]["entries"][0]["timing"] == "Deployment"


def test_sourced_lore_scoped_field_override_changes_lore_with_that_source():
    d = with_sourced_lores(data())
    build.apply_overrides(d, {"fields": {"Gifts (Scourge of Ghyran) > Ichor": {"timing": "Deployment"}}})
    assert d["faction"]["lores"][1]["entries"][0]["timing"] == "Deployment"


def test_sourced_lore_scoped_field_override_leaves_lore_with_other_source_alone():
    d = with_sourced_lores(data())
    build.apply_overrides(d, {"fields": {"Gifts (Scourge of Ghyran) > Ichor": {"timing": "Deployment"}}})
    assert d["faction"]["lores"][0]["entries"][0] == ability("Ichor")


def test_lore_scoped_field_override_leaves_same_named_ability_elsewhere_alone():
    d = data()
    d["faction"]["lores"] = [{"name": "Gifts", "entries": [ability("Rally Cry")]}]
    build.apply_overrides(d, {"fields": {"Gifts > Rally Cry": {"timing": "Deployment"}}})
    assert d["warscrolls"][0]["abilities"][0] == ability("Rally Cry")


@pytest.mark.parametrize("target", ["Gifts > Rally Cry", "Gifts (Scourge of Aqshy) > Ichor"])
def test_unmatched_lore_scoped_field_override_exits(target):
    d = with_sourced_lores(data())
    with pytest.raises(SystemExit):
        build.apply_overrides(d, {"fields": {target: {"timing": "Deployment"}}})


def test_lore_scoped_replacement_changes_that_lore_entry():
    d = data()
    d["faction"]["lores"] = [{"name": "Gifts", "entries": [ability("Ichor")]}]
    build.replace_with_wahapedia(d, {"Gifts > Ichor": "Ichor"}, [wh_ability("Ichor", "Y.")])
    assert d["faction"]["lores"][0]["entries"][0]["effect"] == "Y."


def test_enhancement_table_scoped_replacement_changes_that_table_entry():
    d = data()
    build.replace_with_wahapedia(d, {"Heroic Traits > Bold Leader": "Bold Leader"}, [wh_ability("Bold Leader", "Y.")])
    assert d["faction"]["enhancement_tables"][0]["entries"][0]["effect"] == "Y."


def test_sourced_lore_scoped_replacement_changes_only_lore_with_that_source():
    d = with_sourced_lores(data())
    build.replace_with_wahapedia(d, {"Gifts (Scourge of Ghyran) > Ichor": "Ichor"}, [wh_ability("Ichor", "Y.")])
    assert [l["entries"][0]["effect"] for l in d["faction"]["lores"]] == ["X.", "Y."]


def test_lore_scoped_replacement_leaves_same_named_ability_elsewhere_alone():
    d = data()
    d["faction"]["lores"] = [{"name": "Gifts", "entries": [ability("Rally Cry")]}]
    build.replace_with_wahapedia(d, {"Gifts > Rally Cry": "Rally Cry"}, [wh_ability("Rally Cry", "Y.")])
    assert d["warscrolls"][0]["abilities"][0] == ability("Rally Cry")


@pytest.mark.parametrize("bs_name", ["Gifts > Rally Cry", "Gifts (Scourge of Aqshy) > Ichor"])
def test_unmatched_lore_scoped_replacement_exits(bs_name):
    d = with_sourced_lores(data())
    with pytest.raises(SystemExit):
        build.replace_with_wahapedia(d, {bs_name: "Ichor"}, [wh_ability("Ichor", "Y.")])
