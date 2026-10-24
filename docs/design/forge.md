# Forge

Forge is the army builder, where players build and save armies to use in Quick Play. Scene `scenes/ui/forge/forge.tscn`, script `scripts/ui/forge/forge.gd`.

## Flow

1. **Grand Alliance:** the player picks Order, Chaos, Death or Destruction. Back returns to the main menu.
2. **Faction:** the factions of the chosen alliance are listed. Back returns to the alliance list, with the chosen alliance focused.
3. **Army builder:** not implemented. Picking a faction emits `faction_selected`, which nothing handles yet.

Esc (`ui_cancel`) does the same as the visible Back button.

## Signals

**Signal** | **When**
-- | --
`back_pressed` | The player leaves Forge from the alliance list. `Main` returns to the main menu.
`faction_selected(alliance, faction)` | The player picks a faction. `alliance` is a `GrandAlliance.Type`; `faction` is the faction name.

## Faction data

Factions are listed by name in `scripts/data/faction_catalog.gd`, grouped by `GrandAlliance.Type` (`scripts/data/grand_alliance.gd`). The faction buttons are generated from the catalog. This is a placeholder: factions will become resources holding their units, rules and battle profiles, and the catalog will load those instead.
