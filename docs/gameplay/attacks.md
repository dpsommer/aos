# Attacks and damage

How attacks are implemented. The source is The Rules, Core Rules 16.0-20.0, 26.0 and 27.0. The code is `AttackSequence`.

## Targets

A unit in combat can only attack units in combat with it. Combat attacks need the target within the attacking model's 3" combat range. Shooting attacks need it within the weapon's Range, and a unit in combat can't shoot unless the weapon has Shoot in Combat. Only models that can reach the target attack. A weapon's attacks go to one target, rather than splitting attacks model by model.

## The attack sequence

Rolled for each attack:

1. **Hit**: a D6 plus modifiers, at or above Hit. An unmodified 1 fails. An unmodified 6 that hits is a critical hit.
2. **Wound**: a D6 plus modifiers, at or above Wound. An unmodified 1 fails.
3. **Save**: a D6 plus modifiers minus Rend. An unmodified 1 fails; at or above Save stops the attack.
4. **Damage**: the Damage characteristic goes into the target's damage pool, rolled per attack if it's random.

Modifiers to hit and wound rolls are capped at +1 and -1. Save rolls are capped at +1, with no limit on what can be subtracted (17.1).

## Weapon abilities

Anti-X (+1 Rend) is cumulative. Charge (+1 Damage) applies if the attacker charged this turn. Crit (2 Hits), Crit (Auto-wound) and Crit (Mortal) act on critical hits; if a weapon has several, the attacker uses Mortal, then Auto-wound, then 2 Hits. Companion ignores friendly abilities except negative modifiers and those that say otherwise, such as All-out Attack.

## Damage

After the ability's effect, for each damaged unit, active player first (18.0): one ward roll per damage point, then the rest are allocated one at a time. Damage points reach Health: a model is slain and the count resets to 0. One count per unit is kept, not one per model (18.2). If the slain model breaks coherency, more are removed, as few as possible (18.3). When the last model goes the rest of the damage has no effect (18.4).

## Characteristics

Random characteristics are generated when needed: Attacks per model when the ATTACK ability is declared, Damage per attack (26.0). Modifiers apply set, then multiply or divide, then add, and results below 1 become 1, except Rend, whose minimum is 0 (27.0). Halves round down.
