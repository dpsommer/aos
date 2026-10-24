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
