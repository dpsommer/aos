import copy, json, os

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


def test_rename_updates_enhancement_table_units():
    d = data()
    d["faction"]["enhancement_tables"][0]["units"] = ["Test Riders", "Test Captian"]
    build.apply_overrides(d, RENAME)
    assert d["faction"]["enhancement_tables"][0]["units"] == ["Test Captain", "Test Riders"]


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


# remove_armies()

def test_remove_armies_removes_named_army():
    a = armies()
    build.remove_armies(a, ["Other Host"])
    assert [x["name"] for x in a] == ["New Summercourt"]


def test_remove_armies_removes_in_place():
    a = armies()
    same = a
    build.remove_armies(a, ["Other Host"])
    assert same is a and len(same) == 1


def test_remove_armies_removes_every_named_army():
    a = armies()
    build.remove_armies(a, ["Other Host", "New Summercourt"])
    assert a == []


def test_remove_armies_without_names_changes_nothing():
    a = armies()
    build.remove_armies(a, [])
    assert a == armies()


def test_remove_armies_matching_nothing_exits():
    with pytest.raises(SystemExit):
        build.remove_armies(armies(), ["Nowhere"])


def stub_build(monkeypatch, tmp_path, bs_armies, seen):
    (tmp_path / "faction.html").write_text("<html></html>", encoding="utf-8")
    monkeypatch.setattr(build.bsdata, "faction_files", lambda d, n, extra=(): seen.append(("files", list(extra))) or [])
    monkeypatch.setattr(build.bsdata, "Catalogues", lambda d, files: None)
    monkeypatch.setattr(build.bsdata, "read_faction", lambda cats, n, extra=(): (
        seen.append(("read", list(extra))) or ({}, [], bs_armies)))
    monkeypatch.setattr(build.wahapedia, "parse_faction_page", lambda p: {
        "faction": {}, "armies_of_renown": [], "spearheads": [], "path_to_glory": []})
    monkeypatch.setattr(build.wahapedia, "parse_unit_pages", lambda paths: [])
    monkeypatch.setattr(build, "wahapedia_abilities", lambda page, units: [])
    monkeypatch.setattr(build.merge, "merge_faction", lambda report, bs, wh: {})
    monkeypatch.setattr(build, "link_summons", lambda data, core, others: None)
    monkeypatch.setattr(build.merge, "merge_warscrolls", lambda report, bs, wh: [])
    monkeypatch.setattr(build.merge, "merge_armies", lambda report, bs, wh: seen.append(("armies", [a["name"] for a in bs])) or bs)


def test_build_passes_armies_of_renown_from_to_bsdata(tmp_path, monkeypatch):
    seen = []
    stub_build(monkeypatch, tmp_path, armies(), seen)
    build.build("bs", str(tmp_path), "id", "Faction", {"armies_of_renown_from": ["Other - Host"]})
    assert ("files", ["Other - Host"]) in seen and ("read", ["Other - Host"]) in seen


def test_build_without_armies_of_renown_from_passes_no_extra_armies(tmp_path, monkeypatch):
    seen = []
    stub_build(monkeypatch, tmp_path, armies(), seen)
    build.build("bs", str(tmp_path), "id", "Faction", {})
    assert ("files", []) in seen and ("read", []) in seen


def test_build_removes_armies_of_renown_before_merging(tmp_path, monkeypatch):
    seen = []
    stub_build(monkeypatch, tmp_path, armies(), seen)
    build.build("bs", str(tmp_path), "id", "Faction", {"remove_armies_of_renown": ["Other Host"]})
    assert ("armies", ["New Summercourt"]) in seen


def test_build_removing_unknown_army_of_renown_exits(tmp_path, monkeypatch):
    stub_build(monkeypatch, tmp_path, armies(), [])
    with pytest.raises(SystemExit):
        build.build("bs", str(tmp_path), "id", "Faction", {"remove_armies_of_renown": ["Nowhere"]})


def test_build_renames_armies_before_merging(tmp_path, monkeypatch):
    (tmp_path / "faction.html").write_text("<html></html>", encoding="utf-8")
    merged = []
    monkeypatch.setattr(build.bsdata, "faction_files", lambda d, n, extra=(): [])
    monkeypatch.setattr(build.bsdata, "Catalogues", lambda d, files: None)
    monkeypatch.setattr(build.bsdata, "read_faction", lambda cats, n, extra=(): ({}, [], armies()))
    monkeypatch.setattr(build.wahapedia, "parse_faction_page", lambda p: {
        "faction": {}, "armies_of_renown": [], "spearheads": [], "path_to_glory": []})
    monkeypatch.setattr(build.wahapedia, "parse_unit_pages", lambda paths: [])
    monkeypatch.setattr(build, "wahapedia_abilities", lambda page, units: [])
    monkeypatch.setattr(build.merge, "merge_faction", lambda report, bs, wh: {})
    monkeypatch.setattr(build, "link_summons", lambda data, core, others: None)
    monkeypatch.setattr(build.merge, "merge_warscrolls", lambda report, bs, wh: [])
    monkeypatch.setattr(build.merge, "merge_armies", lambda report, bs, wh: merged.extend(a["name"] for a in bs) or bs)
    build.build("bs", str(tmp_path), "id", "Faction", {"army_names": {"New Summercourt": "The Knights"}})
    assert merged == ["The Knights", "Other Host"]



def test_build_links_summons_after_the_overrides(tmp_path, monkeypatch):
    (tmp_path / "faction.html").write_text("<html></html>", encoding="utf-8")
    seen = []
    monkeypatch.setattr(build.bsdata, "faction_files", lambda d, n, extra=(): [])
    monkeypatch.setattr(build.bsdata, "Catalogues", lambda d, files: None)
    monkeypatch.setattr(build.bsdata, "read_faction", lambda cats, n, extra=(): ({}, [], []))
    monkeypatch.setattr(build.wahapedia, "parse_faction_page", lambda p: {
        "faction": {}, "armies_of_renown": [], "spearheads": [], "path_to_glory": []})
    monkeypatch.setattr(build.wahapedia, "parse_unit_pages", lambda paths: [])
    monkeypatch.setattr(build, "wahapedia_abilities", lambda page, units: [])
    monkeypatch.setattr(build.merge, "merge_faction", lambda report, bs, wh: {})
    monkeypatch.setattr(build.merge, "merge_warscrolls", lambda report, bs, wh: [])
    monkeypatch.setattr(build.merge, "merge_armies", lambda report, bs, wh: bs)
    monkeypatch.setattr(build, "other_manifestations", lambda faction_id: ["others of " + faction_id])
    monkeypatch.setattr(build, "link_summons",
                        lambda data, core, others: seen.append((data["faction"].get("legends"), others)))
    build.build("bs", str(tmp_path), "id", "Faction", {"faction": {"legends": True}})
    assert seen == [(True, ["others of id"])]


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
    monkeypatch.setattr(build.bsdata, "faction_files", lambda d, n, extra=(): [])
    monkeypatch.setattr(build.bsdata, "Catalogues", lambda d, files: None)
    monkeypatch.setattr(build.bsdata, "read_faction", lambda cats, n, extra=(): ({}, [], []))
    monkeypatch.setattr(build.wahapedia, "parse_faction_page", lambda p: {
        "faction": {}, "armies_of_renown": [], "spearheads": [], "path_to_glory": []})
    monkeypatch.setattr(build.wahapedia, "parse_unit_pages", lambda paths: [{"name": "Monsta-killaz", "abilities": []}])
    monkeypatch.setattr(build, "wahapedia_abilities", lambda page, units: [])
    monkeypatch.setattr(build.merge, "merge_faction", lambda report, bs, wh: {})
    monkeypatch.setattr(build, "link_summons", lambda data, core, others: None)
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


# build() without Wahapedia

def bs_army(name, roster):
    return {"name": name, "battle_traits": [ability("Shared Resolve")], "enhancement_tables": [], "lores": [],
            "roster": roster}


def bs_faction():
    return {"battle_traits": [ability("Steady Ranks")], "battle_formations": [], "enhancement_tables": [], "lores": []}


@pytest.fixture
def bsdata_only(monkeypatch):
    """Stubs BSData with a small faction, and makes reading any Wahapedia page fail the test."""
    def no_wahapedia(*args):
        raise AssertionError("Wahapedia was read")
    monkeypatch.setattr(build.bsdata, "faction_files", lambda d, n, extra=(): [])
    monkeypatch.setattr(build.bsdata, "Catalogues", lambda d, files: None)
    monkeypatch.setattr(build.bsdata, "read_faction", lambda cats, n, extra=(): (
        bs_faction(),
        [{"id": "test_captain", "name": "Test Captain", "abilities": [ability("Rally Cry")], "keywords": []}],
        [bs_army("Throng", ["Test Captain", "Test Riders"])]))
    monkeypatch.setattr(build.wahapedia, "parse_faction_page", no_wahapedia)
    monkeypatch.setattr(build.wahapedia, "parse_unit_pages", no_wahapedia)


def test_build_without_wahapedia_reads_no_wahapedia_page(bsdata_only):
    build.build("bs", None, "id", "Faction", {})


def test_build_without_wahapedia_has_empty_report(bsdata_only):
    _, report = build.build("bs", None, "id", "Faction", {})
    assert report.lines == []


def test_build_without_wahapedia_keeps_bsdata_warscrolls(bsdata_only):
    data, _ = build.build("bs", None, "id", "Faction", {})
    assert [w["name"] for w in data["warscrolls"]] == ["Test Captain"]


def test_build_without_wahapedia_sets_faction_id(bsdata_only):
    data, _ = build.build("bs", None, "khazalite_holds", "Faction", {})
    assert data["faction"]["id"] == "khazalite_holds"


def test_build_without_wahapedia_has_no_spearheads(bsdata_only):
    data, _ = build.build("bs", None, "id", "Faction", {})
    assert data["spearheads"] == []


def test_build_without_wahapedia_has_no_path_to_glory(bsdata_only):
    data, _ = build.build("bs", None, "id", "Faction", {})
    assert data["path_to_glory"] == []


def test_build_without_wahapedia_gives_armies_roster_text(bsdata_only):
    data, _ = build.build("bs", None, "id", "Faction", {})
    assert data["armies_of_renown"][0]["text"].splitlines() == ["Roster options:", "Test Captain", "Test Riders"]


def test_build_without_wahapedia_drops_army_roster_field(bsdata_only):
    data, _ = build.build("bs", None, "id", "Faction", {})
    assert "roster" not in data["armies_of_renown"][0]


def test_build_without_wahapedia_applies_warscroll_name_override(bsdata_only):
    data, _ = build.build("bs", None, "id", "Faction", {"warscroll_names": {"Test Captain": "Test Thane"}})
    assert data["warscrolls"][0]["name"] == "Test Thane"


def test_build_without_wahapedia_applies_field_override(bsdata_only):
    data, _ = build.build("bs", None, "id", "Faction", {"fields": {"Rally Cry": {"timing": "Any Hero Phase"}}})
    assert data["warscrolls"][0]["abilities"][0]["timing"] == "Any Hero Phase"


def test_build_without_wahapedia_applies_army_name_override(bsdata_only):
    data, _ = build.build("bs", None, "id", "Faction", {"army_names": {"Throng": "The Throng"}})
    assert data["armies_of_renown"][0]["name"] == "The Throng"


def test_build_without_wahapedia_rejects_override_matching_nothing(bsdata_only):
    with pytest.raises(SystemExit):
        build.build("bs", None, "id", "Faction", {"warscroll_names": {"Nobody": "Somebody"}})


def test_build_without_wahapedia_does_not_change_empty_page(bsdata_only, monkeypatch):
    # A merge that writes into the Wahapedia page must not leak into the next build.
    seen = []
    real = build.merge.merge_faction
    def merge_faction(report, bs, wh):
        seen.append(len(wh["battle_traits"]))
        wh["battle_traits"].append(ability("Leaked"))
        return real(report, bs, wh)
    monkeypatch.setattr(build.merge, "merge_faction", merge_faction)
    before = copy.deepcopy(build.NO_WAHAPEDIA_PAGE)
    build.build("bs", None, "id", "Faction", {})
    build.build("bs", None, "id", "Faction", {})
    assert (seen, build.NO_WAHAPEDIA_PAGE) == ([0, 0], before)


def test_build_with_wahapedia_dir_without_page_exits(bsdata_only, tmp_path):
    with pytest.raises(SystemExit):
        build.build("bs", str(tmp_path), "id", "Faction", {})


def test_build_with_wahapedia_dir_with_two_pages_exits(bsdata_only, tmp_path):
    (tmp_path / "a.html").write_text("<html></html>", encoding="utf-8")
    (tmp_path / "b.html").write_text("<html></html>", encoding="utf-8")
    with pytest.raises(SystemExit):
        build.build("bs", str(tmp_path), "id", "Faction", {})


def test_build_with_wahapedia_dir_reads_its_page(bsdata_only, tmp_path, monkeypatch):
    (tmp_path / "faction.html").write_text("<html></html>", encoding="utf-8")
    read = []
    def parse_faction_page(path):
        read.append(os.path.basename(path))
        return copy.deepcopy(build.NO_WAHAPEDIA_PAGE)
    monkeypatch.setattr(build.wahapedia, "parse_faction_page", parse_faction_page)
    monkeypatch.setattr(build.wahapedia, "parse_unit_pages", lambda paths: [])
    build.build("bs", str(tmp_path), "id", "Faction", {})
    assert read == ["faction.html"]


def test_build_with_wahapedia_reports_bsdata_only_items(bsdata_only, tmp_path, monkeypatch):
    (tmp_path / "faction.html").write_text("<html></html>", encoding="utf-8")
    monkeypatch.setattr(build.wahapedia, "parse_faction_page", lambda p: copy.deepcopy(build.NO_WAHAPEDIA_PAGE))
    monkeypatch.setattr(build.wahapedia, "parse_unit_pages", lambda paths: [])
    _, report = build.build("bs", str(tmp_path), "id", "Faction", {})
    assert report.lines


# path_to_glory overrides

def with_ptg(*sections):
    d = data()
    d["path_to_glory"] = [{"name": name, "text": text, "warscrolls": []} for name, text in sections]
    return d


def test_path_to_glory_override_replaces_text_in_section():
    d = with_ptg(("Quests", "Gain 1 glory point. Then rest."))
    build.apply_overrides(d, {"path_to_glory": {"Quests": {"1 glory point": "2 glory points"}}})
    assert d["path_to_glory"][0]["text"] == "Gain 2 glory points. Then rest."


def test_path_to_glory_override_applies_every_replacement_in_section():
    d = with_ptg(("Quests", "Alpha then beta."))
    build.apply_overrides(d, {"path_to_glory": {"Quests": {"Alpha": "Gamma", "beta": "delta"}}})
    assert d["path_to_glory"][0]["text"] == "Gamma then delta."


def test_path_to_glory_override_leaves_other_sections_alone():
    d = with_ptg(("Quests", "Same words."), ("Veterans", "Same words."))
    build.apply_overrides(d, {"path_to_glory": {"Quests": {"Same": "Other"}}})
    assert d["path_to_glory"][1]["text"] == "Same words."


def test_path_to_glory_override_for_missing_section_exits():
    with pytest.raises(SystemExit):
        build.apply_overrides(with_ptg(("Quests", "Text.")), {"path_to_glory": {"Nowhere": {"Text": "T"}}})


def test_path_to_glory_override_for_absent_text_exits():
    with pytest.raises(SystemExit):
        build.apply_overrides(with_ptg(("Quests", "Text.")), {"path_to_glory": {"Quests": {"Missing": "M"}}})


def test_path_to_glory_override_for_repeated_text_exits():
    with pytest.raises(SystemExit):
        build.apply_overrides(with_ptg(("Quests", "Roll. Roll again.")), {"path_to_glory": {"Quests": {"Roll": "R"}}})


def test_path_to_glory_override_exit_does_not_change_text():
    d = with_ptg(("Quests", "Roll. Roll again."))
    with pytest.raises(SystemExit):
        build.apply_overrides(d, {"path_to_glory": {"Quests": {"Roll": "R"}}})
    assert d["path_to_glory"][0]["text"] == "Roll. Roll again."


# --- summons ---

def manifest(name, id=None, **kw):
    m = {"id": id or name.lower().replace(" ", "_"), "name": name, "keywords": ["MANIFESTATION"], "abilities": []}
    m.update(kw)
    return m


def spell(name, effect="", **kw):
    a = {"name": name, "effect": effect, "keywords": ["SPELL", "SUMMON"]}
    a.update(kw)
    return a


def ids(a, manifestations, owner_id=""):
    return build.summoned_ids(a, manifestations, owner_id)


def test_summon_ability_naming_a_manifestation_summons_it():
    assert ids(spell("Summon Brass Wall"), [manifest("Iron Gate"), manifest("Brass Wall")]) == ["brass_wall"]


def test_ability_without_summon_keyword_or_set_up_summons_nothing():
    a = spell("Summon Brass Wall", keywords=["SPELL"])
    assert ids(a, [manifest("Brass Wall")]) == []


def test_set_up_in_the_rules_marks_a_summoning_ability_without_the_keyword():
    a = {"name": "Call", "keywords": [], "effect": "Set up a Brass Wall wholly within 12\"."}
    assert ids(a, [manifest("Brass Wall")]) == ["brass_wall"]


def test_ability_name_counts_only_when_it_starts_with_summon():
    a = spell("The Lurking Vermintide", "Set up one unit.")
    assert ids(a, [manifest("Vermintide")]) == []


def test_manifestation_named_in_the_rules_is_summoned_by_a_differently_named_ability():
    a = spell("The Lurking Vermintide", "Set up a Vermintide.")
    assert ids(a, [manifest("Vermintide")]) == ["vermintide"]


def test_leading_the_in_the_manifestation_name_is_ignored():
    assert ids(spell("Summon Burning Head"), [manifest("The Burning Head")]) == ["the_burning_head"]


def test_case_punctuation_and_apostrophes_do_not_matter():
    a = spell("SUMMON KHAINE'S WALL!")
    assert ids(a, [manifest("Khaine’s Wall", id="kw")]) == ["kw"]


def test_hyphens_and_non_breaking_hyphens_do_not_matter():
    assert ids(spell("Summon Soul‑Eater"), [manifest("Soul-eater", id="se")]) == ["se"]


def test_longer_manifestation_name_beats_one_contained_in_it():
    found = ids(spell("Summon Lesser Wall"), [manifest("Wall"), manifest("Lesser Wall")])
    assert found == ["lesser_wall"]


def test_ability_on_a_manifestations_own_warscroll_cannot_summon_it():
    assert ids(spell("Summon Brass Wall"), [manifest("Brass Wall")], owner_id="brass_wall") == []


def test_scourge_version_is_chosen_when_the_abilitys_source_matches():
    ms = [manifest("Wall"), manifest("Wall", id="scourge_wall", source="Scourge of Ghyran")]
    assert ids(spell("Summon Wall", source="Scourge of Ghyran"), ms) == ["scourge_wall"]


def test_battletome_version_is_chosen_when_the_abilitys_source_differs():
    ms = [manifest("Wall", id="scourge_wall", source="Scourge of Ghyran"), manifest("Wall")]
    assert ids(spell("Summon Wall"), ms) == ["wall"]


def test_first_version_is_chosen_when_none_matches_the_source():
    ms = [manifest("Wall", id="a", source="X"), manifest("Wall", id="b", source="Y")]
    assert ids(spell("Summon Wall"), ms) == ["a"]


def test_every_named_manifestation_is_summoned():
    a = spell("Summon Horror", "Pick 1 of the following: Gate, Wall or Tower.")
    found = ids(a, [manifest("Gate"), manifest("Wall"), manifest("Tower"), manifest("Pit")])
    assert sorted(found) == ["gate", "tower", "wall"]


def link_data(ability_, extra_warscrolls=()):
    d = data()
    d["warscrolls"] = [manifest("Brass Wall")] + list(extra_warscrolls)
    d["faction"]["lores"] = [{"name": "Lore", "entries": [ability_]}]
    return d


def linked(d):
    return d["faction"]["lores"][0]["entries"][0].get("summons")


def test_link_summons_sets_summons_on_the_ability():
    d = link_data(spell("Summon Brass Wall"))
    build.link_summons(d)
    assert linked(d) == ["brass_wall"]


def test_link_summons_leaves_an_ability_with_summons_alone():
    d = link_data(spell("Summon Brass Wall", summons=["other"]))
    build.link_summons(d)
    assert linked(d) == ["other"]


def test_link_summons_leaves_an_empty_summons_override_alone():
    d = link_data(spell("Summon Brass Wall", summons=[]))
    build.link_summons(d)
    assert linked(d) == []


def test_link_summons_adds_nothing_to_abilities_that_summon_nothing():
    d = link_data(spell("Summon Nothing"))
    build.link_summons(d)
    assert linked(d) is None


def test_link_summons_uses_the_core_manifestations():
    d = link_data(spell("Summon Core Thing"))
    build.link_summons(d, core=[manifest("Core Thing")])
    assert linked(d) == ["core_thing"]


def test_link_summons_uses_others_only_when_nothing_else_matched():
    d = link_data(spell("Summon Brass Wall"))
    build.link_summons(d, others=[manifest("Brass Wall", id="elsewhere")])
    assert linked(d) == ["brass_wall"]


def test_link_summons_falls_back_to_others():
    d = link_data(spell("Summon Far Thing"))
    build.link_summons(d, others=[manifest("Far Thing")])
    assert linked(d) == ["far_thing"]


def test_link_summons_ignores_the_abilities_own_manifestation():
    wall = manifest("Brass Wall", abilities=[spell("Summon Brass Wall")])
    d = link_data(spell("Nothing"), [])
    d["warscrolls"] = [wall]
    build.link_summons(d)
    assert "summons" not in wall["abilities"][0]


def test_link_summons_reaches_armies_of_renown_abilities():
    d = link_data(spell("Nothing"))
    d["armies_of_renown"][0]["lores"] = [{"name": "L", "entries": [spell("Summon Brass Wall")]}]
    build.link_summons(d)
    assert d["armies_of_renown"][0]["lores"][0]["entries"][0]["summons"] == ["brass_wall"]


def summoned_unit(name, **kw):
    w = {"id": name.lower().replace(" ", "_"), "name": name, "points": 0, "keywords": ["WAR MACHINE"], "abilities": []}
    w.update(kw)
    return w


def test_a_unit_with_no_points_is_a_summoned_unit():
    assert build.is_summoned_unit(summoned_unit("Auto-Endrin"))


def test_a_unit_with_points_is_not_a_summoned_unit():
    assert not build.is_summoned_unit(summoned_unit("Gunhauler", points=120))


def test_faction_terrain_is_not_a_summoned_unit():
    assert not build.is_summoned_unit(summoned_unit("Endrin Dock", keywords=["FACTION TERRAIN"]))


def test_link_summons_links_a_summoned_unit_the_rules_set_up():
    a = {"name": "Release", "keywords": [], "effect": "Set up an Auto-Endrin wholly within 6\"."}
    d = link_data(a, [summoned_unit("Auto-Endrin")])
    build.link_summons(d)
    assert linked(d) == ["auto-endrin"]


def test_link_summons_does_not_link_a_unit_with_points():
    a = {"name": "Call", "keywords": [], "effect": "Set up a Gunhauler wholly within 6\"."}
    d = link_data(a, [summoned_unit("Gunhauler", points=120)])
    build.link_summons(d)
    assert linked(d) is None


def write_warscrolls(path, warscrolls):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"warscrolls": warscrolls}), encoding="utf-8")


def test_core_manifestations_reads_the_core_warscrolls(tmp_path):
    write_warscrolls(tmp_path / "core" / "manifestation_lores.json", [manifest("Core Thing")])
    assert [w["id"] for w in build.core_manifestations(str(tmp_path))] == ["core_thing"]


def test_core_manifestations_is_empty_without_the_file(tmp_path):
    assert build.core_manifestations(str(tmp_path)) == []


def test_other_manifestations_skip_the_own_faction_and_non_manifestations(tmp_path):
    write_warscrolls(tmp_path / "factions" / "mine" / "warscrolls.json", [manifest("Mine")])
    write_warscrolls(tmp_path / "factions" / "theirs" / "warscrolls.json",
                     [manifest("Theirs"), {"id": "unit", "name": "Unit", "keywords": ["HERO"]}])
    assert [w["id"] for w in build.other_manifestations("mine", str(tmp_path))] == ["theirs"]


def test_other_manifestations_resolve_shared_warscrolls(tmp_path):
    write_warscrolls(tmp_path / "shared" / "warscrolls.json", [manifest("Shared Thing")])
    write_warscrolls(tmp_path / "factions" / "theirs" / "warscrolls.json", [{"shared": "shared_thing"}])
    assert [w["id"] for w in build.other_manifestations("mine", str(tmp_path))] == ["shared_thing"]


# Legends notices in warscroll notes

NOTICE = "This unit will move to Warhammer Legends on 1 June 2025."
LEGENDS = {"faction": {"legends": True}}


def with_notes(*notes):
    d = data()
    for w, n in zip(d["warscrolls"], notes):
        w["notes"] = n
    return d


def test_legends_faction_drops_notice_from_notes():
    d = with_notes(f"This HERO can join a unit. {NOTICE}")
    build.apply_overrides(d, LEGENDS)
    assert d["warscrolls"][0]["notes"] == "This HERO can join a unit."


def test_legends_faction_drops_notice_at_start_of_notes():
    d = with_notes(f"{NOTICE} This HERO can join a unit.")
    build.apply_overrides(d, LEGENDS)
    assert d["warscrolls"][0]["notes"] == "This HERO can join a unit."


def test_legends_faction_notes_that_are_only_the_notice_become_empty():
    d = with_notes(NOTICE)
    build.apply_overrides(d, LEGENDS)
    assert d["warscrolls"][0]["notes"] == ""


def test_non_legends_faction_keeps_notice():
    d = with_notes(f"This HERO can join a unit. {NOTICE}")
    build.apply_overrides(d, {})
    assert NOTICE in d["warscrolls"][0]["notes"]


def test_legends_faction_drops_notice_from_spearhead_warscrolls():
    d = data()
    d["spearheads"][0]["warscrolls"][0]["notes"] = f"Keep this. {NOTICE}"
    build.apply_overrides(d, LEGENDS)
    assert d["spearheads"][0]["warscrolls"][0]["notes"] == "Keep this."


def test_notes_field_override_wins_over_notice_removal():
    d = with_notes(f"Old. {NOTICE}")
    build.apply_overrides(d, {**LEGENDS, "fields": {"test_riders": {"notes": "Replaced."}, "test_captian": {"notes": "Mine."}}})
    assert d["warscrolls"][0]["notes"] == "Mine."
