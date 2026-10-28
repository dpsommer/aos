class_name Ability
extends Resource
## A rule with a timing and effect: battle traits, enhancements, warscroll abilities, prayers.

## Values of [member type].
const TYPES: PackedStringArray = ["active", "passive", "command", "spell", "prayer"]
## Values of [member colour].
const COLOURS: PackedStringArray = ["black", "yellow", "grey", "blue", "orange", "red", "purple", "green"]

## Icon category, e.g. "offensive", "movement", "special".
@export var category: String
@export var name: String
## How the ability is used: "active", "passive", "command", "spell" or "prayer".
@export var type: String
## The colour of the ability's box on its warscroll, one of [constant COLOURS], from BSData. Empty if
## the data has none; [method AbilityCard.colour] then picks one from its timing.
@export var colour: String
## When the ability is used, e.g. "Passive" or "Your Hero Phase".
@export var timing: String
## Usage limit, e.g. "Once Per Battle". Empty if unlimited.
@export var frequency: String
@export var declare: String
@export var effect: String
## Free text that isn't part of Declare or Effect.
@export var text: String
@export var keywords: PackedStringArray
## Named sub-effects the player picks from, each {"name": String, "text": String}.
@export var options: Array[Dictionary]
## Who uses a reaction, e.g. "The unit using that RUN ability." Empty if the ability declares it.
@export var used_by: String
## Points cost when the ability is an enhancement.
@export var points: int
## Command point cost of a command. 0 if the ability isn't a command.
@export var command_points: int
## Casting value of a spell. 0 if the ability isn't a spell.
@export var casting_value: int
## Chanting value of a prayer. 0 if the ability isn't a prayer.
@export var chanting_value: int
## Expansion the ability comes from, e.g. "Scourge of Aqshy". Empty for the battletome.
@export var source: String
## Warscroll ids of the manifestations the ability sets up, e.g. a summoning spell's. See
## [method ArmyCatalog.summoned].
@export var summons: PackedStringArray
