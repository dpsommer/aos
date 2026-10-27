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


def test_markup_decodes_character_references():
    assert bsdata.markup("&#8226; Set the Damage") == "• Set the Damage"


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


def test_command_points_come_from_cost_characteristic():
    p = profile('typeName="Ability (Command)"><characteristics>'
                '<characteristic name="Cost">2</characteristic></characteristics>')
    out = bsdata.ability(p)
    assert isinstance(out["command_points"], int) and out["command_points"] > 0


def test_ability_without_cost_has_no_command_points():
    p = profile('typeName="Ability (Activated)"><characteristics>'
                '<characteristic name="Effect">X</characteristic></characteristics>')
    assert "command_points" not in bsdata.ability(p)


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


def test_faction_specific_ability_is_a_battle_trait(cats):
    root = element("catalogue", '><sharedSelectionEntries><selectionEntry id="t" name="Battle Traits: Testers">'
                     + FACTION_TYPED_PROFILE + '</selectionEntry></sharedSelectionEntries>')
    assert [a["name"] for a in bsdata.battle_traits(cats, root, FACTION)] == ["Tithe Rite"]


def test_faction_specific_ability_is_an_enhancement_profile():
    entry = element("selectionEntry", 'id="e" name="Tithe Relic">' + FACTION_TYPED_PROFILE)
    assert bsdata.enhancement(None, entry)["effect"] == "Gain a point."


def test_faction_specific_ability_is_on_warscroll(faction_data):
    assert ability_of(faction_data, "Test Wraith", "Wraith Offering")["timing"] == "Your Hero Phase"


def test_manifestation_profile_is_not_a_warscroll_ability(faction_data):
    assert "Test Wraith" not in {a["name"] for a in warscroll(faction_data, "Test Wraith")["abilities"]}


# warscroll()

def test_warscroll_stats_are_ints_and_move_is_a_string(faction_data):
    w = warscroll(faction_data, "Test Captain")
    assert (w["move"], w["health"], w["save"], w["control"]) == ("5", 6, 4, 2)


def test_manifestation_stats_come_from_manifestation_profile(faction_data):
    w = warscroll(faction_data, "Test Wraith")
    assert (w["move"], w["health"], w["save"]) == ("8", 7, 5)


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


def test_non_keyword_categories_are_not_keywords(faction_data):
    keywords = [k.upper() for k in warscroll(faction_data, "Test Riders")["keywords"]]
    assert not [k for k in keywords if k.startswith("NON-")]


def test_non_keyword_category_does_not_drop_other_keywords(faction_data):
    assert "CAVALRY" in warscroll(faction_data, "Test Riders")["keywords"]


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


def with_unlisted_gunners_copy(tmp_path):
    copy = ('<selectionEntry id="u-gunners-copy" name="Test Gunners (Scourge of Aqshy)" type="unit"'
            ' publicationId="pub-bt"/>\n    <selectionEntry id="u-warden"')
    d = edited_fixture(tmp_path, [("Testers - Library.cat", '<selectionEntry id="u-warden"', copy)])
    return bsdata.read_faction(bsdata.Catalogues(str(d)), FACTION)


def test_unlisted_library_copy_of_listed_unit_is_skipped(tmp_path):
    assert [w["name"] for w in with_unlisted_gunners_copy(tmp_path)[1]].count("Test Gunners") == 1


def test_listed_unit_is_kept_over_unlisted_copy(tmp_path):
    assert "points" in warscroll(with_unlisted_gunners_copy(tmp_path), "Test Gunners")


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


def with_group_links(tmp_path, links):
    """read_faction() with the enhancement group ids in `links` linked from each unit entry id."""
    d = fixture_copy(tmp_path)
    for unit_id, group_ids in links.items():
        children = "".join('<entryLink id="l-%s-%s" name="x" targetId="%s" type="selectionEntryGroup"/>'
                           % (unit_id, g, g) for g in group_ids)
        path = next(p for p in d.iterdir() if '<selectionEntry id="%s"' % unit_id in p.read_text(encoding="utf-8"))
        content = path.read_text(encoding="utf-8")
        start = content.index('<selectionEntry id="%s"' % unit_id)
        end = content.index(">", start) + 1
        if content[end - 2] == "/":
            content = content[:end - 2] + "><entryLinks>%s</entryLinks></selectionEntry>" % children + content[end:]
        else:
            content = content[:end] + "<entryLinks>%s</entryLinks>" % children + content[end:]
        path.write_text(content, encoding="utf-8")
    return bsdata.read_faction(bsdata.Catalogues(str(d)), FACTION)


def test_table_linked_by_some_units_lists_them(tmp_path):
    faction_data = with_group_links(tmp_path, {"u-riders": ["g-artefacts"], "u-gunners": ["g-artefacts"]})
    assert table_with(faction_data, "Lens of Truth")["units"] == ["Test Gunners", "Test Riders"]


def test_nested_tables_share_their_group_restriction(tmp_path):
    faction_data = with_group_links(tmp_path, {"u-riders": ["g-heroic"]})
    assert [t.get("units") for t in tables(faction_data) if t["name"] == "Heroic Traits"] == [["Test Riders"]] * 2


def test_table_linked_by_every_non_unique_hero_has_no_units(tmp_path):
    heroes = {u: ["g-heroic"] for u in ("u-captain", "u-warden", "u-retired", "u-host-champ")}
    faction_data = with_group_links(tmp_path, heroes)
    assert "units" not in table_with(faction_data, "Bold Leader")


def test_table_no_unit_links_has_no_units(faction_data):
    assert "units" not in table_with(faction_data, "Lens of Truth")


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

def catalogue_xml(name, cat_id="c"):
    """A minimal catalogue named `name` (raw XML) with id `cat_id`."""
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<catalogue id="%s" name="%s" gameSystemId="sys" '
            'xmlns="%s"><catalogueLinks></catalogueLinks></catalogue>' % (cat_id, name, NS))


def fixture_copy(tmp_path):
    src = os.path.join(FIXTURES, "bsdata")
    for name in os.listdir(src):
        shutil.copy(os.path.join(src, name), tmp_path)
    return tmp_path


def add_faction_link(directory, link, target="x"):
    """Add a catalogueLink named `link` (raw XML) to catalogue id `target` to the fixture faction catalogue."""
    cat = directory / (FACTION + ".cat")
    cat.write_text(cat.read_text(encoding="utf-8").replace(
        "</catalogueLinks>",
        '<catalogueLink id="cl-extra" name="%s" targetId="%s" type="catalogue"/></catalogueLinks>' % (link, target), 1),
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
    (d / "Path to Glory - Testers.cat").write_text(catalogue_xml("Path to Glory - Testers", "ptg"), encoding="utf-8")
    add_faction_link(d, "❖ Path to Glory - Testers", "ptg")
    assert "Path to Glory - Testers.cat" not in bsdata.faction_files(str(d), FACTION)


def test_faction_files_exclude_linked_library_of_other_faction(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Others - Library.cat").write_text(catalogue_xml("Others - Library", "others-lib"), encoding="utf-8")
    add_faction_link(d, "Others - Library", "others-lib")
    assert "Others - Library.cat" not in bsdata.faction_files(str(d), FACTION)


def add_library_link(directory, link, target):
    """Add a catalogueLink named `link` to catalogue id `target` to the fixture faction library."""
    lib = directory / (FACTION + " - Library.cat")
    lib.write_text(lib.read_text(encoding="utf-8").replace(
        "<sharedSelectionEntries>",
        '<catalogueLinks><catalogueLink id="cl-lib-extra" name="%s" targetId="%s" type="catalogue"/>'
        '</catalogueLinks><sharedSelectionEntries>' % (link, target), 1), encoding="utf-8")


def test_faction_files_include_library_linked_from_faction_library(tmp_path):
    # "Ironjawz - Library" links "Orruk Warclans - Library", which holds Kragnos.
    d = fixture_copy(tmp_path)
    (d / "Allies - Library.cat").write_text(catalogue_xml("Allies - Library", "allies-lib"), encoding="utf-8")
    add_library_link(d, "Allies - Library", "allies-lib")
    assert "Allies - Library.cat" in bsdata.faction_files(str(d), FACTION)


def test_unlisted_unit_in_linked_library_is_included(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Allies - Library.cat").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n<catalogue id="allies-lib" name="Allies - Library" '
        'gameSystemId="sys" library="true" xmlns="%s"><sharedSelectionEntries>'
        '<selectionEntry id="u-ally" name="Ally Giant" type="unit"/>'
        '</sharedSelectionEntries></catalogue>' % NS, encoding="utf-8")
    add_library_link(d, "Allies - Library", "allies-lib")
    cats = bsdata.Catalogues(str(d), bsdata.faction_files(str(d), FACTION))
    assert any(w["name"] == "Ally Giant" for w in bsdata.read_faction(cats, FACTION)[1])


def linking_catalogue_xml(name, cat_id, targets=()):
    """A minimal catalogue named `name` with id `cat_id` linking each catalogue id in `targets`."""
    links = "".join('<catalogueLink id="cl-%s" name="%s" targetId="%s" type="catalogue"/>' % (t, t, t)
                    for t in targets)
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<catalogue id="%s" name="%s" gameSystemId="sys" '
            'xmlns="%s"><catalogueLinks>%s</catalogueLinks></catalogue>' % (cat_id, name, NS, links))


def small_faction(tmp_path, faction_links=(), library_links=(), army_links=()):
    """A directory holding only the faction catalogue, its library, an Army of Renown and two
    catalogues that may be linked: another faction's library and a Path to Glory campaign."""
    files = {
        FACTION + ".cat": linking_catalogue_xml(FACTION, "own", faction_links),
        FACTION + " - Library.cat": linking_catalogue_xml(FACTION + " - Library", "own-lib", library_links),
        FACTION + " - Alliance.cat": linking_catalogue_xml(FACTION + " - Alliance", "aor", army_links),
        "Others - Library.cat": linking_catalogue_xml("Others - Library", "others-lib"),
        "Path to Glory - Testers.cat": linking_catalogue_xml("Path to Glory - Testers", "ptg"),
    }
    for name, xml in files.items():
        (tmp_path / name).write_text(xml, encoding="utf-8")
    return str(tmp_path)


def test_faction_files_include_other_library_linked_from_army_of_renown(tmp_path):
    # Khazalite Holds' Throngankor Alliance links "Kharadron Overlords - Library" for its roster.
    d = small_faction(tmp_path, army_links=["others-lib"])
    assert "Others - Library.cat" in bsdata.faction_files(d, FACTION)


def test_faction_files_include_other_library_linked_from_fixture_army_of_renown(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Others - Library.cat").write_text(catalogue_xml("Others - Library", "others-lib"), encoding="utf-8")
    aor = d / (FACTION + " - The Shared Host [LEGENDS].cat")
    aor.write_text(aor.read_text(encoding="utf-8").replace(
        "<entryLinks>", '<catalogueLinks><catalogueLink id="cl-other" name="Others - Library" '
                        'targetId="others-lib" type="catalogue"/></catalogueLinks><entryLinks>', 1),
        encoding="utf-8")
    assert "Others - Library.cat" in bsdata.faction_files(str(d), FACTION)


def test_faction_files_include_other_library_linked_from_own_library_in_small_directory(tmp_path):
    d = small_faction(tmp_path, library_links=["others-lib"])
    assert "Others - Library.cat" in bsdata.faction_files(d, FACTION)


def test_faction_files_exclude_other_library_linked_only_from_faction_catalogue(tmp_path):
    d = small_faction(tmp_path, faction_links=["others-lib"])
    assert "Others - Library.cat" not in bsdata.faction_files(d, FACTION)


def test_faction_files_exclude_unlinked_other_library(tmp_path):
    d = small_faction(tmp_path)
    assert "Others - Library.cat" not in bsdata.faction_files(d, FACTION)


def test_faction_files_exclude_path_to_glory_linked_from_army_of_renown(tmp_path):
    d = small_faction(tmp_path, army_links=["ptg"])
    assert "Path to Glory - Testers.cat" not in bsdata.faction_files(d, FACTION)


def test_faction_files_exclude_path_to_glory_linked_from_own_library(tmp_path):
    d = small_faction(tmp_path, library_links=["ptg"])
    assert "Path to Glory - Testers.cat" not in bsdata.faction_files(d, FACTION)


def test_faction_files_ignore_link_to_missing_catalogue(tmp_path):
    d = small_faction(tmp_path, army_links=["nowhere"])
    assert sorted(bsdata.faction_files(d, FACTION)) == sorted(
        [FACTION + ".cat", FACTION + " - Library.cat", FACTION + " - Alliance.cat"])


# libraries()

def library_xml(name, cat_id, library="true"):
    """A minimal catalogue named `name` (raw XML) with id `cat_id` and the given library flag."""
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<catalogue id="%s" name="%s" gameSystemId="sys" '
            'library="%s" xmlns="%s"></catalogue>' % (cat_id, name, library, NS))


def library_names(directory):
    return [r.get("name") for r in bsdata.libraries(bsdata.Catalogues(str(directory)), FACTION)]


def test_libraries_start_with_faction_library(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Allies - Library.cat").write_text(library_xml("Allies - Library", "allies-lib"), encoding="utf-8")
    add_library_link(d, "Allies - Library", "allies-lib")
    assert library_names(d)[0] == FACTION + " - Library"


def test_libraries_include_linked_library(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Allies - Library.cat").write_text(library_xml("Allies - Library", "allies-lib"), encoding="utf-8")
    add_library_link(d, "Allies - Library", "allies-lib")
    assert "Allies - Library" in library_names(d)


def test_libraries_exclude_linked_non_library_catalogue(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Allies.cat").write_text(library_xml("Allies", "allies", library="false"), encoding="utf-8")
    add_library_link(d, "Allies", "allies")
    assert "Allies" not in library_names(d)


def test_libraries_ignore_links_to_missing_catalogues(tmp_path):
    d = fixture_copy(tmp_path)
    add_library_link(d, "Not Present - Library", "not-present")
    assert library_names(d) == [FACTION + " - Library"]


def test_libraries_without_faction_library_are_empty(tmp_path):
    d = fixture_copy(tmp_path)
    os.remove(d / (FACTION + " - Library.cat"))
    assert library_names(d) == []


def test_faction_files_include_linked_non_library_catalogue(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Regiments of Renown.cat").write_text(catalogue_xml("Regiments of Renown", "ror"), encoding="utf-8")
    add_faction_link(d, "❖ Regiments of Renown", "ror")
    assert "Regiments of Renown.cat" in bsdata.faction_files(str(d), FACTION)


def test_faction_files_follow_links_by_id_when_name_differs_from_file(tmp_path):
    # Flesh-eater Courts links "þ Legions of Nagash", which is "Legions of Nagash [LEGENDS].cat".
    d = fixture_copy(tmp_path)
    (d / "Legions [LEGENDS].cat").write_text(catalogue_xml("þ Legions [LEGENDS]", "legions"), encoding="utf-8")
    add_faction_link(d, "þ Legions", "legions")
    assert "Legions [LEGENDS].cat" in bsdata.faction_files(str(d), FACTION)


def test_faction_files_ignore_links_to_missing_catalogues(tmp_path):
    d = fixture_copy(tmp_path)
    add_faction_link(d, "❖ Not Present")
    assert "Not Present.cat" not in bsdata.faction_files(str(d), FACTION)


def test_faction_files_do_not_follow_links_from_shared_catalogues(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Deep.cat").write_text(catalogue_xml("Deep", "deep"), encoding="utf-8")
    shared = d / "The Shared Host [LEGENDS].cat"
    shared.write_text(shared.read_text(encoding="utf-8").replace(
        "<entryLinks>", '<catalogueLinks><catalogueLink id="cl-deep" name="❖ Deep" targetId="deep" '
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


# profiles_on() / abilities_in() / unit_profiles(): linked profiles

def edited_fixture(tmp_path, edits):
    """A copy of the fixture catalogues with each (file, old, new) replacement made once."""
    d = fixture_copy(tmp_path)
    for file_name, old, new in edits:
        path = d / file_name
        content = path.read_text(encoding="utf-8")
        assert content.count(old) == 1, "%r not found once in %s" % (old, file_name)
        path.write_text(content.replace(old, new), encoding="utf-8")
    return d


def passive_profile(profile_id, name):
    return ('<profile id="%s" name="%s" typeId="ab" typeName="Ability (Passive)"><characteristics>'
            '<characteristic name="Effect" typeId="eff">%s effect.</characteristic></characteristics>'
            '<attributes><attribute name="Type" typeId="t">Special</attribute></attributes></profile>'
            % (profile_id, name, name))


def info_link(target, link_type="profile"):
    return '<infoLink id="il-%s-%s" name="x" targetId="%s" type="%s"/>' % (target, link_type, target, link_type)


LIBRARY_END = "  </sharedSelectionEntries>\n</catalogue>"
SHARED_PROFILES = (LIBRARY_END[:-len("</catalogue>")] + "<sharedProfiles>" + passive_profile("sp-delusion", "Test Delusion")
                   + passive_profile("sp-lib-beast", "Beast") + "</sharedProfiles>\n</catalogue>")
CORE_PROFILES = ("</gameSystem>", "<sharedProfiles>" + passive_profile("sp-core-beast", "Beast")
                 + "</sharedProfiles></gameSystem>")
CAPTAIN = '<selectionEntry id="u-captain" name="Test Captain" type="unit" publicationId="pub-bt">'
CAPTAIN_MODEL = '<selectionEntry id="m-captain" name="Test Captain" type="model">'


def linked_faction(tmp_path, *edits):
    """read_faction() over the fixture with shared profiles (a Delusion, and Beast in both the
    library and the game system) plus `edits`."""
    d = edited_fixture(tmp_path, [("Testers - Library.cat", LIBRARY_END, SHARED_PROFILES),
                                  ("Test System.gst",) + CORE_PROFILES] + list(edits))
    return bsdata.read_faction(bsdata.Catalogues(str(d)), FACTION)


def captain_links(*targets):
    return ("Testers - Library.cat", CAPTAIN, CAPTAIN + "<infoLinks>%s</infoLinks>" % "".join(targets))


def captain_abilities(faction_data):
    return [a["name"] for a in warscroll(faction_data, "Test Captain")["abilities"]]


def test_unit_linked_profile_is_a_warscroll_ability(tmp_path):
    assert "Test Delusion" in captain_abilities(linked_faction(tmp_path, captain_links(info_link("sp-delusion"))))


def test_unit_linked_profile_keeps_its_text(tmp_path):
    data = linked_faction(tmp_path, captain_links(info_link("sp-delusion")))
    assert ability_of(data, "Test Captain", "Test Delusion")["effect"] == "Test Delusion effect."


def test_unit_own_profiles_come_before_linked_ones(tmp_path):
    assert captain_abilities(linked_faction(tmp_path, captain_links(info_link("sp-delusion"))))[-1] == "Test Delusion"


def test_model_linked_profile_is_a_warscroll_ability(tmp_path):
    data = linked_faction(tmp_path, ("Testers - Library.cat", CAPTAIN_MODEL,
                                     CAPTAIN_MODEL + "<infoLinks>%s</infoLinks>" % info_link("sp-delusion")))
    assert "Test Delusion" in captain_abilities(data)


def test_linked_library_copy_of_core_profile_is_skipped(tmp_path):
    assert "Beast" not in captain_abilities(linked_faction(tmp_path, captain_links(info_link("sp-lib-beast"))))


def test_linked_game_system_profile_is_skipped(tmp_path):
    assert "Beast" not in captain_abilities(linked_faction(tmp_path, captain_links(info_link("sp-core-beast"))))


def test_non_profile_info_link_is_not_followed(tmp_path):
    data = linked_faction(tmp_path, captain_links(info_link("sp-delusion", "rule")))
    assert "Test Delusion" not in captain_abilities(data)


def test_unresolved_profile_link_is_ignored(tmp_path):
    data = linked_faction(tmp_path, captain_links(info_link("no-such-profile"), info_link("sp-delusion")))
    assert "Test Delusion" in captain_abilities(data)


def test_battle_traits_include_linked_profiles(tmp_path):
    traits = '<selectionEntry id="se-traits" name="Battle Traits: Testers" type="upgrade">'
    faction, _, _ = linked_faction(tmp_path, ("Testers.cat", traits,
                                              traits + "<infoLinks>%s</infoLinks>" % info_link("sp-delusion")))
    assert [a["name"] for a in faction["battle_traits"]] == ["Steady Ranks", "Test Delusion"]


def traits_root(*names):
    entries = "".join('<selectionEntry id="se-%d" name="%s" type="upgrade">'
                      '<infoLinks>%s</infoLinks></selectionEntry>' % (i, n and "Battle Traits: " + n or "Battle Traits",
                                                                      info_link("p-trait"))
                      for i, n in enumerate(names))
    return element("catalogue", 'id="c" name="Root"><sharedSelectionEntries>%s</sharedSelectionEntries>' % entries)


def test_battle_traits_use_only_entry_named_differently_from_army(cats):
    traits = bsdata.battle_traits(cats, traits_root("The King's Gitz"), "Da King's Gitz")
    assert [a["name"] for a in traits] == ["Steady Ranks"]


def test_battle_traits_use_only_entry_named_without_army(cats):
    traits = bsdata.battle_traits(cats, traits_root(""), "Hedonites of Slaanesh")
    assert [a["name"] for a in traits] == ["Steady Ranks"]


def test_battle_traits_prefer_entry_named_for_army_over_plain_entry(cats):
    root = element("catalogue", 'id="c" name="Root"><sharedSelectionEntries>'
                   '<selectionEntry id="se-plain" name="Battle Traits" type="upgrade"/>'
                   '<selectionEntry id="se-named" name="Battle Traits: Testers" type="upgrade">'
                   '<infoLinks>%s</infoLinks></selectionEntry></sharedSelectionEntries>' % info_link("p-trait"))
    assert [a["name"] for a in bsdata.battle_traits(cats, root, "Testers")] == ["Steady Ranks"]


def formations_root(name):
    entry = '<selectionEntry id="se-f" name="Test Formation" type="upgrade"><infoLinks>%s</infoLinks></selectionEntry>' \
        % info_link("p-trait")
    return element("catalogue", 'id="c" name="Root"><sharedSelectionEntryGroups><selectionEntryGroup id="g" name="%s">'
                   '<selectionEntries>%s</selectionEntries></selectionEntryGroup></sharedSelectionEntryGroups>' % (name, entry))


def test_battle_formations_group_can_be_named_without_army(cats):
    formations = bsdata.battle_formations(cats, formations_root("Battle Formations"), "Hedonites of Slaanesh")
    assert [f["name"] for f in formations] == ["Test Formation"]


def test_battle_formations_of_another_army_are_ignored(cats):
    assert bsdata.battle_formations(cats, formations_root("Battle Formations: Other Army"), "Testers") == []


def test_battle_traits_need_a_name_match_among_several_entries(cats):
    assert bsdata.battle_traits(cats, traits_root("Other Army", "Another Army"), "Da King's Gitz") == []


def test_core_profiles_are_game_system_profile_names(tmp_path):
    d = edited_fixture(tmp_path, [("Test System.gst",) + CORE_PROFILES])
    assert "Beast" in bsdata.Catalogues(str(d)).core_profiles


def test_catalogue_profiles_are_not_core_profiles(cats):
    assert "Rally Cry" not in cats.core_profiles


def test_abilities_in_follows_profile_links(cats):
    entry = element("selectionEntry", 'id="e" name="Linked">' + "<infoLinks>%s</infoLinks>" % info_link("p-trait"))
    assert [a["name"] for a in bsdata.abilities_in(cats, entry)] == ["Steady Ranks"]


def test_unit_profiles_follow_profile_links(cats):
    unit = element("selectionEntry", 'id="u" name="Linked" type="unit">' + "<infoLinks>%s</infoLinks>" % info_link("p-trait"))
    assert [p.get("name") for p in bsdata.unit_profiles(cats, unit)] == ["Steady Ranks"]


# link_name() / units_of(): a unit linked more than once

def test_link_name_comes_from_unconditional_name_modifier():
    link = element("entryLink", 'id="l" name="Riders" targetId="u-riders" type="selectionEntry">'
                   '<modifiers><modifier type="set" value="Riders (2 Models)" field="name"/></modifiers>')
    assert bsdata.link_name(link) == "Riders (2 Models)"


def test_link_name_ignores_conditional_name_modifier():
    link = element("entryLink", 'id="l" name="Riders" targetId="u-riders" type="selectionEntry">'
                   '<modifiers><modifier type="set" value="Riders (2 Models)" field="name"><conditions>'
                   '<condition type="atLeast" value="1" field="selections" scope="roster" childId="x"/>'
                   '</conditions></modifier></modifiers>')
    assert bsdata.link_name(link) is None


def test_link_name_ignores_modifiers_of_other_fields():
    link = element("entryLink", 'id="l" name="Riders" targetId="u-riders" type="selectionEntry">'
                   '<modifiers><modifier type="set" value="true" field="hidden"/></modifiers>')
    assert bsdata.link_name(link) is None


def test_link_name_without_link_is_none():
    assert bsdata.link_name(None) is None


RIDERS_LINK = '<entryLink id="el-riders" name="Test Riders" targetId="u-riders" type="selectionEntry">'


def second_riders_link(modifier):
    return ("Testers.cat", RIDERS_LINK,
            '<entryLink id="el-riders-small" name="Test Riders (Small)" targetId="u-riders" type="selectionEntry">'
            '<modifiers>%s</modifiers><costs><cost name="pts" typeId="points" value="110.0"/></costs></entryLink>'
            % modifier + RIDERS_LINK)


RENAME_MODIFIER = '<modifier type="set" value="Test Riders (Small)" field="name"/>'


def twice_linked(tmp_path, modifier=RENAME_MODIFIER):
    d = edited_fixture(tmp_path, [second_riders_link(modifier)])
    return bsdata.read_faction(bsdata.Catalogues(str(d)), FACTION)


def riders(warscrolls):
    return sorted((w for w in warscrolls if w["name"].startswith("Test Riders")), key=lambda w: w["name"])


def test_unit_linked_twice_gives_a_warscroll_per_link(tmp_path):
    _, warscrolls, _ = twice_linked(tmp_path)
    assert [w["name"] for w in riders(warscrolls)] == ["Test Riders", "Test Riders (Small)"]


def test_renamed_link_gives_warscroll_id_from_new_name(tmp_path):
    _, warscrolls, _ = twice_linked(tmp_path)
    assert named(warscrolls, "Test Riders (Small)")["id"] == bsdata.slug("Test Riders (Small)")


def test_renamed_link_warscroll_ids_are_distinct(tmp_path):
    _, warscrolls, _ = twice_linked(tmp_path)
    ids = [w["id"] for w in warscrolls]
    assert len(ids) == len(set(ids))


def test_each_link_warscroll_takes_its_own_points(tmp_path):
    _, warscrolls, _ = twice_linked(tmp_path)
    assert [w["points"] for w in riders(warscrolls)] == [200, 110]


def test_each_link_warscroll_takes_its_own_reinforcement(tmp_path):
    _, warscrolls, _ = twice_linked(tmp_path)
    assert [w["can_reinforce"] for w in riders(warscrolls)] == [True, False]


def test_renamed_link_warscroll_keeps_the_unit_profile(tmp_path):
    _, warscrolls, _ = twice_linked(tmp_path)
    small, full = named(warscrolls, "Test Riders (Small)"), named(warscrolls, "Test Riders")
    assert (small["move"], small["abilities"]) == (full["move"], full["abilities"])


def test_conditional_name_modifier_does_not_rename_warscroll(tmp_path):
    conditional = ('<modifier type="set" value="Test Riders (Small)" field="name"><conditions>'
                   '<condition type="atLeast" value="1" field="selections" scope="roster" childId="x"/>'
                   '</conditions></modifier>')
    _, warscrolls, _ = twice_linked(tmp_path, conditional)
    assert [w["name"] for w in riders(warscrolls)] == ["Test Riders", "Test Riders"]


# faction_files(): links by id

def test_faction_files_do_not_match_links_by_name(tmp_path):
    d = fixture_copy(tmp_path)
    (d / "Regiments of Renown.cat").write_text(catalogue_xml("Regiments of Renown", "ror"), encoding="utf-8")
    add_faction_link(d, "❖ Regiments of Renown", "some-other-id")
    assert "Regiments of Renown.cat" not in bsdata.faction_files(str(d), FACTION)
