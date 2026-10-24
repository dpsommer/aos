"""Warscrolls and Armies of Renown that several factions use, such as Nagash or the Legions of Nagash.

Each is written once to data/shared/ and the faction files reference it. shared.json lists them
and fixes their typos:

    {
        "warscrolls": {"<id>": {"faction_keyword": true}},
        "armies_of_renown": ["<name>"],
        "fields": {"<warscroll id or Army of Renown name>[ > <weapon or ability name>]": {"<field>": <value>}}
    }

"faction_keyword" marks a warscroll whose every version carries only its own faction's keyword,
e.g. Nagash, Supreme Lord of the Undead is NIGHTHAUNT in Nighthaunt and FLESH-EATER COURTS in
Flesh-eater Courts. The shared profile leaves that keyword out and each reference adds it.

A shared entry is written by the first faction built with it, or again with --update-shared.
Otherwise the shared entry wins and the faction's differences from it are reported, except for
battle profile fields (PER_FACTION) and abilities, which the reference keeps, and keywords only the
faction's version has, which the reference adds. A reference's ability replaces the shared ability
of the same name or, if there's none, is added: each battletome prints its own Nagash, and Flesh-eater
Courts' has a different Invocation of Nagash and an extra Utter Contempt.
"""
import copy, json, os, sys

CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "shared.json")
DEFAULT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                           "data", "shared")
PER_FACTION = ("points", "unit_size", "can_reinforce", "regiment_options", "notes")
FILES = {"warscrolls": ("warscrolls.json", "id"), "armies_of_renown": ("armies_of_renown.json", "name")}


def load_config(path=CONFIG):
    config = json.load(open(path)) if os.path.exists(path) else {}
    config.setdefault("warscrolls", {})
    config.setdefault("armies_of_renown", [])
    config.setdefault("fields", {})
    for target in config["fields"]:
        owner = target.split(" > ", 1)[0]
        if owner not in config["warscrolls"] and owner not in config["armies_of_renown"]:
            sys.exit("shared field override %r names no shared warscroll or Army of Renown" % target)
    return config


def read(shared_dir):
    """The shared entries in shared_dir: {"warscrolls": [...], "armies_of_renown": [...]}."""
    out = {}
    for kind, (name, _) in FILES.items():
        path = os.path.join(shared_dir, name)
        out[kind] = json.load(open(path, encoding="utf-8"))[kind] if os.path.exists(path) else []
    return out


def write(entries, shared_dir):
    os.makedirs(shared_dir, exist_ok=True)
    for kind, (name, key) in FILES.items():
        with open(os.path.join(shared_dir, name), "w", encoding="utf-8") as fh:
            json.dump({kind: sorted(entries[kind], key=lambda e: e[key])}, fh, indent="\t", ensure_ascii=False)
            fh.write("\n")


def apply_fields(warscrolls, armies, fields):
    """Applies the shared field overrides to the faction's versions of the shared warscrolls and
    Armies of Renown, before they go through the schema, which drops fields that don't belong
    (e.g. an ability's effect set on a weapon of the same name)."""
    items = {w.get("id"): w for w in warscrolls}
    items.update({a["name"]: a for a in armies})
    for target, values in fields.items():
        name, _, part = target.partition(" > ")
        item = items.get(name)
        if item is None:
            continue
        if not part:
            item.update(values)
            continue
        parts = item.get("ranged_weapons", []) + item.get("melee_weapons", []) + _abilities(item)
        # Not every faction's version has every ability (only Flesh-eater Courts' Nagash has Utter
        # Contempt), so a part this version lacks is skipped; load_config checks the owner exists.
        for x in [x for x in parts if x["name"] == part]:
            x.update(values)


def _abilities(item):
    tables = item.get("enhancement_tables", []) + item.get("lores", [])
    return item.get("abilities", []) + item.get("battle_traits", []) + [e for t in tables for e in t["entries"]]


def profile(warscroll, faction_keyword, per_faction_keyword):
    """The shared part of a faction's version of a warscroll."""
    out = copy.deepcopy(warscroll)
    out.pop("regiment_options", None)
    if per_faction_keyword:
        out["keywords"] = [k for k in out["keywords"] if k != faction_keyword]
    return out


def reference(warscroll, shared, report):
    """The faction's reference to the shared warscroll: its battle profile, its own keywords and the
    abilities that differ from the shared ones. Other differences are reported."""
    ref = {"shared": shared["id"]}
    for k in PER_FACTION:
        if warscroll.get(k) != shared.get(k) and (warscroll.get(k) or shared.get(k)):
            ref[k] = warscroll.get(k)
    keywords = [k for k in warscroll["keywords"] if k not in shared["keywords"]]
    if keywords:
        ref["keywords"] = keywords
    shared_abilities = {a["name"]: a for a in shared["abilities"]}
    abilities = [a for a in warscroll["abilities"] if shared_abilities.get(a["name"]) != a]
    if abilities:
        ref["abilities"] = abilities
    where = "shared warscroll %s" % shared["id"]
    for k in sorted(set(warscroll) | set(shared)):
        if k not in PER_FACTION and k not in ("keywords", "abilities"):
            diff(report, where, k, shared.get(k), warscroll.get(k))
    names = {a["name"] for a in warscroll["abilities"]}
    for name in shared_abilities:
        if name not in names:
            report.lines.append("%s: ability %s only in the shared profile" % (where, name))
    missing = [k for k in shared["keywords"] if k not in warscroll["keywords"]]
    if missing:
        report.lines.append("%s: keywords %r only in the shared profile" % (where, missing))
    return ref


def diff(report, where, field, shared, mine):
    """Reports where the faction's value differs from the shared one, field by field and, for lists
    of named items, item by item."""
    if isinstance(shared, dict) and isinstance(mine, dict):
        for k in sorted(set(shared) | set(mine)):
            diff(report, where, "%s.%s" % (field, k), shared.get(k), mine.get(k))
    elif _named(shared) and _named(mine) and [x["name"] for x in shared] == [x["name"] for x in mine]:
        for s, m in zip(shared, mine):
            diff(report, where, "%s > %s" % (field, s["name"]), s, m)
    elif shared != mine:
        report.lines.append("%s: %s differs (shared %r, this faction %r)" % (where, field, shared, mine))


def _named(value):
    return isinstance(value, list) and all(isinstance(x, dict) and "name" in x for x in value)


def share(warscrolls, armies, faction_name, config, entries, report, update=False):
    """Replaces the shared warscrolls and Armies of Renown in a faction's schema-shaped data with
    references, adding or updating entries as needed. Returns (warscrolls, armies)."""
    faction_keyword = faction_name.upper()
    shared_warscrolls = {w["id"]: i for i, w in enumerate(entries["warscrolls"])}
    out_warscrolls = []
    for w in warscrolls:
        options = config["warscrolls"].get(w["id"])
        if options is None:
            out_warscrolls.append(w)
            continue
        p = profile(w, faction_keyword, options.get("faction_keyword", False))
        if w["id"] not in shared_warscrolls:
            shared_warscrolls[w["id"]] = len(entries["warscrolls"])
            entries["warscrolls"].append(p)
        elif update:
            entries["warscrolls"][shared_warscrolls[w["id"]]] = p
        out_warscrolls.append(reference(w, entries["warscrolls"][shared_warscrolls[w["id"]]], report))
    shared_armies = {a["name"]: i for i, a in enumerate(entries["armies_of_renown"])}
    out_armies = []
    for a in armies:
        if a["name"] not in config["armies_of_renown"]:
            out_armies.append(a)
            continue
        if a["name"] not in shared_armies:
            shared_armies[a["name"]] = len(entries["armies_of_renown"])
            entries["armies_of_renown"].append(a)
        elif update:
            entries["armies_of_renown"][shared_armies[a["name"]]] = a
        else:
            diff(report, "shared army of renown %s" % a["name"], "army", entries["armies_of_renown"][shared_armies[a["name"]]], a)
        out_armies.append({"shared": a["name"]})
    return out_warscrolls, out_armies
