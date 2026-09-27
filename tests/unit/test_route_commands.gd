extends GutTest
## Creating, editing, deleting and assigning trade routes (SaveRouteCommand, DeleteRouteCommand,
## AssignRouteCommand).

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID
const SHIP := SmallWorld.SHIP_ID

var _sim: Simulation


func before_each() -> void:
	_sim = SmallWorld.simulation()


func _stops(city_ids: Array[String]) -> Array[RouteStop]:
	var stops: Array[RouteStop] = []
	for city_id in city_ids:
		stops.append(RouteStop.new(city_id, [RouteOrder.new(RouteOrder.Action.BUY, "grain", 5)]))
	return stops


func _save(route_id: String, route_name: String, stops: Array[RouteStop]) -> String:
	return _sim.execute(SaveRouteCommand.new(PLAYER, route_id, route_name, stops))


func _player() -> TraderState:
	return _sim.world.player()


func test_saving_a_route_creates_a_copy_with_the_next_id() -> void:
	var stops := _stops(["port", "town"])
	assert_eq(_save("", "  Grain run ", stops), "")
	var route := _player().get_route("route_1")
	assert_eq(route.name, "Grain run")
	assert_eq(_sim.world.next_route_number, 2)
	stops[0].orders[0].quantity = 99
	stops.append(RouteStop.new("port"))
	assert_eq(route.stops.size(), 2, "the saved route is a copy")
	assert_eq(route.stops[0].orders[0].quantity, 5)


func test_invalid_routes_are_refused() -> void:
	var cases: Dictionary[String, Array] = {
		"Give the route a name": ["  ", _stops(["port", "town"])],
		"A route needs 2 to 8 stops": ["R", _stops(["port"])],
		"Stops 3 and 1 are both Port": ["R", _stops(["port", "town", "port"])],
		"Stop 2: unknown city 'riga'": ["R", _stops(["port", "riga"])],
	}
	for expected: String in cases:
		assert_eq(_save("", cases[expected][0], cases[expected][1]), expected)
	var bad_good := _stops(["port", "town"])
	bad_good[1].orders[0].good_id = "amber"
	assert_eq(_save("", "R", bad_good), "Stop 2: unknown good 'amber'")
	var bad_quantity := _stops(["port", "town"])
	bad_quantity[0].orders[0].quantity = 0
	assert_eq(_save("", "R", bad_quantity), "Stop 1: quantities must be positive")
	var bad_limit := _stops(["port", "town"])
	bad_limit[0].orders[0].price_limit = -1
	assert_eq(_save("", "R", bad_limit), "Stop 1: price limits can't be negative")
	assert_eq(_save("route_9", "R", _stops(["port", "town"])), "unknown route 'route_9'")
	assert_eq(_player().routes.size(), 0)


func test_editing_a_route_keeps_ships_on_a_valid_stop() -> void:
	_save("", "Long", _stops(["port", "town", "port", "town"]))
	assert_eq(_sim.execute(AssignRouteCommand.new(PLAYER, SHIP, "route_1", 3)), "")
	assert_eq(_save("route_1", "Short", _stops(["town", "port"])), "")
	var ship := _player().get_ship(SHIP)
	assert_eq(ship.route_id, "route_1")
	assert_eq(ship.route_stop, 1, "stop 4 of 4 becomes stop 2 of 2")
	assert_eq(_player().get_route("route_1").name, "Short")


func test_assigning_and_clearing_a_route() -> void:
	_save("", "Run", _stops(["port", "town"]))
	assert_eq(_sim.execute(AssignRouteCommand.new(PLAYER, SHIP, "route_1", 2)), "Run has no stop 3")
	assert_eq(
		_sim.execute(AssignRouteCommand.new(PLAYER, SHIP, "route_7")), "unknown route 'route_7'"
	)
	assert_eq(_sim.execute(AssignRouteCommand.new(PLAYER, SHIP, "")), "Test follows no route")
	assert_eq(_sim.execute(AssignRouteCommand.new(PLAYER, SHIP, "route_1", 1)), "")
	var ship := _player().get_ship(SHIP)
	assert_eq([ship.route_id, ship.route_stop], ["route_1", 1])
	ship.route_note = "old news"
	assert_eq(_sim.execute(AssignRouteCommand.new(PLAYER, SHIP, "")), "")
	assert_eq([ship.route_id, ship.route_stop, ship.route_note], ["", 0, ""])


func test_deleting_a_route_takes_its_ships_off_it() -> void:
	_save("", "Run", _stops(["port", "town"]))
	_sim.execute(AssignRouteCommand.new(PLAYER, SHIP, "route_1"))
	assert_eq(_sim.execute(DeleteRouteCommand.new(PLAYER, "route_1")), "")
	assert_eq(_player().routes.size(), 0)
	assert_eq(_player().get_ship(SHIP).route_id, "")
	assert_eq(_sim.execute(DeleteRouteCommand.new(PLAYER, "route_1")), "unknown route 'route_1'")
