class_name UnitController
extends BattlefieldController
## One unit in the battle: the only thing that changes its state. It answers [Commands] and listens
## to the battle's events to reset what only lasts a turn. It doesn't know who commands it: the player
## and the AI act on it the same way, through the [GameController]. [member unit] stays the geometry
## the map draws.

var unit: BattleUnit
var army: BattleArmy
## Whether it's a faction terrain feature fighting as a unit (Terrain 1.5).
var is_terrain := false
## Damage points allocated and not yet enough to slay a model (Core Rules 18.2).
var damage_points := 0
## What it's done this turn.
var charged := false
var ran := false
var retreated := false
var moved := false
## The turn it last used a FIGHT ability, or -1.
var fought_serial := -1
## The turn it was set up on the battlefield, or -1 (deployment doesn't count: Core Rules 24.0).
var set_up_serial := -1

var _counters := {}


func _init(on: GameController, of: BattleUnit, in_army: BattleArmy) -> void:
	super(on)
	unit = of
	army = in_army
	characteristics = CharacteristicsController.from_warscroll(of.warscroll)
	on.events.subscribe(BattleEvent.TURN_STARTED, _on_turn_started)


func _on_turn_started(_event: BattleEvent) -> void:
	charged = false
	ran = false
	retreated = false
	moved = false


## The value of a counter, e.g. Ironjawz' momentum.
func counter(counter_name: Variant) -> int:
	return _counters.get(StringName(counter_name), 0)


func handle(command: RefCounted) -> String:
	if command is Commands.DealDamage:
		_take_damage(command)
	elif command is Commands.Heal:
		_heal(command.points)
	elif command is Commands.MoveModels:
		_move(command)
	elif command is Commands.ReturnModels:
		_return_models(command.count)
	elif command is Commands.SetUp:
		_set_up(command.positions)
	elif command is Commands.Remove:
		_remove(command.reserve_name)
	elif command is Commands.Destroy:
		_destroy(command.source_army)
	elif command is Commands.ChangeCounter:
		_counters[command.counter_name] = counter(command.counter_name) + command.by
	else:
		return super(command)
	return ""


# The damage sequence (Core Rules 18.0)

func _take_damage(command: Commands.DealDamage) -> void:
	if unit.destroyed or command.points <= 0:
		return
	var pool: int = command.points
	var ward := game.stats.value(unit, &"ward")
	var warded := 0
	if ward > 0 and not game.stats.is_forbidden(unit, &"ward_rolls"):
		for _i in pool:
			if game.rng.randi_range(1, 6) >= ward:
				warded += 1
		pool -= warded
	var health := maxi(game.stats.value(unit, &"health"), 1)
	var slain := 0
	for _i in pool:
		damage_points += 1
		if damage_points < health:
			continue
		damage_points = 0
		slain += _slay_one()
		if unit.destroyed:
			break
	game.events.publish(BattleEvent.UNIT_DAMAGED, {
		"unit": unit, "points": pool, "warded": warded, "slain": slain, "source_army": command.source_army,
		"text": "%s takes %d damage%s%s." % [unit.name, pool, " (%d warded)" % warded if warded > 0 else "",
				", %d slain" % slain if slain > 0 else ""],
	})
	if unit.destroyed:
		_on_destroyed(command.source_army)


## Slays the model the commander would pick, then any more it takes to stay coherent (18.3): the
## one furthest from the enemy that leaves the rest coherent. Returns how many died.
func _slay_one() -> int:
	var slain := 1
	_remove_model(_model_to_slay())
	while not unit.destroyed:
		var failing := Coherency.failing(unit.positions, unit.bases, unit.facing)
		if failing.is_empty():
			break
		_remove_model(_furthest_of(failing))
		slain += 1
	return slain


func _remove_model(index: int) -> void:
	var at := unit.positions[index]
	unit.remove_model(index)
	game.events.publish(BattleEvent.MODEL_SLAIN, {"unit": unit, "at": at, "text": "A model of %s is slain." % unit.name})


func _model_to_slay() -> int:
	var count := unit.model_count()
	var keeps := PackedInt32Array()
	for i in count:
		var positions := unit.positions.duplicate()
		var bases := unit.bases.duplicate()
		positions.remove_at(i)
		bases.remove_at(i)
		if Coherency.is_coherent(positions, bases, unit.facing):
			keeps.append(i)
	if keeps.is_empty():
		for i in count:
			keeps.append(i)
	return _furthest_of(keeps)


## Of the models at [param indices], the one furthest from the nearest enemy.
func _furthest_of(indices: PackedInt32Array) -> int:
	var enemies := game.enemies_on_battlefield(army)
	var best := indices[0]
	var best_gap := -INF
	for i in indices:
		var gap := INF
		for enemy in enemies:
			gap = minf(gap, BattleGeometry.model_gap(unit, i, enemy))
		if gap > best_gap:
			best = i
			best_gap = gap
	return best


func _destroy(source: BattleArmy) -> void:
	if unit.destroyed:
		return
	while not unit.bases.is_empty():
		_remove_model(unit.bases.size() - 1)
	_on_destroyed(source)


func _on_destroyed(source: BattleArmy) -> void:
	game.events.publish(BattleEvent.UNIT_DESTROYED, {"unit": unit, "army": army, "source_army": source, "text": "%s is destroyed." % unit.name})


# Healing, moving and setting up

func _heal(points: int) -> void:
	var healed := mini(points, damage_points)
	damage_points -= healed
	if healed > 0:
		game.events.publish(BattleEvent.UNIT_HEALED, {"unit": unit, "points": healed, "text": "%s heals %d." % [unit.name, healed]})


func _move(command: Commands.MoveModels) -> void:
	var spec: MoveSpec = command.spec
	unit.positions = command.positions
	moved = true
	match spec.kind:
		MoveSpec.Kind.RUN:
			ran = true
		MoveSpec.Kind.RETREAT:
			retreated = true
		MoveSpec.Kind.CHARGE:
			charged = true
	game.events.publish(BattleEvent.UNIT_MOVED, {"unit": unit, "kind": spec.kind, "text": "%s %s." % [unit.name, spec.verb()]})


## Returns slain models in reach of the unit (22.0). They go next to the first model with room.
func _return_models(count: int) -> void:
	for _i in count:
		if unit.slain_bases.is_empty() or unit.positions.is_empty():
			return
		var base: BaseSize = unit.slain_bases[-1]
		var spot: Variant = MovementRules.spot_beside(game, unit, base)
		if spot == null:
			return
		unit.return_model(spot)
		game.events.publish(BattleEvent.MODEL_RETURNED, {"unit": unit, "at": spot, "text": "A slain model returns to %s." % unit.name})


func _set_up(positions: PackedVector2Array) -> void:
	unit.positions = positions
	unit.deployed = true
	unit.reserve = ""
	set_up_serial = game.state.turn_serial
	game.events.publish(BattleEvent.UNIT_SET_UP, {"unit": unit, "text": "%s is set up." % unit.name})


func _remove(reserve_name: String) -> void:
	unit.positions = PackedVector2Array()
	unit.reserve = reserve_name
	game.events.publish(BattleEvent.UNIT_SET_UP, {"unit": unit, "text": "%s leaves the battlefield." % unit.name})
