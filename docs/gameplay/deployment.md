# Deployment

How the pre-battle roll-off and the deployment phase are run. The rules are the Core Rules' universal deployment abilities ('Deploy Faction Terrain', 'Deploy Unit', 'Deploy Regiment' in `data/core/abilities.json`) and, for Spearhead, each battlepack's Pre-battle Sequence and Deployment sections (`data/core/spearhead/*.json`). The screens are in [Battle](../design/battle.md).

The code is in `scripts/battle/deployment/`. Everything but `DeploymentController` is plain rules with no nodes.

## Roll-off

`RollOff.roll(rng)`: each player rolls a dice, and a tie is rolled again. The winner picks attacker or defender. The AI picks at random for now.

- **Matched Play:** `Battle.assign_roles()` gives the attacker the battleplan's attacker territory and the defender the other.
- **Spearhead:** `assign_roles()` gives the defender terrain group A (or every non-mystical feature) and the attacker group B. The attacker then picks its regiment ability and enhancement, then the defender (`BattleArmy.choose_spearhead_options()`, which fills its deployment abilities in again). The defender then picks the side of the realm battlefield (`Battle.choose_realm()`), the deployment map and which territory is theirs (`Battle.choose_deployment()`). The player picks on `SpearheadOptionsPicker` and `DeploymentMapPicker`; the AI picks at random.

`BattleBuilder` leaves the roles, the territories, and in Spearhead the regiment abilities, enhancements, side and deployment map unset for these steps.

## Steps

`Deployment` runs the phase for both armies.

**Matched Play** has three steps, each starting with the attacker:

1. **Faction terrain:** abilities with DEPLOY TERRAIN.
2. **Armies:** abilities with DEPLOY.
3. **Abilities:** every other ability with the "Deployment Phase" timing.

The sides alternate. When one side has nothing left to do in a step, the other keeps going until it's done too. The next step then starts. A step neither side has anything to do in is skipped.

**Spearhead** runs the same steps in a different order:

1. **Terrain:** the defender sets up all its terrain features, then the attacker.
2. **Armies:** the attacker sets up its whole army, then the defender. The player's army is set out automatically and confirmed in one go (`Deployment.place_army()`): every unit is checked against the rules and against the others, and they're deployed together (see [Battle](../design/battle.md#deployment)). The AI still sets up unit by unit.
3. **Abilities:** these alternate from the attacker, as in Matched Play.

A side has something left to do when:

- **Terrain:** it has terrain features not yet set up.
- **Armies:** it has units not yet deployed.
- **Abilities:** it has an ability it hasn't used and hasn't pressed Done.

## Where things can go

`DeploymentRules` does the geometry. Positions are in inches.

- **Units, Matched Play:** each base is wholly within friendly territory and more than 9" from enemy territory.
- **Units, Spearhead:** the same, with 6" instead of 9".
- **The deployable zone:** `DeploymentRules.zone()` is friendly territory less everything within that distance of enemy territory. A base whose outline is wholly inside the zone meets both conditions. The part of the player's territory outside the zone is shaded on the board, labelled "Within 9" of enemy territory"; in the terrain step the shading shows where terrain can't go instead, unlabelled: outside `DeploymentRules.terrain_zone()`, and within the gap from terrain features already set up (`DeploymentRules.terrain_keep_out()`: 6" in Spearhead, 3" in Matched Play), redrawn as each feature is set up.
- **Faction terrain, Matched Play:** wholly within friendly territory, and more than 3" from every objective (measured to the 40mm marker) and every other terrain feature.
- **Spearhead terrain:** wholly within friendly territory, more than 6" from other terrain features, more than 3" from the long battlefield edges and from enemy territory, and not on an objective. City of Ash's own rule (on a corner of a rectangular objective) isn't checked yet. Each feature is a rectangle, its size from the battlepack data (see [Core rules data](../technical/core-rules-data.md)).
- **No room for the terrain gap:** if no spot left anywhere meets the gap from other terrain features (`Deployment.is_cramped()`), the gap is waived for that feature, which then only has to keep clear of other terrain. It can happen on a Sand and Bone Diagonal map round the Crypt of Blood. Without it the player couldn't set the feature up at all.
- **Overlaps:** models can't overlap other deployed models or faction terrain. They can stand in and on the battlefield's own terrain, as its shape isn't modelled yet.
- **Base outlines:** round and oval bases are ellipses, with the long side along the way the model faces. A "Use model" model is a rectangle.

### Coherency

`Coherency` checks the Core Rules' unit coherency, measured edge to edge between bases:

- In a unit of up to 6 models, each model is within ½" of at least 1 other model of the unit.
- In a unit of 7 or more, each model is within ½" of at least 2 others.
- The unit is a single group.

A unit can't be set up while it's out of coherency.

### Formations

The player lines a unit up by dragging (see [Battle](../design/battle.md#deployment)). `Formations.spread()` stands it in ranks facing left of the drag, the front rank running from where the drag started, as wide as the drag:

- It picks the widest layout whose front rank, close-packed, fits the drag: a deep column for a short drag, more models across and fewer ranks behind for a longer one. Only layouts in coherency are used; a single column, for instance, isn't coherent in a unit of 7 or more.
- It then opens the gaps up to fill the drag, to just under ½".
- The widest it goes is a line: one rank with gaps just under ½". In a unit of 7 or more, each model needs two neighbours, so the two end models are tucked in behind the models next to them.
- A unit with bases of different sizes (e.g. Wildercorps Hunters) is laid out the same way with each model's own base: the biggest bases in the front rank, each rank behind centred on the one in front and set back until it's clear of it, and a part-filled last rank nestled between the models in front. The layouts in coherency are worked out once per mix of bases.

Automatic placement (the AI's, and setting out a Spearhead army) uses `Formations.arrange()`, which lays a unit out in one of five shapes. Each is coherent for bases of one size.

**Formation** | **Shape**
-- | --
Line | One rank. From 7 models it becomes two staggered rows, so the end models have two neighbours.
Wide block | Two ranks.
Narrow block | Four ranks.
Loose | Ranks with gaps just under ½".
Wedge | Rows of 1, 2, 3 and so on, with the point towards the enemy.

A unit with bases of different sizes (Wildercorps Hunters: 40mm, 28.5mm and 25mm) is laid out in the shape for a base of their average size. Each model after the first is then set ¼" from one or two models already down (two in a unit of 7 or more), as near its place in the shape as it will go without overlapping. So the unit is coherent however its bases differ.

## Abilities

`DeploymentAbilities` collects each army's deployment abilities, as `DeploymentAbility`s:

- **Matched Play:** the universal ones, then its battle traits (its Army of Renown's instead, if it has one), its battle formation's abilities, its Regiments of Renown's abilities (tied to that regiment), its enhancements' abilities and its warscroll abilities (each tied to its unit).
- **Spearhead:** 'Deploy Unit', its battle traits, the regiment ability and enhancement it picked after the roll-off, and its warscroll abilities.

**Kind** | **Which abilities** | **What using it does**
-- | -- | --
Deploy Unit | The universal ability | Sets up one unit.
Deploy Regiment | The universal ability | Starts a regiment: the same side keeps deploying, only that regiment's units, until all of it is down. The player's regiment is set out whole and confirmed in one go (`Deployment.place_army()`, which then needs every unit of it left); the AI still sets it up unit by unit.
Deploy Faction Terrain | The universal ability | Sets up one faction terrain feature.
Reserve | A DEPLOY ability whose effect says "in reserve" | Sets its targets up in a named reserve, e.g. "in the clouds", taken from the effect. They count as deployed.
Record | Every other "Deployment Phase" ability | Records its use, and its target if one was picked. Its effect isn't applied yet.
Not supported | Any other DEPLOY or DEPLOY TERRAIN ability, e.g. 'Rise from the Depths' | Shown, but can't be used.

**Reserve targets:**

- A warscroll ability that says "this unit" targets its own unit.
- A Regiment of Renown's ability targets that regiment's units. It can't be used once any of them is deployed.
- Any other reserve ability lets the player pick any undeployed units. The keyword limits in its declare text aren't checked yet.

**Regiments:** once a unit of a regiment is set up by anything but 'Deploy Regiment' (with 'Deploy Unit' or a reserve ability), 'Deploy Regiment' can't be used for that regiment any more. The rest of it is deployed unit by unit.

**How often:**

- Each ability is used once in the phase (Core Rules).
- "Once Per Battle (Army)" abilities are used once for the whole army, whichever unit has them.
- The universal deployment abilities can be used as often as there's something to deploy.

## The AI

`MirrorDeployer` stands in for a deployment AI. The AI's army is a mirror of the player's (`BattleArmy.mirror()`), so each unit, regiment and terrain feature has a counterpart at the same index. An ability's counterpart is the AI's ability with the same name and source, on the counterpart unit or regiment; a Spearhead regiment ability or enhancement the AI didn't pick has none, so it isn't mirrored.

On its turn the AI repeats the earliest action of the player's it hasn't matched yet. Positions are reflected through the middle of the battlefield and facings turned round. Battleplan and Spearhead territories are point-symmetric, so a legal placement stays legal. It mirrors 'Deploy Regiment', reserves and recorded abilities too.

When it can't mirror, it sets up automatically with `PlaceholderDeployment.spot_for_unit()` and `spot_for_terrain()`. In Spearhead it plans its whole army at once with `spots_for_army()` (see below) and sets the units up from that plan. That happens when there's nothing to copy yet (it's the attacker), or when the reflected spot isn't allowed. In the Abilities step with nothing to copy, it presses Done.

**Setting out a whole army** (`PlaceholderDeployment.spots_for_army()`, used for the player's Spearhead army and the AI's): the biggest units go first, each in a coherent formation. It first spreads them out as `spot_for_unit()` does: from the back rank, middle out, 1" apart and clear of terrain. If any unit doesn't fit, it packs them all in instead:

- Spots are tried from one end of the back rank to the other, on a ¼" grid.
- Units are ½" apart, or closer if they must be.
- Bases are checked by their real shape, not as circles, so ovals pack closer.
- Models may stand in the battlefield's terrain, as the rules allow, but not in faction terrain.

Every Spearhead's army fits this way on every realm battlefield, deployment map and side.

`spot_for_terrain()` spreads features out. It picks the legal spot with the most room from other terrain (the first one into a corner, away from the territory's middle), trying 8 turns of the feature. If the army has another feature to set up, it only takes a spot that leaves a legal one for that too. Every placement it makes follows the rules, including the waived gap above.

If nowhere is legal, which can happen in Spearhead's Diagonal territories, it sets the unit or feature up anyway, as near the rules as it can, rather than stall the phase.
