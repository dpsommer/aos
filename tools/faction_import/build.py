"""Build the game's faction JSON from BSData catalogues and Wahapedia pages.

Usage: python -I build.py <wahapedia dir> <out dir> <id> "<BSData faction name>"
                          [--overrides FILE] [--bsdata DIR] [--update-bsdata]
                          [--shared DIR] [--update-shared]

<wahapedia dir> is the directory fetch.py wrote, or "-" to build from BSData alone, for a faction
Wahapedia doesn't have yet (Khazalite Holds); the faction then has no Spearheads, Path to Glory,
regiment options, unit notes or composition, and Armies of Renown get their roster as text. BSData is read from a local checkout,
tools/bsdata by default, which is cloned on first use; --update-bsdata pulls it first.
BSData is the primary source; Wahapedia supplies what BSData lacks. Differences between the
two are printed as a report and never stop the build; fix a wrong value with an overrides file:

    {
        "warscroll_names": {"<name in the data>": "<name to use>"},
        "army_names": {"<BSData Army of Renown name>": "<name to use>"},
        "wahapedia_warscroll_names": {"<Wahapedia unit name>": "<BSData name>"},
        "replace_with_wahapedia": {"<BSData ability name>": "<Wahapedia ability name>"},
        "faction": {"<field>": <value>},
        "fields": {"<target>": {"<field>": <value>}},
        "path_to_glory": {"<section name>": {"<text>": "<replacement>"}}
    }

faction sets fields of the faction itself, e.g. "legends" for a faction moved to Legends.

A fields <target> is a warscroll name or id, an Army of Renown name, an ability name, a weapon name, or
"<owner> > <weapon or ability name>" where a name alone is ambiguous. An owner is a warscroll id, an
Army of Renown name, or a faction enhancement table or lore name, as "<name> (<source>)" when several
share a name.
path_to_glory replaces text in a Path to Glory section, which is stored as text rather than as
abilities; each text must appear in the section exactly once.

replace_with_wahapedia swaps an ability for Wahapedia's version, for when BSData has the
wrong rule; it, army_names and wahapedia_warscroll_names apply before merging, so the renamed items
pair with the other source's (Wahapedia's "Monsta-killaz" is BSData's "Kruleboyz Monsta-killaz"). Its BSData name can be "<warscroll id or Army of Renown
name> > <ability name>" where a name alone is ambiguous. The others apply after merging. Every override must match
something, so stale ones are noticed.

Warscrolls and Armies of Renown listed in shared.json are written once to data/shared/ (or
--shared DIR) and referenced from the faction's files; see shared.py.
"""
import argparse, copy, glob, json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsdata, merge, schema, shared, wahapedia


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


def every_weapon(data):
    return [x for w in every_warscroll(data) for x in w.get("ranged_weapons", []) + w.get("melee_weapons", [])]


def wahapedia_abilities(wh_page, wh_units):
    page = [wh_page["faction"]] + wh_page["armies_of_renown"] + wh_page["spearheads"]
    groups = [b["abilities"] for b in wh_page["faction"]["battle_formations"]]
    for part in page:
        groups += [part.get(k, []) for k in ("battle_traits", "regiment_abilities", "enhancements")]
        groups += [t["entries"] for t in part.get("enhancement_tables", []) + part.get("lores", [])]
    groups += [w["abilities"] for w in wh_units]
    return [a for g in groups for a in g]


def owned_abilities(data, owner):
    """The abilities of the warscroll with id [owner], of the Army of Renown named [owner], and of the
    faction's enhancement tables and lores named [owner] or "<name> (<source>)"."""
    groups = [w["abilities"] for w in every_warscroll(data) if w.get("id") == owner]
    f = data["faction"]
    groups += [t["entries"] for t in f["enhancement_tables"] + f["lores"]
               if owner in (t["name"], "%s (%s)" % (t["name"], t.get("source", "")))]
    for a in data["armies_of_renown"]:
        if a["name"] == owner:
            groups += [a["battle_traits"]] + [t["entries"] for t in a["enhancement_tables"] + a["lores"]]
    return [a for g in groups for a in g]


def replace_with_wahapedia(data, replacements, wh_abilities):
    for bs_name, wh_name in replacements.items():
        wh = next((a for a in wh_abilities if merge.norm(a["name"]) == merge.norm(wh_name)), None)
        if wh is None:
            sys.exit("replace_with_wahapedia: no Wahapedia ability named %r" % wh_name)
        owner, _, name = bs_name.rpartition(" > ")
        abilities = owned_abilities(data, owner) if owner else every_ability(data)
        matched = [a for a in abilities if a["name"] == name]
        if not matched:
            sys.exit("replace_with_wahapedia: no ability named %r" % bs_name)
        for a in matched:
            a.clear()
            a.update(wh, name=wh_name)


def rename(items, names, what):
    for old, new in names.items():
        matched = [x for x in items if x["name"] == old]
        if not matched:
            sys.exit("name override %r matches no %s" % (old, what))
        for x in matched:
            x["name"] = new


def rename_armies(armies, names):
    rename(armies, names, "Army of Renown")


def rename_wahapedia_warscrolls(units, names):
    rename(units, names, "Wahapedia unit")


def apply_overrides(data, overrides):
    data["faction"].update(overrides.get("faction", {}))
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
        if " > " in name:
            owner, part = name.split(" > ", 1)
            weapons = [x for w in every_warscroll(data) if w.get("id") == owner
                       for x in w["ranged_weapons"] + w["melee_weapons"]]
            matched = [x for x in weapons + owned_abilities(data, owner) if x["name"] == part]
        else:
            matched = [w for w in every_warscroll(data) if name in (w["name"], w.get("id"))] \
                or [a for a in data["armies_of_renown"] if a["name"] == name] \
                or [a for a in every_ability(data) if a["name"] == name] \
                or [x for x in every_weapon(data) if x["name"] == name]
        if not matched:
            sys.exit("field override %r matches no warscroll, Army of Renown, ability or weapon" % name)
        for item in matched:
            item.update(fields)
    for section_name, replacements in overrides.get("path_to_glory", {}).items():
        section = next((p for p in data["path_to_glory"] if p["name"] == section_name), None)
        if section is None:
            sys.exit("path_to_glory override %r matches no Path to Glory section" % section_name)
        for old, new in replacements.items():
            if section["text"].count(old) != 1:
                sys.exit("path_to_glory override text %r appears %d times in %r, not once"
                         % (old, section["text"].count(old), section_name))
            section["text"] = section["text"].replace(old, new)


# A Wahapedia faction page with nothing on it, for building from BSData alone.
NO_WAHAPEDIA_PAGE = {
    "faction": {"battle_traits": [], "battle_formations": [], "enhancement_tables": [], "lores": []},
    "armies_of_renown": [], "spearheads": [], "path_to_glory": [],
}


def build(bsdata_dir, wahapedia_dir, faction_id, faction_name, overrides):
    """Builds the faction. A [wahapedia_dir] of None builds from BSData alone, and the report then
    leaves out the comparison, as every item would be BSData-only."""
    cats = bsdata.Catalogues(bsdata_dir, bsdata.faction_files(bsdata_dir, faction_name))
    bs_faction, bs_warscrolls, bs_armies = bsdata.read_faction(cats, faction_name)
    if wahapedia_dir is None:
        wh_page, wh_units = copy.deepcopy(NO_WAHAPEDIA_PAGE), []
    else:
        pages = glob.glob(os.path.join(wahapedia_dir, "*.html"))
        if len(pages) != 1:
            sys.exit("expected one Wahapedia faction page in %s" % wahapedia_dir)
        wh_page = wahapedia.parse_faction_page(pages[0])
        wh_units = wahapedia.parse_unit_pages(sorted(glob.glob(os.path.join(wahapedia_dir, "units", "*.html"))))

    # Renamed before merging so the Army of Renown pairs with Wahapedia's, e.g. BSData's "New
    # Summercourt" is Wahapedia's "The Knights of New Summercourt".
    rename_armies(bs_armies, overrides.get("army_names", {}))
    rename_wahapedia_warscrolls(wh_units, overrides.get("wahapedia_warscroll_names", {}))
    # Swapped in before merging so the replacement is ordered and compared like the rest.
    replace_with_wahapedia({"faction": bs_faction, "warscrolls": bs_warscrolls, "armies_of_renown": bs_armies,
                            "spearheads": [], "path_to_glory": []},
                           overrides.get("replace_with_wahapedia", {}), wahapedia_abilities(wh_page, wh_units))
    # Merged against nothing without Wahapedia, which only orders and shapes the data, so that
    # comparison is dropped.
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
    return data, (merge.Report() if wahapedia_dir is None else report)


def write(data, out_dir, report, shared_dir=shared.DEFAULT_DIR, config=None, update_shared=False):
    """Writes the faction's files, and the shared entries it uses to shared_dir."""
    config = config if config is not None else shared.load_config()
    entries = shared.read(shared_dir)
    shared.apply_fields(data["warscrolls"], data["armies_of_renown"], config["fields"])
    files = {
        "faction.json": schema.faction(data["faction"]),
        "warscrolls.json": {"warscrolls": [schema.warscroll(w) for w in data["warscrolls"]]},
        "armies_of_renown.json": {"armies_of_renown": [schema.army_of_renown(a) for a in data["armies_of_renown"]]},
        "spearhead.json": {"spearheads": [schema.spearhead(s) for s in data["spearheads"]]},
        "path_to_glory.json": {"sections": [schema.rules_section(p) for p in data["path_to_glory"]]},
    }
    # Tidied first so text compares equal to the tidied shared entries.
    files = schema.tidy(files)
    files["warscrolls.json"]["warscrolls"], files["armies_of_renown.json"]["armies_of_renown"] = shared.share(
        files["warscrolls.json"]["warscrolls"], files["armies_of_renown.json"]["armies_of_renown"],
        data["faction"]["name"], config, entries, report, update_shared)
    if config["warscrolls"] or config["armies_of_renown"]:
        shared.write(schema.tidy(entries), shared_dir)
    os.makedirs(out_dir, exist_ok=True)
    for name, obj in files.items():
        with open(os.path.join(out_dir, name), "w", encoding="utf-8") as fh:
            json.dump(schema.tidy(obj), fh, indent="\t", ensure_ascii=False)
            fh.write("\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build faction JSON from BSData and Wahapedia.")
    parser.add_argument("wahapedia_dir", help='directory fetch.py wrote, or "-" for BSData alone')
    parser.add_argument("out_dir")
    parser.add_argument("id", help="faction id, e.g. helsmiths_of_hashut")
    parser.add_argument("name", help="BSData faction name, e.g. 'Helsmiths of Hashut'")
    parser.add_argument("--overrides", help="overrides JSON file")
    parser.add_argument("--bsdata", default=bsdata.DEFAULT_CHECKOUT, help="BSData checkout (default: tools/bsdata)")
    parser.add_argument("--update-bsdata", action="store_true", help="pull the BSData checkout before building")
    parser.add_argument("--shared", default=shared.DEFAULT_DIR, help="shared data directory (default: data/shared)")
    parser.add_argument("--update-shared", action="store_true",
                        help="replace the shared entries this faction uses with its versions")
    args = parser.parse_args()
    bsdata.ensure_checkout(args.bsdata, update=args.update_bsdata)
    overrides = json.load(open(args.overrides)) if args.overrides else {}
    wahapedia_dir = None if args.wahapedia_dir == "-" else args.wahapedia_dir
    data, report = build(args.bsdata, wahapedia_dir, args.id, args.name, overrides)
    write(data, args.out_dir, report, args.shared, update_shared=args.update_shared)
    print("BSData %s" % bsdata.checkout_version(args.bsdata))
    if wahapedia_dir is None:
        print("Built from BSData alone; no Wahapedia comparison.")
        print("\n".join(report.lines) or "No shared entry differences.")
    else:
        print("\n".join(report.lines) or "BSData and Wahapedia agree.")
    print("%d difference(s)" % len(report.lines), file=sys.stderr)
