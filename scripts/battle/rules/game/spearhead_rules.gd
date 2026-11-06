class_name SpearheadRules
extends BattleRules
## Spearhead: a battlepack's battleplan, and its twist and battle tactic decks. There are no command
## points: a player's commands are on the cards in their hand.

## A full hand (Battle Tactic Cards).
const HAND_SIZE := 3
## How far behind a player has to be to draw after seizing the initiative.
const SEIZE_MARGIN := 5

## Each army's deck, hand and discards, by army, as arrays of [SpearheadTacticCard].
var decks := {}
var hands := {}
var _twists: Array[TwistCard] = []
## The current round's twist, or null.
var twist: TwistCard


func round_count() -> int:
	return game.battle.battlepack.battle_rounds


func scoring() -> PackedStringArray:
	return game.battle.battlepack.scoring


## Whose hand [param army] holds.
func hand_of(army: BattleArmy) -> Array:
	return hands.get(army, [])


func on_round_started() -> void:
	_prepare_decks()
	_draw_twist()
	var state := game.state
	for army in game.armies():
		var seized := state.round_number > 1 and army == state.first_this_round and army != state.first_last_round
		var behind := state.points_of(game.battle.enemy_of(army)) - state.points_of(army)
		if seized and not (army == state.underdog and behind >= SEIZE_MARGIN):
			continue
		_fill_hand(army)
	game.refresh_card_abilities()


func _prepare_decks() -> void:
	if not decks.is_empty():
		return
	var pack := game.battle.battlepack
	for army in game.armies():
		var deck: Array = pack.battle_tactic_cards.duplicate()
		_shuffle(deck)
		decks[army] = deck
		hands[army] = []
	if game.battle.realm:
		_twists = game.battle.realm.twists.duplicate()
		_shuffle(_twists)


## Shuffles with the battle's rng, so a seed gives the same battle.
func _shuffle(cards: Array) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := game.rng.randi_range(0, i)
		var swap: Variant = cards[i]
		cards[i] = cards[j]
		cards[j] = swap


func _draw_twist() -> void:
	twist = _twists.pop_back() if not _twists.is_empty() else null
	game.twist_picks = {}
	if twist == null:
		return
	var supported := SpearheadTwists.is_supported(twist)
	game.events.publish(BattleEvent.TWIST_DRAWN, {"twist": twist, "text": "Twist: %s. %s%s" % [twist.name, twist.text, "" if supported else " (Not applied yet.)"]})
	if supported:
		game.push(SpearheadTwists.new(twist))


func _fill_hand(army: BattleArmy) -> void:
	var hand: Array = hands[army]
	var deck: Array = decks[army]
	while hand.size() < HAND_SIZE and not deck.is_empty():
		hand.append(deck.pop_back())


## Takes [param card] out of [param army]'s hand, its command having been used or its tactic scored.
func discard(army: BattleArmy, card: SpearheadTacticCard) -> void:
	hands[army].erase(card)
	game.refresh_card_abilities()


## Scores the battle tactic cards completed, then the battleplan, whose last sentence counts them.
func score_turn(army: BattleArmy) -> void:
	for card: SpearheadTacticCard in hand_of(army).duplicate():
		if SpearheadTactics.is_complete(card, army, game):
			game.complete_tactic(army, card.name)
			discard(army, card)
	super(army)
	SpearheadTwists.on_scored(twist, army, game)


func on_round_ended() -> void:
	SpearheadTwists.on_round_ended(twist, game)
