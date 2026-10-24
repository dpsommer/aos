import os, sys

import pytest

TOOL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIXTURES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")
sys.path.insert(0, TOOL_DIR)

FACTION = "Testers"


@pytest.fixture
def cats():
    """A fresh parse of the hand-written BSData fixture catalogues for each test."""
    import bsdata
    return bsdata.Catalogues(os.path.join(FIXTURES, "bsdata"))


@pytest.fixture
def faction_data(cats):
    """(faction, warscrolls, armies_of_renown) read from the fixture catalogues."""
    import bsdata
    return bsdata.read_faction(cats, FACTION)


def named(items, name):
    """The single item in items called name."""
    matches = [x for x in items if x["name"] == name]
    assert len(matches) == 1, "expected one %r, found %d" % (name, len(matches))
    return matches[0]
