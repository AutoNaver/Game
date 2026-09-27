class_name ScenarioDef
extends RefCounted
## How a new game starts, loaded from data/scenario.json.


class StartingShip:
	extends RefCounted
	var type_id: String
	var name: String

	func _init(p_type_id: String, p_name: String) -> void:
		type_id = p_type_id
		name = p_name


var start_city: String
var coins: int
var ships: Array[StartingShip] = []


func _init(p_start_city: String, p_coins: int, p_ships: Array[StartingShip]) -> void:
	start_city = p_start_city
	coins = p_coins
	ships = p_ships
