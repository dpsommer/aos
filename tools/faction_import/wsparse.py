"""Parse Wahapedia AoS4 warscroll pages into JSON.

Usage: python -I wsparse.py <unit page>.html... > warscrolls_raw.json
"""
import sys, re, json, os
from bs4 import BeautifulSoup, NavigableString, Tag

EXPANSIONS = {
    "SoA_logo3.png": "Scourge of Aqshy", "GHYRAN_logo3.png": "Scourge of Ghyran",
    "WhiteDwarf_logo3.png": "White Dwarf", "Legends_logo3.png": "Legends",
}

ICON_CATEGORY = {
    "abControl": "control", "abDamage": "damage", "abDefensive": "defensive",
    "abMovement": "movement", "abOffensive": "offensive", "abRallying": "rallying",
    "abShooting": "shooting", "abSpecial": "special",
}

def text(el):
    s = el.get_text(" ", strip=True) if isinstance(el, Tag) else str(el)
    s = re.sub(r"\s+", " ", s)
    s = re.sub(r"\s+([,.:;)\]])", r"\1", s)
    s = re.sub(r"([(\[])\s+", r"\1", s)
    s = re.sub(r"\s+([’']s)\b", r"\1", s)
    return s.strip()

def clean(soup):
    for t in soup.select(".tooltip_templates, script, style, .noprint, .ShowFluff, .picSearch"):
        t.decompose()

def int_or(s, default=0):
    m = re.search(r"-?\d+", s or "")
    return int(m.group()) if m else default

def parse_ability(block):
    """block: a BreakInsideAvoid containing an abHeader table and abBody div."""
    header = block.select_one(".abHeader")
    body = block.select_one(".abBody")
    if body is None:
        return None
    icon = header.select_one("img.abLogo") if header else None
    category = ""
    if icon is not None:
        category = ICON_CATEGORY.get(os.path.splitext(os.path.basename(icon.get("src", "")))[0], "")
    timing = text(header) if header else ""
    frequency = ""
    m = re.match(r"^(Once Per (?:Battle|Turn|Phase)(?: \((?:Army|Army, Each Player)\))?),?\s*(.*)$", timing)
    if m:
        frequency, timing = m.group(1), m.group(2)
    name_el = body.find("b")
    name = text(name_el).rstrip(":").strip() if name_el else ""
    # Split the body into labelled parts (Declare/Effect/Keywords/...) by walking children.
    parts, cur, buf = {}, "lead", []
    def flush():
        s = text_join(buf)
        if s:
            parts[cur] = (parts.get(cur, "") + " " + s).strip()
    for c in body.children:
        if c is name_el:
            continue
        if isinstance(c, Tag) and c.name == "b" and text(c).endswith(":"):
            label = text(c).rstrip(":").strip()
            flush(); buf = []
            cur = label.lower() if label.lower() in ("declare", "effect", "keywords") else label
            continue
        if isinstance(c, Tag) and c.name == "br":
            buf.append("\n"); continue
        buf.append(c)
    flush()
    kw_text = parts.pop("keywords", "")
    # Most pages put ability keywords in their own block after the body.
    kw_block = block.select_one(".abKeywordsBodyText")
    if kw_block is not None:
        kw_text = (kw_text + ", " + text(kw_block)).strip(", ")
    keywords = [k.strip() for k in kw_text.split(",") if k.strip()]
    a = {"name": name, "category": category, "timing": timing, "frequency": frequency}
    for key, sel in (("casting_value", ".abSpellPointsN"), ("chanting_value", ".abPrayerPointsN")):
        value = block.select_one(sel)
        if value is not None:
            a[key] = int_or(text(value))
    if parts.get("declare"): a["declare"] = parts.pop("declare")
    a["effect"] = parts.pop("effect", "")
    lead = parts.pop("lead", "")
    if lead: a["text"] = lead
    if keywords: a["keywords"] = keywords
    if parts: a["options"] = [{"name": k, "text": v} for k, v in parts.items()]
    return a

def text_join(nodes):
    out = []
    for n in nodes:
        if n == "\n":
            out.append("\n")
        else:
            t = text(n)
            if t: out.append(t)
    s = " ".join(out)
    s = re.sub(r"[ \t]*\n[ \t]*", "\n", s)
    s = re.sub(r"\n{2,}", "\n", s)
    s = re.sub(r"\s+([,.:;)\]])", r"\1", s)
    s = re.sub(r"\s+([’']s)\b", r"\1", s)
    return s.strip()

def parse_weapons(table):
    ranged, melee, kind = [], [], None
    for tr in table.find_all("tr", recursive=True):
        cls = tr.get("class", [])
        if "wsHeaderRow" in cls:
            kind = "ranged" if tr.select_one(".wsHeaderCellName_RangedWeapons") else "melee"
            continue
        if "wsDataRow" not in cls or "wsDataRow_short" in cls:
            continue
        tds = tr.find_all("td", recursive=False)
        cells = [td for td in tds if "wsCell" in " ".join(td.get("class", []))]
        name_td = [td for td in tds if "wsDataCell_long" in td.get("class", []) and td.get_text(strip=True)]
        if not cells or not name_td: continue
        ntd = name_td[0]
        abil = ntd.select_one(".wsWeaponAbility")
        abilities = []
        if abil:
            abilities = [a.strip() for a in text(abil).split(",") if a.strip() and a.strip() != "-"]
            abil.extract()
        wname = text(ntd)
        vals = [text(c) for c in cells]
        if kind == "melee" and len(vals) == 6 and vals[0] == "":
            vals = vals[1:]
        if kind == "ranged":
            rng, atk, hit, wnd, rnd, dmg = vals[-6:]
        else:
            rng = "0"; atk, hit, wnd, rnd, dmg = vals[-5:]
        w = {"name": wname, "range": int_or(rng), "attacks": atk, "hit": int_or(hit),
             "wound": int_or(wnd), "rend": int_or(rnd), "damage": dmg}
        if abilities: w["abilities"] = abilities
        (ranged if kind == "ranged" else melee).append(w)
    return ranged, melee

def parse_profile(prof):
    out = {}
    t = text(prof)
    m = re.search(r"Unit Size\s*:\s*(\d+)", t); out["unit_size"] = int(m.group(1)) if m else 0
    m = re.search(r"Points\s*:\s*(\d+)", t); out["points"] = int(m.group(1)) if m else 0
    m = re.search(r"Base size\s*:\s*([^C]+?)(?:\s*Can be|\s*Regiment|\s*Notes|$)", t)
    if m: out["base_size"] = m.group(1).strip()
    # Units with mixed bases list each model's size in a "MODEL BASE SIZE" table instead.
    m = re.search(r"MODEL BASE SIZE\s*(.+?)(?:\s*Can be|\s*Regiment|\s*Notes|$)", t)
    if m:
        sizes = re.findall(r"(.+?)\s+([\d.]+\s*(?:×\s*[\d.]+\s*)?mm)", m.group(1))
        out["base_size"] = ", ".join("%s: %s" % (who.strip(" ,"), size) for who, size in sizes)
    m = re.search(r"Can be reinforced\s*:\s*(Yes|No)", t); out["can_reinforce"] = bool(m and m.group(1) == "Yes")
    m = re.search(r"Regiment Options\s*:\s*(.+?)(?:\s*Notes\s*:|$)", t)
    if m:
        out["regiment_options"] = [s.strip() for s in re.split(r",\s*(?=(?:0-\d|Any|\d))", m.group(1)) if s.strip()]
    m = re.search(r"Notes\s*:\s*(.+)$", t)
    if m: out["notes"] = m.group(1).strip()
    return out

def parse_warscroll(sheet, slug):
    top = sheet.select_one(".wsBodyTop"); bottom = sheet.select_one(".wsBodyBottom")
    ws = {"id": "", "slug": slug}
    hdr = top.select_one(".wsHeaderIn")
    add = hdr.select_one(".wsAddName") if hdr else None
    if add: ws["subtitle"] = text(add); add.extract()
    ws["name"] = text(hdr) if hdr else slug
    if "subtitle" in ws:
        sub = ws.pop("subtitle")
        # "with Dirigible Suit", "on Infernal Taurus" continue the name; titles such as
        # "the First Daemonsmith" are set off by a comma.
        ws["name"] += (" " if re.match(r"(with|on) ", sub) else ", ") + sub
    logos = {os.path.basename(i.get("src", "")) for i in sheet.select("img[src*='/expansions/']")}
    for logo, src in EXPANSIONS.items():
        if logo in logos:
            ws["source"] = src
            if ws["name"].startswith(src + " "):
                ws["name"] = ws["name"][len(src) + 1:]
    if ws.get("source") == "Legends":
        ws.pop("source"); ws["legends"] = True
    ws["id"] = re.sub(r"[^a-z0-9]+", "_", ((ws.get("source", "") + " ") if ws.get("source") in ("Scourge of Aqshy", "Scourge of Ghyran") else "").lower() + ws["name"].lower().replace("’", "")).strip("_")
    body = sheet
    for key, sel in [("move", ".wsMove"), ("health", ".wsWounds"), ("save", ".wsSave"), ("control", ".wsBravery"), ("ward", ".wsWard")]:
        e = body.select_one(sel)
        if e is not None:
            v = text(e)
            if key == "move": ws[key] = v  # may be '-' or '*' or e.g. 4"
            elif key in ("save", "ward"): ws[key] = int_or(v, 0)
            else: ws[key] = int_or(v, 0)
    table = top.select_one(".wsTable")
    ws["ranged_weapons"], ws["melee_weapons"] = parse_weapons(table) if table else ([], [])
    prof = top.select_one(".PitchedBattleProfile")
    if prof: ws.update(parse_profile(prof))
    abilities = []
    col = top.select_one(".Columns2_AoS") or top
    for blk in col.select(".BreakInsideAvoid"):
        if blk.select_one(".abBody") is None or blk.find_parent(class_="abBody"): continue
        # only innermost blocks that directly hold an ability
        inner = [b for b in blk.select(".BreakInsideAvoid") if b.select_one(".abBody")]
        if inner: continue
        a = parse_ability(blk)
        if a and a not in abilities: abilities.append(a)
    ws["abilities"] = abilities
    kws = []
    if bottom is not None:
        for line in bottom.select("[class*=wsKeywordLine]"):
            kws += [k.strip() for k in text(line).split(",") if k.strip()]
    ws["keywords"] = kws
    desc = body.select_one(".wsDescription")
    if desc: ws["composition"] = text(desc)
    return ws

def main(paths):
    out = []
    for p in paths:
        soup = BeautifulSoup(open(p, encoding="utf-8").read(), "lxml")
        clean(soup)
        slug = os.path.splitext(os.path.basename(p))[0]
        sheets = soup.select(".datasheet")
        for i, sheet in enumerate(sheets):
            out.append(parse_warscroll(sheet, slug if len(sheets) == 1 else f"{slug}#{i}"))
    json.dump(out, sys.stdout, indent=1, ensure_ascii=False)

if __name__ == "__main__":
    main(sys.argv[1:])
