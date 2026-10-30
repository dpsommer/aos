# Quick Play

Quick Play sets up a battle against an AI opponent: the player picks a game mode, then an army and a battleplan. The design is the "Quick Play Flow" canvas artifact. There's no battle screen yet, so Play hands its choices on and nothing more happens (see [Signals](#signals)).

Both screens are laid out for the design's 1440 × 900 and styled by `UITheme` (see [Forge](forge.md#look)). Their header has Back, which names where it goes, and the breadcrumb "Quick Play › Game mode › Army". Esc does the same as Back.

## Game mode

Scene `scenes/ui/quick_play/game_mode_screen.tscn`, script `scripts/ui/quick_play/game_mode_screen.gd` (`GameModeScreen`). "Choose a game mode" over a card for each mode, each with its icon in white on placeholder stripes, its name, a description and chips:
- **Spearhead** (the icon pack's spear): small, fixed forces from each faction's Spearhead box. Chips count the Spearheads (`GameModeScreen.shown_spearheads()`: every faction's, from `FactionCatalog.spearheads()`, without Legends factions' unless Settings shows them) and say "Fixed rosters".
- **Matched Play** (the pack's frenzied): an army built in the Forge. Chips say "Your Forge armies" and name the General's Handbook battlepack in gold.

Pressing a card emits `mode_chosen`. Spearhead's card is focused when the screen opens, or the mode the player chose before going back.

## Army

Scene `scenes/ui/quick_play/army_select.tscn`, script `scripts/ui/quick_play/army_select.gd` (`ArmySelect`), for either mode. The breadcrumb names the mode.

- **Header:** after the breadcrumb, a box with the points limit (the army's, or "Fixed roster" for a Spearhead) and the rules ("General's Handbook 2026-27" or "Spearhead"), then **Play**: large and gold, with a slight glow, once the army can play; otherwise dark and disabled, its tooltip saying why (`ArmySelect.play_blocker()`), e.g. "Fix this army's problems to play".
- **Left pane (460 px, the same width as the Forge army builder's left pane):** the list of armies. It gives way to one of these, each with a Back button ("Armies" or "Spearheads") that returns to the list and gives focus back to the control that opened it:
  - a unit's warscroll (`WarscrollCard`), from a portrait;
  - a Regiment of Renown's units and rules (`RulesView.regiment_of_renown()`), from its units' portraits;
  - the battleplans (`BattleplanPicker`), from the battle plan card.

  Esc goes back to the list from these, and from the list goes back to the game mode.
- **Detail:** the chosen army, scrolling on its own. Its top row has the army's name and details, with the **battle plan card** on the right: "Random" (picked when the battle starts) or the chosen battleplan with its table and number. It's outlined in gold while the battleplans are open.

### Matched Play

- **Your armies:** the saved armies, most recently saved first (`ArmyStore`), each a card with the faction's icon, the army's name, its faction with its Army of Renown or battle formation, and its points against its limit with when it was saved (`ArmySelect.saved_when()`: "saved today", "saved yesterday", "saved 3 days ago", "saved last week", "saved 3 weeks ago" or "saved on 2 Mar 2026"). Pressing a card chooses the army; the most recent one that can be chosen starts chosen.
  - An army with problems has a red "!" badge whose tooltip lists them.
  - **Edit** (pencil) emits `edit_requested`; `Main` opens the army in the builder, whose Back returns here with the army chosen.
  - Unreadable armies, and armies whose faction has no data, are listed but disabled, with the reason.
  - With no saved armies, a placeholder offers **Open the Forge** (`forge_requested`).
- **Detail:**
  - the name with a status pill ("Army valid", "N problems" or "Constraints overridden"), its faction and Army of Renown or formation, and its points; then its problems, if any, in a red box;
  - **Battle Traits** (the Army of Renown's, else the faction's), two to a row, each foldable by a chevron beside its name (`AbilityCard.make_foldable()`); the first starts unfolded;
  - **Battle Formation** as a short `FormationCard`;
  - **Battle Tactics**, a short `TacticCard` per slot, or a dashed "No battle tactics card in slot 2"; beside them **Lores**, a short `LoreCard` per lore, or a dashed "No spell lore" etc. Formations, tactics cards and lores have an eye that shows them in full in place, keeping focus on the eye;
  - **Army:** each regiment in a box with its name (and a Regiment of Renown chip), unit count and points, then its units' 112 px portraits: the General's crown, the model count, the unit's name, and "General", its enhancements and points under it. Auxiliary units follow in their own box;
  - **Faction Terrain:** the army's terrain feature's portrait.
- **Play:** enabled when the army has no problems, or overrides its constraints.

### Spearhead

- **Spearheads:** every Spearhead shown on the game mode screen, grouped by Grand Alliance, each with its faction's icon, name, faction and unit count (its general included). A search box above filters them by Spearhead or faction name; Esc in it clears it. The first Spearhead starts chosen.
- **Detail:**
  - the name, its faction, Grand Alliance and general, and a pill: "Choose a regiment ability and an enhancement to play", until both are chosen, then "Ready to play";
  - **Battle Traits** (foldable, two to a row, as in Matched Play);
  - below them, two columns: **Regiment Abilities** and **Enhancements**. Each choice is an [ability choice card](abilities.md#choosing-an-ability), as in the Forge's enhancement options. Pressing a card chooses it; pressing the chosen card unchooses it. Each column's heading has a chip, "Choose 1" or "Chosen";
  - **Army:** portraits of the general and each unit, with model counts; each shows the Spearhead's own warscroll.
- **Battle plan:** the card is disabled, so a Spearhead battle always uses Random. The Spearhead battlepacks are in the game data (see [Core rules data](../technical/core-rules-data.md#spearhead-battlepacks)), but the picker only shows the General's Handbook's battleplans.
- **Play:** enabled once a regiment ability and an enhancement are chosen.

### Battleplans

`BattleplanPicker` (`scripts/ui/quick_play/battleplan_picker.gd`) lists, under "Choose battle plan" and a key to the map colours (Attacker red, Defender blue):
- **Random:** "One of the 12 battleplans below, picked when the battle starts."
- each table's battleplans, under "TABLE 1" and "TABLE 2": a small map, the battleplan's number and name, and its twist cut to two lines.

The chosen card is outlined in gold with a check. An eye shows a battleplan in full, swapped in place: a map the width of the pane with its terrain, a caption ("60" × 44" · dashed: terrain · gold rings: objectives with their 3" control zone"), its setup, twist, abilities as [ability cards](abilities.md) and scoring. Pressing a card chooses it and returns to the list.

`BattleplanMap` (`scripts/ui/quick_play/battleplan_map.gd`) draws a map from the battleplan's data: territories, objectives as gold rings and, on a detailed map, terrain as dashed squares (4" small, 6" medium) and each objective's 3" control zone.

## Choices

`BattleSetup` (`scripts/battle/battle_setup.gd`) holds what the player chose: the mode, the Forge army or the Spearhead (its faction, name, regiment ability and enhancement), and the battleplan's name, empty for Random. `ArmySelect.setup()` builds it.

## Signals

**Signal** | **When**
-- | --
`MainMenu.quick_play_pressed` | `Main` opens the game mode screen.
`GameModeScreen.back_pressed` | Back or Esc. `Main` returns to the main menu.
`GameModeScreen.mode_chosen(mode)` | The player pressed a mode's card. `Main` opens the army step for it.
`ArmySelect.back_pressed` | Back, or Esc on the list. `Main` returns to the game mode, focusing the mode's card.
`ArmySelect.edit_requested(army)` | The player pressed an army's Edit. `Main` opens the army builder; its Back returns to the army step.
`ArmySelect.forge_requested` | The player has no armies and pressed Open the Forge. `Main` opens the Forge.
`ArmySelect.play_requested(setup)` | The player pressed Play. Not connected yet: there's no battle screen.
