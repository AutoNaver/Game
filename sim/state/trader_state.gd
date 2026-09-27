class_name TraderState
extends RefCounted
## A trading house: the player or an AI rival (RivalDef, RivalSystem). Both act only through
## commands.

var id: String
var name: String
## Never negative.
var coins: int
var ships: Array[ShipState] = []
## Kontors by city id. Iterate with kontors_in_order() so the order never depends on the dictionary.
var kontors: Dictionary[String, KontorState] = {}
## Trade routes, in creation order.
var routes: Array[RouteState] = []
## Last observed or reported market for each city. Read through this book when planning.
var market_book: Dictionary[String, MarketRecord] = {}


func _init(p_id: String, p_name: String, p_coins: int) -> void:
	id = p_id
	name = p_name
	coins = p_coins


## Returns null if this trader has no ship with that id.
func get_ship(ship_id: String) -> ShipState:
	for ship in ships:
		if ship.id == ship_id:
			return ship
	return null


func remove_ship(ship_id: String) -> void:
	for i in ships.size():
		if ships[i].id == ship_id:
			ships.remove_at(i)
			return


## Returns null if this trader has no route with that id.
func get_route(route_id: String) -> RouteState:
	for route in routes:
		if route.id == route_id:
			return route
	return null


## Returns null if the trader has no kontor in that city.
func get_kontor(city_id: String) -> KontorState:
	return kontors.get(city_id)


## The trader's kontors in the order of `cities` (GameData order), so iteration is deterministic.
func kontors_in_order(cities: Array[CityDef]) -> Array[KontorState]:
	var ordered: Array[KontorState] = []
	for city in cities:
		if kontors.has(city.id):
			ordered.append(kontors[city.id])
	return ordered
