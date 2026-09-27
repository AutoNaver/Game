class_name CityDef
extends RefCounted
## Static definition of a city, loaded from data/cities.json.

var id: String
var name: String
## Position on the world map in map units: km from the map's north-west corner (see MapDef).
var map_position: Vector2
## Starting population.
var population: int
## Units the city's own workshops produce per day, by good id. Goods not listed are not produced.
var production: Dictionary[String, float]
## Multiplies the city's off-map imports (OffMapTradeSystem): trade beyond the map that the game
## doesn't model, such as Bergen's with England and the Low Countries. 1 for most cities.
var import_factor: float = 1.0
## First save version whose world has this entry (data "since_save", default 1). Saves from before
## it get the entry added as a new game starts it; later saves must contain it (SaveGame).
var since_save: int = 1


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
