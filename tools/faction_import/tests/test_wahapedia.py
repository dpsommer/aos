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
