# Effect data

Abilities in the faction data are rules text. What they do in a battle is written separately, in `data/effects/*.json`, so rebuilding a faction doesn't touch it. An ability with no entry shows as "not supported yet" and can't be used.

## Keys

Each file maps a key to an entry. Files are only for organising: they're all merged.

Key | Ability
-- | --
`core:Run` | A core ability
`spearhead:Ironjawz Bigmob/trait/MIGHTY DESTROYERS` | A Spearhead's battle trait; also `regiment/`, `enhancement/`
`spearhead:Ironjawz Bigmob/megaboss/GET STUCK IN, LADZ` | A Spearhead warscroll's ability
`ironjawz:trait/Mighty Destroyers` | A faction's battle trait or battle formation ability
`ironjawz:enhancement/Armour of Gork` | An enhancement
`ironjawz:lore/Mighty 'Eadbutt` | A spell, prayer or summoning ability
`ironjawz:warscroll/ardboyz/Shield Bash` | A warscroll's ability
`pack:Fire and Jade/card/Raid` | The command on a Spearhead battle tactic card
`battleplan:Into the Fire/Secure the Gateway` | A battleplan's ability
`tactic:Fire and Jade/Raid` | A battle tactic's condition (`tactic:General's Handbook/...` in Matched Play)
`scoring:Score N victory points if you control at least N objective.` | A scoring sentence's shape, its numbers as N

## The hash

Each ability entry has a `hash` of the rules text it was written from. If the text changes, the entry goes stale and its ability counts as not supported until someone checks it. After writing or checking entries:

```sh
python -I tools/effects/stamp_hashes.py          # stamp them
python -I tools/effects/stamp_hashes.py --check  # list stale ones
```

`tools/effects/draft.py <faction id>` drafts entries from common sentence shapes. It doesn't understand conditions, so read every draft against the ability's text before copying it in.

## An entry

```json
"spearhead:Ironjawz Bigmob/megaboss/GET STUCK IN, LADZ": {
	"hash": "…",
	"target": {"side": "friendly", "within": 12, "wholly": true},
	"gate": {"dice": "D6", "at_least": 2},
	"do": [{"op": "modify", "stat": "attacks", "by": 1, "weapons": "melee", "until": "start_next_turn"}]
}
```

Field | Meaning
-- | --
`user` | Who uses it. `from` is `owner` (the default for a warscroll's), `any` (any friendly unit), `reserve` (units in reserve, narrowed by `names`), `parent_user` or `parent_targets` (for a reaction, which also come from its "Used By" line). With `keywords`, `when` and `within_parent_user`. No user and no owner means the player does.
`target` | Who it can target: `side`, `within` and `wholly` (of the user), `keywords`, `not_keywords`, `others`, `when`, `closest`, `lower_health_than_user`, and `count` (a number or "all").
`declare` | Ops resolved before reactions.
`roll` | A roll made at declare: `name` and `dice`. Reactions can change it.
`gate` | A roll after reactions: `dice` and `at_least`. Below it, the `do` ops don't happen. Its value is roll `gate`.
`do` | Ops resolved as the effect.
`passive` | Modifiers it always gives its unit, or the whole army if it has no unit.
`trigger` | Ops that run on an event: `event`, `roll`, `at_least`, `when`, `do`. They can't ask anything.
`once_per_parent` | A reaction that can only be used once for each ability it reacts to.
`starts_in_reserve` | On a Spearhead's battle trait: the names of its units that aren't set up in deployment.

An ability's timing, frequency, keywords, command point cost and casting or chanting value come from the rules data, not here. A reaction's trigger comes from its timing; anything the timing grammar doesn't read, such as a range, goes in `user`.

## Ops

Every op can have `if_roll` or `unless_roll` ({"name", "at_least"}). `to` says who it acts on: `target` (the default, or the user if there are no targets), `user`, `parent_user`, `parent_targets`, or `friendly` narrowed by `within` and `wholly`.

Op | Does | Fields
-- | -- | --
`modify`, `grant` | Gives a `Modifier` | See below, and `of_parent` for one that lasts until the parent ability resolves
`mortal` | Mortal damage | `amount` (dice, or `gate`), `per_model_within`, `on`, `roll_stat`, `amount_against`, `bonus_against`, `unless_flag`
`heal` | Heal (N) | `amount`
`return_models` | Returns slain models | `amount`
`move` | Asks for a move | `kind` (`normal`, `run`, `retreat`, `charge`, `pile_in`, `free`), `distance` (dice, `move`, `run`, or `roll` with `roll`), `end_in_combat_if_was`, `avoid_new_combat`
`pick_attacks` | Asks for each weapon's target | `type` (`melee`, `shooting`)
`attack` | Resolves attacks | `type`
`setup` | Asks where to set a unit up | `min_enemy_gap`, `near_user`
`summon` | Summons the ability's `summons` manifestation | `min_enemy_gap`, `near_user`
`counter` | Changes a counter, e.g. ritual points | `name`, `by`
`hook` | A rule in `EffectHooks` | `name`, and what it reads

## Modifiers

Field | Meaning
-- | --
`stat`, `by` | Adds to a roll or characteristic: `hit`, `wound`, `save`, `attacks`, `damage`, `rend`, `move`, `control`, `control_score`, `charge`, `charge_dice`, `run`, `casting`, `chanting`, `health`, `ward`, or a named roll such as `shield_bash`. In `do`, `by` can be dice, rolled per unit.
`stat`, `set` | Sets it.
`stat`, `halve` | Halves it.
`grant` | Gives a keyword or weapon ability, e.g. `STRIKE-FIRST`, `FLY`, `Crit (Mortal)`.
`forbid` | Stops: `contest`, `be_shot`, `ward_rolls`, `rend` (ignore Rend), `hit_below_6`.
`permit` | Allows: `charge_after_run`, `shoot_after_run`, `charge_after_retreat`, `shoot_after_retreat`.
`until` | `phase`, `turn`, `round`, `start_next_turn`, `action`, `battle`. Passives have none.
`against` | It changes rolls against its holder, e.g. attacks that target it.
`weapons`, `weapon` | Only `melee` or `ranged` weapons, or the one named.
`when` | Conditions; see below.
`aura` | It reaches others: `side` (`friendly`, `enemy`), `within`, `wholly`, `keywords`, `others`.
`companion` | It affects Companion weapons although it's friendly and positive.

## Conditions

`Predicates` has the whole list. A condition is a name (`charged`), a one-key dictionary (`{"target_has": "HERO"}`) or a combination (`{"any": [...]}`, `{"all": [...]}`, `{"not": ...}`). Conditions are about the "subject": whose roll or characteristic it is. "Holder" is what holds the modifier.

## Coverage

The whole Ironjawz Bigmob is written. The Fire and Jade deck is written except Attack on Two Fronts' Call Reinforcements command, and all its twists. City of Ash's and Sand and Bone's battle tactics are written where they don't need relics or the like; their commands and twists aren't. 7 of the General's Handbook's 18 battle tactics are written; the rest need pre-battle picks or attack tracking the engine doesn't have, so they can't be completed. 33 of the Ironjawz faction's 74 abilities are written; its counters (momentum, Waaagh! tokens), rage dice and the Bossrokk Tower aren't. Some entries leave out a clause, such as Killa Beat's second target or Mad 'Un's repeat. Other factions' armies have core abilities only.

Some battleplan scoring sentences have twists the engine doesn't know, such as "stable" objectives: `ScoringRules.unsupported()` lists them, and they score nothing.
