class_name BattleRegiment
extends RefCounted
## A regiment on the battlefield: its units, which 'Deploy Regiment' sets up together. See
## docs/gameplay/deployment.md.

var name: String
var units: Array[BattleUnit] = []
## Whether it's a Regiment of Renown.
var is_renown := false


## Whether any of its units has been deployed.
func any_deployed() -> bool:
	for unit in units:
		if unit.deployed:
			return true
	return false


## Whether all its units have been deployed.
func all_deployed() -> bool:
	for unit in units:
		if not unit.deployed:
			return false
	return true
