import pytest
from bs4 import BeautifulSoup

import merge, regiments, wahapedia
from conftest import named


@pytest.fixture
def bs_regiments(cats):
    return regiments.read_regiments(cats)


def alpha(bs_regiments):
    return named(bs_regiments, "Alpha Company")


def old_guard(bs_regiments):
    return named(bs_regiments, "Old Guard")


# read_regiments()

def test_regiments_are_sorted_by_name(bs_regiments):
    names = [r["name"] for r in bs_regiments]
    assert names == sorted(names, key=merge.norm)


def test_only_forces_gated_on_the_regiments_catalogue_are_regiments(bs_regiments):
    assert "Test Army" not in [r["name"] for r in bs_regiments]


def test_points_come_from_the_force_entry(bs_regiments):
    assert alpha(bs_regiments)["points"] == 250


def test_legends_tag_is_dropped_from_the_name_and_sets_legends(bs_regiments):
    r = old_guard(bs_regiments)
    assert r["legends"] is True


def test_regiment_without_legends_tag_has_no_legends_key(bs_regiments):
    assert "legends" not in alpha(bs_regiments)


def test_factions_are_the_catalogues_the_force_is_gated_on(bs_regiments):
    assert alpha(bs_regiments)["factions"] == ["Testers"]


def test_regiments_catalogue_is_not_one_of_its_factions(bs_regiments):
    assert all(regiments.CATALOGUE not in r["factions"] for r in bs_regiments)


def test_regiment_gated_on_several_catalogues_lists_each_faction(bs_regiments):
    assert "Testers" in old_guard(bs_regiments)["factions"]


def test_shared_army_of_renown_catalogue_is_an_army_not_a_faction(bs_regiments):
    r = old_guard(bs_regiments)
    assert (r["factions"], r["armies"]) == (["Testers"], ["The Shared Host"])


def test_regiment_gated_on_no_faction_has_none(bs_regiments):
    r = named(bs_regiments, "Pathless Band")
    assert (r["factions"], r["units"], r["abilities"]) == ([], [], [])


def test_abilities_come_from_the_upgrade_gated_on_the_force(bs_regiments):
    assert [a["name"] for a in alpha(bs_regiments)["abilities"]] == ["Company Drill"]


def test_abilities_of_another_regiment_are_not_included(bs_regiments):
    assert [a["name"] for a in old_guard(bs_regiments)["abilities"]] == ["Veteran Stand"]


def test_ungated_upgrade_belongs_to_no_regiment(bs_regiments):
    names = [a["name"] for r in bs_regiments for a in r["abilities"]]
    assert "Unrelated Rule" not in names


def test_publication_comes_from_the_upgrade(bs_regiments):
    assert alpha(bs_regiments)["publication"] == "General's Handbook 2025-26"


def test_publication_falls_back_to_the_first_unit(bs_regiments):
    assert old_guard(bs_regiments)["publication"] == "Battletome: Testers"


def test_units_are_the_links_gated_on_the_force(bs_regiments):
    assert [u["name"] for u in alpha(bs_regiments)["units"]] == ["Test Captain", "Test Riders", "Alpha Champion"]


def test_unit_count_comes_from_the_min_constraint_modifier_on_the_link(bs_regiments):
    assert named(alpha(bs_regiments)["units"], "Test Captain")["count"] == 3


def test_unit_count_comes_from_a_modifier_group_gated_on_the_force(bs_regiments):
    assert named(alpha(bs_regiments)["units"], "Test Riders")["count"] == 2


def test_unit_count_ignores_modifier_groups_gated_on_other_forces(bs_regiments):
    assert named(old_guard(bs_regiments)["units"], "Test Riders")["count"] == 9


def test_unit_count_defaults_to_one(bs_regiments):
    assert named(old_guard(bs_regiments)["units"], "Old Warden")["count"] == 1


def test_unit_notes_come_from_the_renamed_link(bs_regiments):
    assert named(alpha(bs_regiments)["units"], "Test Captain")["notes"] == "1 model"


def test_unit_without_renamed_link_has_no_notes(bs_regiments):
    assert "notes" not in named(alpha(bs_regiments)["units"], "Test Riders")


def test_links_to_things_that_are_not_units_are_skipped(bs_regiments):
    assert "Alpha Banner" not in [u["name"] for u in alpha(bs_regiments)["units"]]


def test_ungated_links_belong_to_no_regiment(bs_regiments):
    assert "Test Wraith" not in [u["name"] for r in bs_regiments for u in r["units"]]


def test_unit_library_is_the_file_defining_it(bs_regiments):
    assert named(alpha(bs_regiments)["units"], "Test Riders")["library"] == "Testers - Library.cat"


def test_units_the_regiments_catalogue_defines_become_its_warscrolls(bs_regiments):
    r = alpha(bs_regiments)
    assert named(r["units"], "Alpha Champion")["library"] == regiments.CATALOGUE + ".cat"
    assert [w["name"] for w in r["warscrolls"]] == ["Alpha Champion"]


def test_own_warscroll_has_its_profile(bs_regiments):
    w = alpha(bs_regiments)["warscrolls"][0]
    assert (w["health"], w["save"], w["control"]) == (8, 3, 3)


def test_units_from_other_libraries_are_not_warscrolls(bs_regiments):
    assert old_guard(bs_regiments)["warscrolls"] == []


def test_missing_regiments_catalogue_stops_the_build(cats):
    del cats.docs[regiments.CATALOGUE + ".cat"]
    with pytest.raises(SystemExit):
        regiments.read_regiments(cats)


# Wahapedia pages

def ability_html(name, effect, timing="Passive"):
    return ('<div class="BreakInsideAvoid"><table><tbody><tr><td class="abHeader">'
            '<img class="abLogo" src="/aos4/img/abShooting.png"/>%s</td></tr></tbody></table>'
            '<div class="abBody"><b>%s:</b> <b>Effect:</b> %s</div></div>' % (timing, name, effect))


ORGANISATION = """
<ul class="wsOrgList"><li>1 <a href="/aos4/factions/helsmiths-of-hashut/Daemonsmith">Daemonsmith</a></li></ul>
<ul class="wsOrgList"><li>2 <a href="/aos4/factions/kruleboyz/Hobgrot-Slittaz">Hobgrot Slittaz</a> units with 10 models</li></ul>
<p class="wsOrgP"><a href="/aos4/factions/sylvaneth/Drycha-Hamadreth">Drycha Hamadreth</a></p>
"""


def page(organisation=ORGANISATION, logo="", extra="", header="REGIMENT OF RENOWN", errata=""):
    return """<html><body><div class="datasheet">
<div class="nails-header"><span class="nails">&bull;</span>%(header)s<span class="nails">&bull;</span></div>
<div class="wsHeaderIn">Made-up Regiment</div>
%(logo)s
<div class="BreakInsideAvoid Corner22"><div class="Columns2">
<div class="BreakInsideAvoid"><div class="wsAbilityHeader">INCLUSION</div>
This Regiment of Renown can be included in armies from the following factions:
<ul><li><a href="/aos4/factions/skaven">Skaven</a></li><li><a href="/aos4/factions/ironjawz">Ironjawz</a></li></ul></div>
<div class="BreakInsideAvoid"><div class="wsAbilityHeader">ORGANISATION</div>%(organisation)s</div>
</div></div>
<div class="Columns2_AoS"><div class="BreakInsideAvoid PitchedBattleProfile"><div class="wsAbilityHeader">BATTLE PROFILE</div>
<span class="redfont">Points</span><b>:</b> 390<br/></div>
<div class="BreakInsideAvoid">%(abilities)s</div></div>
%(errata)s
</div></body></html>""" % {"header": header, "logo": logo, "organisation": organisation, "errata": errata,
                           "abilities": ability_html("First Rule", "The original first rule.") +
                           ability_html("Second Rule", "The second rule.") + extra}


def parse(tmp_path, html=None):
    path = tmp_path / "regiment.html"
    path.write_text(html if html is not None else page(), encoding="utf-8")
    return regiments.parse_regiment_page(str(path))


def test_page_name_comes_from_the_sheet_header(tmp_path):
    assert parse(tmp_path)["name"] == "Made-up Regiment"


def test_page_without_legends_logo_is_not_legends(tmp_path):
    assert "legends" not in parse(tmp_path)


def test_page_with_legends_logo_is_legends(tmp_path):
    logo = '<img src="/aos4/img/expansions/Legends_logo3.png"/>'
    assert parse(tmp_path, page(logo=logo))["legends"] is True


def test_page_factions_come_from_the_inclusion_list(tmp_path):
    assert parse(tmp_path)["factions"] == ["Skaven", "Ironjawz"]


def test_page_points_come_from_the_battle_profile(tmp_path):
    assert parse(tmp_path)["points"] == 390


def test_page_units_come_from_the_organisation_in_order(tmp_path):
    assert [u["name"] for u in parse(tmp_path)["units"]] == ["Daemonsmith", "Hobgrot Slittaz", "Drycha Hamadreth"]


def test_page_unit_has_count_and_home_faction_slug(tmp_path):
    unit = parse(tmp_path)["units"][0]
    assert (unit["count"], unit["faction"]) == (1, "helsmiths-of-hashut")


def test_page_unit_notes_come_from_text_after_the_link(tmp_path):
    assert parse(tmp_path)["units"][1]["notes"] == "10 models"


def test_page_paragraph_with_only_a_link_is_one_unit(tmp_path):
    unit = parse(tmp_path)["units"][2]
    assert (unit["count"], unit["faction"], "notes" in unit) == (1, "sylvaneth", False)


def test_page_unlinked_list_item_is_a_unit_with_no_faction(tmp_path):
    org = "<ul><li>1 Gotrek Gurnisson</li><li>1 Dreadscythe Harridans unit with 10 models</li></ul>"
    units = parse(tmp_path, page(organisation=org))["units"]
    assert [(u["name"], u["faction"], u.get("notes")) for u in units] == [
        ("Gotrek Gurnisson", "", None), ("Dreadscythe Harridans", "", "10 models")]


def test_page_empty_list_items_are_skipped(tmp_path):
    org = ORGANISATION + "<ul><li> </li></ul><p class=\"wsOrgP\"></p>"
    result = parse(tmp_path, page(organisation=org))
    assert len(result["units"]) == 3 and result["text"] == ""


def test_page_unlinked_paragraph_is_a_unit(tmp_path):
    org = '<p class="wsOrgP">Lady Olynder, Mortarch of Grief</p>'
    units = parse(tmp_path, page(organisation=org))["units"]
    assert [u["name"] for u in units] == ["Lady Olynder, Mortarch of Grief"]


def test_page_linked_paragraph_with_prose_is_text_not_a_unit(tmp_path):
    org = ORGANISATION + ('<p class="wsOrgP">The <a href="/aos4/factions/kruleboyz/Killbow">Beast-skewer Killbow</a>'
                          ' in this Regiment of Renown has the <b>HERO</b> keyword.</p>')
    result = parse(tmp_path, page(organisation=org))
    assert len(result["units"]) == 3
    assert result["text"] == "The Beast-skewer Killbow in this Regiment of Renown has the HERO keyword."


def test_page_organisation_paragraph_without_unit_link_is_the_regiments_text(tmp_path):
    org = ORGANISATION + '<p class="wsOrgP">Each unit in this Regiment of Renown has the KEYWORD keyword.</p>'
    result = parse(tmp_path, page(organisation=org))
    assert result["text"] == "Each unit in this Regiment of Renown has the KEYWORD keyword."
    assert len(result["units"]) == 3


def test_page_without_organisation_notes_has_empty_text(tmp_path):
    assert parse(tmp_path)["text"] == ""


def test_page_unit_listed_twice_is_kept_once(tmp_path):
    org = ORGANISATION + ORGANISATION
    assert len(parse(tmp_path, page(organisation=org))["units"]) == 3


def test_page_abilities_are_parsed_in_order(tmp_path):
    assert [a["name"] for a in parse(tmp_path)["abilities"]] == ["First Rule", "Second Rule"]


def test_page_ability_has_its_effect(tmp_path):
    assert parse(tmp_path)["abilities"][1]["effect"] == "The second rule."


def test_errata_ability_replaces_the_same_named_ability(tmp_path):
    errata = ('<div class="Columns2 faqErrataColumns"><div class="faqErrataCol BreakInsideAvoid">'
              + ability_html("First Rule", "The corrected first rule.") + "</div></div>")
    abilities = parse(tmp_path, page(errata=errata))["abilities"]
    assert [(a["name"], a["effect"]) for a in abilities] == [("First Rule", "The corrected first rule."),
                                                              ("Second Rule", "The second rule.")]


def test_errata_ability_with_a_new_name_is_appended(tmp_path):
    errata = ('<div class="Columns2 faqErrataColumns"><div class="faqErrataCol BreakInsideAvoid">'
              + ability_html("Third Rule", "A new rule.") + "</div></div>")
    abilities = parse(tmp_path, page(errata=errata))["abilities"]
    assert [a["name"] for a in abilities] == ["First Rule", "Second Rule", "Third Rule"]


def test_identical_ability_is_not_repeated(tmp_path):
    abilities = parse(tmp_path, page(extra=ability_html("Second Rule", "The second rule.")))["abilities"]
    assert [a["name"] for a in abilities] == ["First Rule", "Second Rule"]


def test_page_with_only_the_regiment_sheet_has_no_warscrolls(tmp_path):
    assert parse(tmp_path)["warscrolls"] == []


def test_page_without_a_regiment_sheet_stops_the_build(tmp_path):
    with pytest.raises(SystemExit):
        parse(tmp_path, page(header="WARSCROLL"))


# _organisation_entry()

def entry(html):
    item = BeautifulSoup(html, "lxml").select_one("li, p")
    return regiments._organisation_entry(item, wahapedia)


def test_entry_count_name_and_faction():
    result = entry('<li>3 <a href="/aos4/factions/ironjawz/Ardboyz">Ardboyz</a></li>')
    assert (result["count"], result["name"], result["faction"]) == (3, "Ardboyz", "ironjawz")


def test_entry_without_a_count_is_one():
    assert entry('<p><a href="/aos4/factions/ironjawz/Gordrakk">Gordrakk</a></p>')["count"] == 1


def test_entry_notes_drop_the_unit_with_prefix():
    result = entry('<li>2 <a href="/aos4/factions/x/Slittaz">Slittaz</a> units with 10 models</li>')
    assert result["notes"] == "10 models"


def test_entry_notes_drop_the_brackets():
    result = entry('<li>1 <a href="/aos4/factions/x/Frigate">Arkanaut Frigate</a> (the Aelsling)</li>')
    assert result["notes"] == "the Aelsling"


def test_entry_notes_drop_a_bracketed_unit_with_prefix():
    result = entry('<li>1 <a href="/aos4/factions/x/Boltboyz">Man-skewer Boltboyz</a> (unit with 3 models)</li>')
    assert result["notes"] == "3 models"


def test_entry_without_notes_has_no_notes_key():
    assert "notes" not in entry('<li>1 <a href="/aos4/factions/x/Hero">Hero</a></li>')


def test_entry_ending_in_a_full_stop_has_no_notes_key():
    assert "notes" not in entry('<li>1 <a href="/aos4/factions/x/Aquilor">Lord-Aquilor</a>.</li>')


def test_entry_notes_drop_a_closing_full_stop():
    result = entry('<li>1 <a href="/aos4/factions/x/Knights">Chaos Knights</a> unit with 5 models.</li>')
    assert result["notes"] == "5 models"


def test_entry_without_a_link_has_no_faction():
    result = entry("<li>1 Mystery Unit</li>")
    assert (result["name"], result["faction"]) == ("Mystery Unit", "")


def test_entry_optional_unit_keeps_its_range_as_notes():
    result = entry('<li>0-1 <a href="/aos4/factions/x/Edmark">Edmark Valoran the Manticore Knight</a></li>')
    assert (result["count"], result["name"], result["notes"]) == (1, "Edmark Valoran the Manticore Knight", "0-1")


def test_entry_optional_unit_range_joins_other_notes():
    result = entry('<li>0-1 <a href="/aos4/factions/x/Edmark">Edmark</a> (the Manticore Knight)</li>')
    assert result["notes"] == "0-1, the Manticore Knight"


def test_entry_link_text_holding_the_size_is_split_into_name_and_notes():
    result = entry('<li>1 <a href="/aos4/factions/x/Guard">Stormdrake Guard (1 model)</a></li>')
    assert (result["name"], result["notes"]) == ("Stormdrake Guard", "1 model")


def test_unlinked_entry_name_ends_where_its_size_starts():
    result = entry("<li>1 Dreadscythe Harridans unit with 10 models</li>")
    assert (result["name"], result["notes"]) == ("Dreadscythe Harridans", "10 models")


# _is_unit_paragraph()

def paragraph(html):
    return BeautifulSoup('<p class="wsOrgP">%s</p>' % html, "lxml").select_one("p")


def is_unit(html):
    return regiments._is_unit_paragraph(paragraph(html), wahapedia)


LINK = '<a href="/aos4/factions/sylvaneth/Drycha-Hamadreth">Drycha Hamadreth</a>'


@pytest.mark.parametrize("html", [
    LINK, "1 " + LINK, LINK + " (1 model)", LINK + " unit with 5 models", LINK + " units with 5 models",
    LINK + " with 3 Wardens",
])
def test_linked_paragraph_with_only_a_name_and_size_is_a_unit(html):
    assert is_unit(html)


@pytest.mark.parametrize("html", [
    "The " + LINK + " in this Regiment of Renown has the <b>HERO</b> keyword.",
    LINK + " is a very good unit.",
])
def test_linked_paragraph_with_other_prose_is_regiment_text(html):
    assert not is_unit(html)


def test_unlinked_paragraph_that_is_just_a_name_is_a_unit():
    assert is_unit("Lady Olynder, Mortarch of Grief")


def test_unlinked_paragraph_ending_in_a_full_stop_is_regiment_text():
    assert not is_unit("Each unit in this Regiment of Renown has the KRITTOK'S CLAWPACK keyword.")


def test_unlinked_paragraph_with_a_colon_is_regiment_text():
    assert not is_unit("<b>Designer’s Note</b>: Treat it as one unit")


# wahapedia_slug() and page_names()

def test_slug_replaces_punctuation_with_hyphens():
    assert regiments.wahapedia_slug("The Liche's Hand") == "The-Liche-s-Hand"


def test_slug_treats_a_curly_apostrophe_like_a_straight_one():
    assert regiments.wahapedia_slug("Kountin’ Krew") == regiments.wahapedia_slug("Kountin' Krew")


def test_slug_has_no_leading_or_trailing_hyphen():
    assert regiments.wahapedia_slug("  Krew! ") == "Krew"


def test_page_names_start_with_the_regiments_own_slug():
    assert regiments.page_names({"name": "Brand's Oathbound"})[0] == "Brand-s-Oathbound"


def test_page_names_try_the_name_without_and_with_the_article():
    names = regiments.page_names({"name": "The Liche's Hand"})
    assert "Liche-s-Hand" in names
    assert "The-Liche-s-Hand" in names
    assert "The-The-Liche-s-Hand" in names


def test_page_names_try_every_word_capitalised():
    assert "Hargax-Pit-Beasts" in regiments.page_names({"name": "Hargax Pit-beasts"})


def test_page_names_keep_a_possessive_s_lower_case_when_capitalising():
    assert "Hargax-s-Pit-Beasts" in regiments.page_names({"name": "Hargax's Pit-beasts"})
    assert "Hargax-S-Pit-Beasts" not in regiments.page_names({"name": "Hargax's Pit-beasts"})


def test_page_names_put_the_alias_first():
    names = regiments.page_names({"name": "Big Drogg Fort-kicker"}, {"Big Drogg Fort-kicker": "Big Drogg Fort-Kicka"})
    assert names[0] == "Big-Drogg-Fort-Kicka"


def test_page_names_ignore_aliases_of_other_regiments():
    assert regiments.page_names({"name": "Krew"}, {"Other": "Elsewhere"})[0] == "Krew"


def test_page_names_have_no_duplicates():
    names = regiments.page_names({"name": "Krew"})
    assert len(names) == len(set(names))


# merge_regiments()

def bs_regiment(**fields):
    r = {"name": "Krew", "points": 280, "factions": ["Skaven"], "armies": [], "publication": "",
         "units": [{"count": 3, "name": "Gutter Runners", "library": "Skaven - Library.cat"},
                   {"count": 1, "name": "Warlord", "library": "Skaven - Library.cat", "notes": "BSData note"}],
         "abilities": [{"name": "First Rule", "timing": "Passive", "effect": "Same."},
                       {"name": "Second Rule", "timing": "Passive", "effect": "Same."}],
         "warscrolls": []}
    r.update(fields)
    return r


def wh_regiment(**fields):
    r = {"name": "Krew", "points": 280, "text": "", "factions": ["Skaven"],
         "units": [{"count": 3, "name": "Gutter Runners", "faction": "skaven", "notes": "wh note"},
                   {"count": 1, "name": "Warlord", "faction": "skaven", "notes": "wh note"}],
         "abilities": [{"name": "Second Rule", "timing": "Passive", "effect": "Same."},
                       {"name": "First Rule", "timing": "Passive", "effect": "Same."}],
         "warscrolls": []}
    r.update(fields)
    return r


def do_merge(bs, wh):
    report = merge.Report()
    return regiments.merge_regiments(report, bs, wh), report.lines


def test_merge_of_agreeing_sources_reports_nothing():
    assert do_merge([bs_regiment()], [wh_regiment()])[1] == []


def test_merge_keeps_bsdata_unit_counts():
    wh = wh_regiment()
    wh["units"][0]["count"] = 9
    merged, report = do_merge([bs_regiment()], [wh])
    assert merged[0]["units"][0]["count"] == 3
    assert report == []


def test_merge_takes_each_units_faction_from_wahapedia():
    merged, _ = do_merge([bs_regiment()], [wh_regiment()])
    assert {u["faction"] for u in merged[0]["units"]} == {"skaven"}


def test_merge_takes_unit_notes_from_wahapedia_when_bsdata_has_none():
    merged, _ = do_merge([bs_regiment()], [wh_regiment()])
    assert named(merged[0]["units"], "Gutter Runners")["notes"] == "wh note"


def test_merge_keeps_bsdata_unit_notes():
    merged, _ = do_merge([bs_regiment()], [wh_regiment()])
    assert named(merged[0]["units"], "Warlord")["notes"] == "BSData note"


def test_merge_takes_text_from_wahapedia():
    merged, _ = do_merge([bs_regiment()], [wh_regiment(text="Everything has a keyword.")])
    assert merged[0]["text"] == "Everything has a keyword."


def test_merge_without_wahapedia_text_adds_none():
    merged, _ = do_merge([bs_regiment()], [wh_regiment()])
    assert "text" not in merged[0]


def test_merge_orders_abilities_like_wahapedia():
    merged, _ = do_merge([bs_regiment()], [wh_regiment()])
    assert [a["name"] for a in merged[0]["abilities"]] == ["Second Rule", "First Rule"]


def test_merge_orders_units_like_wahapedia():
    wh = wh_regiment()
    wh["units"].reverse()
    merged, _ = do_merge([bs_regiment()], [wh])
    assert [u["name"] for u in merged[0]["units"]] == ["Warlord", "Gutter Runners"]


def test_merge_reports_differing_points():
    _, report = do_merge([bs_regiment()], [wh_regiment(points=300)])
    assert len(report) == 1 and "points" in report[0] and "Krew" in report[0]


def test_merge_reports_differing_legends():
    _, report = do_merge([bs_regiment(legends=True)], [wh_regiment()])
    assert len(report) == 1 and "legends" in report[0]


def test_merge_reports_differing_factions():
    _, report = do_merge([bs_regiment()], [wh_regiment(factions=["Skaven", "Ironjawz"])])
    assert len(report) == 1 and "factions" in report[0]


def test_merge_compares_faction_names_loosely():
    assert do_merge([bs_regiment()], [wh_regiment(factions=["SKAVEN"])])[1] == []


def test_merge_ignores_wahapedia_factions_that_are_bsdata_armies_of_renown():
    bs = bs_regiment(armies=["Legion of the First Prince"])
    wh = wh_regiment(factions=["Skaven", "Legion of the First Prince"])
    assert do_merge([bs], [wh])[1] == []


def test_merge_reports_a_differing_ability():
    wh = wh_regiment()
    wh["abilities"][0] = {"name": "Second Rule", "timing": "Passive", "effect": "Different."}
    _, report = do_merge([bs_regiment()], [wh])
    assert report and all("Second Rule" in line or "effect" in line for line in report)


def test_merge_reports_a_unit_only_bsdata_lists_and_clears_its_faction():
    wh = wh_regiment()
    del wh["units"][1]
    merged, report = do_merge([bs_regiment()], [wh])
    assert named(merged[0]["units"], "Warlord")["faction"] == ""
    assert any("only in BSData" in line and "Warlord" in line for line in report)


def test_merge_keeps_and_reports_a_unit_only_wahapedia_lists():
    wh = wh_regiment()
    wh["units"].append({"count": 1, "name": "Manifestation", "faction": "skaven"})
    merged, report = do_merge([bs_regiment()], [wh])
    assert "Manifestation" in [u["name"] for u in merged[0]["units"]]
    assert any("only in Wahapedia" in line and "Manifestation" in line for line in report)


def test_merge_keeps_a_regiment_only_bsdata_has_with_no_unit_factions():
    merged, report = do_merge([bs_regiment()], [])
    assert [u["faction"] for u in merged[0]["units"]] == ["", ""]
    assert any("only in BSData" in line for line in report)


def test_merge_drops_but_reports_a_regiment_only_wahapedia_has():
    merged, report = do_merge([], [wh_regiment()])
    assert merged == []
    assert any("only in Wahapedia" in line for line in report)


# regiment()

def resolved(**fields):
    r = bs_regiment(source="White Dwarf", text="Rules text.", legends=True)
    for u in r["units"]:
        u.update(faction_id="skaven", warscroll="gutter_runners")
    r.update(fields)
    return r


def test_regiment_has_name_points_and_units():
    out = regiments.regiment(resolved())
    assert (out["name"], out["points"], len(out["units"])) == ("Krew", 280, 2)


def test_regiment_lists_its_faction_ids():
    assert regiments.regiment(resolved(faction_ids=["ironjawz", "skaven"]))["factions"] == ["ironjawz", "skaven"]


def test_regiment_without_faction_ids_lists_no_factions():
    assert regiments.regiment(resolved())["factions"] == []


def test_regiment_unit_names_its_faction_and_warscroll():
    unit = regiments.regiment(resolved())["units"][0]
    assert (unit["count"], unit["faction"], unit["warscroll"]) == (3, "skaven", "gutter_runners")


def test_regiment_unit_without_a_faction_omits_the_key():
    r = resolved()
    r["units"][0]["faction_id"] = ""
    assert "faction" not in regiments.regiment(r)["units"][0]


def test_regiment_unit_notes_are_kept_only_when_present():
    units = regiments.regiment(resolved())["units"]
    assert ("notes" in units[0], units[1].get("notes")) == (False, "BSData note")


def test_regiment_optional_fields_are_kept_when_set():
    out = regiments.regiment(resolved())
    assert (out["source"], out["legends"], out["text"]) == ("White Dwarf", True, "Rules text.")


def test_regiment_omits_empty_optional_fields():
    out = regiments.regiment(resolved(source="", legends=False, text=""))
    assert not {"source", "legends", "text", "warscrolls"} & set(out)


def test_regiment_abilities_are_in_the_schema_shape():
    ability = regiments.regiment(resolved())["abilities"][0]
    assert (ability["name"], ability["type"]) == ("First Rule", "passive")


def test_regiment_own_warscrolls_are_in_the_schema_shape():
    r = resolved(warscrolls=[{"id": "champ", "name": "Champ", "points": 0, "move": "5", "health": 4}])
    warscroll = regiments.regiment(r)["warscrolls"][0]
    assert (warscroll["id"], warscroll["health"]) == ("champ", 4)
