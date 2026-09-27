class_name WorldState
extends RefCounted
## Everything in the world that changes over time. The single source of randomness lives here.

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

var _cities_by_id: Dictionary[String, CityState] = {}


func add_city(city: CityState) -> void:
	assert(not _cities_by_id.has(city.id), "duplicate city id '%s'" % city.id)
	cities.append(city)
	_cities_by_id[city.id] = city


## Returns null for unknown ids.
func get_city(id: String) -> CityState:
	return _cities_by_id.get(id)
