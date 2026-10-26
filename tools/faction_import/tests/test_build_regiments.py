import json, os

import pytest

import build_regiments as br
import regiments
from conftest import FIXTURES, named


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh)


def add_faction(data_dir, fid, name, warscrolls, shared=None):
    base = os.path.join(str(data_dir), "factions", fid)
    write_json(os.path.join(base, "faction.json"), {"id": fid, "name": name, "grand_alliance": "order"})
    write_json(os.path.join(base, "warscrolls.json"), {"warscrolls": warscrolls})


def add_shared(data_dir, warscrolls):
    write_json(os.path.join(str(data_dir), "shared", "warscrolls.json"), {"warscrolls": warscrolls})


def read(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


# rename_wahapedia()

def test_rename_gives_wahapedia_regiments_their_bsdata_names():
    wh = [{"name": "Big Drogg Fort-Kicka"}]
    br.rename_wahapedia(wh, {"Big Drogg Fort-kicker": "Big Drogg Fort-Kicka"})
    assert wh[0]["name"] == "Big Drogg Fort-kicker"


def test_rename_matches_wahapedia_names_loosely():
    wh = [{"name": "Heroes of the Jade Abbey"}]
    br.rename_wahapedia(wh, {"Heroes of the Jade Abbey (BSData)": "heroes of THE jade abbey"})
    assert wh[0]["name"] == "Heroes of the Jade Abbey (BSData)"


def test_rename_leaves_other_regiments_alone():
    wh = [{"name": "Krew"}, {"name": "Fort-Kicka"}]
    br.rename_wahapedia(wh, {"Fort-kicker": "Fort-Kicka"})
    assert wh[0]["name"] == "Krew"


def test_rename_with_no_names_changes_nothing():
    wh = [{"name": "Krew"}]
    br.rename_wahapedia(wh, {})
    assert wh == [{"name": "Krew"}]


def test_rename_of_a_name_no_page_has_stops_the_build():
    with pytest.raises(SystemExit):
        br.rename_wahapedia([{"name": "Krew"}], {"Fort-kicker": "Fort-Kicka"})


# is_campaign_only()

def test_regiment_for_path_to_glory_is_campaign_only():
    assert br.is_campaign_only({"publication": "Path to Glory: Ravaged Coast", "factions": ["Skaven"]})


def test_regiment_no_faction_can_include_is_campaign_only():
    assert br.is_campaign_only({"publication": "", "factions": []})


def test_regiment_with_factions_and_a_normal_publication_is_not_campaign_only():
    assert not br.is_campaign_only({"publication": "General's Handbook", "factions": ["Skaven"]})


# built_factions()

def test_built_factions_maps_names_to_ids_and_warscrolls(tmp_path):
    add_faction(tmp_path, "skaven", "Skaven", [{"id": "gutter_runners", "name": "Gutter Runners"}])
    assert br.built_factions(str(tmp_path)) == {"Skaven": ("skaven", {"Gutter Runners": "gutter_runners"})}


def test_built_factions_lists_every_faction(tmp_path):
    add_faction(tmp_path, "skaven", "Skaven", [])
    add_faction(tmp_path, "ironjawz", "Ironjawz", [])
    assert sorted(br.built_factions(str(tmp_path))) == ["Ironjawz", "Skaven"]


def test_built_factions_resolves_shared_references_to_their_names(tmp_path):
    add_shared(tmp_path, [{"id": "nagash", "name": "Nagash, Supreme Lord"}])
    add_faction(tmp_path, "nighthaunt", "Nighthaunt", [{"shared": "nagash", "points": 1}])
    names = br.built_factions(str(tmp_path))["Nighthaunt"][1]
    assert names == {"Nagash, Supreme Lord": "nagash"}


def test_built_factions_works_without_a_shared_file(tmp_path):
    add_faction(tmp_path, "skaven", "Skaven", [{"shared": "nagash"}])
    assert br.built_factions(str(tmp_path))["Skaven"][1] == {"nagash": "nagash"}


def test_built_factions_prefers_the_battletome_warscroll_over_a_scourge_one(tmp_path):
    add_faction(tmp_path, "sf", "Test", [
        {"id": "knight", "name": "Knight"},
        {"id": "scourge_of_ghyran_knight", "name": "Knight", "source": "Scourge of Ghyran"}])
    assert br.built_factions(str(tmp_path))["Test"][1] == {"Knight": "knight"}


def test_built_factions_without_any_factions_is_empty(tmp_path):
    assert br.built_factions(str(tmp_path)) == {}


# resolve_units()

FACTIONS = {
    "Skaven": ("skaven", {"Gutter Runners": "gutter_runners", "Warlord": "skaven_warlord"}),
    "Ironjawz": ("ironjawz", {"Ardboyz": "ardboyz", "Warlord": "ironjawz_warlord", "Big-Hitta": "big_hitta"}),
    "Helsmiths of Hashut": ("helsmiths_of_hashut", {"Daemonsmith": "daemonsmith"}),
}


def unit(name, **fields):
    return dict({"count": 1, "name": name}, **fields)


def resolve(units, warscrolls=(), factions=FACTIONS):
    r = {"name": "Krew", "units": units, "warscrolls": list(warscrolls)}
    errors = []
    br.resolve_units(r, factions, errors)
    return r["units"], errors


def test_resolve_prefers_the_faction_wahapedia_links_to():
    units, errors = resolve([unit("Warlord", faction="ironjawz")])
    assert (units[0]["faction_id"], units[0]["warscroll"], errors) == ("ironjawz", "ironjawz_warlord", [])


def test_resolve_turns_wahapedia_slug_hyphens_into_underscores():
    units, _ = resolve([unit("Daemonsmith", faction="helsmiths-of-hashut")])
    assert units[0]["faction_id"] == "helsmiths_of_hashut"


def test_resolve_falls_back_to_the_library_that_defines_the_unit():
    units, errors = resolve([unit("Warlord", library="Skaven - Library.cat")])
    assert (units[0]["faction_id"], units[0]["warscroll"], errors) == ("skaven", "skaven_warlord", [])


def test_resolve_falls_back_to_the_only_faction_with_a_warscroll_of_that_name():
    units, errors = resolve([unit("Ardboyz")])
    assert (units[0]["faction_id"], units[0]["warscroll"], errors) == ("ironjawz", "ardboyz", [])


def test_resolve_matches_names_loosely_within_the_home_faction():
    units, _ = resolve([unit("Big Hitta", faction="ironjawz")])
    assert units[0]["warscroll"] == "big_hitta"


def test_resolve_does_not_guess_between_factions_with_the_same_unit_name():
    units, errors = resolve([unit("Warlord")])
    assert len(errors) == 1 and "Krew > Warlord" in errors[0]
    assert "warscroll" not in units[0]


def test_resolve_reports_a_unit_with_no_warscroll():
    _, errors = resolve([unit("Mystery")])
    assert len(errors) == 1 and "Mystery" in errors[0]


def test_resolve_reports_every_unresolved_unit():
    _, errors = resolve([unit("Mystery"), unit("Ardboyz"), unit("Enigma")])
    assert len(errors) == 2


def test_resolve_gives_the_regiments_own_unit_no_faction():
    own = [{"id": "champ", "name": "Champ"}]
    units, errors = resolve([unit("Champ", library=regiments.CATALOGUE + ".cat")], own)
    assert (units[0]["faction_id"], units[0]["warscroll"], errors) == ("", "champ", [])


def test_resolve_does_not_treat_other_libraries_units_as_own():
    own = [{"id": "champ", "name": "Ardboyz"}]
    units, _ = resolve([unit("Ardboyz", library="Ironjawz - Library.cat")], own)
    assert units[0]["faction_id"] == "ironjawz"


def test_resolve_keeps_a_unit_that_already_has_a_warscroll():
    units, errors = resolve([unit("Mystery", faction_id="skaven", warscroll="preset")])
    assert (units[0]["faction_id"], units[0]["warscroll"], errors) == ("skaven", "preset", [])


# apply_overrides()

def regs():
    return [{"name": "Krew", "points": 280,
             "units": [{"name": "Warlord", "count": 1}, {"name": "Runners", "count": 2}],
             "abilities": [{"name": "First Rule", "effect": "Old."}, {"name": "Second Rule", "effect": "Other."}]}]


WH = [{"name": "krew", "abilities": [{"name": "First rule!", "effect": "Wahapedia's.", "timing": "Passive"}]}]


def test_override_sets_a_regiment_field():
    r = regs()
    br.apply_overrides(r, {"fields": {"Krew": {"points": 300}}}, [])
    assert r[0]["points"] == 300


def test_override_sets_an_ability_field():
    r = regs()
    br.apply_overrides(r, {"fields": {"Krew > First Rule": {"effect": "New."}}}, [])
    assert [a["effect"] for a in r[0]["abilities"]] == ["New.", "Other."]


def test_override_sets_a_unit_field():
    r = regs()
    br.apply_overrides(r, {"fields": {"Krew > Runners": {"count": 5}}}, [])
    assert [u["count"] for u in r[0]["units"]] == [1, 5]


def test_override_of_a_unit_faction_also_sets_its_faction_id():
    r = regs()
    br.apply_overrides(r, {"fields": {"Krew > Warlord": {"faction": "ironjawz", "warscroll": "w"}}}, [])
    assert (r[0]["units"][0]["faction_id"], r[0]["units"][0]["warscroll"]) == ("ironjawz", "w")


def test_override_of_a_regiment_faction_does_not_set_a_faction_id():
    r = regs()
    br.apply_overrides(r, {"fields": {"Krew": {"faction": "x"}}}, [])
    assert "faction_id" not in r[0]


def test_override_remove_drops_the_ability():
    r = regs()
    br.apply_overrides(r, {"remove": ["Krew > First Rule"]}, [])
    assert [a["name"] for a in r[0]["abilities"]] == ["Second Rule"]


def test_override_replace_with_wahapedia_swaps_in_its_ability_under_its_name():
    r = regs()
    br.apply_overrides(r, {"replace_with_wahapedia": {"Krew > First Rule": "First rule!"}}, WH)
    assert (r[0]["abilities"][0]["name"], r[0]["abilities"][0]["effect"]) == ("First rule!", "Wahapedia's.")


def test_override_replace_with_wahapedia_copies_rather_than_shares():
    r = regs()
    br.apply_overrides(r, {"replace_with_wahapedia": {"Krew > First Rule": "First rule!"}}, WH)
    r[0]["abilities"][0]["effect"] = "Changed."
    assert WH[0]["abilities"][0]["effect"] == "Wahapedia's."


def test_override_for_an_unknown_regiment_stops_the_build():
    for overrides in ({"fields": {"Nope": {"points": 1}}}, {"remove": ["Nope > First Rule"]}):
        with pytest.raises(SystemExit):
            br.apply_overrides(regs(), overrides, [])


def test_field_override_matching_no_ability_or_unit_stops_the_build():
    with pytest.raises(SystemExit):
        br.apply_overrides(regs(), {"fields": {"Krew > Nothing": {"x": 1}}}, [])


def test_remove_matching_no_ability_stops_the_build():
    with pytest.raises(SystemExit):
        br.apply_overrides(regs(), {"remove": ["Krew > Nothing"]}, [])


def test_replace_with_wahapedia_without_that_wahapedia_ability_stops_the_build():
    with pytest.raises(SystemExit):
        br.apply_overrides(regs(), {"replace_with_wahapedia": {"Krew > First Rule": "Missing"}}, WH)


def test_replace_with_wahapedia_without_that_bsdata_ability_stops_the_build():
    with pytest.raises(SystemExit):
        br.apply_overrides(regs(), {"replace_with_wahapedia": {"Krew > Nothing": "First rule!"}}, WH)


def with_warscroll():
    r = regs()
    r[0]["warscrolls"] = [{"name": "Champ", "abilities": [{"name": "Champ Rule", "effect": "Old."},
                                                          {"name": "Other Rule", "effect": "Keep."}]}]
    return r


WH_WS = [{"name": "Krew", "abilities": [{"name": "Page Rule", "effect": "On the page."}],
          "warscrolls": [{"name": "Champ", "abilities": [{"name": "LAUNCH THE ATTACK", "effect": "Wahapedia's."}]}]}]


def test_every_ability_lists_regiment_then_warscroll_abilities():
    names = [a["name"] for a in br.every_ability(with_warscroll()[0])]
    assert names == ["First Rule", "Second Rule", "Champ Rule", "Other Rule"]


def test_every_ability_of_a_regiment_without_warscrolls_is_its_own():
    assert [a["name"] for a in br.every_ability(regs()[0])] == ["First Rule", "Second Rule"]


def test_every_ability_tolerates_a_page_without_abilities():
    assert br.every_ability({}) == []


def test_field_override_reaches_an_own_warscrolls_ability():
    r = with_warscroll()
    br.apply_overrides(r, {"fields": {"Krew > Champ Rule": {"effect": "New."}}}, [])
    assert r[0]["warscrolls"][0]["abilities"][0]["effect"] == "New."


def test_remove_reaches_an_own_warscrolls_ability():
    r = with_warscroll()
    br.apply_overrides(r, {"remove": ["Krew > Champ Rule"]}, [])
    assert [a["name"] for a in r[0]["warscrolls"][0]["abilities"]] == ["Other Rule"]
    assert len(r[0]["abilities"]) == 2


def test_replace_with_wahapedia_reaches_an_own_warscrolls_ability():
    r = with_warscroll()
    br.apply_overrides(r, {"replace_with_wahapedia": {"Krew > Champ Rule": "Page Rule"}}, WH_WS)
    assert r[0]["warscrolls"][0]["abilities"][0] == {"name": "Page Rule", "effect": "On the page."}


def test_replace_with_wahapedia_finds_abilities_on_the_pages_warscrolls():
    r = with_warscroll()
    br.apply_overrides(r, {"replace_with_wahapedia": {"Krew > First Rule": "LAUNCH THE ATTACK"}}, WH_WS)
    assert r[0]["abilities"][0]["effect"] == "Wahapedia's."


def test_replace_with_wahapedia_names_the_ability_as_the_override_does():
    r = regs()
    br.apply_overrides(r, {"replace_with_wahapedia": {"Krew > First Rule": "Launch the Attack"}}, WH_WS)
    assert r[0]["abilities"][0]["name"] == "Launch the Attack"


def test_add_from_wahapedia_appends_a_copy_of_the_ability():
    r = regs()
    br.apply_overrides(r, {"add_from_wahapedia": ["Krew > Page Rule"]}, WH_WS)
    assert r[0]["abilities"][-1] == {"name": "Page Rule", "effect": "On the page."}
    r[0]["abilities"][-1]["effect"] = "Changed."
    assert WH_WS[0]["abilities"][0]["effect"] == "On the page."


def test_add_from_wahapedia_names_the_ability_as_given():
    r = regs()
    br.apply_overrides(r, {"add_from_wahapedia": ["Krew > Launch the Attack"]}, WH_WS)
    assert r[0]["abilities"][-1]["name"] == "Launch the Attack"


def test_add_from_wahapedia_leaves_the_other_abilities_alone():
    r = regs()
    br.apply_overrides(r, {"add_from_wahapedia": ["Krew > Page Rule"]}, WH_WS)
    assert [a["name"] for a in r[0]["abilities"]] == ["First Rule", "Second Rule", "Page Rule"]


def test_add_from_wahapedia_without_that_ability_stops_the_build():
    with pytest.raises(SystemExit):
        br.apply_overrides(regs(), {"add_from_wahapedia": ["Krew > Missing"]}, WH_WS)


def test_add_from_wahapedia_without_a_page_stops_the_build():
    with pytest.raises(SystemExit):
        br.apply_overrides(regs(), {"add_from_wahapedia": ["Krew > Page Rule"]}, [])


def test_no_overrides_change_nothing():
    r = regs()
    br.apply_overrides(r, {}, [])
    assert r == regs()


def test_load_overrides_of_a_missing_file_is_empty(tmp_path):
    assert br.load_overrides(str(tmp_path / "none.json")) == {}


def test_load_overrides_reads_the_file(tmp_path):
    write_json(str(tmp_path / "o.json"), {"remove": ["a > b"]})
    assert br.load_overrides(str(tmp_path / "o.json")) == {"remove": ["a > b"]}


# write()

def resolved(name, factions, **fields):
    r = {"name": name, "points": 100, "factions": factions, "abilities": [], "warscrolls": [],
         "units": [{"count": 1, "name": "Unit", "faction_id": "skaven", "warscroll": "unit"}]}
    r.update(fields)
    return r


@pytest.fixture
def data_dir(tmp_path):
    add_faction(tmp_path, "skaven", "Skaven", [])
    add_faction(tmp_path, "ironjawz", "Ironjawz", [])
    return tmp_path


def test_write_puts_every_regiment_in_the_shared_file_sorted_by_name(data_dir):
    br.write([resolved("Zed", ["Skaven"]), resolved("Alpha", ["Skaven"])], str(data_dir))
    shared = read(str(data_dir / "shared" / br.FILE))
    assert [r["name"] for r in shared["regiments_of_renown"]] == ["Alpha", "Zed"]


def test_write_shared_regiments_are_in_the_schema_shape(data_dir):
    br.write([resolved("Alpha", ["Skaven"])], str(data_dir))
    regiment = read(str(data_dir / "shared" / br.FILE))["regiments_of_renown"][0]
    assert regiment["units"] == [{"count": 1, "name": "Unit", "faction": "skaven", "warscroll": "unit"}]


def test_write_creates_the_shared_directory(data_dir):
    assert not (data_dir / "shared").exists()
    br.write([resolved("Alpha", ["Skaven"])], str(data_dir))
    assert (data_dir / "shared" / br.FILE).exists()


def test_write_references_regiments_from_each_factions_file(data_dir):
    br.write([resolved("Alpha", ["Skaven"]), resolved("Beta", ["Skaven", "Ironjawz"])], str(data_dir))
    refs = lambda fid: read(str(data_dir / "factions" / fid / br.FILE))["regiments_of_renown"]
    assert refs("skaven") == [{"shared": "Alpha"}, {"shared": "Beta"}]
    assert refs("ironjawz") == [{"shared": "Beta"}]


def test_write_matches_faction_names_loosely(data_dir):
    br.write([resolved("Alpha", ["SKAVEN"])], str(data_dir))
    assert read(str(data_dir / "factions" / "skaven" / br.FILE)) == {"regiments_of_renown": [{"shared": "Alpha"}]}


def test_write_gives_a_faction_no_regiments_an_empty_list(data_dir):
    br.write([resolved("Alpha", ["Skaven"])], str(data_dir))
    assert read(str(data_dir / "factions" / "ironjawz" / br.FILE)) == {"regiments_of_renown": []}


def test_write_makes_no_files_for_unbuilt_factions(data_dir):
    br.write([resolved("Alpha", ["Beasts of Chaos"])], str(data_dir))
    assert sorted(os.listdir(str(data_dir / "factions"))) == ["ironjawz", "skaven"]


def test_unbuilt_factions_lists_factions_regiments_use_that_are_not_built(data_dir):
    merged = [resolved("Alpha", ["Skaven", "Bonesplitterz"]), resolved("Beta", ["Beasts of Chaos", "Bonesplitterz"])]
    assert br.unbuilt_factions(merged, str(data_dir)) == ["Beasts of Chaos", "Bonesplitterz"]


# build()

def test_build_from_bsdata_alone_leaves_out_campaign_only_regiments(tmp_path):
    add_faction(tmp_path, "testers", "Testers", [
        {"id": "test_captain", "name": "Test Captain"}, {"id": "test_riders", "name": "Test Riders"},
        {"id": "old_warden", "name": "Old Warden"}])
    merged, _, skipped = br.build(os.path.join(FIXTURES, "bsdata"), None, {}, str(tmp_path))
    assert skipped == ["Pathless Band"]
    assert [r["name"] for r in merged] == ["Alpha Company", "Old Guard"]


def test_build_resolves_every_unit(tmp_path):
    add_faction(tmp_path, "testers", "Testers", [
        {"id": "test_captain", "name": "Test Captain"}, {"id": "test_riders", "name": "Test Riders"},
        {"id": "old_warden", "name": "Old Warden"}])
    merged, _, _ = br.build(os.path.join(FIXTURES, "bsdata"), None, {}, str(tmp_path))
    units = named(merged, "Alpha Company")["units"]
    assert [(u["faction_id"], u["warscroll"]) for u in units] == [
        ("testers", "test_captain"), ("testers", "test_riders"), ("", "alpha_champion")]


def test_build_stops_when_a_unit_has_no_warscroll(tmp_path):
    add_faction(tmp_path, "testers", "Testers", [])
    with pytest.raises(SystemExit) as error:
        br.build(os.path.join(FIXTURES, "bsdata"), None, {}, str(tmp_path))
    assert "Test Captain" in str(error.value)


def test_build_takes_the_source_from_the_publication(tmp_path):
    add_faction(tmp_path, "testers", "Testers", [
        {"id": "test_captain", "name": "Test Captain"}, {"id": "test_riders", "name": "Test Riders"},
        {"id": "old_warden", "name": "Old Warden"}])
    merged, _, _ = br.build(os.path.join(FIXTURES, "bsdata"), None, {}, str(tmp_path))
    assert named(merged, "Alpha Company")["source"] == ""
