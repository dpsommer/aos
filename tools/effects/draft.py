"""Drafts effect data for a faction's abilities from common sentences, for someone to check.

Usage: python -I tools/effects/draft.py <faction id> > drafts.json

Prints one entry per ability it can read, as data/effects/<faction id>.json would hold it, and lists
the rest on stderr. It only knows a few sentence shapes and doesn't understand conditions, so read
every draft against the ability's text before copying it in, then run stamp_hashes.py. See
docs/technical/effect-data.md.
"""

import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")

ROLLS = {"hit": "hit", "wound": "wound", "save": "save", "charge": "charge", "casting": "casting", "chanting": "chanting"}
UNTIL = [("for the rest of the turn", "turn"), ("this turn", "turn"), ("until the start of your next turn", "start_next_turn"),
         ("in this phase", "phase"), ("this phase", "phase"), ("for the rest of the battle", "battle")]


def draft_target(declare):
    """A target descriptor from "Pick a [visible] friendly/enemy KEYWORD unit [wholly] within N" of this unit"."""
    found = re.search(r'[Pp]ick (?:a|an)(?: visible)? (friendly|enemy) ([A-Z\- ]*?)\s*(?:unit|HERO|MONSTER)?\s*(?:(wholly) )?(?:within (\d+)")?', declare)
    if not found or "to be the target" not in declare:
        return None
    target = {"side": found.group(1)}
    keywords = [word for word in found.group(2).split() if word]
    if "HERO" in declare.split("to be the target")[0] and "non-HERO" not in declare:
        keywords.append("HERO")
    if keywords:
        target["keywords"] = keywords
    if found.group(4):
        target["within"] = int(found.group(4))
        if found.group(3):
            target["wholly"] = True
    return target


def draft_effect(effect, to_target):
    """The ops for one simple effect sentence, or None."""
    until = next((name for phrase, name in UNTIL if phrase in effect), "")
    roll = re.search(r"(Add|Subtract) (\d+) (?:to|from) (hit|wound|save|charge|casting|chanting) rolls", effect)
    if roll:
        by = int(roll.group(2)) * (1 if roll.group(1) == "Add" else -1)
        op = {"op": "modify", "stat": ROLLS[roll.group(3)], "by": by}
        if "that target this unit" in effect or "that target the target" in effect:
            op["against"] = True
        if "combat attacks" in effect or "melee" in effect:
            op["weapons"] = "melee"
        if until:
            op["until"] = until
        return [op]
    attacks = re.search(r"[Aa]dd (\d+) to the Attacks characteristic of .*melee weapons", effect)
    if attacks:
        op = {"op": "modify", "stat": "attacks", "by": int(attacks.group(1)), "weapons": "melee"}
        if until:
            op["until"] = until
        return [op]
    mortal = re.fullmatch(r"(?:Roll a dice\. On a \d\+, )?[Ii]nflict (D?\d+) mortal damage on (?:the target|that enemy unit)\.", effect.strip())
    if mortal:
        return [{"op": "mortal", "amount": mortal.group(1)}]
    heal = re.fullmatch(r"Heal \((D?\d+(?:\+\d+)?)\) (?:the target|that unit|this unit)\.", effect.strip())
    if heal:
        return [{"op": "heal", "amount": heal.group(1)}]
    grant = re.search(r"has (STRIKE-FIRST|STRIKE-LAST|WARD \(\d\+\))", effect)
    if grant:
        word = grant.group(1)
        if word.startswith("WARD"):
            op = {"op": "modify", "stat": "ward", "set": int(re.search(r"\d", word).group())}
        else:
            op = {"op": "modify", "grant": word}
        if until:
            op["until"] = until
        return [op]
    return None


def draft(ability):
    effect = ability.get("effect", "")
    ops = draft_effect(effect, bool(ability.get("declare")))
    if ops is None:
        return None
    if ability.get("timing") == "Passive":
        return {"passive": [{key: value for key, value in op.items() if key != "op"} for op in ops]}
    entry = {"do": ops}
    target = draft_target(ability.get("declare", ""))
    if target:
        entry["target"] = target
    gate = re.match(r"Roll a dice\. On a (\d)\+", effect)
    if gate:
        entry["gate"] = {"dice": "D6", "at_least": int(gate.group(1))}
    return entry


def abilities_of(space):
    with open(os.path.join(ROOT, "data", "factions", space, "faction.json"), encoding="utf-8") as handle:
        faction = json.load(handle)
    with open(os.path.join(ROOT, "data", "factions", space, "warscrolls.json"), encoding="utf-8") as handle:
        scrolls = json.load(handle)
    for ability in faction.get("battle_traits", []):
        yield "%s:trait/%s" % (space, ability["name"]), ability
    for formation in faction.get("battle_formations", []):
        for ability in formation.get("abilities", []):
            yield "%s:trait/%s" % (space, ability["name"]), ability
    for table in faction.get("enhancement_tables", []):
        for ability in table.get("entries", []):
            yield "%s:enhancement/%s" % (space, ability["name"]), ability
    for lore in faction.get("lores", []):
        for ability in lore.get("entries", []):
            yield "%s:lore/%s" % (space, ability["name"]), ability
    for scroll in scrolls["warscrolls"]:
        for ability in scroll.get("abilities", []):
            if "id" in scroll:
                yield "%s:warscroll/%s/%s" % (space, scroll["id"], ability["name"]), ability


def main(argv):
    drafts = {}
    missed = []
    for key, ability in abilities_of(argv[0]):
        entry = draft(ability)
        if entry:
            drafts[key] = entry
        else:
            missed.append(key)
    json.dump(drafts, sys.stdout, ensure_ascii=False, indent="\t")
    print()
    print("%d drafted, %d not: %s" % (len(drafts), len(missed), ", ".join(missed)), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
