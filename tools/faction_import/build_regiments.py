"""Build the Regiments of Renown from BSData and Wahapedia, after the factions they use are built.

Usage: python -I build_regiments.py <wahapedia dir> [--overrides FILE] [--data DIR]
                                    [--bsdata DIR] [--update-bsdata]

<wahapedia dir> is the directory `fetch.py --regiments` wrote, or "-" to build from BSData alone.
Writes data/shared/regiments_of_renown.json, every regiment once, and each built faction's
data/factions/<id>/regiments_of_renown.json, which references the regiments that faction can
include. Each regiment unit names its home faction and warscroll, so the factions must be built
first; a unit that resolves to no warscroll stops the build. Regiments only for Path to Glory
campaigns (BSData's "Path to Glory: Ravaged Coast" ones, and the Regiment of Ghyran, which no
faction can include) are left out.

BSData is the primary source; Wahapedia supplies unit notes and orders units and abilities.
Differences are printed as a report. Fix a wrong value with an overrides file
(tools/faction_import/overrides/regiments_of_renown.json by default):

    {
        "wahapedia_names": {"<BSData regiment name>": "<Wahapedia name>"},
        "replace_with_wahapedia": {"<regiment> > <ability>": "<Wahapedia ability name>"},
        "add_from_wahapedia": ["<regiment> > <Wahapedia ability name>"],
        "remove": ["<regiment> > <ability>"],
        "fields": {"<regiment>[ > <ability or unit name>]": {"<field>": <value>}},
        "add_factions": {"<regiment>": ["<faction name>"]}
    }

An ability is the regiment's or one of its own warscrolls'. add_from_wahapedia adds an ability
only Wahapedia prints (the Godmarked Ascendant's 'Gifts of Chaos'), and remove drops one BSData
wrongly gives a regiment (its Heralds of the Bone-tithe has the Dawnrider Lance's 'Masters of All
Terrain'). add_factions lets more factions include a regiment than BSData allows (the Battle
Profiles let Khazalite Holds include the regiments Fyreslayers could).

wahapedia_names is for a name Wahapedia spells or capitalises differently ("Big Drogg Fort-kicker"
is "Big Drogg Fort-Kicka"); fetch.py uses it to find the page and the build to pair it.

A unit's fields include "faction" (a faction id) and "warscroll" (a warscroll id), to point it at
a warscroll the name doesn't find. Every override must match something.
"""
import argparse, copy, glob, json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsdata, merge, regiments, schema

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_DATA = os.path.join(ROOT, "data")
DEFAULT_OVERRIDES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "overrides", "regiments_of_renown.json")
FILE = "regiments_of_renown.json"


def load_overrides(path=DEFAULT_OVERRIDES):
    return json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}


def rename_wahapedia(wh_regiments, names):
    """Gives Wahapedia's regiments their BSData names, so they pair."""
    by_wahapedia = {merge.norm(v): k for k, v in names.items()}
    matched = set()
    for r in wh_regiments:
        bs_name = by_wahapedia.get(merge.norm(r["name"]))
        if bs_name:
            r["name"] = bs_name
            matched.add(bs_name)
    for name in names:
        if name not in matched:
            sys.exit("wahapedia_names: no Wahapedia regiment named %r" % names[name])


def is_campaign_only(r):
    return r["publication"].startswith("Path to Glory") or not r["factions"]


def built_factions(data_dir):
    """{faction name: (id, {warscroll name: id})} for every faction in data_dir/factions, with
    shared warscroll references resolved to their names."""
    shared_path = os.path.join(data_dir, "shared", "warscrolls.json")
    shared = {w["id"]: w["name"] for w in json.load(open(shared_path, encoding="utf-8"))["warscrolls"]} \
        if os.path.exists(shared_path) else {}
    out = {}
    for path in sorted(glob.glob(os.path.join(data_dir, "factions", "*", "faction.json"))):
        directory = os.path.dirname(path)
        faction = json.load(open(path, encoding="utf-8"))
        names = {}
        ws_path = os.path.join(directory, "warscrolls.json")
        if os.path.exists(ws_path):
            for w in json.load(open(ws_path, encoding="utf-8"))["warscrolls"]:
                if "shared" in w:
                    names.setdefault(shared.get(w["shared"], w["shared"]), w["shared"])
                else:
                    # A Scourge of Ghyran version shares its name; the battletome one comes first.
                    if not w.get("source", "").startswith("Scourge of"):
                        names.setdefault(w["name"], w["id"])
        out[faction["name"]] = (faction["id"], names)
    return out


def resolve_units(regiment, factions, errors):
    """Sets each unit's faction_id and warscroll. The home faction is the one Wahapedia's link
    names, else the one whose BSData library defines the unit, else the only built faction with a
    warscroll of that name."""
    by_id = {fid: (name, names) for name, (fid, names) in factions.items()}
    own = {w["name"]: w["id"] for w in regiment["warscrolls"]}
    for u in regiment["units"]:
        if u.get("warscroll"):
            continue
        if u["name"] in own and u.get("library") == regiments.CATALOGUE + ".cat":
            u["faction_id"], u["warscroll"] = "", own[u["name"]]
            continue
        candidates = []
        if u.get("faction"):
            candidates.append(u["faction"].replace("-", "_"))
        library = (u.get("library") or "").replace(" - Library.cat", "")
        if library in factions:
            candidates.append(factions[library][0])
        found = None
        for fid in candidates:
            names = by_id.get(fid, ("", {}))[1]
            wid = names.get(u["name"]) or next((v for k, v in names.items() if merge.norm(k) == merge.norm(u["name"])), None)
            if wid:
                found = (fid, wid)
                break
        if found is None:
            matches = [(fid, names[u["name"]]) for _, (fid, names) in factions.items() if u["name"] in names]
            if len(matches) == 1:
                found = matches[0]
        if found is None:
            errors.append("%s > %s: no warscroll found (tried %s)" % (regiment["name"], u["name"], candidates or "every faction"))
            continue
        u["faction_id"], u["warscroll"] = found


def every_ability(regiment):
    """A regiment's abilities and those of its own warscrolls."""
    return regiment.get("abilities", []) + [a for w in regiment.get("warscrolls", []) for a in w["abilities"]]


def apply_overrides(regs, overrides, wh_regiments):
    by_name = {r["name"]: r for r in regs}
    def target(name):
        owner, _, part = name.partition(" > ")
        r = by_name.get(owner)
        if r is None:
            sys.exit("regiment override %r names no regiment" % name)
        return r, part
    wh_by = {merge.norm(r["name"]): r for r in wh_regiments}
    def wahapedia_ability(r, wh_name, what):
        a = next((a for a in every_ability(wh_by.get(merge.norm(r["name"]), {}))
                  if merge.norm(a["name"]) == merge.norm(wh_name)), None)
        if a is None:
            sys.exit("%s: no Wahapedia ability %r in %s" % (what, wh_name, r["name"]))
        return dict(copy.deepcopy(a), name=wh_name)
    for name, wh_name in overrides.get("replace_with_wahapedia", {}).items():
        r, part = target(name)
        wh = wahapedia_ability(r, wh_name, "replace_with_wahapedia")
        matched = [a for a in every_ability(r) if a["name"] == part]
        if not matched:
            sys.exit("replace_with_wahapedia: %r matches no ability" % name)
        for a in matched:
            a.clear()
            a.update(copy.deepcopy(wh))
    for name in overrides.get("add_from_wahapedia", []):
        r, part = target(name)
        r["abilities"].append(wahapedia_ability(r, part, "add_from_wahapedia"))
    for name in overrides.get("remove", []):
        r, part = target(name)
        if not any(a["name"] == part for a in every_ability(r)):
            sys.exit("remove: %r matches no ability" % name)
        r["abilities"] = [a for a in r["abilities"] if a["name"] != part]
        for w in r.get("warscrolls", []):
            w["abilities"] = [a for a in w["abilities"] if a["name"] != part]
    for name, fields in overrides.get("fields", {}).items():
        r, part = target(name)
        matched = [r] if not part else [x for x in every_ability(r) + r["units"] if x["name"] == part]
        if not matched:
            sys.exit("field override %r matches no regiment, ability or unit" % name)
        for x in matched:
            x.update(fields)
            # "faction" on a unit override is the faction id.
            if x is not r and "faction" in fields:
                x["faction_id"] = fields["faction"]
    for name, factions in overrides.get("add_factions", {}).items():
        r, _ = target(name)
        r["factions"] = list(dict.fromkeys(r["factions"] + factions))


def build(bsdata_dir, wahapedia_dir, overrides, data_dir=DEFAULT_DATA):
    """(regiments in the schema's shape, report lines, skipped regiment names)."""
    cats = bsdata.Catalogues(bsdata_dir)
    bs = regiments.read_regiments(cats)
    skipped = [r["name"] for r in bs if is_campaign_only(r)]
    bs = [r for r in bs if not is_campaign_only(r)]
    wh = [] if wahapedia_dir is None else \
        [regiments.parse_regiment_page(p) for p in sorted(glob.glob(os.path.join(wahapedia_dir, "*.html")))]
    if wahapedia_dir is not None:
        rename_wahapedia(wh, overrides.get("wahapedia_names", {}))
    report = merge.Report()
    merged = regiments.merge_regiments(report, bs, wh) if wahapedia_dir is not None else \
        [dict(r, units=[dict(u, faction="") for u in r["units"]]) for r in bs]
    wh_by = {merge.norm(r["name"]): r for r in wh}
    for r in merged:
        page = wh_by.get(merge.norm(r["name"]))
        if r["warscrolls"] and page is not None:
            # The regiment page's sheets have no battle profile, so BSData's isn't compared.
            for w in page["warscrolls"]:
                bs = next((x for x in r["warscrolls"] if merge.norm(x["name"]) == merge.norm(w["name"])), {})
                w.update({k: bs[k] for k in ("points", "unit_size", "base_size", "can_reinforce") if k in bs})
            r["warscrolls"] = merge.merge_warscrolls(report, r["warscrolls"], page["warscrolls"])
        r["source"] = bsdata.source_of(r["publication"])
    apply_overrides(merged, overrides, wh)
    errors = []
    factions = built_factions(data_dir)
    for r in merged:
        resolve_units(r, factions, errors)
    if errors:
        sys.exit("unresolved regiment units:\n" + "\n".join(errors))
    return [r for r in merged], report.lines, skipped


def write(merged, data_dir=DEFAULT_DATA):
    """Writes the shared regiments and every built faction's references to them."""
    shared = {"regiments_of_renown": [regiments.regiment(r) for r in sorted(merged, key=lambda r: r["name"])]}
    os.makedirs(os.path.join(data_dir, "shared"), exist_ok=True)
    dump(schema.tidy(shared), os.path.join(data_dir, "shared", FILE))
    for name, (fid, _) in built_factions(data_dir).items():
        refs = [{"shared": r["name"]} for r in sorted(merged, key=lambda r: r["name"])
                if merge.norm(name) in {merge.norm(f) for f in r["factions"]}]
        dump({"regiments_of_renown": refs}, os.path.join(data_dir, "factions", fid, FILE))


def unbuilt_factions(merged, data_dir=DEFAULT_DATA):
    built = {merge.norm(n) for n in built_factions(data_dir)}
    return sorted({f for r in merged for f in r["factions"] if merge.norm(f) not in built})


def dump(obj, path):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(obj, fh, indent="\t", ensure_ascii=False)
        fh.write("\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build the Regiments of Renown from BSData and Wahapedia.")
    parser.add_argument("wahapedia_dir", help='directory "fetch.py --regiments" wrote, or "-" for BSData alone')
    parser.add_argument("--overrides", default=DEFAULT_OVERRIDES, help="overrides JSON file")
    parser.add_argument("--data", default=DEFAULT_DATA, help="the game's data directory (default: data)")
    parser.add_argument("--bsdata", default=bsdata.DEFAULT_CHECKOUT, help="BSData checkout (default: tools/bsdata)")
    parser.add_argument("--update-bsdata", action="store_true", help="pull the BSData checkout before building")
    args = parser.parse_args()
    bsdata.ensure_checkout(args.bsdata, update=args.update_bsdata)
    overrides = load_overrides(args.overrides)
    wahapedia_dir = None if args.wahapedia_dir == "-" else args.wahapedia_dir
    merged, lines, skipped = build(args.bsdata, wahapedia_dir, overrides, args.data)
    write(merged, args.data)
    print("BSData %s" % bsdata.checkout_version(args.bsdata))
    print("%d regiments; left out (Path to Glory only): %s" % (len(merged), ", ".join(skipped) or "none"))
    print("Factions not built, so without references: %s" % (", ".join(unbuilt_factions(merged, args.data)) or "none"))
    print("\n".join(lines) or "BSData and Wahapedia agree.")
    print("%d difference(s)" % len(lines), file=sys.stderr)
