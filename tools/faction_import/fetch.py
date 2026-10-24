"""Download a faction's Wahapedia pages.

Usage: python -I fetch.py <wahapedia slug> <out dir>
e.g.   python -I fetch.py helsmiths-of-hashut /tmp/hoh

Writes <out dir>/<slug>.html and <out dir>/units/<Unit-Name>.html. BSData isn't downloaded
here; build.py reads it from a local checkout (see bsdata.ensure_checkout).
"""
import os, re, sys, time, urllib.error, urllib.request

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
            html = get(WAHAPEDIA + slug + "/" + unit)
        except urllib.error.HTTPError as error:
            # Some links, such as the Path to Glory hero, have no page of their own.
            print("skipped %s: %s" % (unit, error), file=sys.stderr)
            continue
        save(os.path.join(out_dir, "units", unit + ".html"), html)
        print(unit, file=sys.stderr)


if __name__ == "__main__":
    fetch_wahapedia(*sys.argv[1:3])
