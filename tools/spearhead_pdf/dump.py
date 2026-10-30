"""Prints a Spearhead from the committed faction data as text, in the order of its rules PDF, to
compare with extract.py's output.

Usage: python -I dump.py <faction id> "<Spearhead name>"
"""

import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def spearhead(faction_id, name):
    path = os.path.join(REPO, "data", "factions", faction_id, "spearhead.json")
    with open(path, encoding="utf-8") as fh:
        for s in json.load(fh)["spearheads"]:
            if s["name"].lower() == name.lower():
                return s
    sys.exit("no Spearhead named %r in %s" % (name, path))


def ability(a):
    head = ", ".join(x for x in (a.get("frequency"), a.get("timing")) if x)
    lines = ["  [%s] %s%s" % (head, a["name"], " (%s)" % a["colour"] if a.get("colour") else "")]
    if a.get("casting_value"):
        lines.append("    Casting value: %d" % a["casting_value"])
    if a.get("text"):
        lines.append("    Text: " + a["text"])
    if a.get("declare"):
        lines.append("    Declare: " + a["declare"])
    if a.get("effect"):
        lines.append("    Effect: " + a["effect"])
    for o in a.get("options", []):
        lines.append("    %s: %s" % (o["name"], o["text"]))
    if a.get("keywords"):
        lines.append("    Keywords: " + ", ".join(a["keywords"]))
    return lines


def weapon(w):
    rng = '%s"' % w["range"] if w.get("range") else "-"
    rend = w["rend"] or "-"
    return '  %s | %s | %s | %s+ | %s+ | %s | %s | %s' % (
        w["name"], rng, w["attacks"], w["hit"], w["wound"], rend, w["damage"], ", ".join(w.get("abilities", [])) or "-")


def dump(s):
    out = [s["name"].upper(), "General: " + s["general"], "Units:"]
    out += ["  %d %s%s" % (u["count"], u["name"], " (%s)" % u["notes"] if u.get("notes") else "") for u in s["units"]]
    for title, key in (("BATTLE TRAITS", "battle_traits"), ("REGIMENT ABILITIES", "regiment_abilities"),
                       ("ENHANCEMENTS", "enhancements")):
        out.append(title)
        for a in s[key]:
            out += ability(a)
    for w in s["warscrolls"]:
        out.append("WARSCROLL " + w["name"].upper())
        out.append('  Move %s" | Health %s | Save %s+ | Control %s%s' % (
            w["move"], w["health"], w["save"], w["control"], " | Ward %s+" % w["ward"] if w.get("ward") else ""))
        for kind in ("ranged_weapons", "melee_weapons"):
            if w.get(kind):
                out.append(" " + kind.replace("_", " ").upper())
                out += [weapon(x) for x in w[kind]]
        for a in w.get("abilities", []):
            out += ability(a)
        out.append("  Keywords: " + ", ".join(w.get("keywords", [])))
    return "\n".join(out)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    print(dump(spearhead(sys.argv[1], sys.argv[2])))
