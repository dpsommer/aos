class_name Battlepack
extends Resource
## The matched play battlepack from the current General's Handbook: its rules, season rules,
## battle tactics cards and battleplans.

@export var name: String
## The Scourge expansion whose seasonal rules this battlepack uses, e.g. "Scourge of Aqshy". Rules
## from any other Scourge (a [code]source[/code] such as "Scourge of Ghyran") are Legends with it.
@export var scourge: String
@export var battle_rounds: int
## Recommended battlefield size in inches: width (x) by depth (y).
@export var battlefield_size: Vector2
## Rules of the battlepack itself, e.g. "Glorious Victory".
@export var sections: Array[RulesSection]
## Battleplan names in each table, indexed by table number minus 1, then D6 roll minus 1.
@export var battleplan_tables: Array[PackedStringArray]
## Abilities both players can use in every battle, e.g. 'Eruption of Fury'.
@export var season_rules: Array[Ability]
## Rulings on the battlepack and season rules, each {"about": String, "question": String,
## "answer": String}.
@export var faqs: Array[Dictionary]
## Rules for battle tactics, e.g. "2.0 Seizing the Initiative".
@export var battle_tactic_rules: Array[RulesSection]
@export var battle_tactic_cards: Array[BattleTacticCard]
## Rules for battleplan maps.
@export var battleplan_rules: Array[RulesSection]
@export var battleplans: Array[Battleplan]


func get_battleplan(battleplan_name: String) -> Battleplan:
	for battleplan in battleplans:
		if battleplan.name == battleplan_name:
			return battleplan
	return null


func get_battle_tactic_card(card_name: String) -> BattleTacticCard:
	for card in battle_tactic_cards:
		if card.name == card_name:
			return card
	return null
