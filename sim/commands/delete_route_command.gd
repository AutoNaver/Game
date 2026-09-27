class_name DeleteRouteCommand
extends Command
## Deletes a trade route. Ships on it stop following it wherever they are.

var trader_id: String
var route_id: String


func _init(p_trader_id: String, p_route_id: String) -> void:
	trader_id = p_trader_id
	route_id = p_route_id


func validate(sim: Simulation) -> String:
	var trader := sim.world.get_trader(trader_id)
	if trader == null:
		return "unknown trader '%s'" % trader_id
	if trader.get_route(route_id) == null:
		return "unknown route '%s'" % route_id
	return ""


func apply(sim: Simulation) -> void:
	var trader := sim.world.get_trader(trader_id)
	for ship in trader.ships:
		if ship.route_id == route_id:
			AssignRouteCommand.clear_route(ship)
	trader.routes.erase(trader.get_route(route_id))
