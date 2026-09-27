class_name GameSession
extends Node
## The UI's handle on a running game. Advances time at the chosen speed, executes the player's
## commands and remembers what is selected. Panels read from here and redraw on `changed`;
## they never modify simulation state themselves.

signal changed
signal message_posted(text: String)

## Selectable game speeds, as multipliers of HOURS_PER_SECOND. 0 is paused.
const SPEEDS: Array[int] = [0, 1, 2, 4]
## In-game hours per real second at 1× speed.
const HOURS_PER_SECOND: float = 2.0

var sim: Simulation
var speed: int = 1
var selected_city: String = ""
var selected_ship: String = ""
## The save slot used by the HUD's Save and Load buttons (tests point this elsewhere).
var save_slot: String = "quicksave"
## Units per click for trades and transfers, chosen in the market panel.
var trade_quantity: int = 1

var _pending_hours: float = 0.0


func start(data: GameData, seed_value: int) -> void:
	sim = Simulation.new_game(data, seed_value)
	selected_city = data.scenario.start_city
	var ships := sim.world.player().ships
	selected_ship = ships[0].id if not ships.is_empty() else ""
	changed.emit()


## Writes the running game to `save_slot`. Posts the outcome as a message.
func save_game() -> bool:
	var error := SaveGame.save_file(sim.world, SaveGame.path_for(save_slot))
	message_posted.emit("Game saved" if error.is_empty() else "Save failed: %s" % error)
	return error.is_empty()


## Replaces the running game with a saved one, if it loads cleanly. Posts the outcome.
func load_game() -> bool:
	var loader := SaveGame.new()
	var world := loader.load_file(sim.data, SaveGame.path_for(save_slot))
	if world == null:
		message_posted.emit("Load failed: %s" % loader.errors[0])
		return false
	sim = Simulation.new(sim.data, world)
	var ships := player().ships
	if player().get_ship(selected_ship) == null:
		selected_ship = ships[0].id if not ships.is_empty() else ""
	message_posted.emit("Game loaded (day %d)" % (sim.day() + 1))
	changed.emit()
	return true


func player() -> TraderState:
	return sim.world.player()


## Changes how fast time runs from now on. Time already accumulated towards the next hour is
## kept, so switching speeds never loses or stalls time.
func set_speed(value: int) -> void:
	assert(SPEEDS.has(value), "unsupported speed %d" % value)
	speed = value
	changed.emit()


## Runs `hours` ticks immediately, regardless of speed. Announces ships that arrive.
func advance(hours: int) -> void:
	var at_sea: Array[ShipState] = []
	for ship in player().ships:
		if not ship.is_docked():
			at_sea.append(ship)
	for i in hours:
		sim.tick()
	for ship in at_sea:
		if ship.is_docked():
			message_posted.emit("%s arrived in %s" % [ship.name, _city_name(ship.docked_at)])
	changed.emit()


## Executes a player command. Failures are posted as a message instead of changing anything.
func execute(command: Command) -> bool:
	var error := sim.execute(command)
	if error.is_empty():
		# A sold ship may have been the selected one.
		if player().get_ship(selected_ship) == null:
			selected_ship = player().ships[0].id if not player().ships.is_empty() else ""
		changed.emit()
		return true
	message_posted.emit(error)
	return false


## The player's ship that trades in the selected city: the selected ship if it is docked there,
## otherwise the first of the player's ships docked there. Null if there is none.
func trading_ship() -> ShipState:
	var selected := player().get_ship(selected_ship)
	if selected != null and selected.docked_at == selected_city:
		return selected
	for ship in player().ships:
		if ship.docked_at == selected_city:
			return ship
	return null


func select_city(city_id: String) -> void:
	selected_city = city_id
	changed.emit()


func select_ship(ship_id: String) -> void:
	selected_ship = ship_id
	changed.emit()


func _process(delta: float) -> void:
	if sim == null or speed == 0:
		return
	_pending_hours += delta * HOURS_PER_SECOND * speed
	var hours := floori(_pending_hours)
	if hours > 0:
		_pending_hours -= hours
		advance(hours)


func _city_name(city_id: String) -> String:
	return sim.data.get_city(city_id).name
