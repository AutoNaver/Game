class_name RouteState
extends RefCounted
## A trade route: stops visited in order, looping back to the first (ADR 0007). Ships follow it
## through RouteSystem, which issues the same commands the player would.

## Engine limits that keep routes readable in the UI and cheap to run.
const MIN_STOPS: int = 2
const MAX_STOPS: int = 8
const MAX_ORDERS_PER_STOP: int = 6
const MAX_NAME_LENGTH: int = 32

var id: String
var name: String
var stops: Array[RouteStop] = []


func _init(p_id: String, p_name: String, p_stops: Array[RouteStop] = []) -> void:
	id = p_id
	name = p_name
	stops = p_stops


## The stop after `index`, looping back to the first.
func next_stop(index: int) -> int:
	return (index + 1) % stops.size()


## Returns "" if `name` and `stops` make a valid route for `data`, otherwise why not. Shared by
## SaveRouteCommand and save loading.
static func check(data: GameData, route_name: String, route_stops: Array[RouteStop]) -> String:
	if route_name.strip_edges().is_empty():
		return "Give the route a name"
	if route_name.length() > MAX_NAME_LENGTH:
		return "Route names can be at most %d characters" % MAX_NAME_LENGTH
	if route_stops.size() < MIN_STOPS or route_stops.size() > MAX_STOPS:
		return "A route needs %d to %d stops" % [MIN_STOPS, MAX_STOPS]
	for i in route_stops.size():
		var stop := route_stops[i]
		if not data.has_city(stop.city_id):
			return "Stop %d: unknown city '%s'" % [i + 1, stop.city_id]
		var next := route_stops[(i + 1) % route_stops.size()]
		if next.city_id == stop.city_id:
			var city := data.get_city(stop.city_id).name
			return "Stops %d and %d are both %s" % [i + 1, (i + 1) % route_stops.size() + 1, city]
		if stop.orders.size() > MAX_ORDERS_PER_STOP:
			return "Stop %d: at most %d orders" % [i + 1, MAX_ORDERS_PER_STOP]
		for order in stop.orders:
			if not data.has_good(order.good_id):
				return "Stop %d: unknown good '%s'" % [i + 1, order.good_id]
			if order.quantity <= 0:
				return "Stop %d: quantities must be positive" % (i + 1)
			if order.price_limit < 0:
				return "Stop %d: price limits can't be negative" % (i + 1)
	return ""
