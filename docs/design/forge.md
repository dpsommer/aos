# Forge

Forge is the army builder, where players build and save armies to use in Quick Play. Scene `scenes/ui/forge/forge.tscn`, script `scripts/ui/forge/forge.gd`.

## Flow

1. **Saved armies:** the Forge opens on the player's saved armies, most recently saved first. Each row shows the army's name, faction, points against its limit, and whether it's valid. Each row has three buttons:
   - **Open** emits `army_opened`, and `Main` opens the army in the builder. It's disabled when the file can't be read or the faction has no data.
   - **Duplicate** saves a copy named "<name> (copy)".
   - **Delete** asks for confirmation first.

   An unreadable file is listed with the reason, so it can be deleted. **New army** starts the steps below, and Back returns to the main menu.
2. **Grand Alliance:** the player picks Order, Chaos, Death or Destruction. Back returns to the saved armies.
3. **Faction:** the factions of the chosen alliance are listed. Factions without rules data are disabled with a "Coming soon" tooltip, and factions moved to Legends (Fyreslayers) are labelled "(Legends)". Back returns to the alliance list, with the chosen alliance focused.
4. **Army of Renown:** "None (<faction> rules)" or one of the faction's Armies of Renown, which are labelled "(Legends)" where they are. Picking one starts the army. Back returns to the faction list, with the faction focused.
   - **Browse faction rules** emits `browse_requested`, and `Main` opens the read-only faction browser (`scenes/ui/forge/faction_browser.tscn`). It has tabs for the faction's rules (battle traits, formations, enhancements, lores), warscrolls, Armies of Renown, Regiments of Renown, Spearhead and Path to Glory, and each list tab shows the selected entry's full rules. Its title and rules tab mark a Legends faction. Back returns to this step.
5. **Battle Formation:** for "None", the faction's battle formations, with their points if they cost any. Picking one starts the army. A faction without formations skips this step. Back returns to the Army of Renown step.
6. **Army builder:** `Forge` emits `army_started` with a new, empty army, and `Main` opens the builder. Back returns to the saved armies, with the army focused if it was saved. If the army has unsaved changes, Back first asks whether to keep editing (the default), discard the changes, or save and go back.

Esc (`ui_cancel`) does the same as the visible Back button on every screen.

## Army builder

Scene `scenes/ui/forge/builder/army_builder.tscn`, script `scripts/ui/forge/builder/army_builder.gd` (`ArmyBuilder`). It is laid out for the design's 1440 × 900, which is the project's base window size, and styled by `ForgeTheme`: Inter for text (also the project's default font) and Cinzel for headings, both in `assets/2d/fonts/` with their OFL licences, and the design's icons in `assets/2d/icons/`. Icon-only buttons have a tooltip and an accessibility name. The design is the Forge canvas artifact.

- **Header:**
  - Back.
  - The faction, with its alliance and its Army of Renown or battle formation.
  - The points total against the limit, with a bar that turns red when over.
  - A status pill: "Army valid", "N problems" or "Constraints overridden".
  - Save army (also Ctrl+S): saves with `ArmyStore`, committing any name or count still being typed. It reads "Saved" and is disabled until the army changes again.
- **Builder pane:** the army list, top to bottom.
  - **Army name:** an editable field.
  - **Validation:** problems and warnings from `ArmyValidator`.
  - **Battle Tactics:** 2 slots. A filled slot shows the card's name and its battle tactics' names, with Change.
  - **Army List:** each regiment's name, unit count against its capacity, and points, with collapse, Rename and Delete.
    - **Unit rows:** a grip (not on Hero leaders), a unit's name, its enhancements, its points, and buttons: General (leaders only), Reinforce (where allowed), Options, Copy and Remove. Units in a Regiment of Renown have no buttons.
    - **Options:** a unit's name, a select for each enhancement type it can take, and a count for each weapon option, capped by its regiment size, with the option's rules.
    - **Add buttons:** "Choose a leader" in an empty regiment, "Add unit" (disabled when full), "Add regiment" and "Add Regiment of Renown".
  - **Auxiliary Units:** unit rows and "Add auxiliary unit".
  - **Faction Terrain:** a select, hidden when the faction has none or its Army of Renown forbids it.
  - **Lores:** a select each for spell, prayer and manifestation lores. Each has a "?" whose tooltip says which units the lore needs, and which turns amber when the army needs that lore and has none.
- **Info pane:** on the left (`InfoPane`, `info_pane.gd`). A search box sits above tabs for Roster, Rules, Regiments of Renown and Army settings (a gear).
  - **Search:** the placeholder names what the tab searches, and the box is hidden on Army settings. The query is shared by the tabs. Every word must appear somewhere in an entry (`RulesSearch`), and Esc or the clear button empties it.
    - Search unfolds everything it shows.
    - A tab with no matches says so.
  - **Roster:** the faction's units, grouped by type (Hero, Infantry, Cavalry, Monster, War Machine, Other). Each type folds, and a note counts the hidden Legends units.
    - **Unit cards:** points, plus Scourge and Legends chips.
    - **A star** pins the unit to a Favourites list at the top. Favourites are kept per faction in `user://forge.cfg`.
    - **Clicking a card** shows its warscroll and "Add as auxiliary unit". The button is disabled for a Unique unit already in the army.
  - **Rules:** the rules the army uses, from `RulesSections`, in sections that each fold:
    - Battle Traits;
    - Battle Formations;
    - Enhancements, one group per table;
    - Lores, including the universal manifestation lores;
    - Manifestations;
    - Faction Terrain;
    - Battle Tactics: the battlepack's cards in full, with their FAQs.

    An Army of Renown's traits, enhancements and lores replace the faction's, and it has no formations. Lores start folded. The army's formation and lores are chipped "Selected", and its battle tactics cards are chipped with their slot.

    Search keeps a whole section or group whose title matches, and otherwise only the matching rules.
  - **Regiments of Renown:** cards the army can include, or every one when constraints are overridden. Legends regiments are hidden unless shown.
    - Each card lists its units. Each unit unfolds its warscroll, followed by the regiment's rules.
    - "Add to army", or why the army can't take it.
  - **Army settings:**
    - Show Legends units;
    - Override army constraints;
    - the points limit, with −/+ buttons that step 250;
    - the Army of Renown;
    - the battle formation, when there's no Army of Renown.
  - **Links:** each of these clears the search, switches tab, scrolls to the target, highlights it briefly and gives it keyboard focus:
    - a unit's portrait in the army list opens its card in the Roster (and shows Legends units if it is one);
    - a Regiment of Renown unit's portrait opens its regiment in Regiments of Renown;
    - a short battle tactics card opens the card under Rules;
    - picking a lore opens it under Rules.
- **Picker:** replaces the info pane to add something, until it is closed or something is picked. It can show:
  - Heroes to lead a regiment;
  - units the leader's regiment options allow, or every unit when constraints are overridden;
  - auxiliary units;
  - the battlepack's battle tactics cards in full;
  - Regiments of Renown, as in the Regiments of Renown tab (`RenownCard`).

  It hides Legends units unless shown, and Unique units already in the army unless constraints are overridden.
- **Drag and drop** (`BuilderDragDrop`, `drag_drop.gd`): a gold line shows where a drop will go, and the dragged row or card is dimmed.
  - **Roster card:** drop it in a regiment to add the unit there, or on Auxiliary Units.
  - **Unit:** drag its grip to move it within its regiment, to another regiment, or to Auxiliary Units. A full regiment refuses it unless constraints are overridden, and nothing goes before a Hero leader.
    - While a unit is dragged, the info pane shows "Drop to remove from army", which removes it.
  - **Regiment:** drag its grip to reorder the army list.
  - **Regiments of Renown card:** drop it on the army list to add it, if the army can take it.
  - **Feedback:** regiments that can take the dragged unit are outlined in gold, and dragging near the top or bottom of the army list scrolls it.
  - **Keyboard:** the grips move units and regiments with Up and Down. Hero leaders and Regiment of Renown units have no grip.
- **Redrawing and focus:** the builder pane is rebuilt from the army after every change. Controls carry a `focus_key` meta, so keyboard focus returns to the same control afterwards.
  - The info pane is only rebuilt when something its tab shows has changed, as the Rules tab is slow to lay out.
- **Esc:** in the search box, clears the search. Otherwise it closes the picker, then cancels a rename, then goes back.

## Army model

An army is an `Army` resource (`scripts/army/`): its regiments (`ArmyRegiment`), auxiliary units (`ArmyUnit`), general, battle tactics cards, lores, battle formation or Army of Renown, faction terrain, and settings (points limit, Legends, override).
- **Changes:** made through `ArmyEditor`, which emits `changed` and keeps the builder's limits unless the army overrides its constraints:
  - regiment sizes, with a Hero leader kept first;
  - only a regiment leader as the general;
  - one Regiment of Renown;
  - one enhancement of each type;
  - weapon option counts within their caps. Reinforcing moves a count at its cap to the new cap and keeps any other count.
- **Lookups:** `ArmyCatalog` finds the rules an army refers to. An Army of Renown's enhancements and lores replace the faction's.
- **Points:** totalled by `ArmyPoints`.
- **Checks:** done by `ArmyValidator`; see [Army composition](../gameplay/army-composition.md).
- **Search:** `RulesSearch` matches the info pane's search query.
- **Saving:** `ArmySerializer` converts armies to and from JSON, with a format version, and `ArmyStore` saves each army to `user://armies/<id>.json`. An army gets a random id when it's first saved.
  - Loading skips fields with the wrong type and reports them.
  - A unit whose warscroll is no longer in the faction data stays in the army: the builder marks it, and validation reports it.

## Signals

**Signal** | **When**
-- | --
`back_pressed` | The player leaves Forge from the alliance list. `Main` returns to the main menu.
`browse_requested(alliance, faction)` | The player presses Browse faction rules. `alliance` is a `GrandAlliance.Type`; `faction` is the faction name. `Main` opens the faction browser.
`army_started(army)` | The player picks an Army of Renown or a battle formation. `army` is a new `Army`. `Main` opens the army builder.
`army_opened(army)` | The player opens a saved army. `Main` opens the army builder.
`FactionBrowser.back_pressed` | The player leaves the faction browser. `Main` reopens the Forge on that faction's Army of Renown step.
`ArmyBuilder.back_pressed` | The player leaves the army builder, after confirming if there are unsaved changes. `Main` reopens the Forge on the saved armies.

## Faction data

Factions are listed by name in `scripts/data/faction_catalog.gd`, grouped by `GrandAlliance.Type` (`scripts/data/grand_alliance.gd`). The faction buttons are generated from the catalog. Factions with rules data (currently Blades of Khorne, Cities of Sigmar, Daughters of Khaine, Disciples of Tzeentch, Flesh-eater Courts, Fyreslayers, Gloomspite Gitz, Hedonites of Slaanesh, Helsmiths of Hashut, Idoneth Deepkin, Ironjawz, Kharadron Overlords, Khazalite Holds, Kruleboyz, Lumineth Realm-lords, Maggotkin of Nurgle, Nighthaunt, Ogor Mawtribes, Ossiarch Bonereapers, Seraphon, Skaven, Slaves to Darkness, Sons of Behemat, Soulblight Gravelords, Stormcast Eternals and Sylvaneth) are loaded from `data/factions/`; see [Faction data](../technical/faction-data.md).
