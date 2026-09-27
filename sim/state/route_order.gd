class_name RouteOrder
extends RefCounted
## One thing a ship on a route does at a stop: buy, sell, load from the kontor or unload into it.

enum Action { BUY, SELL, LOAD, UNLOAD }

var action: Action
var good_id: String
## Most units handled per visit. Less when stock, space, coins or the price limit run out first.
var quantity: int
## Coins per unit: BUY never pays more for a unit, SELL never takes less. 0 means no limit.
## Unused by LOAD and UNLOAD.
var price_limit: int


func _init(p_action: Action, p_good_id: String, p_quantity: int, p_price_limit: int = 0) -> void:
	action = p_action
	good_id = p_good_id
	quantity = p_quantity
	price_limit = p_price_limit


func duplicate_order() -> RouteOrder:
	return RouteOrder.new(action, good_id, quantity, price_limit)
