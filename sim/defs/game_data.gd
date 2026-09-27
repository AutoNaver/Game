class_name GameData
extends RefCounted
## All static definitions the simulation runs on.
##
## The arrays keep file order so iteration is deterministic; use the getters for lookups by id.

var goods: Array[GoodDef] = []
var cities: Array[CityDef] = []

var _goods_by_id: Dictionary[String, GoodDef] = {}
var _cities_by_id: Dictionary[String, CityDef] = {}


func add_good(good: GoodDef) -> void:
	assert(not has_good(good.id), "duplicate good id '%s'" % good.id)
	goods.append(good)
	_goods_by_id[good.id] = good


func add_city(city: CityDef) -> void:
	assert(not has_city(city.id), "duplicate city id '%s'" % city.id)
	cities.append(city)
	_cities_by_id[city.id] = city


func has_good(id: String) -> bool:
	return _goods_by_id.has(id)


func has_city(id: String) -> bool:
	return _cities_by_id.has(id)


## Returns null for unknown ids.
func get_good(id: String) -> GoodDef:
	return _goods_by_id.get(id)


## Returns null for unknown ids.
func get_city(id: String) -> CityDef:
	return _cities_by_id.get(id)
