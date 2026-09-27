class_name GameData
extends RefCounted
## All static definitions the simulation runs on.
##
## The arrays keep file order so iteration is deterministic; use the getters for lookups by id.

var economy: EconomyDef
var scenario: ScenarioDef
var map: MapDef
var goods: Array[GoodDef] = []
var cities: Array[CityDef] = []
var ships: Array[ShipDef] = []

var _goods_by_id: Dictionary[String, GoodDef] = {}
var _cities_by_id: Dictionary[String, CityDef] = {}
var _ships_by_id: Dictionary[String, ShipDef] = {}


func add_good(good: GoodDef) -> void:
	assert(not has_good(good.id), "duplicate good id '%s'" % good.id)
	goods.append(good)
	_goods_by_id[good.id] = good


func add_city(city: CityDef) -> void:
	assert(not has_city(city.id), "duplicate city id '%s'" % city.id)
	cities.append(city)
	_cities_by_id[city.id] = city


func add_ship(ship: ShipDef) -> void:
	assert(not has_ship(ship.id), "duplicate ship id '%s'" % ship.id)
	ships.append(ship)
	_ships_by_id[ship.id] = ship


func has_good(id: String) -> bool:
	return _goods_by_id.has(id)


func has_city(id: String) -> bool:
	return _cities_by_id.has(id)


func has_ship(id: String) -> bool:
	return _ships_by_id.has(id)


## Returns null for unknown ids.
func get_good(id: String) -> GoodDef:
	return _goods_by_id.get(id)


## Returns null for unknown ids.
func get_city(id: String) -> CityDef:
	return _cities_by_id.get(id)


## Returns null for unknown ids.
func get_ship(id: String) -> ShipDef:
	return _ships_by_id.get(id)
