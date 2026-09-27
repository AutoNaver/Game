class_name CityDef
extends RefCounted
## Static definition of a city, loaded from data/cities.json.

var id: String
var name: String
## Position on the world map in map units (not pixels).
var map_position: Vector2
## Starting population.
var population: int


func _init(p_id: String, p_name: String, p_map_position: Vector2, p_population: int) -> void:
	id = p_id
	name = p_name
	map_position = p_map_position
	population = p_population
