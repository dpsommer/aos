import wahapedia


PAGE = """<html><body>
<h2>Books</h2>
<h2>Faction Rules</h2>
<h2>Battle Formations</h2>
<h3>Lords of the Clan</h3>
<p>A formation that shares its name with an Army of Renown.</p>
<h2>Lords of the Clan</h2>
<p>Lead the clan to war.</p>
<p>ROSTER OPTIONS</p>
<p>The Lady of Vines</p>
<h3>Battle Traits</h3>
</body></html>"""


def parse(tmp_path, page=PAGE):
    path = tmp_path / "faction.html"
    path.write_text(page, encoding="utf-8")
    return wahapedia.parse_faction_page(str(path))


def test_army_of_renown_sharing_a_formation_name_is_found(tmp_path):
    aors = parse(tmp_path)["armies_of_renown"]
    assert [a["name"] for a in aors] == ["Lords of the Clan"]


def test_army_of_renown_sharing_a_formation_name_reads_its_own_text(tmp_path):
    aor = parse(tmp_path)["armies_of_renown"][0]
    assert aor["text"].startswith("Lead the clan to war.")
    assert "formation" not in aor["text"]


def test_formation_sharing_an_army_of_renown_name_stays_a_formation(tmp_path):
    formations = parse(tmp_path)["faction"]["battle_formations"]
    assert [f["name"] for f in formations] == ["Lords of the Clan"]


def test_heading_repeated_before_faction_rules_does_not_shift_section_text(tmp_path):
    page = PAGE.replace("<h2>Books</h2>", "<h2>Lords of the Clan</h2><p>Book blurb.</p>")
    aor = parse(tmp_path, page)["armies_of_renown"][0]
    assert aor["text"].startswith("Lead the clan to war.")


def test_army_of_renown_without_roster_heading_is_found_from_its_text(tmp_path):
    page = PAGE.replace("<p>ROSTER OPTIONS</p>",
                        "<p>Take the units listed in the roster options box below.</p>")
    aors = parse(tmp_path, page)["armies_of_renown"]
    assert [a["name"] for a in aors] == ["Lords of the Clan"]


def test_section_without_roster_options_is_not_an_army_of_renown(tmp_path):
    page = PAGE.replace("<p>ROSTER OPTIONS</p>", "<p>Some other options.</p>")
    assert parse(tmp_path, page)["armies_of_renown"] == []


# parse_profile()

def profile(notes):
    html = ('<div class="PitchedBattleProfile"><p>Unit Size: 1</p><p>Points: 200</p>'
            '<p>Base size: 120 x 92mm</p><p>Notes: %s</p></div>' % notes)
    return wahapedia.BeautifulSoup(html, "html.parser").div


LEGENDS_NOTE = "This unit will move to Warhammer Legends on 1 June 2027."


def test_profile_notes_drop_trailing_base_size():
    assert wahapedia.parse_profile(profile(LEGENDS_NOTE + " 120 x 92mm"))["notes"] == LEGENDS_NOTE


def test_profile_notes_drop_trailing_base_size_with_times_sign():
    assert wahapedia.parse_profile(profile(LEGENDS_NOTE + " 120 × 92mm"))["notes"] == LEGENDS_NOTE


def test_profile_notes_without_base_size_are_unchanged():
    assert wahapedia.parse_profile(profile(LEGENDS_NOTE))["notes"] == LEGENDS_NOTE


# text() / section_text()

def tag(html):
    return wahapedia.BeautifulSoup("<div>%s</div>" % html, "html.parser").div


def test_text_joins_keyword_split_after_hyphen_by_tags():
    html = '<span class="kwnon">non-</span><span class="kwb">HERO</span> unit'
    assert wahapedia.text(tag(html)) == "non-HERO unit"


def test_text_keeps_spaced_dash_between_words():
    assert wahapedia.text(tag("Rend <b>-</b> Damage")) == "Rend - Damage"


def test_section_text_joins_keyword_split_after_hyphen_by_tags():
    soup = wahapedia.BeautifulSoup('<h3>Heading</h3><p>Pick a <span>non-</span><span>HERO</span> unit.</p>',
                                   "html.parser")
    assert wahapedia.section_text(soup.h3) == "Pick a non-HERO unit."


# cell_texts() / table_rows()

def cell(html):
    return wahapedia.BeautifulSoup("<table><tr><td>%s</td></tr></table>" % html, "html.parser").td


def rows(html):
    return wahapedia.table_rows(wahapedia.BeautifulSoup(html, "html.parser").table)


def test_cell_without_list_is_one_text():
    assert wahapedia.cell_texts(cell("10 Cryptguard <b>and</b> friends")) == ["10 Cryptguard and friends"]


def test_cell_list_items_become_cells_of_their_own():
    texts = wahapedia.cell_texts(cell("<ul><li>10 Cryptguard</li><li>Varghulf Courtier</li></ul>"))
    assert texts == ["10 Cryptguard", "Varghulf Courtier"]


def test_ordered_list_items_become_cells_of_their_own():
    texts = wahapedia.cell_texts(cell("<ol><li>3 Morbheg Knights</li><li>Varghulf Courtier</li></ol>"))
    assert texts == ["3 Morbheg Knights", "Varghulf Courtier"]


def test_cell_text_beside_a_list_is_kept_as_its_own_cell():
    texts = wahapedia.cell_texts(cell("<div>General</div><ul><li>Abhorrant Archregent</li></ul>"))
    assert texts == ["General", "Abhorrant Archregent"]


def test_list_nested_below_a_cell_child_is_not_split():
    texts = wahapedia.cell_texts(cell("<div><ul><li>10 Cryptguard</li><li>Varghulf Courtier</li></ul></div>"))
    assert len(texts) == 1


def test_table_rows_split_list_cells_and_drop_blank_text():
    html = ("<table><tr><td><div>Units</div>\n<ul>\n<li>10 Cryptguard</li>\n<li>Varghulf Courtier</li>\n</ul>\n</td>"
            "</tr></table>")
    assert rows(html) == [["Units", "10 Cryptguard", "Varghulf Courtier"]]


def test_table_rows_keep_cells_without_lists():
    html = "<table><tr><th>General</th><td>Abhorrant Archregent</td></tr></table>"
    assert rows(html) == [["General", "Abhorrant Archregent"]]


# parse_weapons()

MELEE_TABLE = """<table class="wsTable">
<tr class="wsHeaderRow"><td>MELEE WEAPONS</td></tr>
%s
</table>"""


def melee_row(name, cells):
    return ('<tr class="wsDataRow"><td class="wsDataCell_long"></td><td class="wsDataCell_long">%s</td>%s</tr>'
            % (name, cells))


def melee_weapons(*rows):
    table = wahapedia.BeautifulSoup(MELEE_TABLE % "".join(rows), "html.parser").table
    return wahapedia.parse_weapons(table)[1]


def test_melee_weapon_reads_its_characteristics():
    cells = "".join('<td class="wsCell">%s</td>' % v for v in ["3", "3+", "4+", "1", "D3"])
    assert melee_weapons(melee_row("Greatblade", cells)) == [
        {"name": "Greatblade", "range": 0, "attacks": "3", "hit": 3, "wound": 4, "rend": 1, "damage": "D3"}]


def test_weapon_with_see_below_has_no_attack_sequence_characteristics():
    cells = '<td class="wsCell">1</td><td colspan="4">See below</td>'
    assert melee_weapons(melee_row("Perfect Strike", cells)) == [
        {"name": "Perfect Strike", "range": 0, "attacks": "1", "hit": 0, "wound": 0, "rend": 0, "damage": "-"}]


def test_weapon_ability_split_after_hyphen_by_tags_is_joined():
    cells = "".join('<td class="wsCell">%s</td>' % v for v in ["3", "3+", "4+", "1", "D3"])
    name = 'Greatblade <span class="wsWeaponAbility">Anti-<span class="kwb">WIZARD</span> (+1 Rend)</span>'
    assert melee_weapons(melee_row(name, cells))[0]["abilities"] == ["Anti-WIZARD (+1 Rend)"]


# parse_unit_pages()

def unit_page(tmp_path, header):
    path = tmp_path / "unit.html"
    path.write_text('<html><body><div class="datasheet"><div class="wsBody"><div class="wsBodyTop">'
                    '<div class="nails-header">%s</div><div class="wsHeaderIn">Test Unit</div>'
                    '</div><div class="wsBodyBottom"></div></div></div></body></html>' % header, encoding="utf-8")
    return wahapedia.parse_unit_pages([str(path)])


def test_regiment_of_renown_sheet_is_not_a_warscroll(tmp_path):
    assert unit_page(tmp_path, '<span class="nails">•</span>REGIMENT OF RENOWN<span class="nails">•</span>') == []


def test_warscroll_sheet_with_nails_header_is_a_warscroll(tmp_path):
    assert [w["name"] for w in unit_page(tmp_path, '<span class="nails">•</span>WARSCROLL<span class="nails">•</span>')] == ["Test Unit"]


# Spearhead Battle Traits outside ability blocks

SPEARHEAD_PAGE = """<html><body>
<h2>Faction Rules</h2>
<h2>SPEARHEAD</h2>
<h2>Madmob</h2>
<table><tr><td>General</td><td>1 Loonboss</td></tr></table>
<div><h3>Battle Traits</h3><div class="Columns2">%s</div></div>
<div><h3>Regiment Abilities</h3></div>
</body></html>"""

ABILITY = ('<div class="BreakInsideAvoid"><table><tr><td class="abHeader">Your Movement Phase</td></tr></table>'
           '<div class="abBody"><b>SQUIGALANCHE:</b> <b>Effect:</b> Set up the unit.</div></div>')

RESERVE = "One of your units of Squig Hoppers is not set up during the deployment phase."

TRAIT_TABLE = ('<div><table class="customTable">'
               '<tr><td>Roll</td><td>Temptation</td></tr>'
               '<tr><td>18+</td><td><b>SADISTIC SPITE:</b> This unit\'s melee weapons have Crit (Mortal).</td></tr>'
               '<tr><td>12-17</td><td><b>HEEDLESS FURY:</b> Add 1 to charge rolls.</td></tr>'
               '</table></div>')


def battle_traits(tmp_path, body):
    return parse(tmp_path, SPEARHEAD_PAGE % body)["spearheads"][0]["battle_traits"]


def test_spearhead_text_before_ability_becomes_its_text(tmp_path):
    traits = battle_traits(tmp_path, RESERVE + "<br><br>" + ABILITY)
    assert [t["name"] for t in traits] == ["SQUIGALANCHE"]
    assert traits[0]["text"] == RESERVE


def test_spearhead_text_before_ability_keeps_ability_effect(tmp_path):
    traits = battle_traits(tmp_path, RESERVE + "<br><br>" + ABILITY)
    assert traits[0]["effect"] == "Set up the unit."


def test_spearhead_ability_alone_has_no_text(tmp_path):
    traits = battle_traits(tmp_path, ABILITY)
    assert [t["name"] for t in traits] == ["SQUIGALANCHE"]
    assert "text" not in traits[0]


def test_spearhead_text_before_ability_does_not_reach_regiment_abilities(tmp_path):
    page = (SPEARHEAD_PAGE % (RESERVE + "<br><br>" + ABILITY)).replace(
        '<div><h3>Regiment Abilities</h3></div>', '<div><h3>Regiment Abilities</h3>%s</div>' % ABILITY)
    regiment = parse(tmp_path, page)["spearheads"][0]["regiment_abilities"]
    assert "text" not in regiment[0]


def titled_rule(text_html="Each turn, roll on the table below.", table=TRAIT_TABLE):
    return '<div class="h_custom">TEMPTATIONS</div>' + text_html + table


def test_spearhead_titled_rule_without_ability_becomes_battle_trait(tmp_path):
    traits = battle_traits(tmp_path, titled_rule())
    assert [t["name"] for t in traits] == ["TEMPTATIONS"]


def test_spearhead_titled_rule_effect_is_its_text(tmp_path):
    trait = battle_traits(tmp_path, titled_rule())[0]
    assert trait["effect"] == "Each turn, roll on the table below."


def test_spearhead_titled_rule_options_come_from_table_rows_without_header(tmp_path):
    options = battle_traits(tmp_path, titled_rule())[0]["options"]
    assert options == [
        {"name": "18+: Sadistic Spite", "text": "This unit's melee weapons have Crit (Mortal)."},
        {"name": "12-17: Heedless Fury", "text": "Add 1 to charge rolls."},
    ]


def test_spearhead_titled_rule_without_table_has_no_options(tmp_path):
    trait = battle_traits(tmp_path, titled_rule(table=""))[0]
    assert trait["effect"] == "Each turn, roll on the table below."
    assert not trait.get("options")


def test_spearhead_untitled_text_without_ability_is_dropped(tmp_path):
    assert battle_traits(tmp_path, RESERVE) == []


def test_spearhead_titled_rule_table_is_not_the_army_table(tmp_path):
    army = parse(tmp_path, SPEARHEAD_PAGE % titled_rule())["spearheads"][0]["army"]
    assert army == [["General", "1 Loonboss"]]


# text_join()

def join_children(html):
    from bs4 import BeautifulSoup
    return wahapedia.text_join(list(BeautifulSoup(html, "lxml").find("div").children))


def test_text_join_renders_list_items_as_bullet_lines():
    assert join_children("<div>Pick one:<ul><li>First</li><li>Second</li></ul></div>") == "Pick one:\n• First\n• Second"


def test_text_join_renders_ordered_list_items_as_bullet_lines():
    assert join_children("<div><ol><li>First</li><li>Second</li></ol></div>") == "• First\n• Second"


def test_text_join_keeps_text_after_a_list_on_its_own_line():
    assert join_children("<div><ul><li>First</li></ul>Then stop.</div>") == "• First\nThen stop."


def test_text_join_removes_whitespace_after_open_brackets():
    assert wahapedia.text_join(["Roll (", "a dice", ") and [", "pick", "]"]) == "Roll (a dice) and [pick]"


# parse_manifestation_lores()

def block(header, name, body="", casting=None):
    points = '<div class="abSpellPointsN">%s</div>' % casting if casting else ""
    return ('<div class="BreakInsideAvoid"><table><tr><td class="abHeader"><img class="abLogo" src="/img/abSpecial.png">%s</td>'
            '<td>%s</td></tr></table><div class="abBody"><b>%s:</b> <b>Effect:</b> %s</div></div>' % (header, points, name, body))


def sheet(name, composition=None):
    desc = '<div class="wsDescription">%s</div>' % composition if composition else ""
    return '<div class="datasheet"><div class="wsBodyTop"><div class="wsHeaderIn">%s</div></div>%s</div>' % (name, desc)


LORES_PAGE = """<html><body>
<h2>Intro</h2><h3>Not A Lore</h3>
<h2>Manifestation Lore</h2>
<table><tr><td>Lore One</td><td>20</td></tr><tr><td>LORE TWO</td><td>10</td></tr><tr><td>Name</td><td>Points</td></tr></table>
<h3>Lore One</h3>
%s
%s
<h3>Lore Two</h3>
%s
<h2>Errata</h2>
<h3>Lore Three</h3>
%s
%s
%s
%s
</body></html>""" % (
    block("Your Hero Phase", "SUMMON ONE", "Set up one.", casting=6),
    block("Your Hero Phase", "SUMMON TWO", "Set up two.", casting=7),
    block("Your Hero Phase", "SUMMON THREE", "Set up three.", casting=8),
    block("Your Hero Phase", "AFTER ERRATA"),
    sheet("Thing One", "SUMMONING REFERENCE: keep this"),
    sheet("Thing One"),
    sheet("Thing Two", "1 model"),
)


def parse_lores(tmp_path, page=LORES_PAGE):
    path = tmp_path / "endless-spells.html"
    path.write_text(page, encoding="utf-8")
    return wahapedia.parse_manifestation_lores(str(path))


def test_manifestation_lores_are_the_h3_headings_after_the_manifestation_lore_heading(tmp_path):
    lores = parse_lores(tmp_path)["lores"]
    assert [(l["name"], l["kind"]) for l in lores] == [("Lore One", "manifestation"), ("Lore Two", "manifestation")]


def test_manifestation_lore_points_come_from_the_table_before_the_first_lore(tmp_path):
    lores = parse_lores(tmp_path)["lores"]
    assert [l["points"] for l in lores] == [20, 10]


def test_manifestation_lore_without_a_points_row_has_zero_points(tmp_path):
    page = LORES_PAGE.replace("<tr><td>LORE TWO</td><td>10</td></tr>", "")
    assert parse_lores(tmp_path, page)["lores"][1]["points"] == 0


def test_manifestation_lore_entries_are_its_ability_blocks(tmp_path):
    lores = parse_lores(tmp_path)["lores"]
    assert [[e["name"] for e in l["entries"]] for l in lores] == [["SUMMON ONE", "SUMMON TWO"], ["SUMMON THREE"]]


def test_manifestation_lore_entry_is_parsed_as_an_ability(tmp_path):
    entry = parse_lores(tmp_path)["lores"][0]["entries"][0]
    assert (entry["timing"], entry["effect"], entry["casting_value"]) == ("Your Hero Phase", "Set up one.", 6)


def test_manifestation_lores_stop_at_the_errata_heading(tmp_path):
    names = [e["name"] for l in parse_lores(tmp_path)["lores"] for e in l["entries"]]
    assert "AFTER ERRATA" not in names


def test_manifestation_lores_stop_at_the_first_datasheet_without_errata(tmp_path):
    page = LORES_PAGE.replace("<h2>Errata</h2>", "")
    page = page.replace(sheet("Thing One", "SUMMONING REFERENCE: keep this"), sheet("Early") + block("Your Hero Phase", "LATE", "x"), 1)
    lores = parse_lores(tmp_path, page)["lores"]
    assert "LATE" not in [e["name"] for l in lores for e in l["entries"]]


def test_manifestation_warscrolls_are_deduplicated_by_name(tmp_path):
    assert [w["name"] for w in parse_lores(tmp_path)["warscrolls"]] == ["Thing One", "Thing Two"]


def test_summoning_reference_composition_is_dropped(tmp_path):
    assert "composition" not in parse_lores(tmp_path)["warscrolls"][0]


def test_real_composition_is_kept(tmp_path):
    assert parse_lores(tmp_path)["warscrolls"][1]["composition"] == "1 model"
