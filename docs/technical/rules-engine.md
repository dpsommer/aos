# Rules engine

The rules engine runs a battle from the end of deployment to its result. It lives in `scripts/battle/rules/`, has no nodes and no `await`, and can play a whole battle headless. How the tabletop rules map onto it is in [Battle rounds](../gameplay/battle-rounds.md) and [Attacks](../gameplay/attacks.md). What abilities do is data: see [Effect data](effect-data.md).

## Layers

```text
BattleMapController (Node: board, input, HUD; reads the event log)
      |  next_decision() / answer()
GameController ---- GameState, BattleRules, UsageLedger, EventBus, StatResolver, AttackRules, ObjectiveControl
      |  a stack of GameFrames
BattleSequence > PhaseController > ActionFrame > ReactionFrame > ActionFrame ...
      |  Action -> Effects -> Commands
UnitController / TerrainController
      |  each has
CharacteristicsController + ModifierController
```

Folder | What's in it
-- | --
`game/` | `GameController`, `GameState`, `BattleSequence`, `BattleRules` and its Matched Play and Spearhead versions, scoring, battle tactics, twists, objectives, events, the usage ledger, geometry
`phases/` | `PhaseController` and one subclass per phase that needs it
`units/` | `UnitController`, `TerrainController`, characteristics, modifiers, predicates, commands, movement rules
`actions/` | `Action`, `ActionFrame`, `ReactionFrame`, `AbilityBook`, `AbilityTiming`, `AttackRules`
`effects/` | `Effect` and its ops, `EffectCatalog`, `EffectHooks`
`decisions/` | `DecisionRequest`, `Decision`, `Participant`
`ai/` | `AiParticipant`

"Controller" here means a node-free rules class, except `BattleMapController` and `DeploymentController`, which are the nodes on the map.

## The decision loop

`GameController.next_decision()` runs the stack of `GameFrame`s until someone has to choose, and returns a `DecisionRequest`, or null when the battle is over. `answer(decision)` gives the top frame the answer and returns an error string, empty on success. Each frame holds its own progress, so nothing in the rules waits on anything. Headless:

```gdscript
var request := game.next_decision()
while request:
	game.answer(ai.decide(request, game))
	request = game.next_decision()
```

On the map, `BattleMapController` hands each request to the army's `Participant`: `AiParticipant` answers on a timer, and `PlayerParticipant` waits for the `TurnHud` and the board. A request holds everything needed to choose, so the two answer it in the same way.

Rng is injected and every answer is logged in `GameController.answers`, so two battles from the same seed and answers have the same event log. A later save could store seed, setup and answers and replay them. There's no saving yet.

Call `GameController.dispose()` when finished with a game: controllers and listeners point back at it.

## Using an ability

`AbilityBook` gathers what an army has, each as an `AbilityEntry` with its effect data and parsed `AbilityTiming`. `GameController.options_in()` picks what's usable now, and `reason_unavailable()` says why not; that's what the HUD and AI go by. `UsageLedger` is the only place that knows about once-per limits and the Rules of One.

An `ActionFrame` then resolves it (Core Rules 5.2): declare (targets, Declare effects, rolls, and casting or chanting rolls), a `ReactionFrame`, the gate roll, the effects, then the damage sequence.

## Commands and events

Effects change state only by sending a command from `Commands` through `GameController.command(unit, command)`, which calls the target's `handle()`. `UnitController` is the only thing that changes a unit's state; `BattleUnit` stays the geometry the map draws. Terrain has the same base class, so effects don't care what they target. A faction terrain feature fights as a stand-in `BattleUnit` (`TerrainController.proxy`).

`EventBus.publish()` logs an event and queues it. The queue waits for the current command to finish, so a listener can never re-enter what's being resolved: a `MODEL_SLAIN` listener can't change a unit in the middle of allocating damage. Controllers listen to reset their turn flags (`UnitController`) and expire modifiers (`ModifierController`). The map reads the log through a cursor, which is what keeps animation out of the rules.

## Characteristics, buffs and debuffs

`CharacteristicsController` holds base values as `DiceExpr`, as Move and Attacks may be random. `ModifierController` holds `Modifier`s and expires them. Neither knows what holds it. `StatResolver` answers the questions: it looks through every holder for modifiers of the stat that apply, so an aura doesn't need attaching and detaching as its source moves.

A `Modifier` lives on its holder, with a selector for weapons rather than on the `Weapon`, a Resource shared by both mirrored armies. Conditions are the closed list in `Predicates`. Cover is simply a terrain's modifier with a condition.

## Adding things

- **A way of playing:** subclass `BattleRules`.
- **A phase's special order:** subclass `PhaseController`, as `CombatPhaseController` does, and add it to `PhaseController.for_window()`.
- **What an ability does:** [Effect data](effect-data.md).

## What's simplified or missing

- Each weapon's attacks go to one target, rather than splitting them model by model.
- Slain models and contested objectives are picked by a rule rather than asked: see [Battle rounds](../gameplay/battle-rounds.md).
- A prayer that can be answered is, and one that can't banks its roll.
- Models move in straight lines, with no path around things.
- Champions, musicians and standard bearers aren't modelled, nor are weapon options: units have every weapon on their warscroll.
- Faction terrain has no shape beyond its base, and battlefield terrain none beyond its footprint.
- Without the [effect data](effect-data.md), an ability shows as "not supported yet" and does nothing.
