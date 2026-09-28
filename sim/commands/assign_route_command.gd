class_name AssignRouteCommand
extends Command
## Puts a ship on one of its owner's trade routes, starting at `start_stop`, or takes it off its
## route (route_id ""). A ship at sea finishes its voyage first; RouteSystem then sends it on.

var trader_id: String
var ship_id: String
var route_id: String
var start_stop: int


func _init(
	p_trader_id: String, p_ship_id: String, p_route_id: String, p_start_stop: int = 0
) -> void:
	trader_id = p_trader_id
	ship_id = p_ship_id
	route_id = p_route_id
	start_stop = p_start_stop


func validate(sim: Simulation) -> String:
	var ship := Command.find_ship(sim, trader_id, ship_id)
	if ship == null:
		return "unknown ship '%s'" % ship_id
	if route_id.is_empty():
		return "" if not ship.route_id.is_empty() else "%s follows no route" % ship.name
	var trader := sim.world.get_trader(trader_id)
	var locked := RankSystem.unlock_error(sim.data, trader, RankDef.ROUTES, "Trade routes")
	if not locked.is_empty():
		return locked
	var route := trader.get_route(route_id)
	if route == null:
		return "unknown route '%s'" % route_id
	if start_stop < 0 or start_stop >= route.stops.size():
		return "%s has no stop %d" % [route.name, start_stop + 1]
	return ""


func apply(sim: Simulation) -> void:
	var ship := Command.find_ship(sim, trader_id, ship_id)
	if route_id.is_empty():
		clear_route(ship)
		return
	ship.route_id = route_id
	ship.route_stop = start_stop
	ship.route_note = ""


static func clear_route(ship: ShipState) -> void:
	ship.route_id = ""
	ship.route_stop = 0
	ship.route_note = ""
