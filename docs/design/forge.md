# Forge

Forge is the army builder, where players build and save armies to use in Quick Play. Scene `scenes/ui/forge/forge.tscn`, script `scripts/ui/forge/forge.gd`.

## Flow

1. **Grand Alliance:** the player picks Order, Chaos, Death or Destruction. Back returns to the main menu.
2. **Faction:** the factions of the chosen alliance are listed. Factions without rules data are disabled with a "Coming soon" tooltip. Back returns to the alliance list, with the chosen alliance focused.
3. **Faction browser:** picking a faction emits `faction_selected`, and `Main` opens the faction browser (`scenes/ui/forge/faction_browser.tscn`). It is read-only, with tabs for the faction's rules (battle traits, formations, enhancements, lores), warscrolls, Armies of Renown, Spearhead and Path to Glory. Each list tab shows the selected entry's full rules. Back returns to the Forge on the same alliance's faction list.
4. **Army builder:** not implemented.

Esc (`ui_cancel`) does the same as the visible Back button on every screen.

## Signals

**Signal** | **When**
-- | --
`back_pressed` | The player leaves Forge from the alliance list. `Main` returns to the main menu.
`faction_selected(alliance, faction)` | The player picks an available faction. `alliance` is a `GrandAlliance.Type`; `faction` is the faction name. `Main` opens the faction browser.
`FactionBrowser.back_pressed` | The player leaves the faction browser. `Main` reopens the Forge on that alliance's factions.

## Faction data

Factions are listed by name in `scripts/data/faction_catalog.gd`, grouped by `GrandAlliance.Type` (`scripts/data/grand_alliance.gd`). The faction buttons are generated from the catalog. Factions with rules data (currently Blades of Khorne, Cities of Sigmar, Daughters of Khaine, Disciples of Tzeentch, Flesh-eater Courts, Gloomspite Gitz, Hedonites of Slaanesh, Helsmiths of Hashut, Idoneth Deepkin, Ironjawz, Kharadron Overlords, Kruleboyz, Lumineth Realm-lords, Maggotkin of Nurgle, Nighthaunt, Ogor Mawtribes, Ossiarch Bonereapers, Seraphon, Skaven, Slaves to Darkness, Sons of Behemat and Sylvaneth) are loaded from `data/factions/`; see [Faction data](../technical/faction-data.md).
