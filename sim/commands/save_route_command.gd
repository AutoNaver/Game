class_name SaveRouteCommand
extends Command
## Creates a trade route, or replaces an existing route's name and stops. Ships already on an
## edited route keep following it, from the same stop number if it still exists.

var trader_id: String
## "" to create a new route.
var route_id: String
var route_name: String
var stops: Array[RouteStop]


func _init(
	p_trader_id: String, p_route_id: String, p_route_name: String, p_stops: Array[RouteStop]
) -> void:
	trader_id = p_trader_id
	route_id = p_route_id
	route_name = p_route_name
	stops = p_stops


func validate(sim: Simulation) -> String:
	var trader := sim.world.get_trader(trader_id)
	if trader == null:
		return "unknown trader '%s'" % trader_id
	if not route_id.is_empty() and trader.get_route(route_id) == null:
		return "unknown route '%s'" % route_id
	var locked := RankSystem.unlock_error(sim.data, trader, RankDef.ROUTES, "Trade routes")
	if not locked.is_empty():
		return locked
	return RouteState.check(sim.data, route_name, stops)


func apply(sim: Simulation) -> void:
	var trader := sim.world.get_trader(trader_id)
	# Copies, so the caller (the route editor) can't change a saved route behind the simulation.
	var copies: Array[RouteStop] = []
	for stop in stops:
		copies.append(stop.duplicate_stop())
	if route_id.is_empty():
		sim.world.add_route(trader, route_name.strip_edges(), copies)
		return
	var route := trader.get_route(route_id)
	route.name = route_name.strip_edges()
	route.stops = copies
	for ship in trader.ships:
		if ship.route_id == route_id:
			ship.route_stop = ship.route_stop % copies.size()
