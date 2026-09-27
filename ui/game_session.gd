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

var _pending_hours: float = 0.0


func start(data: GameData, seed_value: int) -> void:
	sim = Simulation.new_game(data, seed_value)
	selected_city = data.scenario.start_city
	var ships := sim.world.player().ships
	selected_ship = ships[0].id if not ships.is_empty() else ""
	changed.emit()


func player() -> TraderState:
	return sim.world.player()


## Changes how fast time runs from now on. Time already accumulated towards the next hour is
## kept, so switching speeds never loses or stalls time.
func set_speed(value: int) -> void:
	assert(SPEEDS.has(value), "unsupported speed %d" % value)
	speed = value
	changed.emit()


## Runs `hours` ticks immediately, regardless of speed.
func advance(hours: int) -> void:
	for i in hours:
		sim.tick()
	changed.emit()


## Executes a player command. Failures are posted as a message instead of changing anything.
func execute(command: Command) -> bool:
	var error := sim.execute(command)
	if error.is_empty():
		changed.emit()
		return true
	message_posted.emit(error)
	return false


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
