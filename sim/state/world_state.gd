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
## Units of each good that should exist in the world: starting stock plus everything produced
## minus everything consumed. Trading only moves goods, so the actual total must always match
## (checked by EconomyInvariants).
var goods_ledger: Dictionary[String, int] = {}
## The player first, then the rival houses in data order.
var traders: Array[TraderState] = []
## Ship ids are "ship_<n>", numbered in creation order so they are stable and deterministic.
var next_ship_number: int = 1
## Workshop ids are "workshop_<n>", numbered the same way.
var next_workshop_number: int = 1
## Route ids are "route_<n>", numbered the same way.
var next_route_number: int = 1
## Running world events (EventSystem), in start order. Ended events are dropped.
var events: Array[EventState] = []
## Event ids are "event_<n>", numbered the same way.
var next_event_number: int = 1
## Goods traders lost on the last day (spoilage, fires), for the UI. Cleared at the start of each
## day and not saved: the goods ledger already books every loss.
var losses: Array[GoodsLoss] = []

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


## Creates a route with the next free id for `trader`.
func add_route(trader: TraderState, route_name: String, stops: Array[RouteStop]) -> RouteState:
	var route := RouteState.new("route_%d" % next_route_number, route_name, stops)
	next_route_number += 1
	trader.routes.append(route)
	return route


## Creates a workshop of `type_id` with the next free id in `kontor`.
func add_workshop(kontor: KontorState, type_id: String) -> WorkshopState:
	var workshop := WorkshopState.new("workshop_%d" % next_workshop_number, type_id)
	next_workshop_number += 1
	kontor.workshops.append(workshop)
	return workshop
