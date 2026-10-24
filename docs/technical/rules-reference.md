# Rules reference

The official Warhammer: Age of Sigmar rules are the source of truth for every game mechanic in the simulator. Read the relevant section before implementing or changing a rule, and note the rule's source (document and section) in code comments or gameplay docs where it helps.

## Source documents

The PDFs live in `reference/`, which is gitignored; each developer keeps a local copy.

**Document** | **File** | **Use for**
-- | -- | --
Core rules (Apr 2025) | `eng_aos_core&key_the-rules_apr25-*.pdf` | All core mechanics: battle rounds, phases, movement, combat, abilities, objectives
Quickstart guide | `ageofsigmar_corerules&keydownloads_quickstartguide_*.pdf` | Introductory overview; the core rules take precedence where they differ
Battle profiles | `eng_23-09_aos_core&key_battle_profiles-*.pdf` | Unit points, unit sizes and regiment options for army building

When a newer version of a document is released, replace the old file and update this table.

## Documenting rules

Summaries of how each rule is implemented belong in `docs/gameplay/`. Keep them short, and reference the source document rather than reproducing rules text.
