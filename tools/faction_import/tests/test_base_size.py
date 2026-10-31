import pytest

import base_size


def test_round():
    assert base_size.parse("32mm") == {"shape": "round", "diameter": 32}


def test_round_decimal():
    assert base_size.parse("28.5mm") == {"shape": "round", "diameter": 28.5}


@pytest.mark.parametrize("text", ["60 × 35mm", "60 x 35mm", "60×35mm"])
def test_oval_separators(text):
    assert base_size.parse(text) == {"shape": "oval", "length": 60, "width": 35}


def test_oval_reversed_order_puts_longer_side_as_length():
    assert base_size.parse("25 × 50mm") == {"shape": "oval", "length": 50, "width": 25}


@pytest.mark.parametrize("text", ["Use model", "Use Model", "  use model "])
def test_use_model(text):
    assert base_size.parse(text) == {"shape": "model"}


@pytest.mark.parametrize("text", ["", "   ", None])
def test_empty_is_none(text):
    assert base_size.parse(text) is None


def test_dict_passes_through():
    data = {"shape": "round", "diameter": 40}
    assert base_size.parse(data) is data


def test_empty_dict_is_none():
    assert base_size.parse({}) is None


def test_per_model_names():
    out = base_size.parse("Killaboss: 40mm, Stab-grot: 25mm")
    assert out == {"shape": "mixed", "models": [
        {"name": "Killaboss", "count": 1, "base": {"shape": "round", "diameter": 40}},
        {"name": "Stab-grot", "count": 1, "base": {"shape": "round", "diameter": 25}},
    ]}


@pytest.mark.parametrize("sep", ["x", "×"])
def test_named_count(sep):
    out = base_size.parse("Knight: 90mm, 2 %s Gryph-hounds: 40mm" % sep)
    assert out["models"][1]["name"] == "Gryph-hounds"
    assert out["models"][1]["count"] == 2


def test_counts_without_space_between_digit_and_x():
    out = base_size.parse("1x Slaughtershade: 32mm, 2x Hounds: 40mm")
    assert [(m["name"], m["count"]) for m in out["models"]] == [("Slaughtershade", 1), ("Hounds", 2)]


def test_multi_name_group_counts_count_prefixes():
    out = base_size.parse("2 x Scouts and 4 x Trailhounds: 32mm, Boss: 40mm")
    assert out["models"][0]["count"] == 6


def test_multi_name_group_counts_each_name():
    out = base_size.parse("A, B and C: 32mm, Boss: 40mm")
    assert out["models"][0]["count"] == 3
    assert out["models"][0]["name"] == "A, B and C"


def test_lower_case_part_joins_previous_name():
    out = base_size.parse("Kro-Jax, the Aegis: 40mm, Hound: 25mm")
    assert out["models"][0]["count"] == 1
    assert out["models"][0]["name"] == "Kro-Jax, the Aegis"


def test_fractions_give_counts_and_note():
    out = base_size.parse("1/10 32mm (Champion)\n9/10 28.5mm")
    first, second = out["models"]
    assert (first["count"], first["note"], second["count"]) == (1, "Champion", 9)
    assert "name" not in first and "note" not in second


def test_named_fractions():
    out = base_size.parse("Plaguepack: 1/5 32mm (Champion)\n3/5 25mm")
    assert [m["count"] for m in out["models"]] == [1, 3]
    assert out["models"][0]["name"] == "Plaguepack"
    assert out["models"][0]["note"] == "Champion"


def test_groups_of_one_size_collapse_to_a_single_base():
    assert base_size.parse("Boss: 32mm, Grot: 32mm") == {"shape": "round", "diameter": 32}


def test_unreadable_raises():
    with pytest.raises(ValueError):
        base_size.parse("big and round")
