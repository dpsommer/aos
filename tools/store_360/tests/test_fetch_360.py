import json, os, sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import fetch_360

FOLDER = "/app/resources/catalog/product/threeSixty/99120205018_ArkanautFrigate360"


def frame(row, col, folder=FOLDER):
    return {"url": f"{folder}/{row:02d}-{col:02d}.jpg", "label": "Arkanaut Frigate"}


def view(rows=2, cols=3, folder=FOLDER):
    return [[frame(r, c, folder) for c in range(1, cols + 1)] for r in range(1, rows + 1)]


def test_next_data_returns_parsed_json():
    payload = {"props": {"a": [1, 2]}}
    html = f'<html><script id="__NEXT_DATA__" type="application/json">{json.dumps(payload)}</script></html>'
    assert fetch_360.next_data(html) == payload


def test_next_data_reads_multiline_json():
    html = '<script id="__NEXT_DATA__" type="application/json">{\n"a": 1\n}</script>'
    assert fetch_360.next_data(html) == {"a": 1}


def test_next_data_is_none_without_script_tag():
    assert fetch_360.next_data("<html><body>Human Verification</body></html>") is None


def test_product_name_found_nested_in_dicts_and_lists():
    data = {"props": {"items": [{"x": 1}, {"product": {"productName": "Arkanaut Frigate"}}]}}
    assert fetch_360.product_name(data) == "Arkanaut Frigate"


def test_product_name_is_first_found():
    data = {"a": {"productName": "First"}, "b": {"productName": "Second"}}
    assert fetch_360.product_name(data) == "First"


def test_product_name_none_when_absent():
    assert fetch_360.product_name({"a": [{"b": 1}, "text"]}) is None


def test_find_views_finds_images360_nested_anywhere():
    data = {"props": [{"x": {"images": {"images360": view()}}}]}
    assert list(fetch_360.find_views(data)) == ["99120205018_ArkanautFrigate360"]


def test_find_views_makes_urls_absolute():
    rows = fetch_360.find_views({"images360": view()})["99120205018_ArkanautFrigate360"]
    assert rows[0][0] == "https://www.warhammer.com" + FOLDER + "/01-01.jpg"


def test_find_views_keeps_row_and_frame_order():
    rows = fetch_360.find_views({"images360": view(rows=2, cols=3)})["99120205018_ArkanautFrigate360"]
    names = [[u.rsplit("/", 1)[1] for u in row] for row in rows]
    assert names == [["01-01.jpg", "01-02.jpg", "01-03.jpg"], ["02-01.jpg", "02-02.jpg", "02-03.jpg"]]


def test_find_views_dedupes_view_repeated_in_components():
    data = {"a": {"images360": view()}, "b": [{"images360": view()}]}
    assert len(fetch_360.find_views(data)) == 1


def test_find_views_keeps_distinct_views_separate():
    other = "/app/resources/catalog/product/threeSixty/OtherModel360"
    data = {"a": {"images360": view()}, "b": {"images360": view(folder=other)}}
    assert set(fetch_360.find_views(data)) == {"99120205018_ArkanautFrigate360", "OtherModel360"}


def test_find_views_ignores_empty_images360():
    assert fetch_360.find_views({"a": {"images360": []}}) == {}


def test_find_views_empty_when_none_present():
    assert fetch_360.find_views({"a": [{"b": 1}], "c": "text"}) == {}


def test_manifest_stores_page_and_product():
    m = fetch_360.manifest("https://example.com/p", "Arkanaut Frigate", [])
    assert (m["page"], m["product"]) == ("https://example.com/p", "Arkanaut Frigate")


def test_manifest_rows_are_frame_file_names():
    rows = [["https://x/a/01-01.jpg", "https://x/a/01-02.jpg"], ["https://x/a/02-01.jpg"]]
    assert fetch_360.manifest("p", "n", rows)["rows"] == [["01-01.jpg", "01-02.jpg"], ["02-01.jpg"]]
