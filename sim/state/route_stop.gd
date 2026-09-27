class_name RouteStop
extends RefCounted
## A city on a route and the orders carried out there, in order.

var city_id: String
var orders: Array[RouteOrder] = []


func _init(p_city_id: String, p_orders: Array[RouteOrder] = []) -> void:
	city_id = p_city_id
	orders = p_orders


func duplicate_stop() -> RouteStop:
	var copies: Array[RouteOrder] = []
	for order in orders:
		copies.append(order.duplicate_order())
	return RouteStop.new(city_id, copies)
