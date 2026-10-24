import re
from bs4 import Tag, NavigableString

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
