import build_core

from test_wahapedia import LORES_PAGE


def bs_ability(name, **kw):
    a = {"name": name, "category": "special", "timing": "Your Hero Phase", "effect": "Set up one."}
    a.update(kw)
    return a


def bs_warscroll(name, abilities=()):
    return {"id": name.lower().replace(" ", "_"), "name": name, "unit_size": 1, "move": "0", "health": 0, "save": 0,
            "control": 0, "ranged_weapons": [], "melee_weapons": [], "abilities": list(abilities), "keywords": []}


def build(tmp_path, monkeypatch, bs_warscrolls=(), bs_abilities=(), overrides=None, page=LORES_PAGE):
    path = tmp_path / "endless-spells.html"
    path.write_text(page, encoding="utf-8")
    abilities = {build_core.merge.norm(a["name"]): a for a in bs_abilities}
    monkeypatch.setattr(build_core, "bsdata_entries", lambda d: (list(bs_warscrolls), abilities))
    return build_core.build(str(path), "unused", overrides)


def test_spells_take_the_name_casing_of_the_matching_bsdata_ability(tmp_path, monkeypatch):
    data, _ = build(tmp_path, monkeypatch, bs_abilities=[bs_ability("Summon One")])
    assert data["lores"][0]["entries"][0]["name"] == "Summon One"


def test_spell_without_a_bsdata_match_keeps_its_name_and_is_reported(tmp_path, monkeypatch):
    data, report = build(tmp_path, monkeypatch, bs_abilities=[bs_ability("Summon One")])
    assert data["lores"][0]["entries"][1]["name"] == "SUMMON TWO"
    assert any("SUMMON TWO" in line for line in report.lines)


def test_warscroll_abilities_take_the_name_of_the_matching_bsdata_warscroll_ability(tmp_path, monkeypatch):
    page = LORES_PAGE.replace(
        '<div class="datasheet"><div class="wsBodyTop"><div class="wsHeaderIn">Thing One</div></div>'
        '<div class="wsDescription">SUMMONING REFERENCE: keep this</div></div>',
        '<div class="datasheet"><div class="wsBodyTop"><div class="wsHeaderIn">Thing One</div><div class="Columns2_AoS">'
        '<div class="BreakInsideAvoid"><table><tr><td class="abHeader">Passive</td></tr></table>'
        '<div class="abBody"><b>SOME POWER:</b> <b>Effect:</b> Does it.</div></div></div></div></div>')
    bs = bs_warscroll("Thing One", [bs_ability("Some Power", timing="Passive")])
    data, _ = build(tmp_path, monkeypatch, bs_warscrolls=[bs], page=page)
    first = next(w for w in data["warscrolls"] if w["name"] == "Thing One")
    assert [a["name"] for a in first["abilities"]] == ["Some Power"]


def test_warscroll_takes_the_name_and_id_of_the_paired_bsdata_warscroll(tmp_path, monkeypatch):
    bs = bs_warscroll("THING ONE")
    bs["id"] = "bsdata_id"
    data, _ = build(tmp_path, monkeypatch, bs_warscrolls=[bs])
    assert ("THING ONE", "bsdata_id") in [(w["name"], w["id"]) for w in data["warscrolls"]]


def test_warscrolls_are_sorted_by_name(tmp_path, monkeypatch):
    data, _ = build(tmp_path, monkeypatch)
    names = [w["name"] for w in data["warscrolls"]]
    assert names == sorted(names)


def test_every_lore_has_points_even_when_zero(tmp_path, monkeypatch):
    page = LORES_PAGE.replace("<tr><td>LORE TWO</td><td>10</td></tr>", "")
    data, _ = build(tmp_path, monkeypatch, page=page)
    assert [l["points"] for l in data["lores"]] == [20, 0]


def test_fields_override_is_applied_to_a_spell(tmp_path, monkeypatch):
    overrides = {"fields": {"SUMMON TWO": {"effect": "Overridden."}}}
    data, _ = build(tmp_path, monkeypatch, overrides=overrides)
    assert data["lores"][0]["entries"][1]["effect"] == "Overridden."


def test_fields_override_leaves_other_spells_alone(tmp_path, monkeypatch):
    overrides = {"fields": {"SUMMON TWO": {"effect": "Overridden."}}}
    data, _ = build(tmp_path, monkeypatch, overrides=overrides)
    assert data["lores"][0]["entries"][0]["effect"] == "Set up one."
