class_name KontorDef
extends RefCounted
## Terms for a kontor, a trader's warehouse in a city (data/buildings.json). Bought once, no rent.

## One-off purchase price in coins.
var price: int
## Units of goods it can hold, all goods together.
var capacity: int


func _init(p_price: int, p_capacity: int) -> void:
	price = p_price
	capacity = p_capacity
