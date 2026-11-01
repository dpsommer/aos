"""Download the 360 degree view images of a model from its warhammer.com store page.

Usage: python -I fetch_360.py <store page URL>... [--out <dir>] [--profile <dir>]
e.g.   python -I tools/store_360/fetch_360.py \
           https://www.warhammer.com/en-CA/shop/Kharadron-Overlords-Arkanaut-frigate-2017

warhammer.com is behind an AWS WAF bot check, so the page is loaded in a visible Chromium window
(Playwright) with a saved browser profile. If the window shows a "Human Verification" CAPTCHA,
solve it there; the WAF token is kept in the profile, so later runs usually skip it. The window
closes by itself once the page has loaded.

The store page is a Next.js app: its __NEXT_DATA__ JSON lists each 360 view as "images360", a
list of rows (camera heights) of frames (turntable angles), e.g. 3 rows of 12 frames, named
RR-FF.jpg. Row 01 is about eye level and later rows look down from higher up. Each view is saved at full size to <out>/<view folder>/, e.g.
tmp/store_360/99120205018_ArkanautFrigate360/01-01.jpg, with a manifest.json listing the rows.
A page with several 360 views (e.g. a kit with several models) gets a folder for each.

<out> defaults to tmp/store_360/ and <profile> to tmp/.browser-profile/ in the repo; tmp/ is
gitignored, and a .gdignore is written to it so Godot doesn't import the images.
"""
import argparse, json, os, posixpath, re, sys
from urllib.parse import urljoin

SITE = "https://www.warhammer.com"
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TMP = os.path.join(REPO, "tmp")
VERIFICATION_TIMEOUT_MS = 300_000


def next_data(html):
    """The page's __NEXT_DATA__ JSON, or None if the page has none (e.g. the WAF challenge)."""
    match = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.S)
    return json.loads(match.group(1)) if match else None


def product_name(data):
    """The first "productName" in the page data, or None."""
    if isinstance(data, dict):
        if isinstance(data.get("productName"), str):
            return data["productName"]
        children = data.values()
    elif isinstance(data, list):
        children = data
    else:
        return None
    for child in children:
        name = product_name(child)
        if name:
            return name
    return None


def find_views(data):
    """{view folder name: [[frame URL, ...] per row]} for each distinct 360 view in the page data.

    The same view appears in several page components, so views are keyed by the folder their
    frames are in. URLs are absolute and without size or format parameters, so they're full size.
    """
    views = {}

    def walk(node):
        if isinstance(node, dict):
            rows = node.get("images360")
            if isinstance(rows, list) and rows:
                urls = [[urljoin(SITE, frame["url"]) for frame in row] for row in rows]
                folder = posixpath.basename(posixpath.dirname(urls[0][0]))
                views.setdefault(folder, urls)
            for child in node.values():
                walk(child)
        elif isinstance(node, list):
            for child in node:
                walk(child)

    walk(data)
    return views


def manifest(page_url, name, rows):
    """What's saved in a view's manifest.json: the frame file names of each row, top row first."""
    return {
        "page": page_url,
        "product": name,
        "rows": [[posixpath.basename(url) for url in row] for row in rows],
    }


def prepare_tmp(path):
    """Make the output folder and stop Godot importing anything in the repo's tmp/."""
    os.makedirs(path, exist_ok=True)
    if os.path.abspath(path).startswith(TMP + os.sep) or os.path.abspath(path) == TMP:
        open(os.path.join(TMP, ".gdignore"), "a").close()


def load_page(context, url):
    """The HTML of the store page, once it's past the WAF check."""
    page = context.pages[0] if context.pages else context.new_page()
    page.goto(url, timeout=60_000)
    print(f"Loading {url} (solve the CAPTCHA in the browser window if one appears)")
    page.wait_for_selector("script#__NEXT_DATA__", state="attached", timeout=VERIFICATION_TIMEOUT_MS)
    return page.content()


def save_view(context, out, folder, rows, page_url, name):
    view_dir = os.path.join(out, folder)
    os.makedirs(view_dir, exist_ok=True)
    for row in rows:
        for url in row:
            response = context.request.get(url)
            if not response.ok:
                raise RuntimeError(f"{url}: HTTP {response.status}")
            with open(os.path.join(view_dir, posixpath.basename(url)), "wb") as f:
                f.write(response.body())
    with open(os.path.join(view_dir, "manifest.json"), "w") as f:
        json.dump(manifest(page_url, name, rows), f, indent=2)
    frames = sum(len(row) for row in rows)
    print(f"  {folder}: {len(rows)} rows, {frames} frames -> {os.path.relpath(view_dir)}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("urls", nargs="+", help="warhammer.com store page URLs")
    parser.add_argument("--out", default=os.path.join(TMP, "store_360"), help="output folder")
    parser.add_argument("--profile", default=os.path.join(TMP, ".browser-profile"),
                        help="Chromium profile folder, kept between runs for the WAF token")
    args = parser.parse_args(argv)

    from playwright.sync_api import sync_playwright

    prepare_tmp(args.out)
    prepare_tmp(args.profile)
    failed = False
    with sync_playwright() as p:
        context = p.chromium.launch_persistent_context(args.profile, headless=False)
        try:
            for url in args.urls:
                data = next_data(load_page(context, url))
                views = find_views(data)
                if not views:
                    print(f"  no 360 view on {url}", file=sys.stderr)
                    failed = True
                for folder, rows in views.items():
                    save_view(context, args.out, folder, rows, url, product_name(data))
        finally:
            context.close()
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
