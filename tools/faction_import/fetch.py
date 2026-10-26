"""Download a faction's Wahapedia pages.

Usage: python -I fetch.py <wahapedia slug> <out dir>
       python -I fetch.py --regiments <out dir> [<BSData checkout>]
e.g.   python -I fetch.py helsmiths-of-hashut /tmp/hoh

Writes <out dir>/<slug>.html and <out dir>/units/<Unit-Name>.html. BSData isn't downloaded
here; build.py reads it from a local checkout (see bsdata.ensure_checkout).
--regiments writes each Regiment of Renown's page to <out dir>/<Page-Name>.html, finding the pages
from BSData's list of regiments (see fetch_regiments).
"""
import os, re, sys, time, urllib.error, urllib.parse, urllib.request

WAHAPEDIA = "https://wahapedia.ru/aos4/factions/"
HEADERS = {"User-Agent": "Mozilla/5.0"}


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=60) as response:
        return response.read().decode("utf-8")


def save(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


def fetch_wahapedia(slug, out_dir):
    page = get(WAHAPEDIA + slug + "/")
    save(os.path.join(out_dir, slug + ".html"), page)
    units = sorted(set(re.findall(r'href="/aos4/factions/%s/([^"#/?]+)"' % re.escape(slug), page)))
    for unit in units:
        time.sleep(1)
        try:
            # Quoted because some links contain non-ASCII, e.g. a no-break space in a unit name.
            html = get(WAHAPEDIA + slug + "/" + urllib.parse.quote(unit))
        except urllib.error.HTTPError as error:
            # Some links, such as the Path to Glory hero, have no page of their own.
            print("skipped %s: %s" % (unit, error), file=sys.stderr)
            continue
        save(os.path.join(out_dir, "units", unit + ".html"), html)
        print(unit, file=sys.stderr)


def fetch_regiments(out_dir, bsdata_dir):
    """Downloads each BSData Regiment of Renown's Wahapedia page to <out dir>/<Page-Name>.html.
    Wahapedia doesn't link them from faction pages, but has each under every faction that can
    include it, so the faction and page names are tried until one exists. Names Wahapedia spells
    differently come from the "wahapedia_names" of the regiments overrides file. A regiment whose
    page is already in out_dir is skipped, so a rerun only fetches what's missing; use an empty
    directory to fetch them all again."""
    import bsdata, build_regiments, regiments
    bsdata.ensure_checkout(bsdata_dir)
    names = build_regiments.load_overrides().get("wahapedia_names", {})
    for r in regiments.read_regiments(bsdata.Catalogues(bsdata_dir)):
        if build_regiments.is_campaign_only(r):
            continue
        found = False
        for faction in r["factions"]:
            pages = regiments.page_names(r, names)
            if any(os.path.exists(os.path.join(out_dir, p + ".html")) for p in pages):
                found = True
                break
            for page in pages:
                time.sleep(1)
                try:
                    html = get(WAHAPEDIA + regiments.wahapedia_slug(faction).lower() + "/" + page)
                except urllib.error.HTTPError:
                    continue
                save(os.path.join(out_dir, page + ".html"), html)
                print(page, file=sys.stderr)
                found = True
                break
            if found:
                break
        if not found:
            print("no Wahapedia page for %s" % r["name"], file=sys.stderr)


if __name__ == "__main__":
    if sys.argv[1] == "--regiments":
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import bsdata
        fetch_regiments(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else bsdata.DEFAULT_CHECKOUT)
    else:
        fetch_wahapedia(*sys.argv[1:3])
