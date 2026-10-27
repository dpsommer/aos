"""Build the universal manifestation lores, which any army can take, from Wahapedia's Endless
Spells page.

Usage: python -I build_core.py <endless-spells.html> <out dir> [--overrides FILE] [--bsdata DIR] [--update-bsdata]
e.g.   python -I fetch.py endless-spells /tmp/es
       python -I build_core.py /tmp/es/endless-spells.html data/core > report.txt

Writes <out dir>/manifestation_lores.json: the lores, with their Battle Profile points, and the
manifestation warscrolls they summon. Wahapedia is the source. BSData's game system and Lores.cat
supply names (Wahapedia prints ability names in capitals), and the report lists where the two
disagree, as build.py's does. Fix a wrong value with an overrides file's "fields", in build.py's format
(tools/faction_import/overrides/core.json); a target is a warscroll id or name, a lore name, an ability
name or a weapon name, or "<warscroll id or lore name> > <ability or weapon name>".
"""
import argparse, json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsdata, build as faction_build, merge, schema, wahapedia

BSDATA_FILES = ["Age of Sigmar 4.0.gst", "Lores.cat"]


def bsdata_entries(bsdata_dir):
    """BSData's manifestation warscrolls, and its ability profiles by matching key for the lores'
    spells, whose names are unique."""
    cats = bsdata.Catalogues(bsdata_dir, BSDATA_FILES)
    warscrolls = [bsdata.warscroll(cats, el) for el in cats.docs[BSDATA_FILES[0]].iter()
                  if bsdata.tag(el) == "selectionEntry"
                  and any(p.get("typeName") == "Manifestation" for p in bsdata.kids(el, "profiles", "profile"))]
    abilities = {merge.norm(p.get("name")): bsdata.ability(p) for root in cats.docs.values()
                 for p in root.iter() if bsdata.tag(p) == "profile" and bsdata.is_ability(p)}
    return warscrolls, abilities


def rename_spells(report, where, abilities, bs_abilities):
    """Gives each spell BSData's name and reports where its text differs."""
    for a in abilities:
        bs = bs_abilities.get(merge.norm(a["name"]))
        if bs is None:
            report.only("Wahapedia", "ability", where + " > " + a["name"])
            continue
        merge.compare_ability(report, where, bs, a)
        a["name"] = bs["name"]


def build(wahapedia_page, bsdata_dir, overrides=None):
    report = merge.Report()
    wh = wahapedia.parse_manifestation_lores(wahapedia_page)
    bs_warscrolls, bs_abilities = bsdata_entries(bsdata_dir)
    for lore in wh["lores"]:
        rename_spells(report, "lore " + lore["name"], lore["entries"], bs_abilities)
    warscrolls = [merge.wahapedia_warscroll(w) for w in wh["warscrolls"]]
    pairs, wh_left = merge.pair(report, "warscrolls", bs_warscrolls, warscrolls)
    for bs, w in pairs:
        if w is None:
            report.only("BSData", "warscroll", bs["name"])
            continue
        names = {merge.norm(a["name"]): a["name"] for a in bs["abilities"]}
        for a in w["abilities"]:
            a["name"] = names.get(merge.norm(a["name"]), a["name"])
        # Wahapedia's page has no battle profiles, so only the warscroll itself is compared.
        merge.compare_warscroll(report, bs, dict(w, unit_size=bs.get("unit_size"), base_size=bs.get("base_size")))
        w["name"], w["id"] = bs["name"], bs["id"]
    for w in wh_left:
        report.only("Wahapedia", "warscroll", w["name"])
    # In a faction's shape, so build.py applies the overrides and links the summoning spells.
    core = {
        "faction": {"battle_traits": [], "battle_formations": [], "enhancement_tables": [], "lores": wh["lores"]},
        "warscrolls": warscrolls, "armies_of_renown": [], "spearheads": [], "path_to_glory": [],
    }
    faction_build.apply_overrides(core, overrides or {})
    faction_build.link_summons(core)
    data = {
        "lores": [schema.table(lore, points=True) for lore in wh["lores"]],
        "warscrolls": [schema.warscroll(w) for w in sorted(warscrolls, key=lambda w: merge.norm(w["name"]))],
    }
    return schema.tidy(data), report


def write(data, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "manifestation_lores.json"), "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent="\t", ensure_ascii=False)
        fh.write("\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build the universal manifestation lores from Wahapedia.")
    parser.add_argument("page", help="the Endless Spells page fetch.py downloaded")
    parser.add_argument("out_dir")
    parser.add_argument("--overrides", help="overrides JSON file")
    parser.add_argument("--bsdata", default=bsdata.DEFAULT_CHECKOUT, help="BSData checkout (default: tools/bsdata)")
    parser.add_argument("--update-bsdata", action="store_true", help="pull the BSData checkout before building")
    args = parser.parse_args()
    bsdata.ensure_checkout(args.bsdata, update=args.update_bsdata)
    overrides = json.load(open(args.overrides)) if args.overrides else {}
    data, report = build(args.page, args.bsdata, overrides)
    write(data, args.out_dir)
    print("BSData %s" % bsdata.checkout_version(args.bsdata))
    print("\n".join(report.lines) or "BSData and Wahapedia agree.")
    print("%d difference(s)" % len(report.lines), file=sys.stderr)
