class_name GameSession
extends Node
## The UI's handle on a running game. Advances time at the chosen speed, executes the player's
## commands and remembers what is selected. Panels read from here and redraw on `changed`;
## they never modify simulation state themselves.

signal changed
signal message_posted(text: String)
## A new entry in the notification log (already dated).
signal notified(entry: String)

## Selectable game speeds, as multipliers of HOURS_PER_SECOND. 0 is paused.
const SPEEDS: Array[int] = [0, 1, 2, 4]
## In-game hours per real second at 1× speed.
const HOURS_PER_SECOND: float = 2.0
## Notification log entries kept.
const MAX_LOG: int = 50

var sim: Simulation
var speed: int = 1
var selected_city: String = ""
var selected_ship: String = ""
## The save slot used by the HUD's Save and Load buttons (tests point this elsewhere).
var save_slot: String = "quicksave"
## Units per click for trades and transfers, chosen in the market panel.
var trade_quantity: int = 1
## Pause the game when one of the player's ships arrives, so arrivals aren't missed at speed.
var pause_on_arrival: bool = true
## Dated notifications, oldest first: arrivals and workshops that stopped. Kept for the session;
## the last MAX_LOG entries only.
var notification_log: PackedStringArray = []

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


## Runs `hours` ticks immediately, regardless of speed. Notifies about ships that arrive and
## workshops that stop working, and pauses on arrivals if pause_on_arrival is set.
func advance(hours: int) -> void:
	var at_sea: Array[ShipState] = []
	for ship in player().ships:
		if not ship.is_docked():
			at_sea.append(ship)
	var statuses := _workshop_statuses()
	for i in hours:
		sim.tick()
	var arrived := false
	for ship in at_sea:
		if ship.is_docked():
			arrived = true
			notify("%s arrived in %s" % [ship.name, _city_name(ship.docked_at)])
	_notify_stopped_workshops(statuses)
	if arrived and pause_on_arrival and speed != 0:
		speed = 0
		_pending_hours = 0.0
	changed.emit()


## Adds a dated entry to the notification log and shows it as the latest message.
func notify(text: String) -> void:
	var entry := "Day %d: %s" % [sim.day() + 1, text]
	notification_log.append(entry)
	if notification_log.size() > MAX_LOG:
		notification_log = notification_log.slice(notification_log.size() - MAX_LOG)
	message_posted.emit(text)
	notified.emit(entry)


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


## "status/missing good" per workshop id of the player's, to spot changes across a step.
func _workshop_statuses() -> Dictionary[String, String]:
	var statuses: Dictionary[String, String] = {}
	for kontor in player().kontors_in_order(sim.data.cities):
		for workshop in kontor.workshops:
			statuses[workshop.id] = "%d/%s" % [workshop.status, workshop.missing_good]
	return statuses


## Notifies once when a workshop goes idle, or idles for a different reason than before.
func _notify_stopped_workshops(before: Dictionary[String, String]) -> void:
	var idle: Array[WorkshopState.Status] = [
		WorkshopState.Status.NO_INPUTS,
		WorkshopState.Status.KONTOR_FULL,
		WorkshopState.Status.UNPAID,
	]
	for kontor in player().kontors_in_order(sim.data.cities):
		for workshop in kontor.workshops:
			var now := "%d/%s" % [workshop.status, workshop.missing_good]
			if not idle.has(workshop.status) or before.get(workshop.id, now) == now:
				continue
			var workshop_type := sim.data.get_workshop(workshop.type_id)
			var status := KontorPanel.status_text(sim.data, workshop)
			notify("%s in %s: %s" % [workshop_type.name, _city_name(kontor.city_id), status])


func _city_name(city_id: String) -> String:
	return sim.data.get_city(city_id).name
