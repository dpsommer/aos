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
