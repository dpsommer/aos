class_name CampaignBattle
extends Resource
## One battle of a [SpearheadCampaign]: the side of the realm battlefield it is fought on, its own
## territories and its rules.

@export var name: String
## Name of the [RealmBattlefield] the battle is fought on.
@export var realm: String
## The battle's rules, e.g. who picks the starting relics.
@export var text: String
## Starting relics that replace the realm's. Empty if the realm's are used or [member text] says
## how they are picked.
@export var starting_relics: PackedStringArray
## The battle's territories. When [member fixed_territories] is true, territory A is the attacker's
## and B the defender's; otherwise the defender chooses.
@export var deployment_map: DeploymentMap
@export var fixed_territories: bool
