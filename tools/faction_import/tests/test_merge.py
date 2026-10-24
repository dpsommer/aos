import pytest

import merge


def ws(name="Test Riders", **kw):
    """A warscroll as merge sees it from either source; Wahapedia's move is a string."""
    w = {"id": "", "name": name, "points": 100, "unit_size": 5, "move": 10, "health": 4, "save": 4,
         "control": 1, "can_reinforce": True, "base_size": "60mm",
         "ranged_weapons": [], "melee_weapons": [], "abilities": [], "keywords": ["CAVALRY"]}
    w.update(kw)
    return w


def wh_ws(name="Test Riders", **kw):
    return ws(name, **dict({"move": '10"'}, **kw))


def ab(name="Charge", **kw):
    a = {"name": name, "category": "movement", "timing": "Your Movement Phase", "effect": "Add 1."}
    a.update(kw)
    return a


def table(*entries, name="Heroic Traits"):
    return {"name": name, "entries": list(entries)}


# norm / norm_text

def test_norm_ignores_case():
    assert merge.norm("Test RIDERS") == merge.norm("test riders")


def test_norm_ignores_curly_apostrophes():
    assert merge.norm("Rider’s Blessing") == merge.norm("Rider's Blessing")


def test_norm_distinguishes_different_names():
    assert merge.norm("Test Riders") != merge.norm("Test Rider Champion")


def test_norm_text_ignores_case():
    assert merge.norm_text("Add 1 To Hit Rolls.") == merge.norm_text("add 1 to hit rolls.")


def test_norm_text_ignores_curly_quotes():
    assert merge.norm_text("the ‘Tester’ and “Captain”") == merge.norm_text("the 'Tester' and \"Captain\"")


def test_norm_text_ignores_leading_bullets():
    assert merge.norm_text("Pick one:\n• Add 1.\n• Subtract 1.") == merge.norm_text("Pick one:\nAdd 1.\nSubtract 1.")


def test_norm_text_treats_times_sign_as_x():
    assert merge.norm_text("60 × 35mm") == merge.norm_text("60x35mm")


def test_norm_text_ignores_spacing_around_punctuation():
    assert merge.norm_text("Heal (1) , then run.") == merge.norm_text("Heal (1), then run.")


def test_norm_text_of_none_matches_empty():
    assert merge.norm_text(None) == merge.norm_text("")


def test_norm_text_keeps_different_text_apart():
    assert merge.norm_text("Add 1 to hit rolls.") != merge.norm_text("Add 1 to wound rolls.")


# pair()

def test_pair_matches_exact_names():
    pairs, _ = merge.pair(merge.Report(), "x", [{"name": "Charge"}], [{"name": "charge"}])
    assert pairs == [[{"name": "Charge"}, {"name": "charge"}]]


def test_pair_returns_unmatched_wahapedia_items():
    _, left = merge.pair(merge.Report(), "x", [{"name": "Charge"}], [{"name": "Charge"}, {"name": "Retreat"}])
    assert left == [{"name": "Retreat"}]


def test_pair_leaves_unmatched_bsdata_item_without_partner():
    pairs, _ = merge.pair(merge.Report(), "x", [{"name": "Charge"}], [{"name": "Retreat"}])
    assert pairs == [[{"name": "Charge"}, None]]


def test_pair_matches_similar_names():
    pairs, _ = merge.pair(merge.Report(), "x", [{"name": "Hobgrot"}], [{"name": "Hobgrotz"}])
    assert pairs[0][1] == {"name": "Hobgrotz"}


def test_pair_reports_similar_name_matches():
    report = merge.Report()
    merge.pair(report, "x", [{"name": "Hobgrot"}], [{"name": "Hobgrotz"}])
    assert len(report.lines) == 1 and "Hobgrot" in report.lines[0] and "Hobgrotz" in report.lines[0]


def test_pair_does_not_report_exact_matches():
    report = merge.Report()
    merge.pair(report, "x", [{"name": "Charge"}], [{"name": "Charge"}])
    assert report.lines == []


def test_pair_prefers_exact_match_over_similar_one():
    pairs, _ = merge.pair(merge.Report(), "x", [{"name": "Hobgrot"}, {"name": "Hobgrotz"}], [{"name": "Hobgrotz"}])
    assert pairs[1][1] == {"name": "Hobgrotz"} and pairs[0][1] is None


def test_pair_skips_ambiguous_similar_names():
    pairs, _ = merge.pair(merge.Report(), "x", [{"name": "Hobgrot"}], [{"name": "Hobgrotz"}, {"name": "Hobgrots"}])
    assert pairs[0][1] is None


def test_pair_matches_names_with_reordered_words():
    pairs, _ = merge.pair(merge.Report(), "x", [{"name": "Bloodthirster, Wrath of Khorne"}],
                          [{"name": "Wrath of Khorne Bloodthirster"}])
    assert pairs[0][1] == {"name": "Wrath of Khorne Bloodthirster"}


def test_pair_reports_reordered_word_matches():
    report = merge.Report()
    merge.pair(report, "x", [{"name": "Bloodthirster, Wrath of Khorne"}], [{"name": "Wrath of Khorne Bloodthirster"}])
    assert len(report.lines) == 1 and "Wrath of Khorne Bloodthirster" in report.lines[0]


def test_pair_reordered_word_match_wins_over_similar_name():
    pairs, _ = merge.pair(merge.Report(), "x", [{"name": "Hound, Iron"}],
                          [{"name": "Hounds, Iron"}, {"name": "Iron Hound"}])
    assert pairs[0][1] == {"name": "Iron Hound"}


def test_pair_does_not_match_names_with_different_words():
    pairs, _ = merge.pair(merge.Report(), "x", [{"name": "Wrath of Khorne"}], [{"name": "Khorne's Wrath Unbound"}])
    assert pairs[0][1] is None


# wahapedia_warscroll()

def test_wahapedia_manifestation_control_becomes_banishment():
    assert merge.wahapedia_warscroll(wh_ws(control=6, keywords=["MANIFESTATION"]))["banishment"] == 6


def test_wahapedia_manifestation_has_no_control():
    assert merge.wahapedia_warscroll(wh_ws(control=6, keywords=["MANIFESTATION"]))["control"] == 0


def test_wahapedia_ordinary_warscroll_keeps_control():
    assert merge.wahapedia_warscroll(wh_ws(control=2))["control"] == 2


def test_wahapedia_ordinary_warscroll_has_no_banishment():
    assert "banishment" not in merge.wahapedia_warscroll(wh_ws(control=2))


def test_merge_reports_nothing_for_matching_manifestation():
    report = merge.Report()
    merge.merge_warscrolls(report, [ws(control=0, banishment=6, keywords=["MANIFESTATION"])],
                           [wh_ws(control=6, keywords=["MANIFESTATION"])])
    assert report.lines == []


# compare_ability()

def test_timings_differing_only_by_trailing_full_stop_are_not_reported():
    report = merge.Report()
    merge.compare_ability(report, "x", ab(timing="Your Movement Phase"), ab(timing="Your Movement Phase."))
    assert report.lines == []


def test_different_timings_are_reported():
    report = merge.Report()
    merge.compare_ability(report, "x", ab(timing="Your Movement Phase"), ab(timing="Your Charge Phase."))
    assert len(report.lines) == 1 and "timing" in report.lines[0]


# merge_warscrolls()

@pytest.mark.parametrize("field,value", [
    ("regiment_options", ["0-1 Test Captain"]), ("notes", "Some note."), ("composition", "5 models.")])
def test_merge_copies_wahapedia_only_field(field, value):
    (out,) = merge.merge_warscrolls(merge.Report(), [ws()], [wh_ws(**{field: value})])
    assert out[field] == value


def test_merge_keeps_bsdata_value_when_sources_differ():
    (out,) = merge.merge_warscrolls(merge.Report(), [ws(health=4)], [wh_ws(health=5)])
    assert out["health"] == 4


def test_merge_reports_a_differing_value():
    report = merge.Report()
    merge.merge_warscrolls(report, [ws(health=4)], [wh_ws(health=5)])
    assert len(report.lines) == 1 and "health" in report.lines[0]


def test_merge_reports_nothing_when_sources_agree():
    report = merge.Report()
    merge.merge_warscrolls(report, [ws(base_size="60 × 35mm")], [wh_ws(base_size="60x35mm")])
    assert report.lines == []


def test_merge_reports_differing_weapon_value():
    report = merge.Report()
    w = {"name": "Lance", "range": 0, "attacks": "3", "hit": 3, "wound": 4, "rend": 1, "damage": "2"}
    merge.merge_warscrolls(report, [ws(melee_weapons=[w])], [wh_ws(melee_weapons=[dict(w, rend=2)])])
    assert len(report.lines) == 1 and "rend" in report.lines[0]


def test_merge_reports_differing_ability_effect():
    report = merge.Report()
    merge.merge_warscrolls(report, [ws(abilities=[ab()])], [wh_ws(abilities=[ab(effect="Add 2.")])])
    assert len(report.lines) == 1 and "effect" in report.lines[0]


def test_merge_keeps_wahapedia_only_warscroll():
    out = merge.merge_warscrolls(merge.Report(), [], [wh_ws("Lone Hero")])
    assert [w["name"] for w in out] == ["Lone Hero"]


def test_wahapedia_only_warscroll_gets_scourge_prefixed_id():
    (out,) = merge.merge_warscrolls(merge.Report(), [], [wh_ws("Lone Hero", source="Scourge of Aqshy")])
    assert out["id"] == "scourge_of_aqshy_lone_hero"


def test_merge_reports_wahapedia_only_warscroll():
    report = merge.Report()
    merge.merge_warscrolls(report, [], [wh_ws("Lone Hero")])
    assert any("Wahapedia" in l and "Lone Hero" in l for l in report.lines)


def test_merge_keeps_bsdata_only_warscroll():
    out = merge.merge_warscrolls(merge.Report(), [ws("Lone Hero")], [])
    assert [w["name"] for w in out] == ["Lone Hero"]


def test_merge_reports_bsdata_only_warscroll():
    report = merge.Report()
    merge.merge_warscrolls(report, [ws("Lone Hero")], [])
    assert any("BSData" in l and "Lone Hero" in l for l in report.lines)


def test_merge_keeps_scourge_and_battletome_versions_apart():
    bs = [ws("Gunners", source="Scourge of Aqshy", health=1), ws("Gunners", health=2)]
    wh = [wh_ws("Gunners", health=2), wh_ws("Gunners", source="Scourge of Aqshy", health=1)]
    report = merge.Report()
    merge.merge_warscrolls(report, bs, wh)
    assert report.lines == []


def test_designers_note_options_are_not_compared():
    note = {"name": "Designer’s Note", "text": "Commentary."}
    report = merge.Report()
    merge.merge_warscrolls(report, [ws(abilities=[ab(options=[note])])], [wh_ws(abilities=[ab()])])
    assert report.lines == []


def test_rule_options_are_compared():
    option = {"name": "Hold Fast", "text": "Add 1."}
    report = merge.Report()
    merge.merge_warscrolls(report, [ws(abilities=[ab(options=[option])])], [wh_ws(abilities=[ab()])])
    assert len(report.lines) == 1 and "options" in report.lines[0]


# merge_tables()

def test_merge_tables_orders_entries_like_wahapedia():
    bs = [table(ab("A"), ab("B"), ab("C"))]
    wh = [table(ab("C"), ab("A"), ab("B"))]
    (out,) = merge.merge_tables(merge.Report(), "enhancements", bs, wh)
    assert [e["name"] for e in out["entries"]] == ["C", "A", "B"]


def test_merge_tables_orders_tables_by_first_wahapedia_entry():
    bs = [table(ab("A"), name="First"), table(ab("B"), name="Second")]
    wh = [table(ab("B"), ab("A"))]
    out = merge.merge_tables(merge.Report(), "enhancements", bs, wh)
    assert [t["name"] for t in out] == ["Second", "First"]


def test_merge_tables_puts_bsdata_only_entries_last():
    bs = [table(ab("Extra"), ab("A"))]
    (out,) = merge.merge_tables(merge.Report(), "enhancements", bs, [table(ab("A"))])
    assert [e["name"] for e in out["entries"]] == ["A", "Extra"]


def test_merge_tables_reports_differing_points():
    report = merge.Report()
    merge.merge_tables(report, "enhancements", [table(ab("A", points=10))], [table(ab("A", points=15))])
    assert len(report.lines) == 1 and "points" in report.lines[0]


# merge_armies()

def bs_army(**kw):
    a = {"name": "The Shared Host", "roster": ["Test Captain", "Host Champion"],
         "battle_traits": [], "enhancement_tables": [], "lores": []}
    a.update(kw)
    return a


def test_army_without_wahapedia_text_gets_generated_roster_text():
    (out,) = merge.merge_armies(merge.Report(), [bs_army()], [])
    assert "Test Captain" in out["text"] and "Host Champion" in out["text"]


def test_army_without_wahapedia_counterpart_is_reported():
    report = merge.Report()
    merge.merge_armies(report, [bs_army()], [])
    assert any("BSData" in l and "The Shared Host" in l for l in report.lines)


def test_army_text_comes_from_wahapedia():
    wh = {"name": "the shared host", "text": "ROSTER OPTIONS ...", "battle_traits": [], "enhancement_tables": [], "lores": []}
    (out,) = merge.merge_armies(merge.Report(), [bs_army()], [wh])
    assert out["text"] == wh["text"]


def test_merged_army_has_no_roster():
    (out,) = merge.merge_armies(merge.Report(), [bs_army()], [])
    assert "roster" not in out


def wh_army(**kw):
    a = {"name": "The Shared Host", "text": "ROSTER OPTIONS ...", "battle_traits": [], "enhancement_tables": [], "lores": []}
    a.update(kw)
    return a


@pytest.mark.parametrize("wh_list", [[], [wh_army()]], ids=["bsdata_only", "both_sources"])
def test_merged_army_keeps_bsdata_legends(wh_list):
    (out,) = merge.merge_armies(merge.Report(), [bs_army(legends=True)], wh_list)
    assert out["legends"] is True


def test_merged_army_without_bsdata_legends_has_none():
    (out,) = merge.merge_armies(merge.Report(), [bs_army()], [wh_army()])
    assert "legends" not in out


# spearheads()

def spearhead(army, warscroll_names, text="Fluff.\nThis Spearhead army consists of the following units:"):
    return {"name": "Test Vanguard", "army_text": text, "army": army,
            "battle_traits": [], "regiment_abilities": [], "enhancements": [],
            "warscrolls": [wh_ws(n) for n in warscroll_names]}


ARMY = [["General", "test captain"], ["Units", "1 Test Riders (Reinforced)", "2 Test Gunners"]]
NAMES = ["test captain", "Test Riders", "Test Gunners with Long Rifles"]


def test_spearhead_warscroll_names_use_bsdata_spelling():
    (s,) = merge.spearheads([spearhead(ARMY, NAMES)], ["Test Captain"])
    assert s["warscrolls"][0]["name"] == "Test Captain"


def test_spearhead_general_uses_bsdata_spelling():
    (s,) = merge.spearheads([spearhead(ARMY, NAMES)], ["Test Captain"])
    assert s["general"] == "Test Captain"


def test_spearhead_unit_counts_are_ints():
    (s,) = merge.spearheads([spearhead(ARMY, NAMES)], ["Test Captain"])
    assert [u["count"] for u in s["units"]] == [1, 2]


def test_spearhead_unit_parenthetical_becomes_notes():
    (s,) = merge.spearheads([spearhead(ARMY, NAMES)], ["Test Captain"])
    assert (s["units"][0]["name"], s["units"][0]["notes"]) == ("Test Riders", "Reinforced")


def test_spearhead_shortened_unit_name_resolves_by_prefix():
    (s,) = merge.spearheads([spearhead(ARMY, NAMES)], ["Test Captain"])
    assert s["units"][1]["name"] == "Test Gunners with Long Rifles"


def test_spearhead_text_stops_before_army_list():
    (s,) = merge.spearheads([spearhead(ARMY, NAMES)], ["Test Captain"])
    assert s["text"] == "Fluff."


def test_resolve_returns_exact_name():
    assert merge.resolve("Gunners", ["Gunners", "Gunners with Rifles"]) == "Gunners"


def test_resolve_matches_unique_prefix():
    assert merge.resolve("Dominator Engine", ["Dominator Engine with Immolation Cannons", "Other"]) == \
        "Dominator Engine with Immolation Cannons"


def test_resolve_prefix_must_end_at_a_word():
    with pytest.raises(SystemExit):
        merge.resolve("Gun", ["Gunners"])


def test_resolve_fails_without_match():
    with pytest.raises(SystemExit):
        merge.resolve("Nobody", ["Gunners"])


def test_resolve_fails_on_ambiguous_prefix():
    with pytest.raises(SystemExit):
        merge.resolve("Engine", ["Engine with Cannons", "Engine with Drills"])


def test_resolve_matches_reordered_words_with_punctuation():
    names = ["Whisperblade, Freeguild Command Corps", "Freeguild Fusiliers"]
    assert merge.resolve("Freeguild Command Corps Whisperblade", names) == "Whisperblade, Freeguild Command Corps"


def test_resolve_fails_on_ambiguous_reordering():
    with pytest.raises(SystemExit):
        merge.resolve("Corps Command", ["Command, Corps", "Corps, Command"])


def test_resolve_fails_when_reordered_words_differ():
    with pytest.raises(SystemExit):
        merge.resolve("Freeguild Command Corps Whisperblade", ["Whisperblade, Freeguild Steelhelms"])


def cities_spearhead(general="Test Captain", units="2 Test Riders"):
    army = [["General", general], ["Units", units]]
    names = ["Test Captain", "Test Riders", "Pontifex Zenestra, Matriarch of the Great Wheel",
             "Freeguild Fusiliers"]
    (s,) = merge.spearheads([spearhead(army, names)], names)
    return s


def test_spearhead_unit_without_count_counts_as_one():
    s = cities_spearhead(units="Pontifex Zenestra, Matriarch of the Great Wheel 2 Test Riders")
    assert s["units"][0] == {"count": 1, "name": "Pontifex Zenestra, Matriarch of the Great Wheel"}


def test_spearhead_unit_without_count_does_not_drop_following_units():
    s = cities_spearhead(units="Pontifex Zenestra, Matriarch of the Great Wheel 2 Test Riders")
    assert [u["name"] for u in s["units"]] == ["Pontifex Zenestra, Matriarch of the Great Wheel", "Test Riders"]


def test_spearhead_count_after_with_stays_in_its_entry():
    s = cities_spearhead(units="5 Freeguild Fusiliers with 1 Blackpowder Squire token 2 Test Riders")
    assert [(u["count"], u["name"]) for u in s["units"]] == [(5, "Freeguild Fusiliers"), (2, "Test Riders")]


def test_spearhead_token_suffix_becomes_notes():
    s = cities_spearhead(units="5 Freeguild Fusiliers with 1 Blackpowder Squire token")
    assert s["units"][0]["notes"] == "with 1 Blackpowder Squire token"


def test_spearhead_general_parenthetical_is_stripped():
    s = cities_spearhead(general="Test Captain (Thexa, the ash panther, is a token)")
    assert s["general"] == "Test Captain"


def test_spearhead_general_consecutive_parentheticals_are_stripped():
    s = cities_spearhead(general="Test Captain (Thexa is a token) (she has 1 wound)")
    assert s["general"] == "Test Captain"


def ghoul_spearhead(units):
    """A Spearhead whose Units row is split into cells, one per unit, as Wahapedia lists them."""
    names = ["Abhorrant Archregent", "Cryptguard", "Morbheg Knights", "Varghulf Courtier", "Crypt Horrors"]
    (s,) = merge.spearheads([spearhead([["General", "Abhorrant Archregent"], ["Units"] + units], names)], names)
    return s


def test_spearhead_unit_cells_split_before_a_unit_without_count():
    s = ghoul_spearhead(["10 Cryptguard", "3 Morbheg Knights", "Varghulf Courtier"])
    assert [(u["count"], u["name"]) for u in s["units"]] == \
        [(10, "Cryptguard"), (3, "Morbheg Knights"), (1, "Varghulf Courtier")]


def test_spearhead_unit_cells_split_after_a_unit_without_count():
    s = ghoul_spearhead(["Varghulf Courtier", "3 Crypt Horrors"])
    assert [(u["count"], u["name"]) for u in s["units"]] == [(1, "Varghulf Courtier"), (3, "Crypt Horrors")]


def test_spearhead_unit_cell_still_splits_at_counts():
    s = ghoul_spearhead(["10 Cryptguard 3 Morbheg Knights", "Varghulf Courtier"])
    assert [u["name"] for u in s["units"]] == ["Cryptguard", "Morbheg Knights", "Varghulf Courtier"]


def test_spearhead_general_in_its_own_cell_is_not_joined_to_units():
    s = ghoul_spearhead(["10 Cryptguard"])
    assert s["general"] == "Abhorrant Archregent"


def test_spearhead_unit_cell_parenthetical_becomes_notes():
    s = ghoul_spearhead(["Varghulf Courtier (General's Retinue)", "10 Cryptguard"])
    assert (s["units"][0]["name"], s["units"][0].get("notes")) == ("Varghulf Courtier", "General's Retinue")
