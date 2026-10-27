class_name WeaponOptions
extends RefCounted
## How many models in a unit take each of its warscroll's [WeaponOption]s.


static func models(warscroll: Warscroll, reinforced: bool) -> int:
	return maxi(warscroll.unit_size, 1) * (2 if reinforced else 1)


## The most models that can take [param option], e.g. 2 for "1/5 models" in a reinforced unit of 10.
static func cap(option: WeaponOption, warscroll: Warscroll, reinforced: bool) -> int:
	var count := models(warscroll, reinforced)
	return count if option.choice else count / option.per * option.max


## The unit's count for [param option]: its cap until the player changes it, and never more.
static func value(unit: ArmyUnit, option: WeaponOption, warscroll: Warscroll) -> int:
	var limit := cap(option, warscroll, unit.reinforced)
	return mini(unit.weapon_options.get(option.name, limit), limit)


## Every option at its cap, for a new unit.
static func defaults(warscroll: Warscroll, reinforced := false) -> Dictionary:
	var result := {}
	for option in warscroll.weapon_options:
		result[option.name] = cap(option, warscroll, reinforced)
	return result


## Reinforces or unreinforces [param unit]. An option at its old cap moves to the new cap, so a
## unit that took every upgrade keeps doing so; any other count is kept, up to the new cap.
static func set_reinforced(unit: ArmyUnit, warscroll: Warscroll, reinforced: bool) -> void:
	for option in warscroll.weapon_options:
		var old_cap := cap(option, warscroll, unit.reinforced)
		var new_cap := cap(option, warscroll, reinforced)
		var current := value(unit, option, warscroll)
		unit.weapon_options[option.name] = new_cap if current == old_cap else mini(current, new_cap)
	unit.reinforced = reinforced
