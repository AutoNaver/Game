extends GutTest
## Trade routes in save files (save version 3): exact round trips, migration from version 2, and
## rejection of broken routes.

const SmallWorld := preload("res://tests/support/small_world.gd")
const PLAYER := WorldState.PLAYER_ID


## A world with a route, a ship on it mid-voyage, and a second route nobody uses.
func _routed_simulation() -> Simulation:
	var sim := SmallWorld.simulation(3)
	var port_orders: Array[RouteOrder] = [
		RouteOrder.new(RouteOrder.Action.BUY, "grain", 10, 60),
		RouteOrder.new(RouteOrder.Action.UNLOAD, "wine", 5),
	]
	var town_orders: Array[RouteOrder] = [RouteOrder.new(RouteOrder.Action.SELL, "grain", 10, 30)]
	var stops: Array[RouteStop] = [
		RouteStop.new("port", port_orders), RouteStop.new("town", town_orders)
	]
	assert_eq(sim.execute(SaveRouteCommand.new(PLAYER, "", "Grain run", stops)), "")
	assert_eq(sim.execute(SaveRouteCommand.new(PLAYER, "", "Spare", stops)), "")
	assert_eq(sim.execute(AssignRouteCommand.new(PLAYER, SmallWorld.SHIP_ID, "route_1")), "")
	sim.advance_days(1)
	sim.tick()
	return sim


func _through_json(save: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(save)) as Dictionary


func _errors(sim: Simulation, save: Dictionary) -> Array:
	var loader := SaveGame.new()
	assert_null(loader.from_dict(sim.data, save))
	return Array(loader.errors)


func test_routes_round_trip_exactly() -> void:
	var sim := _routed_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	var loader := SaveGame.new()
	var world := loader.from_dict(sim.data, save)
	assert_eq(Array(loader.errors), [])
	assert_eq(_through_json(SaveGame.to_dict(world)), save)
	var route := world.player().get_route("route_1")
	assert_eq(
		[route.name, route.stops.size(), route.stops[0].orders[0].price_limit], ["Grain run", 2, 60]
	)
	assert_eq(world.player().get_ship(SmallWorld.SHIP_ID).route_id, "route_1")
	assert_eq(world.next_route_number, 3)


func test_a_loaded_route_carries_on_identically() -> void:
	var sim := _routed_simulation()
	var loaded := Simulation.new(
		sim.data, SaveGame.new().from_dict(sim.data, _through_json(SaveGame.to_dict(sim.world)))
	)
	sim.advance_days(5)
	loaded.advance_days(5)
	assert_eq(SaveGame.to_dict(loaded.world), SaveGame.to_dict(sim.world))


func test_version_2_saves_load_without_routes() -> void:
	var sim := SmallWorld.simulation(3)
	var save := _through_json(SaveGame.to_dict(sim.world))
	save["save_version"] = 2
	save.erase("next_route_number")
	for trader: Dictionary in save["traders"]:
		trader.erase("routes")
		for ship: Dictionary in trader["ships"]:
			for field: String in ["route", "route_stop", "route_note"]:
				ship.erase(field)
	var loader := SaveGame.new()
	var world := loader.from_dict(sim.data, save)
	assert_eq(Array(loader.errors), [])
	assert_eq(world.player().routes.size(), 0)
	assert_eq(world.next_route_number, 1)
	assert_eq(world.player().get_ship(SmallWorld.SHIP_ID).route_id, "")


func test_broken_routes_are_rejected() -> void:
	var sim := _routed_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	var trader: Dictionary = save["traders"][0]
	trader["routes"][1]["stops"][0]["orders"][0]["action"] = "PLUNDER"
	trader["routes"][1]["stops"].pop_back()
	trader["ships"][0]["route_stop"] = 5
	assert_eq(
		_errors(sim, save),
		[
			"traders[0] routes[1] stops[0] orders[0]: unknown action 'PLUNDER'",
			"traders[0] routes[1]: A route needs 2 to 8 stops",
			"traders[0] ships[0]: route_stop 5 outside the route",
		]
	)


func test_route_references_and_ids_are_checked() -> void:
	var sim := _routed_simulation()
	var save := _through_json(SaveGame.to_dict(sim.world))
	var trader: Dictionary = save["traders"][0]
	trader["ships"][0]["route"] = "route_9"
	trader["routes"][1]["id"] = "route_1"
	save["next_route_number"] = 2
	assert_eq(
		_errors(sim, save),
		[
			"traders[0] ships[0]: unknown route 'route_9'",
			"duplicate route id 'route_1'",
		]
	)
	var unused := _through_json(SaveGame.to_dict(sim.world))
	unused["traders"][0]["ships"][0]["route"] = ""
	assert_eq(_errors(sim, unused), ["traders[0] ships[0]: route_stop and route_note need a route"])


func test_ids_must_have_the_shape_the_game_creates() -> void:
	var sim := _routed_simulation()
	sim.world.player().coins = 5000
	assert_eq(sim.execute(BuyKontorCommand.new(PLAYER, "port")), "")
	assert_eq(sim.execute(BuildWorkshopCommand.new(PLAYER, "port", "vintner")), "")
	var save := _through_json(SaveGame.to_dict(sim.world))
	var trader: Dictionary = save["traders"][0]
	trader["routes"][1]["id"] = "foo/bar_0"
	trader["ships"][0]["id"] = "route_9"
	trader["kontors"][0]["workshops"][0]["id"] = "workshop_01"
	assert_eq(
		_errors(sim, save),
		[
			"ship id 'route_9' is not of the form ship_<number>",
			"workshop id 'workshop_01' is not of the form workshop_<number>",
			"route id 'foo/bar_0' is not of the form route_<number>",
		]
	)
