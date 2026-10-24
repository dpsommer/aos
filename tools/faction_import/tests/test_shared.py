import json

import pytest

import merge
import shared


FACTION = "Testers"


def ability(name, effect="X."):
    return {"name": name, "timing": "Passive", "effect": effect}


def warscroll(**fields):
    """A schema-shaped warscroll, the faction's version of a shared one."""
    w = {"id": "big_hero", "name": "Big Hero", "points": 300, "unit_size": 1, "regiment_options": ["Any HERO"],
         "move": "8", "health": 12, "save": 3, "control": 2,
         "melee_weapons": [{"name": "Axe", "attacks": "4", "hit": 3, "wound": 3, "damage": "2"}],
         "abilities": [ability("Mighty"), ability("Roar")], "keywords": ["HERO", "UNIQUE", FACTION.upper()]}
    w.update(fields)
    return w


def army(**fields):
    a = {"name": "Grand Host", "text": "Roster.", "battle_traits": [ability("Host Trait")],
         "enhancement_tables": [{"name": "Artefacts", "entries": [ability("Relic")]}], "lores": []}
    a.update(fields)
    return a


def config(warscrolls=None, armies=None, fields=None):
    return {"warscrolls": {"big_hero": {}} if warscrolls is None else warscrolls,
            "armies_of_renown": ["Grand Host"] if armies is None else armies, "fields": fields or {}}


def empty():
    return {"warscrolls": [], "armies_of_renown": []}


def shared_profile(**fields):
    p = shared.profile(warscroll(), FACTION.upper(), False)
    p.update(fields)
    return p


# profile

def test_profile_drops_regiment_options():
    assert "regiment_options" not in shared.profile(warscroll(), FACTION.upper(), False)


def test_profile_strips_faction_keyword_when_per_faction():
    assert FACTION.upper() not in shared.profile(warscroll(), FACTION.upper(), True)["keywords"]


def test_profile_keeps_other_keywords_when_per_faction():
    keywords = shared.profile(warscroll(), FACTION.upper(), True)["keywords"]
    assert keywords == [k for k in warscroll()["keywords"] if k != FACTION.upper()]


def test_profile_keeps_faction_keyword_when_not_per_faction():
    assert FACTION.upper() in shared.profile(warscroll(), FACTION.upper(), False)["keywords"]


def test_profile_does_not_change_the_warscroll():
    w = warscroll()
    shared.profile(w, FACTION.upper(), True)
    assert w == warscroll()


# reference

def test_reference_names_shared_id():
    assert shared.reference(warscroll(), shared_profile(), merge.Report())["shared"] == "big_hero"


def test_reference_of_identical_warscroll_has_only_shared_id_and_regiment_options():
    # The shared profile has no regiment options, so the faction's are always its own.
    ref = shared.reference(warscroll(), shared_profile(), merge.Report())
    assert set(ref) == {"shared", "regiment_options"}


def test_reference_includes_differing_per_faction_field():
    ref = shared.reference(warscroll(points=250), shared_profile(), merge.Report())
    assert ref["points"] == 250


def test_reference_omits_equal_per_faction_field():
    assert "unit_size" not in shared.reference(warscroll(), shared_profile(), merge.Report())


def test_reference_omits_per_faction_field_falsy_in_both():
    ref = shared.reference(warscroll(regiment_options=[]), shared_profile(), merge.Report())
    assert "regiment_options" not in ref


def test_reference_does_not_report_per_faction_differences():
    report = merge.Report()
    shared.reference(warscroll(points=250), shared_profile(), report)
    assert report.lines == []


def test_reference_adds_keywords_only_the_faction_has():
    ref = shared.reference(warscroll(), shared_profile(keywords=["HERO", "UNIQUE"]), merge.Report())
    assert ref["keywords"] == [FACTION.upper()]


def test_reference_omits_keywords_when_none_are_extra():
    assert "keywords" not in shared.reference(warscroll(), shared_profile(), merge.Report())


def test_reference_includes_differing_ability():
    w = warscroll(abilities=[ability("Mighty", "Different."), ability("Roar")])
    ref = shared.reference(w, shared_profile(), merge.Report())
    assert ref["abilities"] == [ability("Mighty", "Different.")]


def test_reference_includes_new_ability():
    w = warscroll(abilities=[ability("Mighty"), ability("Roar"), ability("Extra")])
    ref = shared.reference(w, shared_profile(), merge.Report())
    assert ref["abilities"] == [ability("Extra")]


def test_reference_omits_abilities_when_all_equal():
    assert "abilities" not in shared.reference(warscroll(), shared_profile(), merge.Report())


def test_reference_reports_other_field_difference():
    report = merge.Report()
    shared.reference(warscroll(health=14), shared_profile(), report)
    assert len(report.lines) == 1 and "health" in report.lines[0]


def test_reference_does_not_put_other_field_differences_in_ref():
    assert "health" not in shared.reference(warscroll(health=14), shared_profile(), merge.Report())


def test_reference_reports_weapon_difference_by_name():
    w = warscroll(melee_weapons=[{"name": "Axe", "attacks": "5", "hit": 3, "wound": 3, "damage": "2"}])
    report = merge.Report()
    shared.reference(w, shared_profile(), report)
    assert len(report.lines) == 1 and "Axe" in report.lines[0] and "attacks" in report.lines[0]


def test_reference_reports_ability_only_in_shared_profile():
    report = merge.Report()
    shared.reference(warscroll(abilities=[ability("Mighty")]), shared_profile(), report)
    assert len(report.lines) == 1 and "Roar" in report.lines[0]


def test_reference_reports_keywords_only_in_shared_profile():
    report = merge.Report()
    shared.reference(warscroll(keywords=["HERO"]), shared_profile(), report)
    assert len(report.lines) == 1 and "UNIQUE" in report.lines[0]


def test_reference_reports_nothing_for_identical_warscroll():
    report = merge.Report()
    shared.reference(warscroll(), shared_profile(), report)
    assert report.lines == []


# share

def test_share_first_faction_creates_shared_entry():
    entries = empty()
    shared.share([warscroll()], [], FACTION, config(), entries, merge.Report())
    assert entries["warscrolls"] == [shared.profile(warscroll(), FACTION.upper(), False)]


def test_share_first_faction_gets_reference():
    out, _ = shared.share([warscroll()], [], FACTION, config(), empty(), merge.Report())
    assert out[0]["shared"] == "big_hero" and "id" not in out[0]


def test_share_strips_faction_keyword_from_shared_entry_when_configured():
    entries = empty()
    shared.share([warscroll()], [], FACTION, config(warscrolls={"big_hero": {"faction_keyword": True}}),
                 entries, merge.Report())
    assert FACTION.upper() not in entries["warscrolls"][0]["keywords"]


def test_share_per_faction_keyword_goes_in_reference():
    out, _ = shared.share([warscroll()], [], FACTION, config(warscrolls={"big_hero": {"faction_keyword": True}}),
                          empty(), merge.Report())
    assert out[0]["keywords"] == [FACTION.upper()]


def test_share_later_faction_keeps_existing_entry():
    entries = {"warscrolls": [shared_profile(health=14)], "armies_of_renown": []}
    shared.share([warscroll()], [], FACTION, config(), entries, merge.Report())
    assert entries["warscrolls"] == [shared_profile(health=14)]


def test_share_later_faction_reference_is_against_existing_entry():
    entries = {"warscrolls": [shared_profile(points=400)], "armies_of_renown": []}
    out, _ = shared.share([warscroll()], [], FACTION, config(), entries, merge.Report())
    assert out[0]["points"] == warscroll()["points"]


def test_share_later_faction_reports_differences_from_existing_entry():
    entries = {"warscrolls": [shared_profile(health=14)], "armies_of_renown": []}
    report = merge.Report()
    shared.share([warscroll()], [], FACTION, config(), entries, report)
    assert any("health" in line for line in report.lines)


def test_share_update_replaces_existing_entry():
    entries = {"warscrolls": [shared_profile(health=14)], "armies_of_renown": []}
    shared.share([warscroll()], [], FACTION, config(), entries, merge.Report(), update=True)
    assert entries["warscrolls"] == [shared_profile()]


def test_share_passes_unshared_warscroll_through():
    other = warscroll(id="small_guy", name="Small Guy")
    out, _ = shared.share([other], [], FACTION, config(), empty(), merge.Report())
    assert out == [other]


def test_share_does_not_add_unshared_warscroll_to_entries():
    entries = empty()
    shared.share([warscroll(id="small_guy")], [], FACTION, config(), entries, merge.Report())
    assert entries["warscrolls"] == []


def test_share_keeps_warscroll_order():
    ws = [warscroll(id="a_unit"), warscroll(), warscroll(id="z_unit")]
    out, _ = shared.share(ws, [], FACTION, config(), empty(), merge.Report())
    assert [w.get("id", w.get("shared")) for w in out] == ["a_unit", "big_hero", "z_unit"]


def test_share_army_of_renown_becomes_reference():
    _, out = shared.share([], [army()], FACTION, config(), empty(), merge.Report())
    assert out == [{"shared": "Grand Host"}]


def test_share_first_army_of_renown_creates_shared_entry():
    entries = empty()
    shared.share([], [army()], FACTION, config(), entries, merge.Report())
    assert entries["armies_of_renown"] == [army()]


def test_share_later_army_of_renown_keeps_existing_entry():
    entries = {"warscrolls": [], "armies_of_renown": [army(text="Shared roster.")]}
    shared.share([], [army()], FACTION, config(), entries, merge.Report())
    assert entries["armies_of_renown"] == [army(text="Shared roster.")]


def test_share_reports_army_of_renown_difference():
    entries = {"warscrolls": [], "armies_of_renown": [army(text="Shared roster.")]}
    report = merge.Report()
    shared.share([], [army()], FACTION, config(), entries, report)
    assert len(report.lines) == 1 and "text" in report.lines[0] and "Grand Host" in report.lines[0]


def test_share_reports_nothing_for_identical_army_of_renown():
    entries = {"warscrolls": [], "armies_of_renown": [army()]}
    report = merge.Report()
    shared.share([], [army()], FACTION, config(), entries, report)
    assert report.lines == []


def test_share_update_replaces_army_of_renown():
    entries = {"warscrolls": [], "armies_of_renown": [army(text="Shared roster.")]}
    shared.share([], [army()], FACTION, config(), entries, merge.Report(), update=True)
    assert entries["armies_of_renown"] == [army()]


def test_share_passes_unshared_army_of_renown_through():
    other = army(name="Own Host")
    _, out = shared.share([], [other], FACTION, config(), empty(), merge.Report())
    assert out == [other]


# apply_fields

def test_apply_fields_unscoped_target_updates_warscroll():
    ws = [warscroll()]
    shared.apply_fields(ws, [], {"big_hero": {"notes": "Fixed."}})
    assert ws[0]["notes"] == "Fixed."


def test_apply_fields_unscoped_target_updates_army_of_renown():
    armies = [army()]
    shared.apply_fields([], armies, {"Grand Host": {"text": "Fixed."}})
    assert armies[0]["text"] == "Fixed."


def test_apply_fields_scoped_target_updates_ability():
    ws = [warscroll()]
    shared.apply_fields(ws, [], {"big_hero > Roar": {"effect": "Fixed."}})
    assert ws[0]["abilities"][1]["effect"] == "Fixed."


def test_apply_fields_scoped_target_leaves_other_abilities():
    ws = [warscroll()]
    shared.apply_fields(ws, [], {"big_hero > Roar": {"effect": "Fixed."}})
    assert ws[0]["abilities"][0] == ability("Mighty")


def test_apply_fields_scoped_target_updates_weapon():
    ws = [warscroll()]
    shared.apply_fields(ws, [], {"big_hero > Axe": {"attacks": "5"}})
    assert ws[0]["melee_weapons"][0]["attacks"] == "5"


def test_apply_fields_scoped_target_updates_army_battle_trait():
    armies = [army()]
    shared.apply_fields([], armies, {"Grand Host > Host Trait": {"effect": "Fixed."}})
    assert armies[0]["battle_traits"][0]["effect"] == "Fixed."


def test_apply_fields_scoped_target_updates_army_enhancement():
    armies = [army()]
    shared.apply_fields([], armies, {"Grand Host > Relic": {"effect": "Fixed."}})
    assert armies[0]["enhancement_tables"][0]["entries"][0]["effect"] == "Fixed."


def test_apply_fields_ignores_target_for_item_not_in_faction():
    ws, armies = [warscroll()], [army()]
    shared.apply_fields(ws, armies, {"other_hero > Roar": {"effect": "Fixed."}, "Other Host": {"text": "Fixed."}})
    assert (ws, armies) == ([warscroll()], [army()])


def test_apply_fields_skips_part_this_version_lacks():
    ws = [warscroll()]
    shared.apply_fields(ws, [], {"big_hero > Missing": {"effect": "Fixed."}})
    assert ws == [warscroll()]


# load_config

def write_config(tmp_path, data):
    path = tmp_path / "shared.json"
    path.write_text(json.dumps(data))
    return str(path)


def test_load_config_exits_for_override_naming_no_shared_entry(tmp_path):
    path = write_config(tmp_path, {"warscrolls": {"big_hero": {}}, "fields": {"other_hero > Roar": {"effect": "X."}}})
    with pytest.raises(SystemExit):
        shared.load_config(path)


def test_load_config_accepts_overrides_naming_shared_entries(tmp_path):
    fields = {"big_hero > Roar": {"effect": "X."}, "Grand Host": {"text": "X."}}
    path = write_config(tmp_path, {"warscrolls": {"big_hero": {}}, "armies_of_renown": ["Grand Host"], "fields": fields})
    assert shared.load_config(path)["fields"] == fields


def test_load_config_defaults_missing_sections(tmp_path):
    config_ = shared.load_config(write_config(tmp_path, {}))
    assert (config_["warscrolls"], config_["armies_of_renown"], config_["fields"]) == ({}, [], {})


def test_load_config_missing_file_is_empty(tmp_path):
    config_ = shared.load_config(str(tmp_path / "missing.json"))
    assert (config_["warscrolls"], config_["armies_of_renown"], config_["fields"]) == ({}, [], {})


# read and write

def test_read_missing_dir_is_empty(tmp_path):
    assert shared.read(str(tmp_path / "missing")) == empty()


def test_write_then_read_round_trips(tmp_path):
    entries = {"warscrolls": [shared_profile()], "armies_of_renown": [army()]}
    shared.write(entries, str(tmp_path))
    assert shared.read(str(tmp_path)) == entries


def test_write_sorts_warscrolls_by_id(tmp_path):
    entries = {"warscrolls": [shared_profile(id="zed"), shared_profile(id="alpha")], "armies_of_renown": []}
    shared.write(entries, str(tmp_path))
    assert [w["id"] for w in shared.read(str(tmp_path))["warscrolls"]] == ["alpha", "zed"]


def test_write_sorts_armies_of_renown_by_name(tmp_path):
    entries = {"warscrolls": [], "armies_of_renown": [army(name="Zed Host"), army(name="Alpha Host")]}
    shared.write(entries, str(tmp_path))
    assert [a["name"] for a in shared.read(str(tmp_path))["armies_of_renown"]] == ["Alpha Host", "Zed Host"]


def test_write_creates_missing_dir(tmp_path):
    shared.write(empty(), str(tmp_path / "new" / "shared"))
    assert shared.read(str(tmp_path / "new" / "shared")) == empty()
