import os, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import extract_maps


def blocks(*rows):
    """4x4 territory grid from strings of A (attacker), D (defender) and . (neutral)."""
    names = {"A": "attacker", "D": "defender", ".": ""}
    return [[names[c] for c in row] for row in rows]


def test_rectangles_merges_a_row_run():
    grid = blocks("AAAA", "....", "....", "DDDD")
    assert extract_maps.rectangles(grid, "attacker") == [{"x": 0, "y": 0, "width": 60, "depth": 11}]


def test_rectangles_merges_identical_runs_in_consecutive_rows():
    grid = blocks("AA..", "AA..", "..DD", "..DD")
    assert extract_maps.rectangles(grid, "defender") == [{"x": 30, "y": 22, "width": 30, "depth": 22}]


def test_rectangles_keeps_different_runs_apart():
    grid = blocks("A...", "AA..", "..DD", "...D")
    assert extract_maps.rectangles(grid, "attacker") == [
        {"x": 0, "y": 0, "width": 15, "depth": 11},
        {"x": 0, "y": 11, "width": 30, "depth": 11},
    ]


def test_rectangles_splits_a_row_with_a_gap():
    grid = blocks("A..A", "....", "....", "....")
    assert len(extract_maps.rectangles(grid, "attacker")) == 2


def test_rectangles_is_empty_for_an_absent_owner():
    assert extract_maps.rectangles(blocks("....", "....", "....", "...."), "attacker") == []


def test_half_inch_rounds_to_nearest_half():
    assert [extract_maps.half_inch(v) for v in (5.2, 5.3, 37.74, 37.76)] == [5.0, 5.5, 37.5, 38.0]


def test_half_inch_rounds_halfway_up():
    assert extract_maps.half_inch(5.25) == 5.5


def test_find_circles_finds_a_gold_ring():
    pixels = np.full((200, 200, 3), 128, int)
    yy, xx = np.ogrid[:200, :200]
    distance = np.sqrt((xx - 90) ** 2 + (yy - 110) ** 2)
    pixels[(distance > 56) & (distance < 62)] = (200, 160, 70)
    circles = extract_maps.find_circles(pixels)
    assert len(circles) == 1
    x, y, radius = circles[0]
    assert abs(x - 90) <= 2 and abs(y - 110) <= 2 and abs(radius - 59) <= 3
