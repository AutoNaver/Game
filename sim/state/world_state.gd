class_name WorldState
extends RefCounted
## Everything in the world that changes over time. The single source of randomness lives here.

const PLAYER_ID: String = "player"

## Hours elapsed since the game started; one tick is one hour.
var hour: int = 0
## Seeded once per game. Systems must draw from this, never from the global RNG.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## In GameData city order.
var cities: Array[CityState] = []
## The player first; AI traders later.
var traders: Array[TraderState] = []
## Ship ids are "ship_<n>", numbered in creation order so they are stable and deterministic.
var next_ship_number: int = 1

var _cities_by_id: Dictionary[String, CityState] = {}


func add_city(city: CityState) -> void:
	assert(not _cities_by_id.has(city.id), "duplicate city id '%s'" % city.id)
	cities.append(city)
	_cities_by_id[city.id] = city


## Returns null for unknown ids.
func get_city(id: String) -> CityState:
	return _cities_by_id.get(id)


## Returns null for unknown ids.
func get_trader(id: String) -> TraderState:
	for trader in traders:
		if trader.id == id:
			return trader
	return null


func player() -> TraderState:
	return get_trader(PLAYER_ID)


## Creates a docked ship with the next free id and gives it to `trader`.
func add_ship(
	trader: TraderState, type_id: String, ship_name: String, city_id: String
) -> ShipState:
	var ship := ShipState.new("ship_%d" % next_ship_number, type_id, ship_name, city_id)
	next_ship_number += 1
	trader.ships.append(ship)
	return ship
