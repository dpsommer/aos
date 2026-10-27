# Forge

Forge is the army builder, where players build and save armies to use in Quick Play. Scene `scenes/ui/forge/forge.tscn`, script `scripts/ui/forge/forge.gd`.

## Flow

1. **Grand Alliance:** the player picks Order, Chaos, Death or Destruction. Back returns to the main menu.
2. **Faction:** the factions of the chosen alliance are listed. Factions without rules data are disabled with a "Coming soon" tooltip, and factions moved to Legends (Fyreslayers) are labelled "(Legends)". Back returns to the alliance list, with the chosen alliance focused.
3. **Faction browser:** picking a faction emits `faction_selected`, and `Main` opens the faction browser (`scenes/ui/forge/faction_browser.tscn`). Its title and rules tab mark a Legends faction. It is read-only, with tabs for the faction's rules (battle traits, formations, enhancements, lores), warscrolls, Armies of Renown, Regiments of Renown (with each regiment's points, units and abilities), Spearhead and Path to Glory. Each list tab shows the selected entry's full rules. Back returns to the Forge on the same alliance's faction list.
4. **Army builder:** not implemented.

Esc (`ui_cancel`) does the same as the visible Back button on every screen.

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
- **Saving:** `ArmySerializer` converts armies to and from JSON.

## Signals

**Signal** | **When**
-- | --
`back_pressed` | The player leaves Forge from the alliance list. `Main` returns to the main menu.
`faction_selected(alliance, faction)` | The player picks an available faction. `alliance` is a `GrandAlliance.Type`; `faction` is the faction name. `Main` opens the faction browser.
`FactionBrowser.back_pressed` | The player leaves the faction browser. `Main` reopens the Forge on that alliance's factions.

## Faction data

Factions are listed by name in `scripts/data/faction_catalog.gd`, grouped by `GrandAlliance.Type` (`scripts/data/grand_alliance.gd`). The faction buttons are generated from the catalog. Factions with rules data (currently Blades of Khorne, Cities of Sigmar, Daughters of Khaine, Disciples of Tzeentch, Flesh-eater Courts, Fyreslayers, Gloomspite Gitz, Hedonites of Slaanesh, Helsmiths of Hashut, Idoneth Deepkin, Ironjawz, Kharadron Overlords, Khazalite Holds, Kruleboyz, Lumineth Realm-lords, Maggotkin of Nurgle, Nighthaunt, Ogor Mawtribes, Ossiarch Bonereapers, Seraphon, Skaven, Slaves to Darkness, Sons of Behemat, Soulblight Gravelords, Stormcast Eternals and Sylvaneth) are loaded from `data/factions/`; see [Faction data](../technical/faction-data.md).
