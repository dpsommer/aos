class_name DeploymentAbility
extends RefCounted
## An ability an army can use in the deployment phase: a universal one ('Deploy Unit', 'Deploy
## Regiment', 'Deploy Faction Terrain'), or one of its own with the DEPLOY or DEPLOY TERRAIN
## keyword or the "Deployment Phase" timing. See docs/gameplay/deployment.md.

## The deployment step the ability is used in.
enum Step { TERRAIN, UNITS, OTHER }
## What using it does here.
enum Kind {
	## 'Deploy Unit': set up one unit.
	DEPLOY_UNIT,
	## 'Deploy Regiment': set up a whole regiment without alternating.
	DEPLOY_REGIMENT,
	## 'Deploy Faction Terrain': set up one faction terrain feature.
	DEPLOY_TERRAIN,
	## A DEPLOY ability that sets units up in reserve.
	RESERVE,
	## Any other deployment phase ability: its use is recorded, its effect not applied yet.
	RECORD,
	## A DEPLOY or DEPLOY TERRAIN ability the simulator can't use yet.
	UNSUPPORTED,
}

const TIMING := "Deployment Phase"
const UNIVERSAL := "Universal"
const DEPLOY_UNIT := "Deploy Unit"
const DEPLOY_REGIMENT := "Deploy Regiment"
const DEPLOY_FACTION_TERRAIN := "Deploy Faction Terrain"
## The reserve's name when the effect doesn't give one.
const DEFAULT_RESERVE := "in reserve"

var ability: Ability
## Where it comes from, e.g. "Universal", "Battle trait" or "Warscroll".
var source: String
## The unit whose warscroll or enhancement has it, or null.
var owner: BattleUnit
## The Regiment of Renown it belongs to, or null: its targets are that regiment's units.
var regiment: BattleRegiment

static var _reserve_pattern: RegEx


static func create(of: Ability, from: String, unit: BattleUnit = null, renown: BattleRegiment = null) -> DeploymentAbility:
	var result := DeploymentAbility.new()
	result.ability = of
	result.source = from
	result.owner = unit
	result.regiment = renown
	return result


## Whether [param of] is used in the deployment phase.
static func is_deployment(of: Ability) -> bool:
	return of != null and (of.timing == TIMING or "DEPLOY" in of.keywords or "DEPLOY TERRAIN" in of.keywords)


func name() -> String:
	return ability.name


func step() -> Step:
	if "DEPLOY TERRAIN" in ability.keywords:
		return Step.TERRAIN
	if "DEPLOY" in ability.keywords:
		return Step.UNITS
	return Step.OTHER


func kind() -> Kind:
	if source == UNIVERSAL:
		match ability.name:
			DEPLOY_UNIT:
				return Kind.DEPLOY_UNIT
			DEPLOY_REGIMENT:
				return Kind.DEPLOY_REGIMENT
			DEPLOY_FACTION_TERRAIN:
				return Kind.DEPLOY_TERRAIN
	match step():
		Step.OTHER:
			return Kind.RECORD
		Step.UNITS:
			if ability.effect.to_lower().contains("in reserve"):
				return Kind.RESERVE
	return Kind.UNSUPPORTED


## The reserve the ability's targets go into, e.g. "in the clouds" for "Set up all of those units
## in reserve in the clouds.", or "in reserve" if the effect doesn't name one.
func reserve_name() -> String:
	if _reserve_pattern == null:
		_reserve_pattern = RegEx.create_from_string("(?i)in reserve ([^.,;:!]+)")
	var found := _reserve_pattern.search(ability.effect)
	if found == null:
		return DEFAULT_RESERVE
	var words := found.get_string(1).strip_edges()
	# Stop at a following clause, e.g. "stalking the prey or set up this unit...".
	for joiner in [" or ", " and ", " then ", " using "]:
		var at := words.find(joiner)
		if at > 0:
			words = words.substr(0, at)
	# Not a name: "...in reserve and cannot be targeted", "...in reserve – even your army".
	for not_a_name in ["and ", "to ", "–", "-"]:
		if words.begins_with(not_a_name):
			return DEFAULT_RESERVE
	return words


## Whether it can only be used once per battle.
func is_once_per_battle() -> bool:
	return ability.frequency.to_lower().begins_with("once per battle")


## Whether once per battle is for the whole army ("Once Per Battle (Army)") rather than per unit.
func is_once_per_army() -> bool:
	return ability.frequency.to_lower().contains("(army)")


## Whether its only target is its own unit: a warscroll ability that says "this unit".
func targets_owner() -> bool:
	return owner != null and (ability.declare.to_lower().contains("this unit") or ability.declare.is_empty())


## The copy of this ability in a mirrored army: [param units] maps this army's units to the copy's,
## [param regiments] its regiments.
func mirrored(units: Dictionary, regiments: Dictionary) -> DeploymentAbility:
	return create(ability, source, units.get(owner) if owner else null, regiments.get(regiment) if regiment else null)


## "Deploy Unit", or "Hidden Hunters (Saurus Hunters)" for a unit's own ability.
func label() -> String:
	return "%s (%s)" % [ability.name, owner.name] if owner else ability.name
