class_name BuyShipCommand
extends Command
## Buys a new ship from a city's shipyard; it starts docked there, empty.

var trader_id: String
var city_id: String
var ship_type_id: String


func _init(p_trader_id: String, p_city_id: String, p_ship_type_id: String) -> void:
	trader_id = p_trader_id
	city_id = p_city_id
	ship_type_id = p_ship_type_id


func validate(sim: Simulation) -> String:
	var trader := sim.world.get_trader(trader_id)
	var ship_type := sim.data.get_ship(ship_type_id)
	var error := ""
	if trader == null:
		error = "unknown trader '%s'" % trader_id
	elif not sim.data.has_city(city_id):
		error = "unknown city '%s'" % city_id
	elif ship_type == null:
		error = "unknown ship type '%s'" % ship_type_id
	elif ship_type.price > trader.coins:
		error = "A %s costs %d coins, you have %d" % [ship_type.name, ship_type.price, trader.coins]
	return error


func apply(sim: Simulation) -> void:
	var trader := sim.world.get_trader(trader_id)
	var ship_type := sim.data.get_ship(ship_type_id)
	trader.coins -= ship_type.price
	var ship_name := "%s %d" % [ship_type.name, sim.world.next_ship_number]
	sim.world.add_ship(trader, ship_type_id, ship_name, city_id)
