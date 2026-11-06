"""Stamps data/effects/*.json entries with a hash of the rules text they were written from.

Usage: python -I tools/effects/stamp_hashes.py [--check]

Run it after writing or checking an entry. An entry whose rules text has since changed is stale, and
its ability counts as not supported until someone checks it and stamps it again; --check lists stale
and missing entries without changing anything. See docs/technical/effect-data.md.
"""

import glob
import hashlib
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
UNHASHED = ("scoring:", "tactic:", "twist:")


def load(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as handle:
        return json.load(handle)


def text_hash(ability):
    text = "%s\n%s\n%s\n%s" % (ability.get("timing", ""), ability.get("declare", ""), ability.get("effect", ""), ability.get("text", ""))
    return hashlib.md5(text.encode("utf-8")).hexdigest()[:8]


def named(abilities, name):
    return next((a for a in abilities if a.get("name") == name), None)


def faction_files(space):
    return load("data", "factions", space, "faction.json"), load("data", "factions", space, "warscrolls.json")


def find_spearhead(name):
    for path in glob.glob(os.path.join(ROOT, "data", "factions", "*", "spearhead.json")):
        with open(path, encoding="utf-8") as handle:
            for army in json.load(handle).get("spearheads", []):
                if army["name"] == name:
                    return army
    return None


def find_pack(name):
    for path in glob.glob(os.path.join(ROOT, "data", "core", "spearhead", "*.json")):
        with open(path, encoding="utf-8") as handle:
            pack = json.load(handle)
            if pack["name"] == name:
                return pack
    return None


def locate(key):
    """The ability an effect data key points at, or None."""
    space, _, path = key.partition(":")
    parts = path.split("/")
    if space == "core":
        core = load("data", "core", "abilities.json")
        return named(core["abilities"], path)
    if space == "spearhead":
        army = find_spearhead(parts[0])
        if army is None:
            return None
        section, name = parts[1], "/".join(parts[2:])
        if section == "trait":
            return named(army["battle_traits"], name)
        if section == "regiment":
            return named(army["regiment_abilities"], name)
        if section == "enhancement":
            return named(army["enhancements"], name)
        scroll = next((w for w in army["warscrolls"] if w["id"] == section), None)
        return named(scroll["abilities"], name) if scroll else None
    if space == "pack":
        pack = find_pack(parts[0])
        if pack is None:
            return None
        if parts[1] == "card":
            card = next((c for c in pack["battle_tactic_cards"] if c["name"] == parts[2]), None)
            return card["command"] if card else None
        return named(pack["abilities"], "/".join(parts[1:]))
    if space == "battleplan":
        plans = load("data", "core", "battleplans.json")["battleplans"]
        plan = next((p for p in plans if p["name"] == parts[0]), None)
        return named(plan["abilities"], parts[1]) if plan else None
    return locate_in_faction(space, parts)


def locate_in_faction(space, parts):
    faction, scrolls = faction_files(space)
    section = parts[0]
    name = "/".join(parts[1:])
    if section == "trait":
        found = named(faction.get("battle_traits", []), name)
        if found:
            return found
        for formation in faction.get("battle_formations", []):
            found = named(formation.get("abilities", []), name)
            if found:
                return found
        return None
    if section == "enhancement":
        for table in faction.get("enhancement_tables", []):
            found = named(table.get("entries", []), name)
            if found:
                return found
        return None
    if section == "lore":
        for lore in faction.get("lores", []):
            found = named(lore.get("entries", []), name)
            if found:
                return found
        return None
    if section == "warscroll":
        scroll = next((w for w in scrolls["warscrolls"] if w.get("id") == parts[1]), None)
        return named(scroll["abilities"], "/".join(parts[2:])) if scroll else None
    return None


def main(argv):
    check = "--check" in argv
    problems = 0
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "effects", "*.json"))):
        with open(path, encoding="utf-8") as handle:
            entries = json.load(handle)
        changed = False
        for key, entry in entries.items():
            if key.startswith(UNHASHED):
                continue
            ability = locate(key)
            if ability is None:
                print("no such ability: %s" % key)
                problems += 1
                continue
            stamp = text_hash(ability)
            if entry.get("hash") != stamp:
                if check:
                    print("stale: %s" % key)
                    problems += 1
                else:
                    entry["hash"] = stamp
                    changed = True
        if changed:
            with open(path, "w", encoding="utf-8") as handle:
                json.dump(entries, handle, ensure_ascii=False, indent="\t")
                handle.write("\n")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
