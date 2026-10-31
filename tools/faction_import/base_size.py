"""Turns a warscroll's base size text into the base_size object the faction JSON stores. See
docs/technical/faction-data.md#base-sizes.

The sources write base sizes as text:
- one base: "32mm" (round) or "60 × 35mm" (oval);
- "Use model": the model has no base;
- per model, by name: "Killaboss: 40mm, 2 x Stab-grots: 25mm";
- per model, by share of the unit: "1/10 32mm (Champion)\n9/10 28.5mm", optionally named
  ("Plaguepack: 1/5 32mm (Champion)\n3/5 25mm").

parse() returns:
- {"shape": "round", "diameter": 32}
- {"shape": "oval", "length": 60, "width": 35}, length the longer side
- {"shape": "model"} for "Use model"; an override adds a best-guess "length" and "width"
- {"shape": "mixed", "models": [{"name": ..., "count": n, "note": ..., "base": {...}}, ...]}
"""
import re

SIZE = r"[\d.]+(?:\s*[x×]\s*[\d.]+)?\s*mm"
FRACTION = r"(\d+)/(\d+)\s+(" + SIZE + r")(?:\s*\(([^)]*)\))?"
FRACTION_LINE = r"\d+/\d+\s+" + SIZE + r"(?:\s*\([^)]*\))?"
# A group: who, then a size or a run of fraction lines, up to the next ", " or the end.
GROUP = re.compile(r"\s*(?:([^:]*?):\s*)?((?:" + FRACTION_LINE + r"\s*)+|" + SIZE + r")\s*(?:,|$)", re.S)
COUNT = re.compile(r"^(\d+)\s*[x×]\s*(.+)$")


def number(text):
    value = float(text)
    return int(value) if value.is_integer() else value


def single(text):
    """A base from "32mm" or "60 × 35mm", or None."""
    m = re.fullmatch(r"\s*([\d.]+)\s*(?:[x×]\s*([\d.]+)\s*)?mm\s*", text)
    if not m:
        return None
    if not m.group(2):
        return {"shape": "round", "diameter": number(m.group(1))}
    a, b = number(m.group(1)), number(m.group(2))
    return {"shape": "oval", "length": max(a, b), "width": min(a, b)}


def names(who):
    """The models a group names, with counts: "2 x Scouts and 4 x Trailhounds" is 2 and 4,
    "Kro-Jax, the Aegis" is one model (a part starting in lower case belongs to the one before)."""
    parts = []
    for part in re.split(r",\s*|\s+and\s+", who):
        part = part.strip()
        if not part:
            continue
        if parts and part[0].islower() and not COUNT.match(part):
            parts[-1] += ", " + part
        else:
            parts.append(part)
    out = []
    for part in parts:
        m = COUNT.match(part)
        out.append((int(m.group(1)), m.group(2).strip()) if m else (1, part))
    return out


def entry(name, count, base, note=""):
    out = {}
    if name:
        out["name"] = name
    out["count"] = count
    if note:
        out["note"] = note
    out["base"] = base
    return out


def parse(text):
    """The base_size object for a base size text (or an object, returned as it is), or None."""
    if isinstance(text, dict):
        return text or None
    text = (text or "").strip()
    if not text:
        return None
    if re.fullmatch(r"use model", text, re.I):
        return {"shape": "model"}
    base = single(text)
    if base:
        return base
    models = []
    pos = 0
    while pos < len(text):
        m = GROUP.match(text, pos)
        if not m or m.end() == pos:
            raise ValueError("unreadable base size %r" % text)
        pos = m.end()
        who, size = (m.group(1) or "").strip(), m.group(2).strip()
        fractions = re.findall(FRACTION, size)
        if fractions:
            for count, _of, each, note in fractions:
                models.append(entry(who, int(count), single(each), note.strip()))
            continue
        counted = names(who) if who else [(1, "")]
        if len(counted) == 1:
            models.append(entry(counted[0][1], counted[0][0], single(size)))
        else:
            models.append(entry(who, sum(c for c, _ in counted), single(size)))
    if len({repr(m["base"]) for m in models}) == 1:
        return models[0]["base"]
    return {"shape": "mixed", "models": models}
