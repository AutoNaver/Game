class_name BuyKontorCommand
extends Command
## Buys the trader a kontor (warehouse) in a city. One per city per trader; bought once, no rent.

var trader_id: String
var city_id: String


func _init(p_trader_id: String, p_city_id: String) -> void:
	trader_id = p_trader_id
	city_id = p_city_id


func validate(sim: Simulation) -> String:
	var trader := sim.world.get_trader(trader_id)
	var price := sim.data.kontor.price
	var error := ""
	if trader == null:
		error = "unknown trader '%s'" % trader_id
	elif not sim.data.has_city(city_id):
		error = "unknown city '%s'" % city_id
	elif trader.get_kontor(city_id) != null:
		error = "You already have a kontor in %s" % Command.city_name(sim, city_id)
	elif price > trader.coins:
		error = "A kontor costs %d coins, you have %d" % [price, trader.coins]
	return error


func apply(sim: Simulation) -> void:
	var trader := sim.world.get_trader(trader_id)
	trader.coins -= sim.data.kontor.price
	trader.kontors[city_id] = KontorState.new(city_id)
