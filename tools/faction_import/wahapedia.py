"""Wahapedia AoS4 page parsers.

BSData is the primary source (see bsdata.py). These parsers supply what BSData lacks
(Spearhead, Path to Glory, regiment options, composition, Army of Renown text) and the
values the diff report compares against.

parse_unit_pages() returns warscrolls in Wahapedia's raw shape: move is a string such as
'4"', abilities keep Wahapedia's casing. parse_faction_page() returns faction rules,
Armies of Renown, Spearheads and Path to Glory sections.
"""
import os, re
from bs4 import BeautifulSoup, NavigableString, Tag

import schema


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
    frequency, timing = schema.split_frequency(timing)
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
    # Some notes end with a stray copy of the base size ("... on 1 June 2027. 120 x 92mm").
    if m: out["notes"] = re.sub(r"\s*[\d.]+\s*[x×]\s*[\d.]+\s*mm$", "", m.group(1).strip())
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

def parse_unit_pages(paths):
    """Warscrolls from Wahapedia unit pages, in the raw shape described above."""
    out = []
    for p in paths:
        soup = BeautifulSoup(open(p, encoding="utf-8").read(), "lxml")
        clean(soup)
        slug = os.path.splitext(os.path.basename(p))[0]
        sheets = soup.select(".datasheet")
        for i, sheet in enumerate(sheets):
            out.append(parse_warscroll(sheet, slug if len(sheets) == 1 else f"{slug}#{i}"))
    return out


# Line-based text for sections too varied to model (Path to Glory, AoR descriptions).

BLOCK = {"div", "p", "tr", "br", "table", "li", "ul", "h1", "h2", "h3", "h4", "tbody"}

def prepare(soup):
    """Drop narrow-layout duplicates and make block ends line breaks. Mutates soup."""
    for t in soup.select(".block_very_short, .block_short"):
        t.decompose()
    for el in soup.find_all(list(BLOCK) + ["td"]):
        if el.name != "td" and el.parent is not None:
            el.insert_after("\n")

def section_text(heading, stop=("h1", "h2", "h3")):
    """Plain text of everything after `heading` up to the next heading, one block per line."""
    out = []
    for el in heading.next_elements:
        if isinstance(el, Tag):
            if el.name in stop and el is not heading: break
            if el is heading: continue
            if el.name in BLOCK: out.append("\n")
            elif el.name == "td": out.append(" \t ")
            elif el.name in ("b", "span", "i", "a"): out.append(" ")
        elif isinstance(el, NavigableString):
            if el.parent is not None and el.parent.name in ("script", "style"): continue
            if heading in el.parents: continue
            out.append(str(el))
    s = "".join(out)
    s = re.sub(r"[  ]+", " ", s)
    lines = []
    for line in s.split("\n"):
        cells = [re.sub(r"\s+", " ", c).strip() for c in line.split("\t")]
        cells = [c for c in cells if c]
        if cells: lines.append(" | ".join(cells))
    text = "\n".join(lines)
    text = re.sub(r"\s+([,.:;)\]])", r"\1", text)
    text = re.sub(r"([(\[])\s+", r"\1", text)
    text = re.sub(r"\s+’s\b", "’s", text)
    text = re.sub(r"\s+'s\b", "'s", text)
    return text.strip()


# Faction page.

LOGO_SOURCE = {"GHYRAN": "Scourge of Ghyran", "SoA": "Scourge of Aqshy", "WhiteDwarf": "White Dwarf"}

def logo_source(el):
    for img in el.find_all("img") if isinstance(el, Tag) else []:
        src = img.get("src", "")
        if "/expansions/" in src:
            key = os.path.basename(src).split("_logo")[0]
            if key in LOGO_SOURCE: return LOGO_SOURCE[key]
    return ""

def cell_texts(td):
    """A cell's text, with each item of a list in it as a cell of its own, so a Spearhead unit
    listed without a count ("Varghulf Courtier") isn't run into the one before it."""
    if td.find(["ul", "ol"], recursive=False) is None:
        return [text(td)]
    cells = []
    for child in td.children:
        if isinstance(child, Tag) and child.name in ("ul", "ol"):
            cells += [text(li) for li in child.find_all("li")]
        else:
            cells.append(text(child))
    return cells

def table_rows(tbl):
    rows = []
    for tr in tbl.find_all("tr"):
        cells = [c for td in tr.find_all(["td", "th"], recursive=False) for c in cell_texts(td)]
        cells = [c for c in cells if c]
        if cells: rows.append(cells)
    return rows

def points_table(rows):
    pts = {}
    for r in rows:
        if len(r) == 2 and re.fullmatch(r"\d+", r[1]): pts[r[0].upper()] = int(r[1])
    return pts

def dp(ab):
    m = re.search(r"\s*([+-]\d+)\s*DP\s*$", ab["timing"])
    if m:
        ab["destiny_points"] = int(m.group(1)); ab["timing"] = ab["timing"][:m.start()].strip()
    return ab

def parse_faction_page(path):
    """Faction rules, Armies of Renown, Spearheads and Path to Glory from a Wahapedia faction page."""
    soup = BeautifulSoup(open(path, encoding="utf-8").read(), "lxml")
    for t in soup.select(".tooltip_templates, script, style, .noprint, .ShowFluff, .picSearch, .faqErrataSpoilerBody, .faqErrataHead"):
        t.decompose()
    tsoup = BeautifulSoup(open(path, encoding="utf-8").read(), "lxml")
    for t in tsoup.select(".tooltip_templates, script, style, .noprint, .ShowFluff, .picSearch, .faqErrataSpoilerBody, .faqErrataHead, .wsDataRow_short, .wsDataCell_short, .datasheet"):
        t.decompose()
    prepare(tsoup)
    # Headings by tag and title, so a formation and an Army of Renown sharing a name ("Lords of the
    # Clan") each find their own section. Repeats of a heading are matched in page order.
    theads, seen = {}, {}
    for h in tsoup.find_all(["h1", "h2", "h3"]):
        theads.setdefault((h.name, text(h)), []).append(h)
    def sec_text(tag, title):
        hs = theads.get((tag, title), [])
        i = seen.get((tag, title), 0)
        return section_text(hs[i]) if len(hs) > i else ""
    start = soup.find("h2", string=re.compile("Faction Rules"))
    for h in start.find_all_previous(["h1", "h2", "h3"]):
        if h.find_parent(class_="datasheet") is None:
            seen[(h.name, text(h))] = seen.get((h.name, text(h)), 0) + 1
    events = []  # (kind, payload) in document order
    for el in start.find_all_next(True):
        if el.find_parent(class_="datasheet") is not None and "datasheet" not in (el.get("class") or []):
            continue
        cls = el.get("class") or []
        if el.name in ("h1", "h2", "h3"):
            events.append(("h", el.name, text(el), el))
        elif "datasheet" in cls:
            events.append(("ws", el))
        elif "abBody" in cls:
            blk = el.find_parent(class_="BreakInsideAvoid")
            if blk is not None and blk.select_one(".abHeader") is None:
                blk = blk.find_parent(class_="BreakInsideAvoid") or blk
            a = parse_ability(blk) if blk is not None else None
            if a: events.append(("ab", dp(a)))
        elif el.name == "table" and not el.find_parent("table") and not el.select(".abHeader") and not el.find_parent(class_="abBody"):
            events.append(("table", table_rows(el)))
        elif el.name == "p" and not el.find_parent("table"):
            t = text(el)
            if t: events.append(("p", t))

    faction = {"battle_traits": [], "battle_formations": [], "enhancement_tables": [], "lores": []}
    aors, spearheads, ptg = [], [], []
    h2, h3, src = None, None, ""
    pts = {}
    mode = "faction"
    cur_aor = cur_sh = cur_ptg = cur_table = cur_formation = None

    def new_table(name, group=""):
        t = {"name": name, "entries": []}
        if group: t["group"] = group
        if src: t["source"] = src
        return t

    def new_lore(name, heading):
        lore = {"name": name, "kind": heading.split()[0].lower(), "entries": []}
        if pts.get(name.upper()): lore["points"] = pts[name.upper()]
        return lore

    for ev in events:
        kind = ev[0]
        if kind == "h":
            _, tag, title, el = ev
            text_here = sec_text(tag, title)
            seen[(tag, title)] = seen.get((tag, title), 0) + 1
            sec_src = ""
            for e2 in el.next_elements:
                if getattr(e2, "name", None) in ("h1", "h2", "h3") and e2 is not el: break
                if getattr(e2, "name", None) == "img" and "/expansions/" in e2.get("src", ""):
                    k = os.path.basename(e2["src"]).split("_logo")[0]
                    sec_src = LOGO_SOURCE.get(k, ""); break
            if tag == "h2" and mode in ("faction", "aor") and "ROSTER OPTIONS" in text_here:
                mode = "aor"; cur_aor = {"name": title, "text": text_here, "battle_traits": [], "enhancement_tables": [], "lores": []}
                if sec_src: cur_aor["source"] = sec_src
                aors.append(cur_aor); h3 = None; continue
            if title.upper() == "PATH TO GLORY":
                mode = "ptg"; cur_ptg = None; continue
            if title.upper() == "SPEARHEAD":
                mode = "spearhead"; continue
            if mode == "spearhead" and tag == "h2":
                cur_sh = {"name": title, "army_text": text_here, "army": [], "battle_traits": [], "regiment_abilities": [], "enhancements": [], "warscrolls": []}
                spearheads.append(cur_sh); h3 = None; continue
            if mode == "ptg":
                if tag in ("h3", "h1") and title != "Your Hero's Warscroll":
                    cur_ptg = {"name": title, "text": text_here, "warscrolls": []}
                    ptg.append(cur_ptg)
                continue
            if mode == "aor":
                h3 = title
                if title.endswith("Lore"):
                    cur_table = new_lore(title, title); cur_aor["lores"].append(cur_table)
                elif title != "Battle Traits":
                    cur_table = {"name": title, "entries": []}; cur_aor["enhancement_tables"].append(cur_table)
                continue
            if mode == "spearhead":
                h3 = title; continue
            # Faction mode. An h2 is Battle Traits, Battle Formations, a lore type ("Spell Lore",
            # "Prayer Lore", "Manifestation Lore") or an enhancement type ("Heroic Traits",
            # "Great Endrinworks"...). An h3 under it names a formation, lore or enhancement table.
            if tag == "h2":
                h2, h3, src = title, None, sec_src
                cur_table = cur_formation = None
            else:
                h3 = title; src = sec_src
                if h2 == "Battle Formations":
                    cur_formation = {"name": title, "points": pts.get(title.upper(), 0), "abilities": []}
                    faction["battle_formations"].append(cur_formation)
                elif h2.endswith("Lore"):
                    cur_table = new_lore(title, h2); faction["lores"].append(cur_table)
                elif h2 != "Battle Traits":
                    cur_table = new_table(h2, title); faction["enhancement_tables"].append(cur_table)
            continue
        if kind == "table":
            rows = ev[1]
            if rows and rows[0][0].startswith("Q:"): continue
            pts.update(points_table(rows))
            if mode == "spearhead" and cur_sh is not None and not cur_sh["army"]:
                cur_sh["army"] = rows
            continue
        if kind == "p":
            if mode == "ptg" and cur_ptg is None:
                cur_ptg = {"name": "Path to Glory", "text": ev[1], "warscrolls": []}; ptg.append(cur_ptg)
            continue
        if kind == "ws":
            el = ev[1]
            if mode == "spearhead" and cur_sh is not None: cur_sh["warscrolls"].append(parse_warscroll(el, "spearhead"))
            elif mode == "ptg" and cur_ptg is not None: cur_ptg["warscrolls"].append(parse_warscroll(el, "ptg"))
            continue
        a = ev[1]
        if mode == "faction":
            if h2 == "Battle Traits": faction["battle_traits"].append(a)
            elif h2 == "Battle Formations":
                if cur_formation is not None: cur_formation["abilities"].append(a)
            elif h2.endswith("Lore"):
                if cur_table is None:
                    cur_table = new_lore(h2, h2); faction["lores"].append(cur_table)
                cur_table["entries"].append(a)
            else:
                # Abilities straight under an enhancement h2 form a table with no group.
                if cur_table is None:
                    cur_table = new_table(h2); faction["enhancement_tables"].append(cur_table)
                a["points"] = pts.get(a["name"].upper(), 0); cur_table["entries"].append(a)
        elif mode == "aor":
            if h3 == "Battle Traits": cur_aor["battle_traits"].append(a)
            elif cur_table is not None and all(e["name"] != a["name"] for e in cur_table["entries"]): cur_table["entries"].append(a)
        elif mode == "spearhead" and cur_sh is not None:
            key = {"Battle Traits": "battle_traits", "Regiment Abilities": "regiment_abilities", "Enhancements": "enhancements"}.get(h3)
            if key: cur_sh[key].append(a)
        elif mode == "ptg":
            pass  # PtG abilities are kept in the section text
    return {"faction": faction, "armies_of_renown": aors, "spearheads": spearheads, "path_to_glory": ptg}
