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


@pytest.mark.parametrize("line", [
    "*Designer's Note: This is commentary, not a rule.*",
    "***Designer's Note**: This is commentary, not a rule.*",
])
def test_italic_designers_note_becomes_an_option(line):
    effect, options = bsdata.split_options("Heal (1) this unit.\n" + line)
    assert effect == "Heal (1) this unit."
    assert options == [{"name": "Designer’s Note", "text": "This is commentary, not a rule."}]


def test_option_label_closed_inside_bold_becomes_an_option():
    _, options = bsdata.split_options("Pick one:\n***Nullshot*:** Add 1 to hit rolls.")
    assert options == [{"name": "Nullshot", "text": "Add 1 to hit rolls."}]


def test_option_label_with_colon_inside_markup_becomes_an_option():
    _, options = bsdata.split_options("Pick one:\n***Iron Will:*** Add 1 to save rolls.")
    assert options == [{"name": "Iron Will", "text": "Add 1 to save rolls."}]


@pytest.mark.parametrize("line", [
    "**^^Hero^^** units have Ward (6+).",
    "***^^Hero^^** units have Ward (6+).***",
])
def test_line_starting_with_bold_keyword_is_not_an_option(line):
    effect, options = bsdata.split_options("Heal (1).\n" + line)
    assert options == [] and "units have Ward (6+)." in effect


HEADED = ("Each battle round, gain a boon:\n"
          "Battle Round 1:\n***Iron Will:*** Add 1 to save rolls.\n"
          "Battle Round 2:\n***Daemonic Weaponry:*** Add 1 to hit rolls.")


def test_option_headings_prefix_option_names():
    _, options = bsdata.split_options(HEADED)
    assert [o["name"] for o in options] == ["Battle Round 1: Iron Will", "Battle Round 2: Daemonic Weaponry"]


def test_option_heading_is_not_added_to_previous_option_text():
    _, options = bsdata.split_options(HEADED)
    assert options[0]["text"] == "Add 1 to save rolls."


def test_option_headings_are_removed_from_effect():
    effect, _ = bsdata.split_options(HEADED)
    assert effect == "Each battle round, gain a boon:"


def test_single_heading_before_options_stays_in_effect():
    effect, options = bsdata.split_options("Battle Round 1:\n***Iron Will:*** A.\n***Bold:*** B.")
    assert (effect, [o["name"] for o in options]) == ("Battle Round 1:", ["Iron Will", "Bold"])


def test_ability_without_options_has_no_options_key():
    p = profile('typeName="Ability (Passive)"><characteristics>'
                '<characteristic name="Effect">Plain effect.</characteristic></characteristics>')
    assert "options" not in bsdata.ability(p)


def test_ability_name_can_be_overridden():
    p = profile('name="Profile Name" typeName="Ability (Passive)">')
    assert bsdata.ability(p, "Entry Name")["name"] == "Entry Name"


# is_ability()

@pytest.mark.parametrize("type_name", ["Ability (Passive)", "Ability (Spell)", "Ability (Blood Tithe)"])
def test_ability_typed_profile_is_an_ability(type_name):
    assert bsdata.is_ability(profile('typeName="%s">' % type_name))


@pytest.mark.parametrize("type_name", ["Ranged Weapon", "Melee Weapon", "Unit", "Manifestation", "Abilities"])
def test_other_profile_types_are_not_abilities(type_name):
    assert not bsdata.is_ability(profile('typeName="%s">' % type_name))


def test_profile_without_type_is_not_an_ability():
    assert not bsdata.is_ability(profile('name="Untyped">'))


def element(tag_name, xml):
    return ET.fromstring('<%s xmlns="%s" %s</%s>' % (tag_name, NS, xml, tag_name))


FACTION_TYPED_PROFILE = ('<profiles><profile id="p-x" name="Tithe Rite" typeName="Ability (Blood Tithe)">'
                         '<characteristics><characteristic name="Effect">Gain a point.</characteristic>'
                         '</characteristics></profile></profiles>')


def test_faction_specific_ability_is_a_battle_trait():
    root = element("catalogue", '><sharedSelectionEntries><selectionEntry id="t" name="Battle Traits: Testers">'
                     + FACTION_TYPED_PROFILE + '</selectionEntry></sharedSelectionEntries>')
    assert [a["name"] for a in bsdata.battle_traits(root, FACTION)] == ["Tithe Rite"]


def test_faction_specific_ability_is_an_enhancement_profile():
    entry = element("selectionEntry", 'id="e" name="Tithe Relic">' + FACTION_TYPED_PROFILE)
    assert bsdata.enhancement(None, entry)["effect"] == "Gain a point."


def test_faction_specific_ability_is_on_warscroll(faction_data):
    assert ability_of(faction_data, "Test Wraith", "Wraith Offering")["timing"] == "Your Hero Phase"


def test_manifestation_profile_is_not_a_warscroll_ability(faction_data):
    assert "Test Wraith" not in {a["name"] for a in warscroll(faction_data, "Test Wraith")["abilities"]}


# warscroll()

def test_warscroll_stats_are_ints(faction_data):
    w = warscroll(faction_data, "Test Captain")
    assert (w["move"], w["health"], w["save"], w["control"]) == (5, 6, 4, 2)


def test_manifestation_stats_come_from_manifestation_profile(faction_data):
    w = warscroll(faction_data, "Test Wraith")
    assert (w["move"], w["health"], w["save"]) == (8, 7, 5)


def test_manifestation_banishment_is_an_int(faction_data):
    assert warscroll(faction_data, "Test Wraith")["banishment"] == 6


def test_manifestation_has_no_control(faction_data):
    assert warscroll(faction_data, "Test Wraith")["control"] == 0


def test_ordinary_unit_has_no_banishment(faction_data):
    assert "banishment" not in warscroll(faction_data, "Test Captain")


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


def test_weapon_name_is_stripped(faction_data):
    # The fixture's Cutlass has a leading space, as BSData's Warsong Revenant weapon does.
    names = [w["name"] for w in warscroll(faction_data, "Test Captain")["melee_weapons"]]
    assert "Cutlass" in names


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


def test_lore_source_comes_from_linked_lore_publication(faction_data):
    assert named(faction_data[0]["lores"], "Lore of Embers")["source"] == "Scourge of Aqshy"


def test_lore_source_falls_back_to_option_publication(faction_data):
    assert named(faction_data[0]["lores"], "Lore of Ashes")["source"] == "Scourge of Aqshy"


def test_battletome_lore_has_no_source(faction_data):
    assert "source" not in named(faction_data[0]["lores"], "Lore of Testing")


def test_linked_lore_publication_wins_over_option_publication(tmp_path):
    d = fixture_copy(tmp_path)
    gst = d / "Test System.gst"
    gst.write_text(gst.read_text(encoding="utf-8").replace(
        "</publications>", '<publication id="pub-sog" name="Scourge of Ghyran"/></publications>'), encoding="utf-8")
    cat = d / (FACTION + ".cat")
    cat.write_text(cat.read_text(encoding="utf-8").replace(
        'id="o-lore-embers" name="Lore of Embers" type="upgrade"',
        'id="o-lore-embers" name="Lore of Embers" type="upgrade" publicationId="pub-sog"'), encoding="utf-8")
    faction, _, _ = bsdata.read_faction(bsdata.Catalogues(str(d)), FACTION)
    assert named(faction["lores"], "Lore of Embers")["source"] == "Scourge of Aqshy"


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


def test_split_legends_tag_strips_tag():
    assert bsdata.split_legends_tag("The Duardin Ascendant [LEGENDS]") == ("The Duardin Ascendant", True)


def test_split_legends_tag_handles_missing_closing_bracket():
    assert bsdata.split_legends_tag("Lethis [LEGENDS") == ("Lethis", True)


def test_split_legends_tag_leaves_untagged_name():
    assert bsdata.split_legends_tag("Lethis") == ("Lethis", False)


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


# faction_files()

def catalogue_xml(name, links=()):
    """A minimal catalogue named `name` with catalogueLinks to each of `links` (raw XML names)."""
    link_xml = "".join('<catalogueLink id="cl-%d" name="%s" targetId="x" type="catalogue"/>' % (i, link)
                       for i, link in enumerate(links))
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<catalogue id="c" name="%s" gameSystemId="sys" '
            'xmlns="%s"><catalogueLinks>%s</catalogueLinks></catalogue>' % (name, NS, link_xml))


def fixture_copy(tmp_path):
    src = os.path.join(FIXTURES, "bsdata")
    for name in os.listdir(src):
        shutil.copy(os.path.join(src, name), tmp_path)
    return tmp_path


def add_faction_link(directory, link):
    """Add a catalogueLink named `link` (raw XML) to the fixture faction catalogue."""
    cat = directory / (FACTION + ".cat")
    cat.write_text(cat.read_text(encoding="utf-8").replace(
        "</catalogueLinks>",
        '<catalogueLink id="cl-extra" name="%s" targetId="x" type="catalogue"/></catalogueLinks>' % link, 1),
        encoding="utf-8")


def fixture_files():
    return bsdata.faction_files(os.path.join(FIXTURES, "bsdata"), FACTION)


def test_faction_files_include_faction_catalogue():
    assert FACTION + ".cat" in fixture_files()


def test_faction_files_include_game_system():
    assert "Test System.gst" in fixture_files()


def test_faction_files_include_lores():
    assert "Lores.cat" in fixture_files()


def test_faction_files_include_faction_library():
    assert FACTION + " - Library.cat" in fixture_files()


def test_faction_files_include_armies_of_renown():
    assert FACTION + " - The Shared Host [LEGENDS].cat" in fixture_files()


def test_faction_files_follow_links_with_decorative_prefix():
    assert "The Shared Host [LEGENDS].cat" in fixture_files()


def test_faction_files_are_sorted():
    files = fixture_files()
    assert files == sorted(files)


def test_faction_files_have_no_duplicates():
    files = fixture_files()
    assert len(files) == len(set(files))


def test_faction_files_exclude_unrelated_catalogue(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Others.cat").write_text(catalogue_xml("Others"), encoding="utf-8")
    assert "Others.cat" not in bsdata.faction_files(str(d), FACTION)


def test_faction_files_exclude_faction_with_same_name_prefix(tmp_path):
    d = fixture_copy(tmp_path)
    (d / (FACTION + " Rivals.cat")).write_text(catalogue_xml(FACTION + " Rivals"), encoding="utf-8")
    assert FACTION + " Rivals.cat" not in bsdata.faction_files(str(d), FACTION)


def test_faction_files_exclude_linked_path_to_glory(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Path to Glory - Testers.cat").write_text(catalogue_xml("Path to Glory - Testers"), encoding="utf-8")
    add_faction_link(d, "❖ Path to Glory - Testers")
    assert "Path to Glory - Testers.cat" not in bsdata.faction_files(str(d), FACTION)


def test_faction_files_exclude_linked_library_of_other_faction(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Others - Library.cat").write_text(catalogue_xml("Others - Library"), encoding="utf-8")
    add_faction_link(d, "Others - Library")
    assert "Others - Library.cat" not in bsdata.faction_files(str(d), FACTION)


def test_faction_files_include_linked_non_library_catalogue(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Regiments of Renown.cat").write_text(catalogue_xml("Regiments of Renown"), encoding="utf-8")
    add_faction_link(d, "❖ Regiments of Renown")
    assert "Regiments of Renown.cat" in bsdata.faction_files(str(d), FACTION)


def test_faction_files_unescape_link_names(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Bob's & Co.cat").write_text(catalogue_xml("Bob&apos;s &amp; Co"), encoding="utf-8")
    add_faction_link(d, "þ Bob&apos;s &amp; Co")
    assert "Bob's & Co.cat" in bsdata.faction_files(str(d), FACTION)


def test_faction_files_ignore_links_to_missing_catalogues(tmp_path):
    d = fixture_copy(tmp_path)
    add_faction_link(d, "❖ Not Present")
    assert "Not Present.cat" not in bsdata.faction_files(str(d), FACTION)


def test_faction_files_do_not_follow_links_from_shared_catalogues(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Deep.cat").write_text(catalogue_xml("Deep"), encoding="utf-8")
    shared = d / "The Shared Host [LEGENDS].cat"
    shared.write_text(shared.read_text(encoding="utf-8").replace(
        "<entryLinks>", '<catalogueLinks><catalogueLink id="cl-deep" name="❖ Deep" targetId="x" '
                        'type="catalogue"/></catalogueLinks><entryLinks>', 1), encoding="utf-8")
    assert "Deep.cat" not in bsdata.faction_files(str(d), FACTION)


def test_faction_files_without_faction_catalogue_exit():
    with pytest.raises(SystemExit):
        bsdata.faction_files(os.path.join(FIXTURES, "bsdata"), "No Such Faction")


# Catalogues(files)

def test_catalogues_with_files_load_only_those(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Others.cat").write_text(catalogue_xml("Others"), encoding="utf-8")
    cats = bsdata.Catalogues(str(d), bsdata.faction_files(str(d), FACTION))
    assert "Others.cat" not in cats.docs


def test_catalogues_with_files_load_listed_files(tmp_path):
    d = fixture_copy(tmp_path)
    files = bsdata.faction_files(str(d), FACTION)
    assert sorted(bsdata.Catalogues(str(d), files).docs) == files


def test_catalogues_without_files_load_every_catalogue(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Others.cat").write_text(catalogue_xml("Others"), encoding="utf-8")
    assert "Others.cat" in bsdata.Catalogues(str(d)).docs


def test_catalogues_without_files_load_game_system(tmp_path):
    assert "Test System.gst" in bsdata.Catalogues(str(fixture_copy(tmp_path))).docs


# ensure_checkout() / checkout_version()

class FakeRun:
    """Stands in for subprocess.run, recording each argv and returning `stdout`."""

    def __init__(self, stdout=""):
        self.calls = []
        self.stdout = stdout

    def __call__(self, argv, **kwargs):
        self.calls.append(argv)
        return type("Result", (), {"stdout": self.stdout, "returncode": 0})()


@pytest.fixture
def fake_run(monkeypatch):
    run = FakeRun()
    monkeypatch.setattr(bsdata.subprocess, "run", run)
    return run


def test_ensure_checkout_clones_when_missing(tmp_path, fake_run):
    path = str(tmp_path / "bsdata")
    bsdata.ensure_checkout(path)
    (argv,) = fake_run.calls
    assert argv[:2] == ["git", "clone"] and "--depth" in argv and argv[argv.index("--depth") + 1] == "1" \
        and argv[-1] == path


def test_ensure_checkout_clones_the_repository(tmp_path, fake_run):
    bsdata.ensure_checkout(str(tmp_path / "bsdata"))
    assert bsdata.REPOSITORY in fake_run.calls[0]


def test_ensure_checkout_clones_even_when_updating(tmp_path, fake_run):
    bsdata.ensure_checkout(str(tmp_path / "bsdata"), update=True)
    (argv,) = fake_run.calls
    assert argv[:2] == ["git", "clone"]


def test_ensure_checkout_does_nothing_when_present(tmp_path, fake_run):
    (tmp_path / ".git").mkdir()
    bsdata.ensure_checkout(str(tmp_path))
    assert fake_run.calls == []


def test_ensure_checkout_pulls_when_updating(tmp_path, fake_run):
    (tmp_path / ".git").mkdir()
    bsdata.ensure_checkout(str(tmp_path), update=True)
    (argv,) = fake_run.calls
    assert argv[:5] == ["git", "-C", str(tmp_path), "pull", "--ff-only"]


def test_ensure_checkout_returns_path(tmp_path, fake_run):
    (tmp_path / ".git").mkdir()
    assert bsdata.ensure_checkout(str(tmp_path)) == str(tmp_path)


def test_checkout_version_runs_git_in_checkout(tmp_path, fake_run):
    bsdata.checkout_version(str(tmp_path))
    (argv,) = fake_run.calls
    assert argv[:3] == ["git", "-C", str(tmp_path)]


def test_checkout_version_is_stripped_output(tmp_path, fake_run):
    fake_run.stdout = "abc1234 2026-10-01\n"
    assert bsdata.checkout_version(str(tmp_path)) == "abc1234 2026-10-01"


def test_checkout_version_without_output_is_unknown(tmp_path, fake_run):
    fake_run.stdout = "  \n"
    assert bsdata.checkout_version(str(tmp_path)) == "unknown"
