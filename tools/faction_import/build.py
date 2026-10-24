"""Build the game's faction JSON from BSData catalogues and Wahapedia pages.

Usage: python -I build.py <fetch dir> <out dir> <id> "<BSData faction name>" [overrides.json]

<fetch dir> is the directory fetch.py wrote (bsdata/ and wahapedia/). BSData is the primary
source; Wahapedia supplies what BSData lacks. Differences between the two are printed as a
report and never stop the build; fix a wrong value with an overrides file:

    {
        "warscroll_names": {"<name in the data>": "<name to use>"},
        "fields": {"<warscroll name or id, or ability name>": {"<field>": <value>}}
    }

Overrides apply after merging. Every override must match something, so stale ones are noticed.
"""
import glob, json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsdata, merge, schema, wahapedia


def every_warscroll(data):
    return data["warscrolls"] + [w for s in data["spearheads"] for w in s["warscrolls"]] \
        + [w for p in data["path_to_glory"] for w in p["warscrolls"]]


def every_ability(data):
    f = data["faction"]
    groups = [f["battle_traits"]] + [b["abilities"] for b in f["battle_formations"]] \
        + [t["entries"] for t in f["enhancement_tables"] + f["lores"]] \
        + [w["abilities"] for w in every_warscroll(data)]
    for a in data["armies_of_renown"]:
        groups += [a["battle_traits"]] + [t["entries"] for t in a["enhancement_tables"] + a["lores"]]
    for s in data["spearheads"]:
        groups += [s["battle_traits"], s["regiment_abilities"], s["enhancements"]]
    return [a for g in groups for a in g]


def apply_overrides(data, overrides):
    for old, new in overrides.get("warscroll_names", {}).items():
        matched = [w for w in every_warscroll(data) if w["name"] == old]
        if not matched:
            sys.exit("warscroll name override %r matches no warscroll" % old)
        for w in matched:
            w["name"] = new
            if w.get("id"):
                w["id"] = w["id"].replace(schema.slug(old), schema.slug(new))
        for s in data["spearheads"]:
            s["general"] = new if s["general"] == old else s["general"]
            for u in s["units"]:
                u["name"] = new if u["name"] == old else u["name"]
    for name, fields in overrides.get("fields", {}).items():
        matched = [w for w in every_warscroll(data) if name in (w["name"], w.get("id"))] \
            or [a for a in every_ability(data) if a["name"] == name]
        if not matched:
            sys.exit("field override %r matches no warscroll or ability" % name)
        for item in matched:
            item.update(fields)


def build(fetch_dir, faction_id, faction_name, overrides):
    cats = bsdata.Catalogues(os.path.join(fetch_dir, "bsdata"))
    bs_faction, bs_warscrolls, bs_armies = bsdata.read_faction(cats, faction_name)
    pages = glob.glob(os.path.join(fetch_dir, "wahapedia", "*.html"))
    if len(pages) != 1:
        sys.exit("expected one Wahapedia faction page in %s" % os.path.join(fetch_dir, "wahapedia"))
    wh_page = wahapedia.parse_faction_page(pages[0])
    wh_units = wahapedia.parse_unit_pages(sorted(glob.glob(os.path.join(fetch_dir, "wahapedia", "units", "*.html"))))

    report = merge.Report()
    faction = merge.merge_faction(report, bs_faction, wh_page["faction"])
    faction["id"] = faction_id
    warscrolls = merge.merge_warscrolls(report, bs_warscrolls, wh_units)
    data = {
        "faction": faction,
        "warscrolls": warscrolls,
        "armies_of_renown": merge.merge_armies(report, bs_armies, wh_page["armies_of_renown"]),
        "spearheads": merge.spearheads(wh_page["spearheads"], [w["name"] for w in warscrolls]),
        "path_to_glory": merge.path_to_glory(wh_page["path_to_glory"]),
    }
    apply_overrides(data, overrides)
    return data, report


def write(data, out_dir):
    files = {
        "faction.json": schema.faction(data["faction"]),
        "warscrolls.json": {"warscrolls": [schema.warscroll(w) for w in data["warscrolls"]]},
        "armies_of_renown.json": {"armies_of_renown": [schema.army_of_renown(a) for a in data["armies_of_renown"]]},
        "spearhead.json": {"spearheads": [schema.spearhead(s) for s in data["spearheads"]]},
        "path_to_glory.json": {"sections": [schema.rules_section(p) for p in data["path_to_glory"]]},
    }
    os.makedirs(out_dir, exist_ok=True)
    for name, obj in files.items():
        with open(os.path.join(out_dir, name), "w", encoding="utf-8") as fh:
            json.dump(schema.tidy(obj), fh, indent="\t", ensure_ascii=False)
            fh.write("\n")


if __name__ == "__main__":
    fetch_dir, out_dir, faction_id, faction_name = sys.argv[1:5]
    overrides = json.load(open(sys.argv[5])) if len(sys.argv) > 5 else {}
    data, report = build(fetch_dir, faction_id, faction_name, overrides)
    write(data, out_dir)
    print("\n".join(report.lines) or "BSData and Wahapedia agree.")
    print("%d difference(s)" % len(report.lines), file=sys.stderr)
