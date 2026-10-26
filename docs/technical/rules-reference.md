# Rules reference

The official Warhammer: Age of Sigmar rules are the source of truth for every game mechanic in the simulator. Read the relevant section before implementing or changing a rule, and note the rule's source (document and section) in code comments or gameplay docs where it helps.

## Source documents

Official rules are sourced from [Sigdex](https://sigdex.io/rules), which in turn uses [BSData](https://github.com/BSData/age-of-sigmar-4th).

Faction data (warscrolls, battle traits, enhancements and so on) is built from BSData first. [Wahapedia](https://wahapedia.ru/aos4/) supplies what BSData lacks (Spearhead, Path to Glory, regiment options, unit composition, Army of Renown descriptions). Disagreements between them are reported at build time; the "AoS Rules" NotebookLM notebook (`a30c0d6a-8127-4eab-b97e-e457c97a65fc`) helps settle them. Legends warscrolls follow the "AoS Legends" NotebookLM notebook (`69365d24-6043-4353-bb04-2b0d3ecca253`), which is the source of truth for them. See [Faction data](faction-data.md).

Games Workshop's [Rules Updates](https://assets.warhammer-community.com/eng_23-09_aos_core&key_rule_updates-eu6fu82jl3-dlyuiignte.pdf) PDF (September 2026) collects errata and FAQs for every book. Its errata should be reflected in the faction data, and its FAQ rulings are summarised per faction in [Faction FAQs](../gameplay/faq/README.md).

## Documenting rules

Summaries of how each rule is implemented belong in `docs/gameplay/`. Keep them short, and reference the source document rather than reproducing rules text.
