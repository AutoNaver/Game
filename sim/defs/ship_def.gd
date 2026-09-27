class_name ShipDef
extends RefCounted
## Static definition of a ship type, loaded from data/ships.json.

var id: String
var name: String
## Cargo space in units of goods (every good takes one unit of space for now).
var capacity: int
## Map units travelled per hour.
var speed: float
## Purchase price in coins.
var price: int


func _init(p_id: String, p_name: String, p_capacity: int, p_speed: float, p_price: int) -> void:
	id = p_id
	name = p_name
	capacity = p_capacity
	speed = p_speed
	price = p_price
