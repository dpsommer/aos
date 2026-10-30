import os, sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import extract


def make_pdf(path, page_texts):
    """Writes a minimal valid PDF with one Helvetica text line per page."""
    objs = {}
    n = len(page_texts)
    kids = " ".join("%d 0 R" % (4 + 2 * i) for i in range(n))
    objs[1] = "<< /Type /Catalog /Pages 2 0 R >>"
    objs[2] = "<< /Type /Pages /Kids [%s] /Count %d >>" % (kids, n)
    objs[3] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    for i, text in enumerate(page_texts):
        stream = "BT /F1 12 Tf 72 700 Td (%s) Tj ET" % text
        objs[4 + 2 * i] = ("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents %d 0 R "
                           "/Resources << /Font << /F1 3 0 R >> >> >>" % (5 + 2 * i))
        objs[5 + 2 * i] = "<< /Length %d >>\nstream\n%s\nendstream" % (len(stream), stream)
    out = b"%PDF-1.4\n"
    offsets = {}
    for num in sorted(objs):
        offsets[num] = len(out)
        out += ("%d 0 obj\n%s\nendobj\n" % (num, objs[num])).encode("latin-1")
    xref = len(out)
    out += ("xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)).encode()
    for num in sorted(objs):
        out += ("%010d 00000 n \n" % offsets[num]).encode()
    out += ("trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)).encode()
    path.write_bytes(out)
    return str(path)


@pytest.fixture
def pdf(tmp_path):
    return make_pdf(tmp_path / "sample.pdf", ["Hello Spearhead"])


def test_pages_returns_text_per_page(tmp_path):
    path = make_pdf(tmp_path / "two.pdf", ["First page", "Second page"])
    texts = extract.pages(path, "plain")
    assert len(texts) == 2
    assert "First page" in texts[0] and "Second page" in texts[1]


def test_as_text_gives_layout_then_plain_headers_with_text(pdf):
    out = extract.as_text(pdf)
    layout = out.index("=== sample.pdf page 1 (layout) ===")
    plain = out.index("=== sample.pdf page 1 (plain) ===")
    assert layout < plain
    assert "Hello Spearhead" in out[layout:plain]
    assert "Hello Spearhead" in out[plain:]


def test_as_text_single_mode_omits_the_other(pdf):
    out = extract.as_text(pdf, ("plain",))
    assert "(plain)" in out and "(layout)" not in out


def test_as_text_orders_pages_before_modes(tmp_path):
    path = make_pdf(tmp_path / "two.pdf", ["A", "B"])
    out = extract.as_text(path)
    order = [out.index(h) for h in ("page 1 (layout)", "page 1 (plain)", "page 2 (layout)", "page 2 (plain)")]
    assert order == sorted(order)


def test_main_mode_plain_prints_only_plain(pdf, capsys):
    extract.main([pdf, "--mode", "plain"])
    out = capsys.readouterr().out
    assert "(plain)" in out and "(layout)" not in out


def test_main_out_writes_file_named_after_pdf_stem(pdf, tmp_path, capsys):
    dest = tmp_path / "nested" / "out"
    extract.main([pdf, "--out", str(dest)])
    written = (dest / "sample.txt").read_text(encoding="utf-8")
    assert "=== sample.pdf page 1 (layout) ===" in written
    assert capsys.readouterr().out == ""
