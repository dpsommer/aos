class_name BattleSetup
extends Resource
## What the player chose in Quick Play: the game mode, their army and the battleplan. See
## docs/design/quick-play.md.

enum Mode { SPEARHEAD, MATCHED_PLAY }

@export var mode: Mode
## The player's Forge army, in Matched Play.
@export var army: Army
## Name of the Spearhead's faction, in Spearhead.
@export var faction: String
## Name of the Spearhead, in Spearhead.
@export var spearhead: String
## Name of the Spearhead regiment ability the player chose.
@export var regiment_ability: String
## Name of the Spearhead enhancement the player's general takes.
@export var enhancement: String
## Name of the battleplan, or empty to pick one at random when the battle starts.
@export var battleplan: String


static func display_name(of: Mode) -> String:
	return "Spearhead" if of == Mode.SPEARHEAD else "Matched Play"
