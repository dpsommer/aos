# Ability cards

Every ability (warscroll abilities, battle traits, battle formations, enhancements, spells, prayers, Regiment of Renown and Spearhead abilities) is shown as an `AbilityCard` (`scripts/ui/ability_card.gd`), laid out like the abilities on the official Age of Sigmar warscrolls.

## Anatomy

- **Outer box:** in the ability's colour (`AbilityCard.colour()`, colours in `UITheme.ABILITY_COLOURS`). Its header shows:
  - an icon for the ability's kind, from its `category` (`AbilityCard.icon_name()`);
  - its frequency and timing in small capitals, e.g. "ONCE PER TURN (ARMY) · YOUR HERO PHASE". The text wraps, so long reaction timings don't widen the card;
  - chips for its casting value, chanting value, command points and points, where it has them.
- **Inner box:** the ability's name in bold Cinzel, a horizontal rule, then its rules text, Declare, Effect and options (`RulesFormatter.ability_body()`), its keywords in small capitals and its source.

A summoning ability's manifestation warscrolls follow its card, from `ArmyCatalog.summoned()`.

## Colours

An ability's colour is its `colour` from the data, as printed on its warscroll and read from BSData (see [Ability colours](../technical/faction-data.md#ability-colours)). It mostly follows the phase, but not always: a passive ability that affects combat is red, and Battle Damaged is black.

An ability without one in the data (most Spearhead abilities, the core rules, battleplans) is coloured by the phase of its timing (`AbilityCard.phase()`, `AbilityCard.PHASE_COLOURS`):

Phase | Timings | Colour
-- | -- | --
`deployment` | Deployment Phase; Start of any turn or battle round | Black
`hero` | Hero phase | Yellow (gold)
`movement` | Movement phase; anything unrecognised | Grey
`shooting` | Shooting phase | Blue
`charge` | Charge phase | Orange
`combat` | Combat phase | Red
`end` | End of any turn | Purple
`passive` | Passive abilities | Green

A reaction (a timing with "Reaction:", or "You declared ..." without it) takes the phase named before it (e.g. "Your Movement Phase, Reaction: ..."), else the phase of the ability it reacts to: FIGHT or ATTACK is combat, SHOOT is shooting, CHARGE is charge, RUN, RETREAT or MOVE is movement, and SPELL, PRAYER or UNBIND is hero. Keywords match whole words, so "GRUNTA" isn't RUN. Failing that, it takes any phase its timing names.

The header text has a WCAG contrast of at least 4.5:1 against every colour (`UITheme.ABILITY_COLOUR_MIN_CONTRAST`), checked by a unit test.

## Icons

`assets/2d/icons/ability_<category>.svg`, line icons in the style of the other icons:

Category | Icon
-- | --
`offensive` | Sword
`defensive` | Shield
`movement` | Double chevron
`shooting` | Crosshair
`rallying` | Banner (also for the data's stray `rally`)
`control` | Objective marker
`damage` | Burst
`special` | Star (also for abilities with no or an unknown category)

Battle Damaged (`AbilityCard.is_battle_damaged()`) always shows a skull (`skull.svg`), whatever its category.

## Battle Damaged weapons

In a `WarscrollCard`'s weapon tables, each weapon that the unit's Battle Damaged ability changes has a small skull before its name, with the tooltip "Changed by Battle Damaged", linking it to the ability's card. `WarscrollCard.battle_damaged_weapons()` finds them by name in the ability's rules: the full name, or for a weapon with several profiles (e.g. "Menhir Club: Calamitous Sweep" and "Menhir Club: Crushing Blow") the part before the colon, which marks every profile. A Battle Damaged ability that changes no weapon (e.g. Nagash's power level) marks none.

## Where cards appear

- Warscrolls (`WarscrollCard`), in the info pane, picker, Regiments of Renown cards and faction browser.
- The info pane's Rules tab: battle traits, battle formations, enhancements and lores (`InfoPane`, `LoreCard`).
- Regiments of Renown cards (`RenownCard`).
- Battle formation cards on the Forge's Battle Formation step.
- Enhancement cards in a unit's options (`UnitRow`), where the card's header shows the points.
- The faction browser, whose tabs are built from controls by `RulesView` (`scripts/ui/forge/rules_view.gd`).
