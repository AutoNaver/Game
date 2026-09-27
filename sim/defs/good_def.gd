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
## Share of the units stored in ships and kontors that spoils each day (0 for goods that keep).
var spoilage_per_day: float = 0.0
## First save version whose world has this entry (data "since_save", default 1). Saves from before
## it get the entry added as a new game starts it; later saves must contain it (SaveGame).
var since_save: int = 1


func _init(
	p_id: String,
	p_name: String,
	p_category: String,
	p_base_price: int,
	p_consumption_per_1000: float,
	p_spoilage_per_day: float = 0.0,
) -> void:
	id = p_id
	name = p_name
	category = p_category
	base_price = p_base_price
	consumption_per_1000 = p_consumption_per_1000
	spoilage_per_day = p_spoilage_per_day
