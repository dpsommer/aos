# Quick Play

Quick Play sets up a battle against an AI opponent: the player picks a game mode, then an army and a battleplan. The design is the "Quick Play Flow" canvas artifact. Play opens the [loading screen and game map](battle.md).

Both screens are laid out for the design's 1440 × 900 and styled by `UITheme` (see [Forge](forge.md#look)). Their header has Back, which names where it goes, and the breadcrumb "Quick Play › Game mode › Army". Esc does the same as Back.

## Game mode

Scene `scenes/ui/quick_play/game_mode_screen.tscn`, script `scripts/ui/quick_play/game_mode_screen.gd` (`GameModeScreen`). "Choose a game mode" over a card for each mode, each with its icon in white on placeholder stripes, its name, a description and chips:
- **Spearhead** (the icon pack's spear): small, fixed forces from each faction's Spearhead box. Chips count the Spearheads (`GameModeScreen.shown_spearheads()`: every faction's, from `FactionCatalog.spearheads()`, without Legends factions' unless Settings shows them) and say "Fixed rosters".
- **Matched Play** (the pack's frenzied): an army built in the Forge. Chips say "Your Forge armies" and name the General's Handbook battlepack in gold.

Pressing a card emits `mode_chosen`. Spearhead's card is focused when the screen opens, or the mode the player chose before going back.

## Army

Scene `scenes/ui/quick_play/army_select.tscn`, script `scripts/ui/quick_play/army_select.gd` (`ArmySelect`), for either mode. The breadcrumb names the mode.

- **Header:** after the breadcrumb, a box with the points limit (the army's, or "Fixed roster" for a Spearhead) and the rules, in gold ("General's Handbook 2026-27" or "Spearhead"), then **Play**, as tall as that box: large and gold, with a slight glow, once the army can play; otherwise dark and disabled, its tooltip saying why (`ArmySelect.play_blocker()`), e.g. "Fix this army's problems to play".
- **Left pane (460 px, the same width as the Forge army builder's left pane):** the list of armies. It gives way to one of these, each with a Back button ("Armies" or "Spearheads") that returns to the list and gives focus back to the control that opened it:
  - a unit's warscroll (`WarscrollCard`), from a portrait;
  - a Regiment of Renown's units and rules (`RulesView.regiment_of_renown()`), from its units' portraits;
  - the battleplans (`BattleplanPicker`, or `RealmPicker` in Spearhead), from the battle plan card.

  Esc goes back to the list from these, and from the list goes back to the game mode.
- **Detail:** the chosen army, scrolling on its own. Its top row has the army's name and details, with the **battle plan card** on the right: "Random" (picked when the battle starts), with a white monster icon (`fighters/gargantuan`, as on the battleplan picker's Random card), or the chosen battleplan's name, with its map (`BattleplanMap`) in the icon's place. The icon or map fills a 64 × 48 box, and the card stays the same size whichever is chosen. It's outlined in gold while the battleplans are open.

### Matched Play

- **Your armies:** the saved armies, most recently saved first (`ArmyStore`), each a card with the faction's icon, the army's name, its faction with its Army of Renown or battle formation, and its points against its limit with when it was saved (`ArmySelect.saved_when()`: "saved today", "saved yesterday", "saved 3 days ago", "saved last week", "saved 3 weeks ago" or "saved on 2 Mar 2026"). Pressing a card chooses the army; the most recent one that can be chosen starts chosen.
  - An army with problems has a red "!" badge whose tooltip lists them.
  - **Edit** (pencil) emits `edit_requested`; `Main` opens the army in the builder, whose Back returns here with the army chosen.
  - Unreadable armies, and armies whose faction has no data, are listed but disabled, with the reason.
  - With no saved armies, a placeholder offers **Open the Forge** (`forge_requested`).
- **Detail:**
  - the name with a status pill ("Army valid", "N problems" or "Constraints overridden"), its faction and Army of Renown or formation, and its points; then its problems, if any, in a red box;
  - **Army:** each regiment in a box with its name (and a Regiment of Renown chip), unit count and points, then its units' 112 px portraits (a render of the unit's model, found by its warscroll's name even if the player renamed it, or its initials if it has no model): the General's crown, the model count, the unit's name, and "General", its enhancements and points under it. Auxiliary units follow in their own box;
  - **Faction Terrain:** the army's terrain feature's portrait;
  - **Battle Tactics**, a short `TacticCard` per slot, or a dashed "No battle tactics card in slot 2"; beside them **Lores**, a short `LoreCard` per lore, or a dashed "No spell lore" etc. Tactics cards and lores have an eye that shows them in full in place, keeping focus on the eye.
- **Play:** enabled when the army has no problems, or overrides its constraints.

### Spearhead

- **Spearheads:** every Spearhead shown on the game mode screen, grouped by Grand Alliance, each with its faction's icon, name, faction and unit count (its general included). A search box above filters them by Spearhead, faction or Grand Alliance name; Esc in it clears it. The first Spearhead starts chosen.
- **Detail:**
  - the name, its faction, Grand Alliance and general;
  - **Army:** portraits of the general and each unit, with model counts; each shows the Spearhead's own warscroll;
  - **Battle Traits**, two to a row, each foldable by a chevron beside its name (`AbilityCard.make_foldable()`), all starting folded;
  - below them, two columns: **Regiment Abilities** and **Enhancements**, read-only: each is an [ability card](abilities.md), foldable by its chevron, all starting folded. Each column's heading has a "Picked later" chip, as the attacker and then the defender pick them after the roll-off (see [Battle](battle.md#regiment-ability-and-enhancement-spearhead)).
- **Battle plan:** each Spearhead battlepack has one battleplan, fought on whichever side of its realm battlefield the defender chooses after the roll-off, so the card chooses a battlepack: Random, Fire and Jade, Sand and Bone or City of Ash (see [Realm battlefields](#realm-battlefields)). It shows "Random" or the battlepack's name over its sides, e.g. "Fire and Jade" over "Aqshy or Ghyran: the defender picks", with its first side's map (`RealmMap`) in the icon's place, as in Matched Play.
- **Play:** enabled once a Spearhead is chosen.

### Battleplans

`BattleplanPicker` (`scripts/ui/quick_play/battleplan_picker.gd`) lists, under "Choose battle plan" and a key to the map colours (Attacker red, Defender blue):
- **Random:** "One of the 12 battleplans below, picked when the battle starts."
- each battleplan, in the battlepack's order: a small map, its name, and its twist cut to two lines. The battlepack's tables and numbers aren't shown, as they're for rolling a battleplan on the tabletop.

The chosen card is outlined in gold with a check. An eye shows a battleplan in full, swapped in place: a map the width of the pane with its terrain, a caption ("60" × 44" · dashed: terrain · gold rings: objectives with their 3" control zone"), its setup, twist, abilities as [ability cards](abilities.md) and scoring. Pressing a card chooses it and returns to the list.

`BattleplanMap` (`scripts/ui/quick_play/battleplan_map.gd`) draws a map from the battleplan's data: territories, objectives as gold rings and, on a detailed map, terrain as dashed squares (4" small, 6" medium, `MapFeature.TERRAIN_WIDTHS`) and each objective's 3" control zone. A `neutral` map shades both territories grey, as the loading screen does before the roll-off.

### Realm battlefields

`RealmPicker` (`scripts/ui/quick_play/realm_picker.gd`) is Spearhead's battleplan picker, under "Choose battle plan" (no colour key, as the defender chooses which territory is whose). It lists the Spearhead battlepacks from the game data (see [Core rules data](../technical/core-rules-data.md#spearhead-battlepacks)):
- **Random:** "One of the 3 realm battlefields below, picked when the battle starts."
- a card for each battlepack's realm battlefield (Fire and Jade, Sand and Bone, City of Ash): a small map of each of its sides, its name, and its sides ("Sides: Aqshy or Ghyran · the defender picks one").

The chosen card is outlined in gold with a check. An eye shows a battlepack in full, swapped in place: for each side, its name, a map the width of the pane with the objectives named, a caption ("30" × 22" · gold: objectives, contested by models on them", plus roads and pre-set terrain where the side has them), its starting relics as [ability cards](abilities.md) and its twist deck; then the deployment maps ("The defender picks the side, a map and which territory is theirs."), the battleplan's pre-battle sequence as Setup and the scoring. Pressing a card chooses it and returns to the list. The side, deployment map, terrain, regiment abilities and enhancements are all pre-battle choices, made after the roll-off.

`RealmMap` (`scripts/ui/quick_play/realm_map.gd`) draws a side from its data: roads in grey, objectives as gold circles (each its battlepack's radius or its own) or rotated rectangles, and terrain set up before the players' (Ossia's Crypt of Blood) as a dashed square. Given a deployment map, it shades territory A lighter than B with a line between them, and writes "A" and "B" in the middle of each. A detailed map names the objectives.

## Choices

`BattleSetup` (`scripts/battle/battle_setup.gd`) holds what the player chose: the mode, the Forge army or the Spearhead (its faction and name), and the battleplan: in Matched Play its name (`battleplan`), in Spearhead the battlepack's name (`battlepack`), each empty for Random. `ArmySelect.setup()` builds it. `BattleSetup` can also name a Spearhead regiment ability, enhancement and side (`regiment_ability`, `enhancement`, `realm`), which the battle then starts with, but Quick Play leaves them to the pre-battle choices.

## Signals

**Signal** | **When**
-- | --
`MainMenu.quick_play_pressed` | `Main` opens the game mode screen.
`GameModeScreen.back_pressed` | Back or Esc. `Main` returns to the main menu.
`GameModeScreen.mode_chosen(mode)` | The player pressed a mode's card. `Main` opens the army step for it.
`ArmySelect.back_pressed` | Back, or Esc on the list. `Main` returns to the game mode, focusing the mode's card.
`ArmySelect.edit_requested(army)` | The player pressed an army's Edit. `Main` opens the army builder; its Back returns to the army step.
`ArmySelect.forge_requested` | The player has no armies and pressed Open the Forge. `Main` opens the Forge.
`ArmySelect.play_requested(setup)` | The player pressed Play. `Main` opens the loading screen (see [Battle](battle.md)).
