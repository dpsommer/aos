class_name RosterInclusion
extends Resource
## Units of another faction an Army of Renown's roster makes available, such as the Ironsunz's Ogors
## or the Throngankor Alliance's Kharadron Overlords. Its entries still decide which can be included.

## Id of the faction the units come from, e.g. "kharadron_overlords".
@export var faction: String
## Names of the faction's warscrolls to include. Empty for all of its units.
@export var units: PackedStringArray
