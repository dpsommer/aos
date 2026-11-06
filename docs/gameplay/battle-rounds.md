# Battle rounds

How the battle sequence is implemented. The source is The Rules (Core Rules 11.0-13.1 and 28.0-33.0, Commands 1.0, Battle Tactics 1.0-2.0) and each Spearhead battlepack's battleplan. See [Rules engine](../technical/rules-engine.md) for the code.

## A round

1. **Who goes first** (12.0). In Matched Play, round 1: the player who finished setting up their army first decides. In Spearhead, round 1: the attacker decides. Later rounds: a priority roll-off, whose winner decides; a tie goes to whoever went first in the previous round.
2. **The underdog** (12.0). Whoever has fewer victory points. There's none on a tie.
3. **Command points** (Commands 1.1), Matched Play only: each player gains 4, the underdog 1 more, and unspent points are lost at the end of the round. Spearhead doesn't use command points (it doesn't use the Advanced Rules): its commands are on battle tactic cards.
4. **Spearhead only**: a twist card is drawn and battle tactic hands are filled to 3. A player who seizes the initiative draws none unless they're the underdog and at least 5 points behind.
5. **Start of Battle Round abilities**: the active player's, then their opponent's.
6. **Two turns**, then End of Battle Round abilities. The battle ends after the battleplan's last round: 5 in Matched Play, 4 in Spearhead.

## A turn

Seven phases (13.0): Start of Turn, Hero, Movement, Shooting, Charge, Combat, End of Turn. In each, the active player uses "Your" and "Any" abilities in any order, then their opponent uses "Enemy" and "Any" ones. A phase nobody can act in passes straight away.

In the combat phase (13.1), non-FIGHT abilities come first, then the players alternate picking a unit to fight, starting with the active player. Each unit in combat or that charged must fight if it can. STRIKE-FIRST units must fight before others, and STRIKE-LAST after them (19.0). STRIKE-FIRST has no effect on a unit that wasn't in combat at the start of the phase.

At the end of a turn (31.0): End of Turn abilities, then objective control, then the active player scores.

## Using an ability

Declare, then reactions (the user's player first, alternating until both pass in a row), then the effect (5.2). Rules of One (5.3): a unit uses 1 CORE ability per phase and each ability once per phase; a unit gets the same passive once at a time. Once Per limits apply per unit, or per player or army as the ability says (28.2). Each unit uses 1 command per phase, and each command is used once per army per phase (Commands 1.2).

Simplifications:

- A player only gets a reaction prompt when they have a reaction they can use.
- The simulator doesn't ask about a unit's slain models or which objective a unit that contests several counts for. The models furthest from the enemy that keep the unit coherent are slain, and a unit contests the nearest objective.

## Objectives

Objective control is worked out at the start of the first round and at the end of each turn (32.2): each player totals the Control of their models contesting it; a higher total gains control, which lasts until the opponent gains it. Each unit contests one objective at a time. A model contests a Matched Play objective within its 3" control zone, and a Spearhead objective when its base is on it. Terrain control works the same way but doesn't last (32.3).

## Victory

- **Matched Play** (General's Handbook, Glorious Victory): 5 or more points ahead is a major victory, fewer is a minor one. A tie goes to whoever completed more battle tactics, as a minor victory, otherwise it's a draw.
- **Spearhead**: most points wins; a tie is a draw.

## Terrain

The simulator has no terrain height, so visibility is not blocked by height, and models can stand on battlefield terrain as in deployment. Cover and Obscuring use each feature's footprint: a unit is behind a feature when every line between the attacker's and target's models crosses it (Terrain 1.1), ignoring the part within the attacker's combat range.
