class_name SetFactorOrdersCommand
extends Command
## Replaces the standing orders of the trader's factor at their kontor in a city (ADR 0015).
## An empty list dismisses the factor.

var trader_id: String
var city_id: String
var orders: Array[FactorOrder]


func _init(p_trader_id: String, p_city_id: String, p_orders: Array[FactorOrder]) -> void:
	trader_id = p_trader_id
	city_id = p_city_id
	orders = p_orders


func validate(sim: Simulation) -> String:
	var trader := sim.world.get_trader(trader_id)
	if trader == null:
		return "unknown trader '%s'" % trader_id
	if trader.get_kontor(city_id) == null:
		return "You have no kontor in %s" % Command.city_name(sim, city_id)
	var locked := RankSystem.unlock_error(sim.data, trader, RankDef.FACTORS, "Factors")
	if not locked.is_empty() and not orders.is_empty():
		return locked
	return FactorOrder.check(sim.data, orders)


func apply(sim: Simulation) -> void:
	var kontor := sim.world.get_trader(trader_id).get_kontor(city_id)
	kontor.factor_orders.clear()
	for order in orders:
		kontor.factor_orders.append(order.duplicate_order())
