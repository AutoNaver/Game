class_name CityDef
extends RefCounted
## Static definition of a city, loaded from data/cities.json.

var id: String
var name: String
## Position on the world map in map units (not pixels).
var map_position: Vector2
## Starting population.
var population: int
## Units the city's own workshops produce per day, by good id. Goods not listed are not produced.
var production: Dictionary[String, float]


func _init(
	p_id: String,
	p_name: String,
	p_map_position: Vector2,
	p_population: int,
	p_production: Dictionary[String, float],
) -> void:
	id = p_id
	name = p_name
	map_position = p_map_position
	population = p_population
	production = p_production


## Units produced per day of `good_id`; 0 if the city does not make it.
func production_of(good_id: String) -> float:
	return production.get(good_id, 0.0)
