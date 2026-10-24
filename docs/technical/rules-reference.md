# Rules reference

The official Warhammer: Age of Sigmar rules are the source of truth for every game mechanic in the simulator. Read the relevant section before implementing or changing a rule, and note the rule's source (document and section) in code comments or gameplay docs where it helps.

## Source documents

Official rules are sourced from [Sigdex](https://sigdex.io/rules), which in turn uses [BSData](https://github.com/BSData/age-of-sigmar-4th).

Faction data (warscrolls, battle traits, enhancements and so on) is extracted from [Wahapedia](https://wahapedia.ru/aos4/) and cross-checked against the "AoS Rules" NotebookLM notebook (`a30c0d6a-8127-4eab-b97e-e457c97a65fc`) and BSData. See [Faction data](faction-data.md).

## Documenting rules

Summaries of how each rule is implemented belong in `docs/gameplay/`. Keep them short, and reference the source document rather than reproducing rules text.
