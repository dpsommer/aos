class_name SpearheadCampaign
extends Resource
## A Spearhead mini campaign: linked battles played in order with a battlepack's rules, e.g. City of
## Ash's "Hidden in the Ashes".

@export var name: String
## The campaign's rules, e.g. "Rules Changes" and "Total Victory Points".
@export var sections: Array[RulesSection]
## The battles in the order they are played.
@export var battles: Array[CampaignBattle]
