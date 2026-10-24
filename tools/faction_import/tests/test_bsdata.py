import os, shutil
import xml.etree.ElementTree as ET

import pytest

import bsdata
from conftest import FACTION, FIXTURES, named

NS = "http://www.battlescribe.net/schema/catalogueSchema"


def warscroll(faction_data, name):
    return named(faction_data[1], name)


def ability_of(faction_data, unit, name):
    return named(warscroll(faction_data, unit)["abilities"], name)


def profile(xml):
    return ET.fromstring('<profile xmlns="%s" %s</profile>' % (NS, xml))


# markup()

def test_markup_uppercases_keyword_markup():
    assert bsdata.markup("Pick a **^^Hero^^** unit.") == "Pick a HERO unit."


def test_markup_strips_emphasis():
    assert bsdata.markup("This is ***very*** **bold** *text*.") == "This is very bold text."


def test_markup_collapses_spaces_around_newlines():
    assert bsdata.markup("one  \xa0two \n  three") == "one two\nthree"


def test_markup_of_none_is_empty():
    assert bsdata.markup(None) == ""


# Catalogues

def test_links_resolve_to_entries_in_other_files(cats):
    link = next(el for el in cats.catalogue(FACTION).iter() if el.get("id") == "el-captain")
    assert cats.resolve(link).get("name") == "Test Captain"


def test_publication_names_come_from_the_game_system(cats):
    unit = next(el for el in cats.docs["Testers - Library.cat"].iter() if el.get("id") == "u-warden")
    assert cats.publication(unit) == "Warhammer Legends"


def test_missing_catalogue_exits(cats):
    with pytest.raises(SystemExit):
        cats.catalogue("No Such Faction")


# ability()

def test_ability_category_is_lowercased_type(faction_data):
    assert ability_of(faction_data, "Test Captain", "Rally Cry")["category"] == "rallying"


def test_passive_ability_timing_is_passive(faction_data):
    assert ability_of(faction_data, "Test Captain", "Commanding Presence")["timing"] == "Passive"


def test_frequency_is_split_from_timing(faction_data):
    a = ability_of(faction_data, "Test Captain", "Rally Cry")
    assert (a["frequency"], a["timing"]) == ("Once Per Turn (Army)", "Any Combat Phase")


def test_ability_without_frequency_has_no_frequency_key(faction_data):
    assert "frequency" not in ability_of(faction_data, "Test Captain", "Captain's Bolt")


def test_declare_is_converted_from_markup(faction_data):
    assert ability_of(faction_data, "Test Captain", "Rally Cry")["declare"] == "Pick a friendly INFANTRY unit."


def test_casting_value_is_an_int(faction_data):
    a = ability_of(faction_data, "Test Captain", "Captain's Bolt")
    assert isinstance(a["casting_value"], int) and a["casting_value"] > 0


def test_chanting_value_is_an_int(faction_data):
    a = ability_of(faction_data, "Test Riders", "Riders' Blessing")
    assert isinstance(a["chanting_value"], int) and a["chanting_value"] > 0


def test_ability_keywords_are_uppercased_list(faction_data):
    assert ability_of(faction_data, "Test Captain", "Rally Cry")["keywords"] == ["RALLY", "CORE"]


def test_labelled_lines_become_options(faction_data):
    options = ability_of(faction_data, "Test Captain", "Rally Cry")["options"]
    assert [o["name"] for o in options[:2]] == ["Hold Fast", "Press On"]


def test_option_text_excludes_label(faction_data):
    hold_fast = named(ability_of(faction_data, "Test Captain", "Rally Cry")["options"], "Hold Fast")
    assert hold_fast["text"] == "Add 1 to save rolls."


def test_lines_after_an_option_continue_that_option(faction_data):
    press_on = named(ability_of(faction_data, "Test Captain", "Rally Cry")["options"], "Press On")
    assert press_on["text"].endswith("wholly within 12\".")


def test_options_are_removed_from_effect(faction_data):
    effect = ability_of(faction_data, "Test Captain", "Rally Cry")["effect"]
    assert effect == "Pick one of the following:"


def test_designers_note_becomes_an_option(faction_data):
    note = named(ability_of(faction_data, "Test Captain", "Rally Cry")["options"], "Designer’s Note")
    assert note["text"] == "This is commentary, not a rule."


def test_ability_without_options_has_no_options_key():
    p = profile('typeName="Ability (Passive)"><characteristics>'
                '<characteristic name="Effect">Plain effect.</characteristic></characteristics>')
    assert "options" not in bsdata.ability(p)


def test_ability_name_can_be_overridden():
    p = profile('name="Profile Name" typeName="Ability (Passive)">')
    assert bsdata.ability(p, "Entry Name")["name"] == "Entry Name"


# warscroll()

def test_warscroll_stats_are_ints(faction_data):
    w = warscroll(faction_data, "Test Captain")
    assert (w["move"], w["health"], w["save"], w["control"]) == (5, 6, 4, 2)


def test_ward_comes_from_ward_category(faction_data):
    assert warscroll(faction_data, "Test Captain")["ward"] == 5


def test_ward_category_is_kept_as_keyword(faction_data):
    assert "WARD (5+)" in warscroll(faction_data, "Test Captain")["keywords"]


def test_warscroll_without_ward_has_no_ward_key(faction_data):
    assert "ward" not in warscroll(faction_data, "Test Riders")


def test_ranged_weapon_values(faction_data):
    gun = named(warscroll(faction_data, "Test Captain")["ranged_weapons"], "Volley Gun")
    assert {k: gun[k] for k in ("range", "attacks", "hit", "wound", "rend", "damage")} == \
        {"range": 12, "attacks": "3", "hit": 3, "wound": 4, "rend": 1, "damage": "D3"}


def test_weapon_abilities_are_split(faction_data):
    gun = named(warscroll(faction_data, "Test Captain")["ranged_weapons"], "Volley Gun")
    assert gun["abilities"] == ["Crit (Mortal)", "Shoot in Combat"]


def test_melee_weapon_range_is_zero(faction_data):
    assert named(warscroll(faction_data, "Test Captain")["melee_weapons"], "Cutlass")["range"] == 0


def test_dash_rend_is_zero(faction_data):
    assert named(warscroll(faction_data, "Test Captain")["melee_weapons"], "Cutlass")["rend"] == 0


def test_dash_weapon_ability_gives_no_abilities(faction_data):
    assert "abilities" not in named(warscroll(faction_data, "Test Captain")["melee_weapons"], "Cutlass")


def test_unit_size_sums_model_min_constraints(faction_data):
    assert warscroll(faction_data, "Test Riders")["unit_size"] == 5


def test_unit_size_defaults_to_one_without_models(faction_data):
    assert warscroll(faction_data, "Old Warden")["unit_size"] == 1


def test_single_base_size_is_plain(faction_data):
    assert warscroll(faction_data, "Test Captain")["base_size"] == "40mm"


def test_per_model_base_sizes_name_each_model(faction_data):
    assert warscroll(faction_data, "Test Riders")["base_size"] == "Rider Champion: 60 × 35mm, Rider: 90 × 52mm"


def test_unit_level_base_size_uses_times_sign(faction_data):
    # Model-level "60x35mm" becomes "60 × 35mm"; a unit-level rule should match that style.
    assert warscroll(faction_data, "Test Gunners")["base_size"] == "60 × 35mm"


def test_points_come_from_faction_link(faction_data):
    assert warscroll(faction_data, "Test Riders")["points"] == 200


def test_reinforced_link_allows_reinforcing(faction_data):
    assert warscroll(faction_data, "Test Riders")["can_reinforce"] is True


def test_no_reinforced_link_forbids_reinforcing(faction_data):
    assert warscroll(faction_data, "Test Captain")["can_reinforce"] is False


def test_unlinked_unit_has_no_points(faction_data):
    assert "points" not in warscroll(faction_data, "Summoned Spirit")


def test_scourge_suffix_is_removed_from_name(faction_data):
    assert any(w["name"] == "Test Gunners" for w in faction_data[1])


def test_scourge_suffix_becomes_source(faction_data):
    assert warscroll(faction_data, "Test Gunners")["source"] == "Scourge of Aqshy"


def test_scourge_suffix_prefixes_id(faction_data):
    assert warscroll(faction_data, "Test Gunners")["id"] == "scourge_of_aqshy_test_gunners"


def test_battletome_unit_has_no_source(faction_data):
    assert "source" not in warscroll(faction_data, "Test Captain")


def test_legends_publication_marks_legends(faction_data):
    assert warscroll(faction_data, "Old Warden")["legends"] is True


def test_legends_category_marks_legends(faction_data):
    assert warscroll(faction_data, "Retired Hero")["legends"] is True


def test_legends_category_is_not_a_keyword(faction_data):
    assert "LEGENDS" not in warscroll(faction_data, "Retired Hero")["keywords"]


def test_non_legends_unit_has_no_legends_key(faction_data):
    assert "legends" not in warscroll(faction_data, "Test Captain")


def test_hidden_categories_are_not_keywords(faction_data):
    assert "HIDDEN MARKER" not in warscroll(faction_data, "Test Captain")["keywords"]


# units

def test_unlisted_library_unit_is_included(faction_data):
    assert any(w["name"] == "Summoned Spirit" for w in faction_data[1])


def test_army_of_renown_unit_is_included(faction_data):
    assert any(w["name"] == "Host Champion" for w in faction_data[1])


def test_anvil_of_apotheosis_hero_is_excluded(faction_data):
    assert not any(w["name"].startswith("Anvil of Apotheosis") for w in faction_data[1])


def test_each_unit_appears_once(faction_data):
    names = [w["name"] for w in faction_data[1]]
    assert len(names) == len(set(names))


# faction rules

def test_grand_alliance_comes_from_unit_categories(faction_data):
    assert faction_data[0]["grand_alliance"] == "order"


def test_battle_traits_are_read(faction_data):
    assert [a["name"] for a in faction_data[0]["battle_traits"]] == ["Steady Ranks"]


def test_battle_formation_has_points_and_abilities(faction_data):
    f = named(faction_data[0]["battle_formations"], "Test Brigade")
    assert f["points"] > 0 and [a["name"] for a in f["abilities"]] == ["Brigade Drill"]


# enhancement tables

def tables(faction_data):
    return faction_data[0]["enhancement_tables"]


def table_with(faction_data, entry):
    return next(t for t in tables(faction_data) if any(e["name"] == entry for e in t["entries"]))


def test_nested_group_with_parent_name_has_no_group(faction_data):
    assert "group" not in table_with(faction_data, "Bold Leader")


def test_nested_group_with_other_name_becomes_group(faction_data):
    assert table_with(faction_data, "Fiery Heart")["group"] == "Fiery Traits"


def test_nested_group_keeps_parent_table_name(faction_data):
    assert table_with(faction_data, "Fiery Heart")["name"] == "Heroic Traits"


def test_nested_group_scourge_publication_becomes_source(faction_data):
    assert table_with(faction_data, "Fiery Heart")["source"] == "Scourge of Aqshy"


def test_battletome_nested_group_has_no_source(faction_data):
    assert "source" not in table_with(faction_data, "Bold Leader")


def test_direct_entries_form_a_table(faction_data):
    assert table_with(faction_data, "Lens of Truth")["name"] == "Artefacts of Power"


def test_enhancement_points_come_from_entry_cost(faction_data):
    assert named(table_with(faction_data, "Bold Leader")["entries"], "Bold Leader")["points"] == 10


def test_enhancement_without_cost_has_no_points(faction_data):
    assert "points" not in named(table_with(faction_data, "Fiery Heart")["entries"], "Fiery Heart")


@pytest.mark.parametrize("group", ["Paths", "Battle Formations: Testers", "Spell Lores", "Manifestation Lores"])
def test_non_enhancement_groups_are_not_tables(faction_data, group):
    assert group not in {t["name"] for t in tables(faction_data)}


# lores

def test_faction_lore_is_included(faction_data):
    lore = named(faction_data[0]["lores"], "Lore of Testing")
    assert [e["name"] for e in lore["entries"]] == ["Test Bolt"]


def test_lore_kind_comes_from_group(faction_data):
    lores = faction_data[0]["lores"]
    assert (named(lores, "Lore of Testing")["kind"], named(lores, "Manifestations of Testing")["kind"]) == \
        ("spell", "manifestation")


def test_core_rules_lore_is_skipped(faction_data):
    assert not any(l["name"] == "Universal Spell Lore" for l in faction_data[0]["lores"])


def test_generals_handbook_lore_is_skipped(faction_data):
    assert not any(l["name"] == "Handbook Manifestations" for l in faction_data[0]["lores"])


def test_lore_points_come_from_option_cost(faction_data):
    assert named(faction_data[0]["lores"], "Manifestations of Testing")["points"] == 40


def test_lore_without_cost_has_no_points(faction_data):
    assert "points" not in named(faction_data[0]["lores"], "Lore of Testing")


# Armies of Renown

def army(faction_data):
    (a,) = faction_data[2]
    return a


def test_army_name_comes_from_file_name_without_legends_tag(faction_data):
    assert army(faction_data)["name"] == "The Shared Host"


def test_legends_tag_marks_army_as_legends(faction_data):
    assert army(faction_data)["legends"] is True


def test_army_battle_traits_come_from_shared_catalogue(faction_data):
    assert [a["name"] for a in army(faction_data)["battle_traits"]] == ["Shared Resolve"]


def test_army_roster_includes_units_from_both_catalogues(faction_data):
    assert set(army(faction_data)["roster"]) == {"Test Captain", "Host Champion"}


def test_army_enhancements_come_from_shared_catalogue(faction_data):
    (t,) = army(faction_data)["enhancement_tables"]
    assert [e["name"] for e in t["entries"]] == ["Shared Courage"]


def test_army_group_named_for_the_army_has_no_group(faction_data):
    (t,) = army(faction_data)["enhancement_tables"]
    assert "group" not in t


def test_army_does_not_take_rules_from_linked_library(faction_data):
    assert army(faction_data)["lores"] == []


def test_short_name_strips_owner_suffix():
    assert bsdata.short_name("Heroic Traits: Pioneer Outpost", "Pioneer Outpost") == "Heroic Traits"


def test_short_name_keeps_other_suffix():
    assert bsdata.short_name("Heroic Traits: Elsewhere", "Pioneer Outpost") == "Heroic Traits: Elsewhere"


def test_short_name_without_owner_keeps_name():
    assert bsdata.short_name("Heroic Traits: Pioneer Outpost", "") == "Heroic Traits: Pioneer Outpost"


def test_aor_file_name_strips_faction_and_extension():
    assert bsdata.aor_file_name("Kharadron Overlords", "Kharadron Overlords - The Duardin Ascendant [LEGENDS].cat") \
        == "The Duardin Ascendant [LEGENDS]"


def test_faction_link_wins_over_priced_army_of_renown_link(tmp_path):
    # Points and reinforcement come from the faction catalogue's link (docs/technical/faction-data.md),
    # even when an Army of Renown links the same unit with its own cost.
    src = os.path.join(FIXTURES, "bsdata")
    for name in os.listdir(src):
        shutil.copy(os.path.join(src, name), tmp_path)
    aor = tmp_path / "Testers - The Shared Host [LEGENDS].cat"
    aor.write_text(aor.read_text(encoding="utf-8").replace(
        '<entryLink id="el-aor-captain" name="Test Captain" targetId="u-captain" type="selectionEntry"/>',
        '<entryLink id="el-aor-captain" name="Test Captain" targetId="u-captain" type="selectionEntry">'
        '<costs><cost name="pts" typeId="points" value="999.0"/></costs></entryLink>'), encoding="utf-8")
    _, warscrolls, _ = bsdata.read_faction(bsdata.Catalogues(str(tmp_path)), FACTION)
    assert named(warscrolls, "Test Captain")["points"] == 120
