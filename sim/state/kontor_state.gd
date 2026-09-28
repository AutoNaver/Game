class_name KontorState
extends Hold
## A trader's warehouse in one city, holding goods (the Hold it extends) and the trader's
## workshops there. Capacity is GameData.kontor.capacity.

var city_id: String
## In build order.
var workshops: Array[WorkshopState] = []
## The factor's standing orders, run daily in this order (FactorSystem). At most one per good.
var factor_orders: Array[FactorOrder] = []


func _init(p_city_id: String) -> void:
	city_id = p_city_id
