class_name FactorOrder
extends RefCounted
## A kontor factor's standing order for one good (ADR 0015), carried out once a day through the
## same trade commands the player uses.

enum Action { BUY, SELL }

var action: Action
var good_id: String
## BUY fills the kontor up to this many units; SELL sells down to this many.
var amount: int
## Coins per unit: BUY never pays more for a unit, SELL never takes less. 0 means no limit.
var price_limit: int


func _init(p_action: Action, p_good_id: String, p_amount: int, p_price_limit: int = 0) -> void:
	action = p_action
	good_id = p_good_id
	amount = p_amount
	price_limit = p_price_limit


func duplicate_order() -> FactorOrder:
	return FactorOrder.new(action, good_id, amount, price_limit)


## "" if `orders` are a valid order list for one kontor, otherwise the first problem.
static func check(data: GameData, orders: Array[FactorOrder]) -> String:
	var seen: Dictionary[String, bool] = {}
	for order in orders:
		var good := data.get_good(order.good_id)
		if good == null:
			return "unknown good '%s'" % order.good_id
		if seen.has(good.id):
			return "The factor takes one order per good (%s twice)" % good.name
		seen[good.id] = true
		if order.amount < 0 or order.amount > data.kontor.capacity:
			return "%s: amount must be 0 to %d" % [good.name, data.kontor.capacity]
		if order.price_limit < 0:
			return "%s: price limit must not be negative" % good.name
	return ""
