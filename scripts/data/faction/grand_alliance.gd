class_name GrandAlliance
extends RefCounted
## The four Grand Alliances that every faction belongs to.

enum Type { ORDER, CHAOS, DEATH, DESTRUCTION }

const _DISPLAY_NAMES := {
	Type.ORDER: "Order",
	Type.CHAOS: "Chaos",
	Type.DEATH: "Death",
	Type.DESTRUCTION: "Destruction",
}


static func display_name(type: Type) -> String:
	return _DISPLAY_NAMES[type]


## Parses a lowercase id such as "order". Returns -1 if [param id] isn't an alliance.
static func from_id(id: String) -> int:
	for type: Type in _DISPLAY_NAMES:
		if _DISPLAY_NAMES[type].to_lower() == id:
			return type
	return -1
