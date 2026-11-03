# Documentation

**Folder** | **Contents**
-- | --
`design/` | Game design: modes, UI/UX, army builder, AI opponent behaviour
`gameplay/` | How tabletop rules map onto the simulator: battle rounds, phases, objectives, battle tactics, battleplans
`technical/` | Engineering: project layout, architecture, conventions, testing

## Index

### Technical

- [Project layout](technical/layout.md): folder structure and what goes where
- [UI scenes](technical/ui-scenes.md): prefer Godot scenes over building visible elements in code, how the scenes are written (factories, unique names, inherited scenes), checking UI at 50%, 100% and 200% render scale, and what's still built in code
- [Testing](technical/testing.md): test layout, running tests, and testing rules
- [Rules reference](technical/rules-reference.md): the official rules documents and how to use them
- [Faction data](technical/faction-data.md): faction JSON format, sources, how to add a faction, and the Regiments of Renown
- [3D models](technical/models.md): where unit, manifestation, faction terrain and Spearhead terrain models and the realm battlefields' boards live, how they're named and found, their scale, axes and textures, building them from Tabletop Simulator's cache, and Git LFS
- [Core rules data](technical/core-rules-data.md): JSON for the universal abilities and manifestation lores every army uses, the General's Handbook battlepack (season rules, battle tactics, battleplans and their FAQs), and the Spearhead battlepacks (Fire and Jade, Sand and Bone and City of Ash: realm battlefields with their objectives and roads, twist and battle tactic decks, deployment maps, terrain, relics, the Hidden in the Ashes campaign, Call for Reinforcements)

### Design

- [Main menu](design/main-menu.md): menu options, their destinations, and the signals the menu emits
- [Quick Play](design/quick-play.md): choosing a game mode (Spearhead or Matched Play), an army and a battleplan
- [Battle](design/battle.md): the loading screen and the game map: the battlefield at tabletop size, models on their bases (3D models where there are any), the roll-off, the Spearhead deployment map picker, the deployment screens, the camera and the in-battle menu
- [Forge](design/forge.md): army builder flow and screen, faction browser, signals, and faction data
- [Ability cards](design/abilities.md): how abilities are shown everywhere: the phase-coloured box, its icon, timing and colours
- [Settings](design/settings.md): the General, Graphics, Sound and Input tabs, key remapping, and how settings are saved and applied
- [Accessibility](design/accessibility.md): keyboard use, including reordering the army list, and screen reader names

### Gameplay

- [Army composition](gameplay/army-composition.md): the army rules the Forge checks, and what it doesn't check yet
- [Deployment](gameplay/deployment.md): the roll-off, the deployment steps and who goes when, where units and terrain can be set up, coherency, formations, deployment abilities and reserves, and the AI's mirrored deployment
- [Faction FAQs](gameplay/faq/README.md): each faction's official FAQ rulings from the latest rules update

Add new documents to this index.
