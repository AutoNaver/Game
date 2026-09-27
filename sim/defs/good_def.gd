class_name GoodDef
extends RefCounted
## Static definition of a tradeable good, loaded from data/goods.json.

const CATEGORIES: PackedStringArray = ["raw", "processed", "luxury"]

var id: String
var name: String
var category: String
## Reference price in coins per unit; market prices move around it.
var base_price: int
## Units the population eats or uses per day, per 1000 citizens.
var consumption_per_1000: float


func _init(
	p_id: String,
	p_name: String,
	p_category: String,
	p_base_price: int,
	p_consumption_per_1000: float,
) -> void:
	id = p_id
	name = p_name
	category = p_category
	base_price = p_base_price
	consumption_per_1000 = p_consumption_per_1000
