class_name RegimentUnit
extends Resource
## One unit in a Regiment of Renown.

@export var count: int
@export var name: String
## Id of the unit's home faction, or empty for a unit in the regiment's own warscrolls.
@export var faction_id: String
## Id of the unit's warscroll in its home faction, or in the regiment's own warscrolls.
@export var warscroll_id: String
## Size notes, e.g. "1 model".
@export var notes: String
