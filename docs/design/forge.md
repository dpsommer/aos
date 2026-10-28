# Forge

Forge is the army builder, where players build and save armies to use in Quick Play. Scene `scenes/ui/forge/forge.tscn`, script `scripts/ui/forge/forge.gd`.

## Flow

Every step shares a header and the scrolling page below it, styled by `UITheme` (see [Look](#look)):
- **Back** names where it goes: "Main menu", "Armies", "Grand Alliance", "Factions" or "Army of Renown". Esc (`ui_cancel`) does the same (`Forge.go_back()`).
- **Breadcrumb:** from the Grand Alliance step on, "Grand Alliance › Faction › Army of Renown › Battle Formation › Builder", with each step already done replaced by its choice (e.g. "Order › Stormcast Eternals › **Army of Renown** › …"), and the current step in bold. The saved armies show "Forge" instead.
- **Browse faction rules:** on the Army of Renown and Battle Formation steps. It emits `browse_requested`, and `Main` opens the read-only faction browser (`scenes/ui/forge/faction_browser.tscn`). The browser has tabs for:
  - the faction's rules (battle traits, formations, enhancements, lores);
  - warscrolls;
  - Armies of Renown;
  - Regiments of Renown;
  - Spearhead;
  - Path to Glory.

  Each list tab shows the selected entry's full rules in a scrolling pane. The tabs are built from controls by `RulesView` (`scripts/ui/forge/rules_view.gd`): abilities as [ability cards](abilities.md), warscrolls as `WarscrollCard`s and lores as `LoreCard`s, as in the army builder. Its title and rules tab mark a Legends faction. Back returns to the Army of Renown step.
- **Cards:** on every step, pressing a card makes that step's choice and moves straight on. Going back to a step focuses the card chosen there before.

The steps:
1. **Saved armies:** "Your armies", most recently saved first, with **New army** at the top right.
   - **Army cards:** each has:
     - the faction's initials as placeholder art;
     - the army's name;
     - its faction, alliance and points against its limit;
     - a status pill: "Valid", "N problems" or "Constraints overridden".
   - **Buttons:**
     - **Open** emits `army_opened`, and `Main` opens the army in the builder. It's disabled when the file can't be read or the faction has no data.
     - **Duplicate** (icon) saves a copy named "<name> (copy)".
     - **Delete** (icon) asks for confirmation first, with Cancel focused so a stray Enter doesn't delete the army.
   - **Unreadable files** are listed with the reason, so they can be deleted.
   - **No armies:** a placeholder says so.
2. **Grand Alliance:** a card for each of Order, Chaos, Death and Destruction, with its number of factions. Pressing one goes straight to its factions.
3. **Faction:** a card for each faction of the chosen alliance. Pressing one goes straight to its Army of Renown step.
   - Factions without rules data are disabled, with a "Coming soon" chip and tooltip.
   - Factions moved to Legends (Fyreslayers) have a Legends chip.
4. **Army of Renown:**
   - **"No Army of Renown" card:** the faction's own rules. It's focused when the step opens, unless an Army of Renown was chosen earlier for the same faction.
   - **Army of Renown cards:** below it, two to a row. Each has:
     - its name and source;
     - its roster options (`Forge.roster_summary()`);
     - chips for Legends, "No Regiments of Renown", "No faction terrain" and "Fixed General" (`Forge.renown_chips_for()`).
   - **Pressing a card:** "No Army of Renown" goes to the Battle Formation step, or starts the army if the faction has no formations. An Army of Renown starts the army (`Forge.choose_army_of_renown()`).
5. **Battle Formation:** the faction's battle formations, three to a row. Each card shows:
   - its points, or the type of its first ability;
   - its name;
   - each ability as an [ability card](abilities.md).

   The first card is focused, or the one chosen before. Pressing a card starts the army with that formation (`Forge.choose_formation()`). A faction without formations skips this step.
6. **Army builder:** `Forge` emits `army_started` with a new, empty army, and `Main` opens the builder.
   - **Back** returns to the saved armies, with the army focused if it was saved.
   - **Unsaved changes:** if the army has any, Back first asks whether to keep editing (the default), discard the changes, or save and go back.

## Look

Every screen uses `UITheme` (`scripts/ui/ui_theme.gd`), set as its `theme` in `_ready()`, built from the Forge design canvas. It provides:
- dark panels, warm text and a gold accent;
- chips (tags such as Legends, Scourge or a battle tactic's kind) in pale tints of their colour, with a WCAG contrast of at least 9:1 against their background (`UITheme.CHIP_MIN_CONTRAST`);
- Inter for text (also the project's default font) and Cinzel for headings, both in `assets/2d/fonts/` with their OFL licences;
- abilities as [ability cards](abilities.md), boxes in each ability's warscroll colour (`UITheme.ABILITY_COLOURS`);
- rules text (`RulesFormatter.ability_body()`, shown in a `RichTextLabel`) with extra space between paragraphs so an ability's Declare and Effect read as separate sections;
- the design's icons, in `assets/2d/icons/`;
- type variations, e.g. `GoldButton`, `OptionCard`, `PageTitleLabel`.
- dialogs in a pane-coloured window with a border. `UITheme.style_dialog()`, called on every dialog, sets its title and buttons in Cinzel (`DialogButton`; `DialogGoldButton` for the main action, e.g. Quit or Save and go back; `DialogDangerButton`, in red, for a destructive one, e.g. Delete or Discard changes). It overrides the title font on the dialog itself, because a window's title takes the theme's default font and size over its `Window` theme items. The project's default clear colour is the pane colour too: when the UI is scaled, a dialog's window can be a pixel wider and taller than its panel, and that pixel would otherwise show as a grey line along its right and bottom edges.

`UIBuilder` (`scripts/ui/ui_builder.gd`) builds controls in code. Shared pieces:
- **`OptionCard`** (`scripts/ui/option_card.gd`): a large button holding any controls, which fits its height to them. In toggle mode it shows as selected (gold border) while pressed.
- **`PressableCard`** (`scripts/ui/forge/builder/pressable_card.gd`): the base of `TacticCard` and `LoreCard`. A card that can be made pressable as a whole, with a gold outline on keyboard focus and a grey one on hover. Buttons on a pressable card (e.g. the picker's eye) still take their own clicks.
- **`DashedStyleBox`** (`scripts/ui/dashed_style_box.gd`): a rounded box with a dashed border, used by the `DashedButton` variation for empty slots.
- **`ArtPlaceholder`** (`scripts/ui/art_placeholder.gd`, shader `assets/shaders/ui/art_placeholder.gdshader`): diagonal stripes in a rounded box. It stands in for army, faction and unit art, including the builder's portraits.

## Army builder

Scene `scenes/ui/forge/builder/army_builder.tscn`, script `scripts/ui/forge/builder/army_builder.gd` (`ArmyBuilder`). It is laid out for the design's 1440 × 900, which is the project's base window size, and styled by `UITheme` (see [Look](#look)). Icon-only buttons have a tooltip and an accessibility name. The design is the Forge canvas artifact.

- **Header:**
  - Back.
  - The faction, with its alliance and its Army of Renown or battle formation.
  - The points total against the limit, with a bar that turns red when over.
  - A status pill: "Army valid", "N problems" or "Constraints overridden".
  - Save army (also Ctrl+S, or Command+S on macOS; the tooltip names only this platform's shortcut): saves with `ArmyStore`, committing any name or count still being typed. It reads "Saved" and is disabled until the army changes again.
- **Builder pane:** the army list, top to bottom.
  - **Army name:** in Cinzel, with a pencil button that swaps it for a field to edit it. Enter or leaving the field saves the new name (a blank name is ignored); Esc cancels.
  - **Validation:** problems and warnings from `ArmyValidator`.
  - **Battle Tactics:** 2 slots. An empty slot is a dashed box (`DashedButton`) that opens the picker. A filled slot shows the card's name and its battle tactics' names, with Change.
  - **Army List:** each regiment's name, unit count against its capacity, and points, with collapse, Rename and Delete.
    - **Unit rows:** from left to right:
      - a grip, or for a regiment's leader the General crown in the same column, so a Hero leader lines up with the grips below it;
      - the unit's portrait;
      - its name, with a pencil that swaps the name for a field (Enter or leaving the field renames it, a blank name goes back to the warscroll's, Esc cancels);
      - under the name, `UnitRow.subtext()`: "Leader" or "General", the warscroll's name if the unit is renamed, its model count, its enhancements and its weapon options, e.g. "General · Lord-Celestant · 1 model · Sword of Judgement", followed by Scourge and Legends chips;
      - its points, with any points from enhancements in a gold tag after them with an enhancement icon, e.g. "150 pts [+20 ✦]" (`ArmyPoints.enhancement_points()`);
      - buttons: Reinforce (where allowed), Options (disabled when the unit has nothing to choose), Copy and Remove.

      Units in a Regiment of Renown have no buttons and can't be renamed.
    - **Options:** for each enhancement type the unit can take, the type's name as a heading in Cinzel over a card for each enhancement (`ArmyCatalog.enhancement_choices()`: only tables whose `units` include it, and no Legends tables unless Legends are shown, though the unit's current pick stays). Each card shows its table's group, Scourge and Legends tags over the enhancement's [ability card](abilities.md), which shows its points; pressing a card gives the unit that enhancement (taking it from any other unit, as only one of each type is allowed) and pressing the picked card, which is outlined in gold with a check, takes it away. Then a count for each weapon option, capped by its regiment size, with the option's rules.
    - **Add buttons:** "Choose a leader" in an empty regiment, "Add unit" (hidden when full, unless constraints are overridden), "Add regiment" and "Add Regiment of Renown" (hidden once the army has one, unless constraints are overridden).
  - **Auxiliary Units:** a box like a regiment's, with unit rows and "Add auxiliary unit" beside "or drag one here". While a unit that can go there is dragged, it's highlighted like a regiment.
  - **Faction Terrain:** "Up to 1 terrain feature". A row for each terrain warscroll, laid out like a unit row: a portrait, its name, the universal terrain abilities its composition lists (`ArmyBuilder.terrain_abilities()`), its points, and an Add button or, once included, a red bin icon button to remove it. Hidden when the faction has none or its Army of Renown forbids it.
  - **Lores:** a slot each for spell, prayer and manifestation lores, side by side, for the kinds the army has lores to choose from.
    - **Empty slot:** a dashed box, "Choose spell lore", that opens the picker. Its tooltip says which units the lore needs (e.g. "Your army must contain one or more Wizards to cast the spells in your Spell Lore."), and its text turns amber when the army needs that lore and has none.
    - **Filled slot:** a short `LoreCard`: the kind (with the same tooltip), the lore's name with its points, Scourge and Legends tags, and its spells' or prayers' names as chips. Change and a red bin icon button (which removes the lore and focuses the empty slot) sit in its upper right.
    - **View in Rules** opens the Rules tab's Lores section.
- **Info pane:** on the left (`InfoPane`, `info_pane.gd`). A search box sits above tabs for Roster, Rules, Regiments of Renown and Army settings (a gear).
  - **Search:** the placeholder names what the tab searches, on every tab. The query is shared by the tabs. Every word must appear somewhere in an entry (`RulesSearch`), and Esc or the clear button empties it.
    - Search unfolds everything it shows. On Army settings it shows the settings whose title or note matches.
    - A tab with no matches says so.
  - **Roster:** the faction's units, grouped by type (Hero, Infantry, Cavalry, Monster, War Machine, Other). Each type folds, and a note counts the hidden Legends units.
    - **Unit cards:** points, plus Scourge and Legends chips.
    - **A star** pins the unit to a Favourites list at the top. Favourites are kept per faction in `user://forge.cfg`.
    - **Clicking a card** shows its warscroll and "Add as auxiliary unit". Warscrolls in the builder are `WarscrollCard`s, each in its own box: the name in Cinzel with points, model count and base size under it, characteristics in boxes (Move, Health, Control, Save, then Ward and Banish), a bordered table for ranged and one for melee weapons, each with its icon (`ranged.svg`, `melee.svg`), its values bold and centred in fixed-width columns so Attacks to Damage line up between the tables, each weapon's abilities under it (and a skull before a weapon changed by Battle Damaged, see [ability cards](abilities.md)), then the abilities as [ability cards](abilities.md) and the keywords. An ability that summons a manifestation (e.g. Jacobus Vyne's Summon Wisper) has the manifestation's warscroll indented under it, from `ArmyCatalog.summoned()`; so do warscrolls in Regiments of Renown cards and the faction browser. The button is disabled for a Unique unit already in the army. While the card has focus, its whole box (star included) is outlined in gold.
  - **Rules:** the rules the army uses, from `RulesSections`, in sections that each fold:
    - Battle Traits;
    - Battle Formations;
    - Enhancements, one group per table;
    - Lores, including the universal manifestation lores. Each spell or prayer that summons manifestations shows their warscrolls on its card, from its `summons` ids (`ArmyCatalog.summoned()`);
    - Faction Terrain;
    - Battle Tactics: the battlepack's cards in full, with their FAQs. Rules divide a full card's setup, each battle tactic and its FAQs.

    An Army of Renown's traits, enhancements and lores replace the faction's, and it has no formations. Lores start folded. Each group folds on its own, even when several share a name (e.g. two Artefacts of Power tables). Enhancement tables and lores from Scourge of Aqshy or Scourge of Ghyran (their `source`) are tagged "SoA" or "SoG". Legends enhancement tables and lores (those from a Scourge the battlepack doesn't use, i.e. Scourge of Ghyran) are tagged Legends and hidden unless Legends are shown (though the army's picked lores stay), until the builder can switch between General's Handbook versions. The army's formation and lores are chipped "Selected", and its battle tactics cards are chipped with their slot.

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
    - a lore's short card opens it under Rules;
    - View in Rules, in the Lores section, opens the Lores section under Rules.
- **Picker:** replaces the info pane to add something, until it is closed or something is picked. It can show:
  - Heroes to lead a regiment;
  - units the leader's regiment options allow, or every unit when constraints are overridden;
  - auxiliary units;
  - the battlepack's battle tactics cards, each in brief: its name and each battle tactic's kind, name and victory points. An eye icon toggle beside the name shows the card in full (its setup, each battle tactic's condition and its FAQs, divided by rules) and back; the card is swapped in place, so the list keeps its scroll and focus stays on the eye. The whole card is pressed (clicked, or Enter or Space) to choose it. Cards already chosen for either slot aren't listed;
  - the lores of one kind (`LoreCard`), each in short: its name, tags and its spells' or prayers' names as chips, with the universal manifestation lores marked as such. As with battle tactics cards, an eye icon toggle shows the lore in full, with each spell or prayer's rules and the warscrolls of the manifestations it summons, and the whole card is pressed to choose it. The army's current lore isn't listed, nor Legends lores unless Legends are shown;
  - Regiments of Renown, as in the Regiments of Renown tab (`RenownCard`).

  Units are listed in foldable sections by type (Hero, Infantry, Cavalry and so on), as in the Roster. It hides Legends units unless shown, and Unique units already in the army unless constraints are overridden.
- **Drag and drop** (`BuilderDragDrop`, `drag_drop.gd`): a gold line shows where a drop will go, and the dragged row or card is dimmed.
  - **Roster card:** drop it in a regiment to add the unit there, or on Auxiliary Units.
  - **Unit:** drag its grip to move it within its regiment, to another regiment, or to Auxiliary Units. A full regiment refuses it unless constraints are overridden, and nothing goes before a Hero leader.
    - While a unit is dragged, the info pane shows "Drop to remove from army", which removes it.
  - **Regiment:** drag its grip to reorder the army list.
  - **Regiments of Renown card:** drop it on the army list to add it, if the army can take it.
  - **Feedback:** regiments that can take the dragged unit are outlined in gold, and dragging near the top or bottom of the army list scrolls it.
  - **Keyboard:** the grips move units and regiments with Up and Down. Hero leaders and Regiment of Renown units have no grip.
- **Redrawing and focus:** the builder pane is rebuilt from the army after every change. Controls carry a `focus_key` meta, so keyboard focus returns to the same control afterwards. If it's gone, focus goes to the picker's first button while the picker is open, else to Back. Closing the picker returns focus to the control that opened it. When a pick fills a regiment, which hides its "Add unit", focus goes to the regiment's collapse button.
  - The info pane is only rebuilt when something its tab shows has changed, as the Rules tab is slow to lay out.
- **Esc:** in the search box, clears the search. Otherwise it closes the picker, then cancels a regiment, unit or army rename, then goes back.

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
`back_pressed` | The player leaves Forge from the saved armies. `Main` returns to the main menu.
`browse_requested(alliance, faction)` | The player presses Browse faction rules. `alliance` is a `GrandAlliance.Type`; `faction` is the faction name. `Main` opens the faction browser.
`army_started(army)` | The player continues to the builder from the Army of Renown or Battle Formation step. `army` is a new `Army`. `Main` opens the army builder.
`army_opened(army)` | The player opens a saved army. `Main` opens the army builder.
`FactionBrowser.back_pressed` | The player leaves the faction browser. `Main` reopens the Forge on that faction's Army of Renown step.
`ArmyBuilder.back_pressed` | The player leaves the army builder, after confirming if there are unsaved changes. `Main` reopens the Forge on the saved armies.

## Faction data

Factions are listed by name in `scripts/data/faction_catalog.gd`, grouped by `GrandAlliance.Type` (`scripts/data/grand_alliance.gd`). The faction buttons are generated from the catalog. Factions with rules data (currently Blades of Khorne, Cities of Sigmar, Daughters of Khaine, Disciples of Tzeentch, Flesh-eater Courts, Fyreslayers, Gloomspite Gitz, Hedonites of Slaanesh, Helsmiths of Hashut, Idoneth Deepkin, Ironjawz, Kharadron Overlords, Khazalite Holds, Kruleboyz, Lumineth Realm-lords, Maggotkin of Nurgle, Nighthaunt, Ogor Mawtribes, Ossiarch Bonereapers, Seraphon, Skaven, Slaves to Darkness, Sons of Behemat, Soulblight Gravelords, Stormcast Eternals and Sylvaneth) are loaded from `data/factions/`; see [Faction data](../technical/faction-data.md).
